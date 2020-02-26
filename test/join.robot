*** Settings ***
Resource          ../function/cluster_helpers.robot
Resource          ../function/helm.robot
Resource          ../function/skuba_join.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/rbac.robot

*** Test Cases ***
deploy cluster
    Given cluster running
    And helm install
