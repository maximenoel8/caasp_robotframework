*** Settings ***
Resource          common.robot

*** Keywords ***
configure_vmware
    configure_terraform_tfvars_vmware

configure_terraform_tfvars_vmware
    ${terraform_tvars}    OperatingSystem.Get File    ${TERRAFORMDIR}/terraform.tfvars.example
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_datastore = ""    vsphere_datastore = "3PAR"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_datacenter = ""    vsphere_datacenter = "PROVO"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_network = ""    vsphere_network = "VM Network"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    vsphere_resource_pool = ""    vsphere_resource_pool = "CaaSP_RP"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    template_name = ""    template_name = "SLES15-SP1-GM-up191203-guestinfo"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    stack_name = "caasp-v4"    stack_name = "${SUFFIX}-${CLUSTER}"
    ${terraform_tvars}    Replace String    ${terraform_tvars}    masters = 1    masters = ${VM_NUMBER[0]}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    workers = 2    workers = ${VM_NUMBER[1]}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    worker_disk_size = 40    worker_disk_size = 80
    ${terraform_tvars}    Replace String    ${terraform_tvars}    repositories = {}    repositories = {\n\t${REPOS_LIST}\n}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    packages = [    packages = [ ${PACKAGEs_LIST}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    authorized_keys = []    authorized_keys = [ "${SSH_PUB_KEY}" ]
    Create File    ${TERRAFORMDIR}/terraform.tfvars    ${terraform_tvars}
    Append To File    ${TERRAFORMDIR}/terraform.tfvars    worker_cpus = 8 \n
    Append To File    ${TERRAFORMDIR}/terraform.tfvars    worker_memory = 16384 \n

set_vmware_env_variables
    ${keys}    Get Dictionary Keys    ${VMWARE}
    FOR    ${key}    IN    @{keys}
        Set Environment Variable    ${key}    ${VMWARE["${key}"]}
    END
