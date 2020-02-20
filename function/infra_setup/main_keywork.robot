*** Settings ***
Resource          vmware_setup.robot
Resource          aws_setup.robot

*** Keywords ***
deploy cluster vms
    get skuba tool
    get terraform configuration
    set_vmware_env_variables
    Run Keyword If    "${MODE}"=="${EMPTY}"    configure_registration_auto_tfvars_vmware
    ...    ELSE    set_repo_and_packages
    configure_vmware
    run terraform
