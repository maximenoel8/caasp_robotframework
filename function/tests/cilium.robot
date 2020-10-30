*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../setup_environment.robot
Resource          ../tools.robot
Resource          ../cluster_deployment.robot
Resource          coredns.robot

*** Variables ***
${POST_curlreq}    curl -sm10 -XPOST deathstar.default.svc.cluster.local/v1/request-landing
${PUT_curlreq}    curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
${cilium_config}    ${EMPTY}

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

teardown testsuite cilium
    [Tags]    release
    step    teardown testsuite cilium
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/minikube/http-sw-app.yaml
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/minikube/sw_l3_l4_policy.yaml
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/minikube/sw_l3_l4_l7_policy.yaml
    Run Keyword And Ignore Error    kubectl    delete -f ${DATADIR}/manifests/cilium
    [Teardown]    teardown_test

l3 l4 policiy is deployed
    kubectl    create -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/minikube/sw_l3_l4_policy.yaml
    step    deploy l3 l4 policy

l7 policy is deployed
    kubectl    apply -f https://raw.githubusercontent.com/cilium/cilium/v1.7/examples/minikube/sw_l3_l4_l7_policy.yaml

PUT request create error
    [Arguments]    ${node}
    ${output}    Wait Until Keyword Succeeds    30s    10s    kubectl    exec ${node} -- ${PUT_curlreq}
    Should Contain    ${output}    Panic: deathstar exploded

PUT request is denied
    [Arguments]    ${node}
    ${output}    kubectl    exec ${node} -- ${PUT_curlreq}
    Should Contain    ${output}    Access denied

cilium version should be
    [Arguments]    ${expected_version}
    ${cilium_pods}    wait podname    -l k8s-app=cilium -n kube-system
    ${version_results}    kubectl    exec ${cilium_pods[0]} -n kube-system -- cilium version
    ${lines}    Split To Lines    ${version_results}
    FOR    ${line}    IN    @{lines}
        ${value}    Split String    ${line}
        Should Be Equal    ${value[1]}    ${expected_version}
    END

cilium-config should contain crd setting
    get cm cilium-config
    Should Be Equal    ${cilium_config["data"]["bpf-ct-global-any-max"]}    262144
    Should Be Equal    ${cilium_config["data"][ "bpf-ct-global-tcp-max"]}    524288
    Should Be Equal    ${cilium_config["data"]["debug"]}    false
    Should Be Equal    ${cilium_config["data"]["enable-ipv4"]}    true
    Should Be Equal    ${cilium_config["data"]["enable-ipv6"]}    false
    Should Be Equal    ${cilium_config["data"]["identity-allocation-mode"]}    crd
    Should Be Equal    ${cilium_config["data"]["preallocate-bpf-maps"]}    false

cilium-config should not contain etcd config
    Dictionary Should Not Contain Key    ${cilium_config["data"]}    etcd-config
    Dictionary Should Not Contain Key    ${cilium_config["data"]}    kvstore
    Dictionary Should Not Contain Key    ${cilium_config["data"]}    kvstore-opt

get cm cilium-config
    kubectl    get cm cilium-config -n kube-system -o json > ${LOGDIR}/cilium-config.json
    ${cilium_config}    Load JSON From File    ${LOGDIR}/cilium-config.json
    Set Test Variable    ${cilium_config}
    Log Dictionary    ${cilium_config}

setup test suite cilium
    Given cluster running
    And deathstar is deployed
    and deploy httpbin
    and deploy tblshoot

apply a default network policy to deny all traffic
    kubectl    apply -f ${DATADIR}/manifests/cilium/network-policy-deny-all.yaml

send ${method} request to ${path}
    ${curl_cmd}    Set Variable    curl -s -o /dev/null -w \"\%\{http_code\}\" --connect-timeout 3 -X ${method} http://httpbin${path}
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    exec tblshoot -- ${curl_cmd}
    [Return]    ${output}

check http traffic
    [Arguments]    ${method}    ${path}    ${retcode}
    ${output}    When send ${method} request to ${path}
    Then Should Be Equal    ${output}    ${retcode}

clean all network policies
    kubectl    delete cnp --all

apply network policy to allow DNS traffic
    kubectl    apply -f ${DATADIR}/manifests/cilium/network-policy-allow-dns.yaml

apply network policy to allow http traffic at layer 3
    kubectl    apply -f ${DATADIR}/manifests/cilium/network-policy-allow-http-l3.yaml

apply network policy to allow http traffic with Layer 7 filtering
    kubectl    delete -f ${DATADIR}/manifests/cilium/network-policy-allow-http-l3.yaml
    kubectl    apply -f ${DATADIR}/manifests/cilium/network-policy-allow-delete-get-put-l7.yaml
