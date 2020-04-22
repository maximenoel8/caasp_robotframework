*** Settings ***
Resource          ../function/tests/centralized_logging.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
Centralized logging
    [Tags]    release
    Given cluster running
    And helm is installed
    And rsyslog is deployed
    And messages are log on peer
    Then logs should exist on rsyslog-server
    [Teardown]    teardown centralized log
