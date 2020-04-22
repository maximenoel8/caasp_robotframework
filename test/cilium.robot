*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/cilium.robot

*** Test Cases ***
Cilium: L3/L4 policy test
    [Tags]    release
    Given cluster running
    and deathstar is deployed
    then node is able to land    tiefighter
    and node is able to land    xwing
    when l3 l4 policiy is deployed
    then node is able to land    tiefighter
    and node is not able to land    xwing
    [Teardown]    clean cilium test
