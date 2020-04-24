*** Settings ***
Resource          ../function/cluster_helpers.robot
Resource          ../function/helm.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/tools.robot
Resource          ../parameters/tool_parameters.robot
Resource          ../function/setup_environment.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
deploy cluster
    [Tags]    upgrade    release    backup
    Given cluster running
    And helm is installed
    [Teardown]    teardown deploy

deploy double cluster
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL"    deploy cluster vms
    load vm ip
    create ssh session with workstation and nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    cluster is deployed
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait nodes are ready
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait pods ready
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait cillium
    wait nodes are ready    cluster_number=2
    wait pods ready    cluster_number=2
    wait cillium    cluster_number=2

deploy bare server
    [Tags]    bare
    ${cluster_number}    Set Variable    1
    set infra env parameters
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL" and ${cluster_number}==1    deploy cluster vms
    load vm ip

load ip
    load vm ip

*** Keywords ***
teardown deploy
    Run Keyword If Test Failed    Fatal Error
    [Teardown]    teardown_test
