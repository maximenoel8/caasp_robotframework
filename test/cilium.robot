*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/cilium.robot

*** Test Cases ***
check L3-L4 policy
    [Tags]    release
    Given cluster running
    and deathstar is deployed
    then node is able to land    tiefighter
    and node is able to land    xwing
    when l3 l4 policiy is deployed
    then node is able to land    tiefighter
    and node is not able to land    xwing
    [Teardown]    clean cilium test

check L7 policy
    Given cluster running
    and deathstar is deployed
    Then PUT request create error    tiefighter
    When l7 policy is deployed
    Then PUT request is denied    tiefighter
    And node is able to land    tiefighter
    [Teardown]    clean cilium test
