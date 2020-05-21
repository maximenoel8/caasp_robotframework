*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../setup_environment.robot
Resource          ../tools.robot

*** Variables ***
${POST_curlreq}    curl -sm10 -XPOST deathstar.default.svc.cluster.local/v1/request-landing
${PUT_curlreq}    curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port

*** Keywords ***
deathstar is deployed
    kubectl    create -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/http-sw-app.yaml
    wait pods ready    -l 'org in (empire,alliance)'
    step    deathstar is deployed

node is able to land
    [Arguments]    ${node}
    ${output}    Wait Until Keyword Succeeds    30s    10s    kubectl    exec ${node} -- ${POST_curlreq}
    Should Contain    ${output}    Ship landed
    step    ${node} is able to land

node is NOT able to land
    [Arguments]    ${node}
    Run Keyword And Expect Error    *exit code 28*    kubectl    exec ${node} -- ${POST_curlreq}
    step    ${node} is NOT able to land

clean cilium test
    [Tags]    release
    step    clean cilium test
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/http-sw-app.yaml
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_policy.yaml
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_l7_policy.yaml
    [Teardown]    teardown_test

l3 l4 policiy is deployed
    kubectl    create -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_policy.yaml
    step    deploy l3 l4 policy

l7 policy is deployed
    kubectl    apply -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_l7_policy.yaml

PUT request create error
    [Arguments]    ${node}
    ${output}    Wait Until Keyword Succeeds    30s    10s    kubectl    exec ${node} -- ${PUT_curlreq}
    Should Contain    ${output}    Panic: deathstar exploded

PUT request is denied
    [Arguments]    ${node}
    ${output}    kubectl    exec ${node} -- ${PUT_curlreq}
    Should Contain    ${output}    Access denied
