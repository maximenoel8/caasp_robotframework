*** Settings ***
Resource          ../function/monitoring.robot
Resource          ../function/skuba_join.robot
Resource          ../function/helm.robot

*** Test Cases ***
monitoring
    Given cluster running
    And helm install
    And prometheus is deployed
    And grafana is deployed
    Then prometheus should be healthy
    And grafana should be healthy
    And prometheus dashboard should be accessible
    And grafana dashboard should be accessible
    [Teardown]    cleaning monitoring
