*** Settings ***
Resource          common.robot

*** Keywords ***
set openstack env variables
    ${keys}    Get Dictionary Keys    ${OPENSTACK}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${OPENSTACK["${key}"]}
    END

configure terraform tfvars openstack
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{openstack_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Set To Dictionary    ${openstack_dico}    image_name    SLES15-SP1-JeOS.x86_64-QU1
        Set To Dictionary    ${openstack_dico}    internal_net    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${openstack_dico}    external_net    floating
        Set To Dictionary    ${openstack_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${openstack_dico}    subnet_cidr    172.28.0.0/24
        Set To Dictionary    ${openstack_dico}    master_size    m1.large
        Set To Dictionary    ${openstack_dico}    worker_size    m1.xxlarge
        ${openstack_dico}    configure terraform file common    ${openstack_dico}
        _create tvars json file    ${openstack_dico}    ${cluster_number}
    END
