*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/cap.robot

*** Test Cases ***
deploy and test cap v1
    [Tags]    cap
    given cluster running
    and helm is installed
    and storageclass is deployed
    deploy cap v1
    test cap
    Comment    destroy cap

deploy and test cap v2
    [Tags]    cap
    Pass Execution If    ${HELM_VERSION} != 3    CAP v2 need helm 3
    given cluster running
    and helm is installed
    and storageclass is deployed
    create config cap v2
    Comment    cleanup cap v2
    deploy cap v2
    deploy stratos
    cleanup cap v2
