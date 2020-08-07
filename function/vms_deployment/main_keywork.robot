*** Settings ***
Resource          vmware_setup.robot
Resource          aws_setup.robot
Resource          openstack_setup.robot
Resource          libvirt_setup.robot
Resource          ../tools.robot
Resource          ../terraform_files_change.robot
Resource          azure_setup.robot

*** Keywords ***
deploy cluster vms
    [Arguments]    ${redeploy}=False
    step    Deploying vm on \ ${PLATFORM} ...
    Run Keyword If    ${redeploy}    copy terraform from temporay
    ...    ELSE    copy terraform configuration
    set repo and packages
    Run Keyword If    "${MODE}"=="${EMPTY}" or "${MODE}"=="RELEASE" or "${PLATFORM}"=="aws" or "${PLATFORM}"=="azure"    Run Keyword And Ignore Error    configure registration auto tfvars vmware
    Run Keyword If    "${PLATFORM}"=="vmware"    configure terraform tfvars vmware
    ...    ELSE IF    "${PLATFORM}"=="openstack"    Configure terraform tfvars openstack
    ...    ELSE IF    "${PLATFORM}"=="libvirt"    configure terraform tfvars libvirt
    ...    ELSE IF    "${PLATFORM}"=="aws"    configure terraform tvars aws
    ...    ELSE IF    "${PLATFORM}"=="azure"    configure terraform tfvars azure
    ...    ELSE    Fail    Wrong platform
    run terraform
    step    vms are deployed
    Set Global Variable    ${PLATFORM_DEPLOY}    PASS
    Run Keyword If    "${PLATFORM}"=="aws"    sleep    30

set infra env parameters
    Run Keyword If    "${PLATFORM}"=="vmware"    Set vmware env variables
    ...    ELSE IF    "${PLATFORM}"=="openstack"    Set openstack env variables
    ...    ELSE IF    "${PLATFORM}"=="azure"    set azure env variables
    ...    ELSE IF    "${PLATFORM}"=="aws"    set aws env variables
