*** Settings ***
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          commands.robot

*** Variables ***
&{deployment_state}
${worker_deployment_limit}    4
${master_deployment_limit}    1
${bootstrap_deployment_limit}    1
${bootstrap_expected_output}    [bootstrap] successfully bootstrapped core add-ons on node
${master_expected_output}    [join] node successfully joined the cluster
${worker_expected_output}    [join] node successfully joined the cluster

*** Keywords ***
create cluster deployment dictionnary
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        ${masters}    get master servers name    cluster_number=${cluster_number}
        ${workers}    get worker servers name    cluster_number=${cluster_number}
        @{emptylist}    Create List
        &{temp_cluster}    Create Dictionary    state=bootstrap    waiting_master=${masters}    waiting_worker=${workers}    on_going=${emptylist}    done=${emptylist}
        Set To Dictionary    ${deployment_state}    cluster_${cluster_number}=${temp_cluster}
    END
    Log Dictionary    ${deployment_state}

check on going node deployment limite reach
    [Arguments]    ${cluster}
    ${state}    _get current state    ${cluster}
    ${process number}    _get number of on going deployment    ${cluster}
    ${status}    Set Variable If    ${process number} < ${${state}_deployment_limit}    False    True
    [Return]    ${status}

check if node are waiting for deployment
    [Arguments]    ${cluster}
    ${state}    _get current state    ${cluster}
    Return From Keyword If    "${state}"=="bootstrap"    bootstrap
    ${waiting_pod}    Get Length    ${deployment_state["${cluster}"]["waiting_${state}"]}
    ${status}    Set Variable If    ${waiting_pod} == 0    False    True
    [Return]    ${status}

start new deployment
    [Arguments]    ${cluster}
    ${state}    _get current state    ${cluster}
    ${node}    _move node from waiting state to on going    ${cluster}
    Run Keyword If    "${state}" == "bootstrap"    start bootstrap    ${node}    ${cluster}
    ...    ELSE IF    "${state}" == "master" or "${state}" == "worker"    join node    ${node}    ${cluster}
    ...    ELSE    Fail    wrong state

_move node from waiting state to on going
    [Arguments]    ${cluster}
    ${state}    _get current state    ${cluster}
    ${state}    Set Variable if    "${state}"=="bootstrap"    master    ${state}
    ${node}    Remove From List    ${deployment_state["${cluster}"]["waiting_${state}"]}    0
    Append To List    ${deployment_state["${cluster}"]["on_going"]}    ${node}
    Log Dictionary    ${deployment_state}
    [Return]    ${node}

start bootstrap
    [Arguments]    ${node}    ${cluster}
    ${cluster_number}    get cluster number    ${cluster}
    open ssh session    ${BOOSTRAP_MASTER_${cluster_number}}    ${node}
    execute command with ssh    skuba cluster init --control-plane ${IP_LB_${cluster_number}} cluster    ${node}
    ${output}    skuba_write    node bootstrap --user ${VM_USER} --sudo --target ${cluster_state["${cluster}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]} ${CLUSTER_PREFIX}-${cluster_number}-master-0
    Create File    ${LOGDIR}/${node}    ${output}\n

join node
    [Arguments]    ${node}    ${cluster}=cluster_1    ${ip}=auto    ${after_remove}=False
    ${cluster_number}    get cluster number    ${cluster}
    open ssh session    ${BOOSTRAP_MASTER_${cluster_number}}    ${node}
    ${node exist}    check node exit in CS    ${node}    ${cluster_number}
    ${node disable}    Run Keyword If    ${node exist}    check node disable    ${node}    ${cluster_number}
    ${ip}    Run Keyword If    ${node exist} and "${ip}"=="auto"    get node ip from CS    ${node}    ${cluster_number}
    ...    ELSE    Set Variable    ${ip}
    ${type}    get node type    ${node}
    Run Keyword If    ${node exist} and not ${node disable}    Fail    Worker already part of the cluster !
    ...    ELSE IF    ${node exist} and ${node disable} and ${after_remove}    Run Keywords    unmask kubelet    ${ip}
    ...    AND    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${node}    True
    ...    AND    wait nodes
    ...    AND    wait pods
    ...    AND    enable node in CS    ${node}
    ...    ELSE IF    ${node exist} and ${node disable} and not ${after_remove}    initiale join    ${node}    ${ip}    ${type}
    ...    ELSE    Run Keywords    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${node}    True
    ...    AND    add node to cluster state    ${node}    ${ip}

initiale join
    [Arguments]    ${node}    ${ip}    ${type}
    ${output}    skuba_write    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${node}
    Append To File    ${LOGDIR}/${node}    ${output}\n

check if node is deployed
    [Arguments]    ${cluster}    ${node}
    [Timeout]
    ${state}    _get current state    ${cluster}
    ${expecting value}    Set Variable    ${${state}_expected_output}
    Switch Connection    ${node}
    ${console_output}    Read
    Append To File    ${LOGDIR}/${node}    ${console_output}\n
    ${status_command}    ${output}    Run Keyword And Ignore Error    Should Contain    ${console_output}    ${expecting value}
    ${status_node}    ${output}    Run Keyword And Ignore Error    Should Not Contain    ${console_output}    error joining node ${node}
    ${status_node_already exist}    ${output}    Run Keyword And Ignore Error    Should Not Contain    ${console_output}    [join] failed to join the node with name "${node}"
    Run Keyword If    "${status_node_already exist}"=="FAIL"    _move node from on going to done    ${cluster}    ${node}
    Run Keyword If    "${status_node}"=="FAIL"    _move node from ongoing to waiting    ${cluster}    ${node}
    Should Not Contain    ${console_output}    [join] failed to join the node with name "mnoel-cluster-itgx-1-worker-1"
    Should Not Contain    ${console_output}    error bootstrapping node
    ${status}    Set Variable if    "${status_command}"=="PASS"    True    False
    Run Keyword If    ${status} and "${state}"=="bootstrap"    Run Keywords    _change deployment state    ${cluster}
    ...    AND    Get Directory    cluster    ${WORKDIR}/${cluster}    recursive=true
    Run Keyword If    ${status}    Close Connection
    [Return]    ${status}

_get current state
    [Arguments]    ${cluster}
    ${state}    Set Variable    ${deployment_state["${cluster}"]["state"]}
    [Return]    ${state}

_move node from on going to done
    [Arguments]    ${cluster}    ${node}
    ${cluster_number}    get cluster number    ${cluster}
    ${index}    Get Index From List    ${deployment_state["${cluster}"]["on_going"]}    ${node}
    Run Keyword If    "${index}"=="-1"    Fail    ${node} Not found in on-going list
    @{on_going}    Set Variable    ${deployment_state["${cluster}"]["on_going"]}
    ${node}    Remove From List    ${on_going}    ${index}
    Append To List    ${deployment_state["${cluster}"]["done"]}    ${node}
    Set To Dictionary    ${deployment_state["${cluster}"]}    on_going=${on_going}
    Log Dictionary    ${deployment_state}
    enable node in CS    ${node}    ${cluster_number}

do I need to start new deployment
    [Arguments]    ${cluster}
    ${status_1}    check if node are waiting for deployment    ${cluster}
    ${status_2}    check on going node deployment limite reach    ${cluster}
    Run Keyword If    "${status_1}"!="False" and not ${status_2}    Run Keywords    start new deployment    ${cluster}
    ...    AND    do I need to start new deployment    ${cluster}

do I need to change state
    [Arguments]    ${cluster}
    ${process number}    _get number of on going deployment    ${cluster}
    ${deployment_waiting_status}    check if node are waiting for deployment    ${cluster}
    Run Keyword If    ${process number} == 0 and "${deployment_waiting_status}"=="False"    _change deployment state    ${cluster}

_get number of on going deployment
    [Arguments]    ${cluster}
    ${ongoing_deployment}    Get Length    ${deployment_state["${cluster}"]["on_going"]}
    [Return]    ${ongoing_deployment}

_change deployment state
    [Arguments]    ${cluster}
    ${state}    _get current state    ${cluster}
    Run Keyword If    "${state}"=="bootstrap"    Set To Dictionary    ${deployment_state["${cluster}"]}    state=master
    ...    ELSE IF    "${state}"=="master"    Set To Dictionary    ${deployment_state["${cluster}"]}    state=worker
    ...    ELSE IF    "${state}"=="worker"    Set To Dictionary    ${deployment_state["${cluster}"]}    state=done

do some nodes are finished to deploy
    [Arguments]    ${cluster}
    FOR    ${node}    IN    @{deployment_state["${cluster}"]["on_going"]}
        ${status}    check if node is deployed    ${cluster}    ${node}
        Run Keyword If    ${status}    _move node from on going to done    ${cluster}    ${node}
    END

check deployment status for cluster
    [Arguments]    ${cluster}
    do I need to start new deployment    ${cluster}
    do some nodes are finished to deploy    ${cluster}
    do I need to change state    ${cluster}

check state of all the cluster is done
    ${clusters}    Get Dictionary Keys    ${deployment_state}
    Sleep    15 sec
    FOR    ${cluster}    IN    @{clusters}
        Log Dictionary    ${deployment_state}
        Continue For Loop If    "${deployment_state["${cluster}"]["state"]}"=="done"
        check deployment status for cluster    ${cluster}
    END
    FOR    ${cluster}    IN    @{clusters}
        ${status}    _check status is done    ${cluster}
        BuiltIn.Exit For Loop If    not ${status}
    END
    [Return]    ${status}

skuba_write
    [Arguments]    ${arguments}    ${debug}=10
    ${output}    Write    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba ${arguments} -v ${debug}
    [Return]    ${output}

cluster is deployed
    create cluster deployment dictionnary
    ${clusters}    Get Dictionary Keys    ${deployment_state}
    ${waiting time}    Set Variable    1
    ${sleep_time}    Set Variable    10
    FOR    ${cluster}    IN    @{clusters}
        ${worker_number}    Get Length    ${deployment_state["${cluster}"]["waiting_worker"]}
        ${master_number}    Get Length    ${deployment_state["${cluster}"]["waiting_master"]}
        ${waiting time}    Evaluate    (${worker_number} + ${master_number}) * ( 300 / ${sleep_time} ) + ${waiting time}
    END
    FOR    ${temp}    IN RANGE    ${waiting time}
        ${status}    check state of all the cluster is done
        Exit For Loop If    ${status}
        Sleep    ${sleep_time}
    END

get cluster number
    [Arguments]    ${cluster}
    ${out}    Split String    ${cluster}    _
    ${cluster_number}    Set Variable    ${out[-1]}
    [Return]    ${cluster_number}

_check status is done
    [Arguments]    ${cluster}
    ${status}    Set Variable If    "${deployment_state["${cluster}"]["state"]}"=="done"    True    False
    [Return]    ${status}

_move node from ongoing to waiting
    [Arguments]    ${cluster}    ${node}
    ${state}    _get current state    ${cluster}
    @{on_going}    Set Variable    ${deployment_state["${cluster}"]["on_going"]}
    ${index}    Get Index From List    ${on_going}    ${node}
    Run Keyword If    "${index}"=="-1"    Fail    ${node} Not found in on-going list
    ${node}    Remove From List    ${on_going}    ${index}
    Append To List    ${deployment_state["${cluster}"]["waiting_${state}"]}    ${node}
    Set To Dictionary    ${deployment_state["${cluster}"]}    on_going=${on_going}
    Log Dictionary    ${deployment_state}
