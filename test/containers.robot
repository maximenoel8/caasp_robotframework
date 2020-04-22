*** Settings ***
Resource          ../function/tests/nginx.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
nginx container
    [Tags]    release
    Given cluster running
    And nginx is deployed old
    Then can access nginx server
