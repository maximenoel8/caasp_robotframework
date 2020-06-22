*** Settings ***
Resource          common.robot
Resource          ../../parameters/vm_deployment.robot

*** Keywords ***
configure terraform tfvars azure
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{azure_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        ${zone_list}    Create List    1    2    3
        ${ntp_servers}    create list    0.novell.pool.ntp.org    1.novell.pool.ntp.org    2.novell.pool.ntp.org    3.novell.pool.ntp.org
        Set To Dictionary    ${azure_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${azure_dico}    azure_location    West Europe
        Set To Dictionary    ${azure_dico}    enable_zone    ${true}
        Set To Dictionary    ${azure_dico}    azure_availability_zones    ${zone_list}
        Set To Dictionary    ${azure_dico}    cidr_block    10.1.0.0/16
        Set To Dictionary    ${azure_dico}    private_subnet_cidr    10.1.4.0/24
        Set To Dictionary    ${azure_dico}    dnsdomain    ${CLUSTER_PREFIX}-${cluster_number}.example.com
        Set To Dictionary    ${azure_dico}    create_bastionhost    ${false}
        Set To Dictionary    ${azure_dico}    master_vm_size    Standard_D2s_v3
        Set To Dictionary    ${azure_dico}    master_storage_account_type    StandardSSD_LRS
        Set To Dictionary    ${azure_dico}    master_disk_size    ${30}
        Set To Dictionary    ${azure_dico}    worker_vm_size    Standard_D2s_v3
        Set To Dictionary    ${azure_dico}    worker_storage_account_type    StandardSSD_LRS
        Set To Dictionary    ${azure_dico}    worker_disk_size    ${30}
        Set To Dictionary    ${azure_dico}    ntp_servers    ${ntp_servers}
        Set To Dictionary    ${azure_dico}    repositories    ${REPOS_LIST}
        ${azure_dico}    configure terraform file common    ${azure_dico}
        _create tvars json file    ${azure_dico}    ${cluster_number}
    END

set azure env variables
    Set Environment Variable    ARM_CLIENT_ID    ${AZURE["client_id"]}
    Set Environment Variable    ARM_CLIENT_SECRET    ${AZURE["client_secret"]}
    Set Environment Variable    ARM_SUBSCRIPTION_ID    ${AZURE["subscription_id"]}
    Set Environment Variable    ARM_TENANT_ID    ${AZURE["tenant_id"]}
