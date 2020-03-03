*** Settings ***
Library           OperatingSystem
Resource          commands.robot
Library           String
Library           Collections

*** Keywords ***
wait nodes
    [Arguments]    ${nodes}=${EMPTY}
    kubectl    wait nodes --all --for=condition=ready --timeout=10m ${nodes}

wait reboot
    Wait Until Keyword Succeeds    30s    5s    execute command localy    kubectl cluster-info

wait pods
    [Arguments]    ${arguments}=${EMPTY}
    Run Keyword If    "${arguments}"=="${EMPTY}"    wait all pods are running
    ...    ELSE    kubectl    wait pods --for=condition=ready --timeout=5m ${arguments}

wait cillium
    ${cilium_pod_names}    wait podname    -l k8s-app=cilium -n kube-system
    ${number_cillium_pods}    Get Length    ${cilium_pod_names}
    ${cillium_pod_status}    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status
    ${controler_status}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *([0-9]+)/    1
    ${controler_status_2}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *[0-9]+/([0-9]+)    1
    Should Be Equal    ${controler_status}    ${controler_status_2}    Controller status unhealthy
    Wait Until Keyword Succeeds    300s    10s    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status | grep -E "^Cluster health:\\s+(${number_cillium_pods})/\\1 reachable"

wait podname
    [Arguments]    ${args}
    ${output}    kubectl    wait pods --for=condition=ready --timeout=5m ${args} -o name
    ${output}    Remove String    ${output}    pod/
    ${pod_names}    Split String    ${output}    \n
    ${length}    Get Length    ${pod_names}
    ${pod_name}    Set Variable If    ${length}==1    ${pod_names[0]}    ${pod_names}
    [Return]    ${pod_name}

check cluster exist
    ${CLUSTER_STATUS}    ${output}    Run Keyword And Ignore Error    OperatingSystem.Directory Should Exist    ${WORKDIR}/cluster
    Set Global Variable    ${CLUSTER_STATUS}

check replicat for
    [Arguments]    ${args}    ${number_replicat}
    ${ouput}    kubectl    describe pods ${args}
    ${nodes_list}    Get Regexp Matches    ${ouput}    Node: *(.*)/.*\n    1
    ${length}    Get Length    ${nodes_list}
    Should Be Equal As Integers    ${length}    ${number_replicat}    Number of ${args} not equal to replicat
    List Should Not Contain Duplicates    ${nodes_list}    ${args} are not correctly replicate

check_pod_log_contain
    [Arguments]    ${args}    ${expected_value}
    ${output}    kubectl    logs ${args}
    Should Contain    ${output}    ${expected_value}

wait deploy
    [Arguments]    ${arg}
    kubectl    wait deployment --for=condition=available --timeout=5m ${arg}

check cluster state exist
    ${status}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster_state.json
    [Return]    ${status}

check cluster deploy
    ${PLATFORM_DEPLOY}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster.json
    Set Global Variable    ${PLATFORM_DEPLOY}

wait all pods are running
    ${output}    kubectl    get pods --no-headers -n kube-system -o wide | grep -vw Completed | grep -vw Terminating
    ${output}    Split String    ${output}    \n
    FOR    ${element}    IN    @{output}
        ${key}    Split String    ${element}
        Run Keyword If    "${key[2]}"!="Running"    kubectl    wait pods --for=condition=ready --timeout=5m ${key[0]} -n kube-system
    END

expose service
    [Arguments]    ${service}    ${port}    ${namespace}=default
    ${service_string}    Split String    ${service}    ${SPACE}
    ${service_name}    Set Variable    ${service_string[-1]}
    kubectl    expose ${service} --port=${port} --type=NodePort -n ${namespace} --name="expose-${service_name}"
    ${node port}    kubectl    get svc/expose-${service_name} -n ${namespace} -o json | jq '.spec.ports[0].nodePort'
    [Return]    ${nodePort}