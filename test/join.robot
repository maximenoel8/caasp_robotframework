*** Settings ***
Suite Teardown    Close All Connections
Resource          ../function/install_tools.robot
Resource          ../function/helpers.robot
Resource          ../function/helm.robot
Resource          ../function/skuba_join.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/rbac.robot

*** Test Cases ***
bootstrap
    Given cluster running
    And helm install

check pod running
    389ds server installed
