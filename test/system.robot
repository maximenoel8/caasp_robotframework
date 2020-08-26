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
    refresh ssh session
    Then apparmor should be running and enabled on all the nodes

swap turned off
    [Tags]    release
    refresh ssh session
    Then swap should be turn off
