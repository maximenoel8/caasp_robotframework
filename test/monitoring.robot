*** Settings ***
Suite Setup       setup test suite monitoring
Suite Teardown    cleaning monitoring
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
    When certificates dashboard is deployed
    Then grafana dashboard should be accessible

customize dex and gangway certificate
    Given cluster running
    And helm is installed
    And storageclass is deployed
    And nginx is deployed
    And prometheus is deployed
    And grafana is deployed
    When add custom certificate to    oidc-gangway
    And add custom certificate to    oidc-dex
    And reboot cert-exporter
    And reboot grafana
    And certificates dashboard is deployed
    Then grafana dashboard should be accessible
