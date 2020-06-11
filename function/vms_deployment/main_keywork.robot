*** Settings ***
Resource          vmware_setup.robot
Resource          aws_setup.robot
Resource          openstack_setup.robot
Resource          libvirt_setup.robot
Resource          ../tools.robot
Resource          ../terraform_files_change.robot

*** Keywords ***
deploy cluster vms
    [Arguments]    ${redeploy}=False
    step    Deploying vm on \ ${PLATFORM} ...
    Run Keyword If    ${redeploy}    copy terraform from temporay
    ...    ELSE    copy terraform configuration from skuba folder
    set repo and packages
    Run Keyword If    "${MODE}"=="${EMPTY}" or "${MODE}"=="RELEASE"    Run Keyword And Ignore Error    configure registration auto tfvars vmware
    Run Keyword If    "${PLATFORM}"=="vmware"    configure terraform tfvars vmware
    ...    ELSE IF    "${PLATFORM}"=="openstack"    Configure terraform tfvars openstack
    ...    ELSE IF    "${PLATFORM}"=="libvirt"    configure terraform tfvars libvirt
    ...    ELSE IF    "${PLATFORM}"=="aws"    configure terraform tvars aws
    ...    ELSE    Fail    Wrong platform
    run terraform
    step    vms are deployed
    Set Global Variable    ${PLATFORM_DEPLOY}    PASS

set infra env parameters
    Set vmware env variables
    Set openstack env variables
