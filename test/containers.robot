*** Settings ***
Resource          ../function/tests/nginx.robot
Resource          ../function/skuba_commands.robot

*** Test Cases ***
nginx container
    [Tags]    release
    Given cluster running
    And nginx is deployed old
    Then can access nginx server
