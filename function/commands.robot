*** Settings ***
Library           SSHLibrary
Library           OperatingSystem
Resource          ../parameters/global_parameters.robot
Resource          ../parameters/velero.robot
Resource          ssh.robot

*** Keywords ***
execute command with ssh
    [Arguments]    ${cmd}    ${alias}=skuba_station_1    ${check_rc}=True    ${timeout}=15min
    [Documentation]    Run command in remote server by using alias created with `open ssh session`
    ...
    ...    The function by default will fail if command fail. Can be change with ${check_rc} variable
    Switch Connection    ${alias}
    ${output}    ${stderr}    ${rc}    Execute Command    ${cmd}    return_stdout=True    return_stderr=True    return_rc=True    timeout=${timeout}
    log    ${stderr}    repr=true    formatter=repr
    Run Keyword And Ignore Error    Append To File    ${LOGDIR}/tests/${TEST NAME}-error.log    \n\nCommand :${cmd} : ERROR :\n${stderr}\n
    log    ${output}    repr=true    formatter=repr
    Run Keyword And Ignore Error    Append To File    ${LOGDIR}/tests/${TEST NAME}.log    \n\nCommand :${cmd}\noutput: \n${output}\n
    Run Keyword If    ${check_rc}    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

execute command localy
    [Arguments]    ${cmd}    ${check_rc}=True
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    log    ${output}    repr=true    formatter=repr
    Run Keyword And Ignore Error    Append To File    ${LOGDIR}/tests/${TEST NAME}.log    \n\nCommand :${cmd} output: \n${output} \n    encoding=ASCII
    Run Keyword If    ${check_rc}    Should Be Equal As Integers    ${rc}    0    ${output}
    ...    ELSE    Return From Keyword    ${output}    ${rc}
    [Return]    ${output}

kubectl
    [Arguments]    ${arguments}    ${cluster_number}=1    ${screenshot}=False
    log    kubectl ${arguments}
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${retry}    Set Variable If    ${screenshot}    1    5
    FOR    ${i}    IN RANGE    0    ${retry}
        ${status}    ${output}    Run Keyword And Ignore Error    _kubectl configuration    ${arguments}    ${cluster_number}    ${screenshot}
        ${timeout_status}    Run Keyword If    "${status}"=="FAIL"    _kubectl timeout error    ${output}    ${cluster_number}
        ...    ELSE    Set variable    False
        Exit For Loop If    "${status}"=="PASS" or not ${timeout_status}
        Run Keyword If    not ${screenshot}    Sleep    30sec
    END
    Run Keyword If    "${status}"=="FAIL"    Fail    ${output}
    [Return]    ${output}

skuba
    [Arguments]    ${arguments}    ${ssh}=False    ${debug}=10    ${timeout}=15min    ${cluster_number}=1
    ${output}    Run Keyword If    ${ssh}    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba -v ${debug} ${arguments}    timeout=${timeout}    alias=skuba_station_${cluster_number}
    ...    ELSE    execute command localy    skuba ${arguments}
    Run Keyword If    "${mode}"=="${EMPTY}"    Should Not Contain    ${output}    ** This is an UNTAGGED version and NOT intended for production usage. **
    [Return]    ${output}

helm
    [Arguments]    ${arguments}    ${cluster_number}=1
    Set Environment Variable    HELM_HOME    ${WORKDIR}/helm_${cluster_number}
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${output}    Wait Until Keyword Succeeds    3x    2s    execute command localy    helm${HELM_VERSION} ${arguments}
    [Return]    ${output}

velero
    [Arguments]    ${argument}    ${cluster_number}=1
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${output}    execute command localy    ${velero_path}velero ${argument}
    Comment    ${output}    execute command localy    ${velero_path}velero ${argument} -cacert ${DATADIR}/certificate/minio-ca.crt
    [Return]    ${output}

_kubectl configuration
    [Arguments]    ${arguments}    ${cluster_number}    ${screenshot}
    ${output}    ${rc}    execute command localy    kubectl ${arguments}    False
    Comment    Run Keyword if    ${rc}!=0 and not ${screenshot}    screenshot cluster status    ${cluster_number}
    Should Be Equal As Integers    ${rc}    0    ${output}    values=False
    [Return]    ${output}

skuba_write
    [Arguments]    ${arguments}    ${debug}=10
    ${output}    Write    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba ${arguments} -v ${debug}
    [Return]    ${output}

sonobuoy
    [Arguments]    ${args}    ${cluster_number}=1
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${output}    execute command localy    ${LOGDIR}/sonobuoy ${args}
    [Return]    ${output}

govc
    [Arguments]    ${args}
    execute command localy    govc ${args}

_kubectl timeout error
    [Arguments]    ${output}    ${cluster_number}
    ${connection_error}    Set Variable    connection to the server ${IP_LB_${cluster_number}}:6443 was refused
    ${unable to connect}    Set Variable    Unable to connect to the server:
    ${etcd timedout}    Set Variable    Error from server: etcdserver: request timed out
    ${status_connection}    ${output_status}    Run Keyword And Ignore Error    Should Contain    ${output}    ${connection_error}
    ${status_unable}    ${output_status}    Run Keyword And Ignore Error    Should Contain    ${output}    ${unable to connect}
    ${status_etcdserver}    ${output_status}    Run Keyword And Ignore Error    Should Contain    ${output}    ${etcd timedout}
    ${status}    Set Variable If    "${status_connection}"=="PASS" or "${status_unable}"=="PASS" or "${status_etcdserver}"=="PASS"    True    False
    [Return]    ${status}
