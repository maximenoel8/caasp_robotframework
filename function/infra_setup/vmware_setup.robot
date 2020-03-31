*** Settings ***
Resource          common.robot

*** Keywords ***
configure terraform tfvars vmware
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{vmware_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Set To Dictionary    ${vmware_dico}    vsphere_datastore    3PAR
        Set To Dictionary    ${vmware_dico}    vsphere_datacenter    PROVO
        Set To Dictionary    ${vmware_dico}    vsphere_network    VM Network
        Set To Dictionary    ${vmware_dico}    vsphere_resource_pool    CaaSP_RP
        Set To Dictionary    ${vmware_dico}    template_name    SLES15-SP1-GM-up191203-guestinfo
        Set To Dictionary    ${vmware_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${vmware_dico}    worker_disk_size    ${80}
        Set To Dictionary    ${vmware_dico}    worker_cpus    ${8}
        Set To Dictionary    ${vmware_dico}    worker_memory    ${16384}
        Set To Dictionary    ${vmware_dico}    repositories    ${REPOS_LIST}
        ${vmware_dico}    configure terraform file common    ${vmware_dico}
        _create tvars json file    ${vmware_dico}    ${cluster_number}
    END

set vmware env variables
    ${keys}    Get Dictionary Keys    ${VMWARE}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${VMWARE["${key}"]}
    END
