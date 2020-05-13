*** Settings ***
Resource          ../function/tests/sonobuoy.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
sonobuoy
    [Tags]    sonobuoy
    Given cluster running
    When run sonobuoy
    Then analyze sonobuoy result
