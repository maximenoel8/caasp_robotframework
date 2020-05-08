*** Settings ***
Resource          ../function/tests/monitoring/monitoring.robot
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/nginx.robot

*** Test Cases ***
monitoring
    [Tags]    release
    Given cluster running
    And helm is installed
    And storageclass is deployed
    And nginx is deployed
    And prometheus is deployed
    And grafana is deployed
    Then prometheus should be healthy
    And grafana should be healthy
    And prometheus dashboard should be accessible
    When deploy dashboard
    Then grafana dashboard should be accessible
    [Teardown]    cleaning monitoring
