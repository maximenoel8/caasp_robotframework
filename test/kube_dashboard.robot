*** Settings ***
Resource          ../function/tests/kube_dashboard.robot
Resource          ../function/skuba_join.robot

*** Test Cases ***
kube dashboard
    [Tags]    release
    Given cluster running
    And kubernetes dashboard is deployed
    and deploy selenium pod
    Then fail to login authorized user without admin rights and list namespaces
    When create a service account for dashboard and grant access to kube-system namespace
    then login authorized user with admin rights and list namespaces
    [Teardown]    teardown kube dashboard
