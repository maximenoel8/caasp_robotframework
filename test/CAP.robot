*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/cap.robot

*** Test Cases ***
deploy and test cap
    [Tags]    cap
    given cluster running
    and helm is installed
    and storageclass is deployed
    deploy cap
