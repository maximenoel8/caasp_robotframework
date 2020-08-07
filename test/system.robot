*** Settings ***
Suite Setup       Given cluster running
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/system.robot

*** Test Cases ***
skuba update enabled
    [Tags]    release
    Then skuba-update should be enabled

apparmor enabled
    [Tags]    release
    Then apparmor should be running and enabled on all the nodes

swap turned off
    [Tags]    release
    Then swap should be turn off
