*** Settings ***
Resource          common.robot
Resource          ../../parameters/vm_deployment.robot
Library           JSONLibrary

*** Keywords ***
set azure env variables
    Set Environment Variable    ARM_CLIENT_ID    ${AZURE["client_id"]}
    Set Environment Variable    ARM_CLIENT_SECRET    ${AZURE["client_secret"]}
    Set Environment Variable    ARM_SUBSCRIPTION_ID    ${AZURE["subscription_id"]}
    Set Environment Variable    ARM_TENANT_ID    ${AZURE["tenant_id"]}

_setup azure cloud configuration
    [Arguments]    ${cluster_number}=1
    ${azure_conf}    JSONLibrary.Load JSON From File    ${DATADIR}/cpi/azure.conf.template
    Log Dictionary    ${azure_conf}
    Log    ${AZURE["tenant_id"]}
    Set To Dictionary    ${azure_conf}    tenantId=${AZURE["tenant_id"]}
    Set To Dictionary    ${azure_conf}    subscriptionId=${AZURE["subscription_id"]}
    Set To Dictionary    ${azure_conf}    resourceGroup=${CLUSTER_PREFIX}-${cluster_number}-resource-group
    Set To Dictionary    ${azure_conf}    location=${AZURE["location"]}
    Set To Dictionary    ${azure_conf}    routeTableName=${CLUSTER_PREFIX}-${cluster_number}-route-table
    ${azure_conf_data}    JSONLibrary.Convert JSON To String    ${azure_conf}
    Create File    ${LOGDIR}/azure.conf    ${azure_conf_data}
    Put File    ${LOGDIR}/azure.conf    /home/${VM_USER}/cluster/cloud/azure/

configure terraform tfvars azure
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{azure_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        ${zone_list}    Create List    1    2    3
        ${ntp_servers}    create list    0.novell.pool.ntp.org    1.novell.pool.ntp.org    2.novell.pool.ntp.org    3.novell.pool.ntp.org
        Set To Dictionary    ${azure_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${azure_dico}    azure_location    ${AZURE["location"]}
        Set To Dictionary    ${azure_dico}    enable_zone    ${false}
        comment    Set To Dictionary    ${azure_dico}    azure_availability_zones    ${zone_list}
        Set To Dictionary    ${azure_dico}    cidr_block    10.1.0.0/16
        Set To Dictionary    ${azure_dico}    private_subnet_cidr    10.1.4.0/24
        Set To Dictionary    ${azure_dico}    dnsdomain    ${CLUSTER_PREFIX}-${cluster_number}.example.com
        Set To Dictionary    ${azure_dico}    create_bastionhost    ${false}
        Set To Dictionary    ${azure_dico}    master_vm_size    Standard_D2s_v3
        Set To Dictionary    ${azure_dico}    master_storage_account_type    StandardSSD_LRS
        Set To Dictionary    ${azure_dico}    master_disk_size    ${90}
        Set To Dictionary    ${azure_dico}    worker_vm_size    Standard_D2s_v3
        Set To Dictionary    ${azure_dico}    worker_storage_account_type    StandardSSD_LRS
        Set To Dictionary    ${azure_dico}    worker_disk_size    ${90}
        Set To Dictionary    ${azure_dico}    ntp_servers    ${ntp_servers}
        Set To Dictionary    ${azure_dico}    repositories    ${REPOS_LIST}
        Set To Dictionary    ${azure_dico}    cpi_enable    ${true}
        ${azure_dico}    configure terraform file common    ${azure_dico}
        _create tvars json file    ${azure_dico}    ${cluster_number}
    END
