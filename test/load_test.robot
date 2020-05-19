*** Settings ***
Suite Teardown    teardown suite load test
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/load_test.robot
Resource          ../function/tests/backup_and_restore/wordpress.robot
Resource          ../function/tests/nginx.robot

*** Test Cases ***
wordpress load test
    [Tags]    release
    Given cluster running
    And helm is installed
    And storageclass is deployed
    And nginx is deployed
    And wordpress is deployed
    And locust is deployed
    When run load testing    4000    40
    Then fail rate should be inferior to    10
    [Teardown]    wordpress is removed

wordpress with hpa test
    Given cluster running
    And helm is installed
    And storageclass is deployed
    And nginx is deployed
    And wordpress is deployed
    And locust is deployed
    And hpa is apply on    wordpress
    When swarm load test    800    5
    And sleep    60
    Then number of pods for should be sup to    wordpress    3
    When sleep    60
    Then number of pods for should be sup to    wordpress    6
    When stop load test
    And sleep    90
    Then number of pods for should be inf to    wordpress    15
    Then fail rate should be inferior to    10
    [Teardown]    wordpress is removed
