*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/system.robot

*** Test Cases ***
skuba update enabled
    [Tags]    release
    Given cluster running
    Then skuba-update should be enabled

apparmor enabled
    [Tags]    release
    Given cluster running
    Then apparmor should be running and enabled on all the nodes

swap turned off
    [Tags]    release
    Given cluster running
    Then swap should be turn off
