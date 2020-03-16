*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot

*** Variables ***
${curlreq}        curl -sm10 -XPOST deathstar.default.svc.cluster.local/v1/request-landing

*** Keywords ***
deathstar is deployed
    kubectl    create -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/http-sw-app.yaml
    wait pods ready    -l 'org in (empire,alliance)'

node is able to land
    [Arguments]    ${node}
    ${output}    Wait Until Keyword Succeeds    30s    10s    kubectl    exec ${node} -- ${curlreq}
    Should Contain    ${output}    Ship landed

node is NOT able to land
    [Arguments]    ${node}
    Run Keyword And Expect Error    *exit code 28*    kubectl    exec ${node} -- ${curlreq}

clean cilium test
    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/http-sw-app.yaml
    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_policy.yaml

l3 l4 policiy is deployed
    kubectl    create -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_policy.yaml
