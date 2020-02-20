*** Settings ***
Suite Teardown    Close All Connections
Resource          ../function/helpers.robot
Resource          ../function/helm.robot
Resource          ../function/skuba_join.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/rbac.robot

*** Test Cases ***
deploy cluster
    Comment    Given cluster running
    set_vmware_env_variables
    clean cluster
