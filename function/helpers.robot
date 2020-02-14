*** Settings ***
Library           OperatingSystem
Resource          generic_function.robot
Library           String

*** Keywords ***
wait_nodes
    [Arguments]    ${nodes}=${EMPTY}
    execute command localy    kubectl wait nodes --all --for=condition=ready --timeout=10m ${nodes}

wait_reboot
    Wait Until Keyword Succeeds    30s    5s    execute command localy    kubectl cluster-info

wait_pods
    ${output}    execute command localy    kubectl get pods --no-headers -n kube-system -o wide | grep -vw Completed
    ${output}    Split String    ${output}    \n
    Create Dictionary
    FOR    ${element}    IN    @{output}
        ${key}    Split String    ${element}
        Run Keyword If    "${key[2]}"!="Running"    execute command localy    kubectl wait pods --for=condition=ready --timeout=5m ${key[0]} -n kube-system
    END

wait_cillium
    ${cilium_pod_names}    wait_podname    -l k8s-app=cilium -n kube-system
    ${number_cillium_pods}    Get Length    ${cilium_pod_names}
    ${cillium_pod_status}    execute command localy    kubectl -n kube-system exec ${cilium_pod_names[0]} -- cilium status
    ${controler_status}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *([0-9]+)/    1
    ${controler_status_2}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *[0-9]+/([0-9]+)    1
    Should Be Equal    ${controler_status}    ${controler_status_2}    Controller status unhealthy
    Wait Until Keyword Succeeds    300s    10s    execute command localy    kubectl -n kube-system exec ${cilium_pod_names[0]} -- cilium status | grep -E "^Cluster health:\\s+(${number_cillium_pods})/\\1 reachable"

wait_podname
    [Arguments]    ${args}
    ${output}    execute command localy    kubectl wait pods --for=condition=ready --timeout=5m ${args} -o name
    ${output}    Remove String    ${output}    pod/
    ${pod_names}    Split String    ${output}    \n
    [Return]    ${pod_names}
