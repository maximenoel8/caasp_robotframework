*** Settings ***
Resource          ../function/tests/monitoring.robot
Resource          ../function/skuba_commands.robot
Resource          ../function/helm.robot

*** Test Cases ***
monitoring
    [Tags]    release
    Given cluster running
    And helm is installed
    And prometheus is deployed
    And grafana is deployed
    Then prometheus should be healthy
    And grafana should be healthy
    And prometheus dashboard should be accessible
    And grafana dashboard should be accessible
    [Teardown]    cleaning monitoring
