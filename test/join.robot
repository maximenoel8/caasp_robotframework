*** Settings ***
Resource          ../function/cluster_helpers.robot
Resource          ../function/helm.robot
Resource          ../function/skuba_join.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/rbac.robot
Resource          ../function/tools.robot
Resource          ../parameters/tool_parameters.robot

*** Test Cases ***
deploy cluster
    Given cluster running
    And helm is installed

deploy cluster with nfs
    Given cluster running
    And helm is installed
    And nfs client is deployed    ${NFS_IP}    ${NFS_PATH}