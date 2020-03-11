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
        ${terraform_tvars}    OperatingSystem.Get File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        ${terraform_tvars}    Replace String    ${terraform_tvars}    image_name = ""    image_name = "SLES15-SP1-JeOS.x86_64-QU1"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    internal_net = ""    internal_net = "${CLUSTER_PREFIX}-${cluster_number}"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    external_net = ""    external_net = "floating"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    stack_name = "my-caasp-cluster"    stack_name = "${CLUSTER_PREFIX}-${cluster_number}"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    subnet_cidr = ""    subnet_cidr = "172.28.0.0\/24"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    master_size = ""    master_size = "m1.large"
        ${terraform_tvars}    Replace String    ${terraform_tvars}    worker_size = ""    worker_size = "m1.xxlarge"
        ${terraform_tvars}    configure terraform file common    ${terraform_tvars}
        Create File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars    ${terraform_tvars}
    END
