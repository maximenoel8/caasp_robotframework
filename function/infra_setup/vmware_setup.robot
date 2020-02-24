*** Settings ***
Resource          common.robot

*** Keywords ***
configure terraform tfvars vmware
    ${terraform_tvars}    OperatingSystem.Get File    ${TERRAFORMDIR}/terraform.tfvars.example
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_datastore = ""    vsphere_datastore = "3PAR"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_datacenter = ""    vsphere_datacenter = "PROVO"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_network = ""    vsphere_network = "VM Network"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_resource_pool = ""    vsphere_resource_pool = "CaaSP_RP"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    template_name = ""    template_name = "SLES15-SP1-GM-up191203-guestinfo"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    stack_name = "caasp-v4"    stack_name = "${CLUSTER_PREFIX}"
    ${terraform_tvars}    configure terraform file common    ${terraform_tvars}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    worker_disk_size = 40    worker_disk_size = 80
    Create File    ${TERRAFORMDIR}/terraform.tfvars    ${terraform_tvars}
    Append To File    ${TERRAFORMDIR}/terraform.tfvars    worker_cpus = 8 \n
    Append To File    ${TERRAFORMDIR}/terraform.tfvars    worker_memory = 16384 \n

set vmware env variables
    ${keys}    Get Dictionary Keys    ${VMWARE}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${VMWARE["${key}"]}
    END
