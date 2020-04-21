*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/tests/nginx.robot

*** Test Cases ***
nginx ingress
    [Tags]    release
    Given cluster running
    And nginx is deployed
    When resources pear and apple are deployed
    And nginx ingress is patched
    Then service should be accessible
    [Teardown]    teardown nginx testcase
