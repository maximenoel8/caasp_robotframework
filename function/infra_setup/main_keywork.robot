*** Settings ***
Resource          vmware_setup.robot
Resource          aws_setup.robot
Resource          openstack_setup.robot
Resource          libvirt_setup.robot

*** Keywords ***
deploy cluster vms
    Comment    clone skuba locally
    copy terraform configuration from skuba folder
    set infra env parameters
    Run Keyword If    "${MODE}"=="${EMPTY}"    Run Keyword And Ignore Error    configure registration auto tfvars vmware
    ...    ELSE    set repo and packages
    Run Keyword If    "${PLATFORM}"=="vmware"    configure terraform tfvars vmware
    ...    ELSE IF    "${PLATFORM}"=="openstack"    Configure terraform tfvars openstack
    ...    ELSE IF    "${PLATFORM}"=="libvirt"    configure terraform tfvars libvirt
    ...    ELSE IF    "${PLATFORM}"=="aws"    configure terraform tvars aws
    ...    ELSE    Fail    Wrong platform
    run terraform

set infra env parameters
    Set vmware env variables
    Set openstack env variables
