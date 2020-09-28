*** Settings ***
Resource          common.robot

*** Keywords ***
set openstack env variables
    ${keys}    Get Dictionary Keys    ${OPENSTACK}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${OPENSTACK["${key}"]}
    END

configure terraform tfvars openstack
    ${template}    Set Variable If    "${VM_VERSION}"=="SP1"    SLES15-SP1-JeOS.x86_64-QU1    SLES15-SP2-JeOS.x86_64-15.2-OpenStack-Cloud-GM
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        _modify master and worker instances    ${cluster_number}
        &{openstack_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Set To Dictionary    ${openstack_dico}    image_name    ${template}
        Set To Dictionary    ${openstack_dico}    internal_net    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${openstack_dico}    external_net    floating
        Set To Dictionary    ${openstack_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${openstack_dico}    subnet_cidr    172.28.0.0/24
        Set To Dictionary    ${openstack_dico}    master_size    m1.large
        Set To Dictionary    ${openstack_dico}    worker_size    m1.xxlarge
        Set To Dictionary    ${openstack_dico}    repositories    ${REPOS_LIST}
        Set To Dictionary    ${openstack_dico}    hostname_from_dhcp    ${true}
        _create package list    ${openstack_dico}
        ${openstack_dico}    configure terraform file common    ${openstack_dico}
        _create tvars json file    ${openstack_dico}    ${cluster_number}
    END

_modify master and worker instances
    [Arguments]    ${cluster_number}
    ${master_file}    OperatingSystem.Get File    ${TERRAFORMDIR}/cluster_${cluster_number}/master-instance.tf
    ${worker_file}    OperatingSystem.Get File    ${TERRAFORMDIR}/cluster_${cluster_number}/worker-instance.tf
    ${master_file}    Replace String    ${master_file}    caasp-master-\${var.stack_name}-\${count.index}    \${var.stack_name}-master-\${count.index}
    ${worker_file}    Replace String    ${worker_file}    caasp-worker-\${var.stack_name}-\${count.index}    \${var.stack_name}-worker-\${count.index}
    create file    ${TERRAFORMDIR}/cluster_${cluster_number}/master-instance.tf    ${master_file}
    create file    ${TERRAFORMDIR}/cluster_${cluster_number}/worker-instance.tf    ${worker_file}

add cap security group
    @{workers}    get worker servers name
    FOR    ${worker}    IN    @{workers}
        execute command localy    openstack server add security group ${worker} validator-cap
    END
