*** Settings ***
Resource          ../function/cluster_helpers.robot
Resource          ../function/helm.robot
Resource          ../function/skuba_join.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/rbac.robot
Resource          ../function/tools.robot
Resource          ../parameters/tool_parameters.robot
Resource          ../function/setup_environment.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
deploy cluster
    Given cluster running
    And helm is installed

deploy cluster with nfs
    Given cluster running
    And helm is installed
    And nfs client is deployed    ${NFS_IP}    ${NFS_PATH}

deploy double cluster
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL"    deploy cluster vms
    load vm ip
    open bootstrap session
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    cluster is deployed
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait pods
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait cillium
    wait nodes    cluster_number=2
    wait pods    cluster_number=2
    wait cillium    cluster_number=2
