*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../setup_environment.robot

*** Keywords ***
coredns replicats should be ${replicat}
    ${output}    kubectl    -n kube-system get deploy coredns
    @{lines}    Split To Lines    ${output}
    FOR    ${line}    IN    @{lines}
        ${elements}    Split String    ${line}
        Continue For Loop If    "${elements[0]}"=="NAME"
        Should Be Equal    ${elements[0]}    coredns
        Should Be Equal    ${elements[1]}    ${replicat}/${replicat}
    END

dns traffic is forbidden
    [Arguments]    ${name}    ${ip}
    ${output}    When resolve ${name} request
    Should Contain    ${output}    ;; connection timed out; no servers could be reached
    ${output}    When reverse resolving ${ip} request
    Should Contain    ${output}    ;; connection timed out; no servers could be reached

dns traffic is allowed
    [Arguments]    ${name}    ${ip}
    When resolve ${name} should contain ${ip}
    When reverse resolving ${ip} should contain ${name}

resolve ${name} request
    ${dig_cmd}    Set Variable    dig +timeout=2 +tries=1 +short ${name}
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    exec tblshoot -- ${dig_cmd}
    [Return]    ${output}

reverse resolving ${ip} request
    ${dig_cmd}    Set Variable    dig +timeout=2 +tries=1 +short -x ${ip}
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    exec tblshoot -- ${dig_cmd}
    [Return]    ${output}

check ${service} service exists
    ${output}    kubectl    -n kube-system get svc ${service} -ojsonpath={.metadata.name}
    Should Be Equal    ${output}    ${service}

resolve ${name} should contain ${ip}
    ${output}    resolve ${name} request
    Then Should Contain    ${output}    ${ip}

reverse resolving ${ip} should contain ${name}
    ${output}    When reverse resolving ${ip} request
    Then Should Contain    ${output}    ${name}

deploy dnsutils-netcat
    kubectl    apply -f ${DATADIR}/manifests/dnsutils/dnsutils-netcat-pod.yaml

dnsutils-netcat should be deployed successfully
    wait pods ready    dnsutils-netcat

deploy dnsutils-netcat service
    ${output}    kubectl    apply -f ${DATADIR}/manifests/dnsutils/dnsutils-netcat-service.yaml
    Should Contain    ${output}    service/dnsutils-netcat
    Should Contain Any    ${output}    created    unchanged

deploy dnsutils-netcat service headless
    ${output}    kubectl    apply -f ${DATADIR}/manifests/dnsutils/dnsutils-netcat-service-headless.yaml
    Should Contain    ${output}    service/dnsutils-netcat-headless
    Should Contain Any    ${output}    created    unchanged

teardown coredns
    Run Keyword And Ignore Error    kubectl    delete -f ${DATADIR}/manifests/dnsutils
