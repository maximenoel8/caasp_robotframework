*** Settings ***
Library           OperatingSystem
Resource          commands.robot
Library           String
Library           Collections

*** Keywords ***
wait nodes are ready
    [Arguments]    ${nodes}=${EMPTY}    ${cluster_number}=1
    Wait Until Keyword Succeeds    12min    10sec    kubectl    wait nodes --all --for=condition=ready --timeout=10m ${nodes}    ${cluster_number}

wait reboot
    Wait Until Keyword Succeeds    30s    5s    execute command localy    kubectl cluster-info

wait pods ready
    [Arguments]    ${arguments}=${EMPTY}    ${cluster_number}=1
    Run Keyword If    "${arguments}"=="${EMPTY}"    wait all pods are running    ${cluster_number}
    ...    ELSE    kubectl    wait pods --for=condition=ready --timeout=5m ${arguments}    ${cluster_number}

wait cillium
    [Arguments]    ${cluster_number}=1
    ${cilium_pod_names}    wait podname    -l k8s-app=cilium -n kube-system    ${cluster_number}
    ${number_cillium_pods}    Get Length    ${cilium_pod_names}
    ${cillium_pod_status}    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status    ${cluster_number}
    ${controler_status}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *([0-9]+)/    1
    ${controler_status_2}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *[0-9]+/([0-9]+)    1
    Should Be Equal    ${controler_status}    ${controler_status_2}    Controller status unhealthy
    Wait Until Keyword Succeeds    600s    15s    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status | grep -E "^Cluster health:\\s+(${number_cillium_pods})/\\1 reachable"    ${cluster_number}

wait podname
    [Arguments]    ${args}    ${cluster_number}=1
    ${output}    kubectl    wait pods --for=condition=ready --timeout=10m ${args} -o name    ${cluster_number}
    ${output}    Remove String    ${output}    pod/
    ${pod_names}    Split String    ${output}    \n
    ${length}    Get Length    ${pod_names}
    ${pod_name}    Set Variable If    ${length}==1    ${pod_names[0]}    ${pod_names}
    [Return]    ${pod_name}

get ressource name
    [Arguments]    ${args}    ${ressource_type}    ${cluster_number}=1
    @{names}    Create List
    ${output}    kubectl    get ${ressource_type} ${args} -o name    ${cluster_number}
    ${element_names}    Split String    ${output}    \n
    FOR    ${element_name}    IN    @{element_names}
        ${element_parts}    Split String    ${element_name}    /
        Collections.Append To List    ${names}    ${element_parts[-1]}
    END
    ${length}    Get Length    ${element_names}
    ${ressource_name}    Set Variable If    ${length}==1    ${names[0]}    ${names}
    [Return]    ${ressource_name}

check cluster exist
    [Arguments]    ${cluster_number}=1
    ${CLUSTER_STATUS}    ${output}    Run Keyword And Ignore Error    OperatingSystem.Directory Should Exist    ${WORKDIR}/cluster_${cluster_number}
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
    [Arguments]    ${arg}    ${timeout}=5m
    kubectl    wait deployment --for=condition=available --timeout=${timeout} ${arg}

check cluster state exist
    ${status}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster_state.json
    [Return]    ${status}

check cluster deploy
    [Arguments]    ${cluster_number}=1
    ${PLATFORM_DEPLOY}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster${cluster_number}.json
    Set Global Variable    ${PLATFORM_DEPLOY}

wait all pods are running
    [Arguments]    ${cluster_number}=1
    FOR    ${i}    IN RANGE    1    5
        ${status}    restart CrashLoopBack pod
        Exit For Loop If    ${status}
        Sleep    15
    END
    ${output}    kubectl    get pods --no-headers -n kube-system -o wide | grep -vw Completed | grep -vw Terminating    ${cluster_number}
    ${output}    Split String    ${output}    \n
    FOR    ${element}    IN    @{output}
        ${key}    Split String    ${element}
        Run Keyword If    "${key[2]}"!="Running"    kubectl    wait pods --for=condition=ready --timeout=10m ${key[0]} -n kube-system    ${cluster_number}
    END

expose service
    [Arguments]    ${service}    ${port}    ${namespace}=default
    ${service_string}    Split String    ${service}    ${SPACE}
    ${service_name}    Set Variable    ${service_string[-1]}
    kubectl    expose ${service} --port=${port} --type=NodePort -n ${namespace} --name="expose-${service_name}"
    ${node port}    kubectl    get svc/expose-${service_name} -n ${namespace} -o json | jq '.spec.ports[0].nodePort'
    [Return]    ${nodePort}

wait job
    [Arguments]    ${arguments}    ${condition}    ${cluster_number}=1
    kubectl    wait job --for=condition=${condition} --timeout=5m ${arguments}    ${cluster_number}

wait pod deleted
    [Arguments]    ${arguments}    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    wait pods --for=delete --timeout=5m ${arguments}    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL" and "${output}"!="error: no matching resources found"    Fail    ${output}

restart CrashLoopBack pod
    @{pods}    kubectl    get pods --field-selector=status.phase=CrashLoopBackOff -n kube-system -o name
    ${length}    Get Length    ${pods}
    FOR    ${pod}    IN    @{pods}
        kubectl    delete ${pod} -n kube-system
    END
    ${status}    Set Variable If    ${length} == 0    True    False
    [Return]    ${status}
