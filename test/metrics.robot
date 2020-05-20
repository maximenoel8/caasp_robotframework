*** Settings ***
Resource          ../function/tests/metrics.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
metrics format
    [Tags]    release
    Given cluster running
    Then can get cpu/memory for nodes
    And can get cpu/memory for pods
