*** Settings ***
Resource          vmware_setup.robot
Resource          aws_setup.robot
Resource          openstack_setup.robot

*** Keywords ***
deploy cluster vms
    get skuba tool
    get terraform configuration
    set infra env parameters
    &{variable}    Get Environment Variables
    Log Dictionary    ${variable}
    Run Keyword If    "${MODE}"=="${EMPTY}"    configure registration auto tfvars vmware
    ...    ELSE    set repo and packages
    Run Keyword If    "${PLATFORM}"=="vmware"    configure terraform tfvars vmware
    ...    ELSE IF    "${PLATFORM}"=="openstack"    Configure terraform tfvars openstack
    run terraform

set infra env parameters
    Set vmware env variables
    Set openstack env variables

teardown_suite
    Run Keyword And Ignore Error    Copy Files    ${OUTPUT_DIR}/*    ${LOGDIR}
    Run Keyword And Ignore Error    Run Keyword Unless    ${KEEP}    clean cluster    ${CLUSTER}
    Run Keyword And Ignore Error    dump cluster state
