*** Settings ***
Resource          common.robot
Resource          ../../parameters/vm_deployment.robot

*** Keywords ***
configure terraform tfvars vmware
    ${cpi_enable}    Set Variable If    ${CPI_VSPHERE}    true    false
    ${hostname_from_dhcp}    Set Variable If    ${DNS_HOSTNAME}    true    false
    ${template}    Set Variable If    "${VM_VERSION}"=="SP1"    SLES15-SP1-GM-up191203-guestinfo    SLES15-SP2-GMC-up200615-guestinfo
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{vmware_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Remove From Dictionary    ${vmware_dico}    vsphere_datastore
        Set To Dictionary    ${vmware_dico}    vsphere_datacenter    ${DATACENTER}
        Set To Dictionary    ${vmware_dico}    vsphere_network    VM Network
        Set To Dictionary    ${vmware_dico}    vsphere_resource_pool    ${RESSOURCE_POOL}
        Set To Dictionary    ${vmware_dico}    template_name    ${template}
        Set To Dictionary    ${vmware_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${vmware_dico}    worker_disk_size    ${80}
        Set To Dictionary    ${vmware_dico}    worker_cpus    ${8}
        Set To Dictionary    ${vmware_dico}    worker_memory    ${16384}
        Set To Dictionary    ${vmware_dico}    vsphere_datastore_cluster    LOCAL-DISKS-CLUSTER
        Set To Dictionary    ${vmware_dico}    cpi_enable    ${${cpi_enable}}
        Set To Dictionary    ${vmware_dico}    hostname_from_dhcp    ${${hostname_from_dhcp}}
        Set To Dictionary    ${vmware_dico}    repositories    ${REPOS_LIST}
        _create package list    ${vmware_dico}
        ${vmware_dico}    configure terraform file common    ${vmware_dico}
        _create tvars json file    ${vmware_dico}    ${cluster_number}
    END

set vmware env variables
    ${keys}    Get Dictionary Keys    ${VMWARE}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${VMWARE["${key}"]}
        Set Global Variable    ${${key}}    ${VMWARE["${key}"]}
    END

_change_vsphere_datastorage
    [Arguments]    ${cluster_number}
    modify string in file    ${TERRAFORMDIR}/cluster_${cluster_number}/variables.tf    datastore    datastore_cluster
    modify string in file    ${TERRAFORMDIR}/cluster_${cluster_number}/master-instance.tf    datastore    datastore_cluster
    modify string in file    ${TERRAFORMDIR}/cluster_${cluster_number}/worker-instance.tf    datastore    datastore_cluster

_setup vsphere cloud configuration
    [Arguments]    ${cluster_number}
    _create vsphere cloud configuration
    Put File    ${LOGDIR}/vsphere.conf    /home/${VM_USER}/cluster/cloud/vsphere/

copy vsphere cloud configuration to all nodes
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    _create vsphere cloud configuration
    FOR    ${node}    IN    @{nodes}
        Switch Connection    ${node}
        Put File    ${LOGDIR}/vsphere.conf    /home/${VM_USER}/
        execute command with ssh    sudo cp /home/${VM_USER}/vsphere.conf /etc/kubernetes/    ${node}
    END

_create vsphere cloud configuration
    [Arguments]    ${cluster_number}=1
    Copy File    ${DATADIR}/cpi/vsphere.conf.template    ${LOGDIR}/vsphere.conf
    modify string in file    ${LOGDIR}/vsphere.conf    <user>    ${vmware["VSPHERE_USER"]}
    modify string in file    ${LOGDIR}/vsphere.conf    <password>    ${vmware["VSPHERE_PASSWORD"]}
    modify string in file    ${LOGDIR}/vsphere.conf    <stack>    ${CLUSTER_PREFIX}-${cluster_number}
