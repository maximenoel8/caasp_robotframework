*** Settings ***
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          commands.robot
Resource          cluster_helpers.robot
Resource          skuba_commands.robot
Resource          vms_deployment/main_keywork.robot
Resource          helper.robot
Resource          helm.robot
Resource          tools.robot
Resource          setup_environment.robot
Resource          upgrade/upgrade.robot

*** Variables ***
&{deployment_state}
${worker_deployment_limit}    4
${master_deployment_limit}    1
${bootstrap_deployment_limit}    1
${bootstrap_expected_output}    [bootstrap] successfully bootstrapped
${master_expected_output}    [join] node successfully joined the cluster
${worker_expected_output}    [join] node successfully joined the cluster
${sleep_time}     10

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
    ${cluster_number}    get cluster number    ${cluster}
    ${state}    _get current state    ${cluster}
    ${boostrat_state}    Set Variable If    "${state}"=="bootstrap"    True    False
    ${state}    Set Variable if    ${boostrat_state}    master    ${state}
    ${index}    Run Keyword If    ${boostrat_state}    Get Index From List    ${deployment_state["${cluster}"]["waiting_${state}"]}    ${CLUSTER_PREFIX}-${cluster_number}-master-0
    ...    ELSE    Set Variable    0
    ${node}    Remove From List    ${deployment_state["${cluster}"]["waiting_${state}"]}    ${index}
    Append To List    ${deployment_state["${cluster}"]["on_going"]}    ${node}
    Log Dictionary    ${deployment_state}
    [Return]    ${node}

check if node is deployed
    [Arguments]    ${cluster}    ${node}
    [Timeout]
    ${state}    _get current state    ${cluster}
    ${cluster_number}=    get cluster number    ${cluster}
    ${skuba_name}    get node skuba name    ${node}    ${cluster_number}
    ${expecting value}    Set Variable    ${${state}_expected_output}
    Switch Connection    ${node}
    ${console_output}    Read
    Append To File    ${LOGDIR}/deployment/${node}    ${console_output}\n
    ${status_command}    ${output}    Run Keyword And Ignore Error    Should Contain    ${console_output}    ${expecting value}
    ${status_node}    ${output}    Run Keyword And Ignore Error    Should Not Contain    ${console_output}    error joining node ${skuba_name}
    ${status_node_already exist}    ${output}    Run Keyword And Ignore Error    Should Not Contain    ${console_output}    [join] failed to join the node with name "${skuba_name}"
    ${status_bootstrapping fail}    ${boostrap_output}    Run Keyword And Ignore Error    Should Not Contain    ${console_output}    error bootstrapping node
    Run Keyword If    "${status_node_already exist}"=="FAIL"    _move node from on going to done    ${cluster}    ${node}
    Run Keyword If    "${status_node}"=="FAIL"    _move node from ongoing to waiting    ${cluster}    ${node}
    Run Keyword If    "${status_bootstrapping fail}"=="FAIL" and "${state}"=="bootstrap"    _move node from ongoing to waiting    ${cluster}    ${node}
    ...    ELSE IF    "${status_bootstrapping fail}"=="FAIL"    Fail    ${boostrap_output}
    Should Not Contain    ${console_output}    invalid node name "${node}"
    Should Not Contain    ${console_output}    [join] failed to join the node with name "mnoel-cluster-itgx-1-worker-1"
    ${status}    Set Variable if    "${status_command}"=="PASS"    True    False
    Run Keyword If    ${status} and "${state}"=="bootstrap"    Run Keywords    _change deployment state    ${cluster}
    ...    AND    Get Directory    cluster    ${WORKDIR}/${cluster}    recursive=true
    ...    AND    wait nodes are ready    cluster_number=${cluster_number}
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

cluster is deployed
    create cluster deployment dictionnary
    ${waiting time}    _set deployment timeout
    FOR    ${temp}    IN RANGE    ${waiting time}
        ${status}    check state of all the cluster is done
        Exit For Loop If    ${status}
        Sleep    ${sleep_time}
    END

_check status is done
    [Arguments]    ${cluster}
    ${status}    Set Variable If    "${deployment_state["${cluster}"]["state"]}"=="done"    True    False
    [Return]    ${status}

_move node from ongoing to waiting
    [Arguments]    ${cluster}    ${node}
    ${state}    _get current state    ${cluster}
    ${state}    Set Variable if    "${state}"=="bootstrap"    master    ${state}
    @{on_going}    Set Variable    ${deployment_state["${cluster}"]["on_going"]}
    ${index}    Get Index From List    ${on_going}    ${node}
    Run Keyword If    "${index}"=="-1"    Fail    ${node} Not found in on-going list
    ${node}    Remove From List    ${on_going}    ${index}
    Append To List    ${deployment_state["${cluster}"]["waiting_${state}"]}    ${node}
    Set To Dictionary    ${deployment_state["${cluster}"]}    on_going=${on_going}
    Log Dictionary    ${deployment_state}

_set deployment timeout
    ${clusters}    Get Dictionary Keys    ${deployment_state}
    ${waiting time}    Set Variable    1
    FOR    ${cluster}    IN    @{clusters}
        ${worker_number}    Get Length    ${deployment_state["${cluster}"]["waiting_worker"]}
        ${master_number}    Get Length    ${deployment_state["${cluster}"]["waiting_master"]}
        ${waiting time}    Evaluate    (${worker_number} + ${master_number}) * ( 300 / ${sleep_time} ) + ${waiting time}
    END
    [Return]    ${waiting time}

cluster running
    [Arguments]    ${cluster_number}=1
    set infra env parameters
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL" and ${cluster_number}==1    deploy cluster vms
    load vm ip
    Run Keyword If    ${cluster_number}==1    open bootstrap session
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL" and ${cluster_number}==1    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL" and ${cluster_number}==1    cluster is deployed
    wait nodes are ready    cluster_number=${cluster_number}
    wait pods ready    cluster_number=${cluster_number}
    wait cillium    cluster_number=${cluster_number}
    Run Keyword If    ${UPGRADE}    upgrade cluster

cluster is deployed temp
    FOR    ${i}    IN RANGE    1    3
        ${status}    ${output}    Run Keyword And Ignore Error    cluster is deployed
        ${status_boostrapfail}    ${output}    Run Keyword And Ignore Error    Should Contain    ${output}    error bootstrapping node
        ${bootstrap_status}    is deployment state equal to    bootstrap
        Exit For Loop If    ( not ${bootstrap_status} and "${status_boostrapfail}"=="FAIL" ) or "${status}"=="PASS"
    END

is deployment state equal to
    [Arguments]    ${state}
    ${state_status}    Set Variable    False
    FOR    ${i}    IN RANGE    1    ${NUMBER_OF_CLUSTER}
        ${state_status}    Set Variable If    "${deployment_state["cluster_${i}"]["state"]}"=="${state}"    True    False
        Exit For Loop If    ${state_status}
    END
    [Return]    ${state_status}
