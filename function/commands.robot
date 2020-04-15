*** Settings ***
Library           SSHLibrary
Library           OperatingSystem
Resource          ../parameters/global_parameters.robot
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          ../parameters/velero.robot

*** Keywords ***
execute command with ssh
    [Arguments]    ${cmd}    ${alias}=skuba_station_1    ${check_rc}=True    ${timeout}=15min
    Switch Connection    ${alias}
    ${output}    ${stderr}    ${rc}    Execute Command    ${cmd}    return_stdout=True    return_stderr=True    return_rc=True    timeout=${timeout}
    log    ${stderr}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/${TEST NAME}.log    \n\nCommand :${cmd} : ERROR :\n${stderr} \n
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/${TEST NAME}.log    output: \n${output} \n
    Run Keyword If    ${check_rc}    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

execute command localy
    [Arguments]    ${cmd}    ${check_rc}=True
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/${TEST NAME}.log    \n\nCommand :${cmd} output: \n${output} \n
    Run Keyword If    ${check_rc}    Should Be Equal As Integers    ${rc}    0    ${output}
    ...    ELSE    Return From Keyword    ${output}    ${rc}
    [Return]    ${output}

open ssh session
    [Arguments]    ${server}    ${alias}=default
    ${server_ip}    Run Keyword If    "${alias}"=="default"    get node ip from CS    ${server}
    ...    ELSE    Set Variable    ${server}
    ${alias}    Set Variable If    "${alias}"=="default"    ${server}    ${alias}
    Open Connection    ${server_ip}    alias=${alias}    timeout=20min
    Login With Public Key    ${VM_USER}    data/id_shared

kubectl
    [Arguments]    ${arguments}    ${cluster_number}=1    ${screenshot}=False
    Comment    ${connection_error}    Set Variable    connection to the server (([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9]):6443 was refused
    ${connection_error}    Set Variable    connection to the server ${IP_LB_${cluster_number}}:6443 was refused
    ${unable to connect}    Set Variable    Unable to connect to the server: EOF
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    FOR    ${i}    IN RANGE    1    5
        ${status}    ${output}    Run Keyword And Ignore Error    _kubectl configuration    ${arguments}    ${cluster_number}    ${screenshot}
        ${status_connection}    ${output_status}    Run Keyword And Ignore Error    Should Contain    ${output}    ${connection_error}
        ${status_unable}    ${output_status}    Run Keyword And Ignore Error    Should Contain    ${output}    ${unable to connect}
        Exit For Loop If    "${status_connection}"=="FAIL" and "${status_unable}"=="FAIL"
        Sleep    3 min
    END
    Run Keyword If    "${status}"=="FAIL"    Fail    ${output}
    [Return]    ${output}

skuba
    [Arguments]    ${arguments}    ${ssh}=False    ${debug}=10    ${timeout}=15min
    ${output}    Run Keyword If    ${ssh}    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba ${arguments} -v ${debug}    timeout=${timeout}
    ...    ELSE    execute command localy    skuba ${arguments}
    [Return]    ${output}

helm
    [Arguments]    ${arguments}    ${cluster_number}=1
    Set Environment Variable    HELM_HOME    ${WORKDIR}/helm_${cluster_number}
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${output}    execute command localy    helm ${arguments}
    [Return]    ${output}

reinitialize skuba session
    [Arguments]    ${cluster_number}=1
    Switch Connection    skuba_station_${cluster_number}
    Close Connection
    open ssh session    ${WORKSTATION__${cluster_number}}    alias=skuba_station_${cluster_number}

openssl
    [Arguments]    ${cmd}
    ${output}    execute command with ssh    openssl ${cmd}
    [Return]    ${output}

velero
    [Arguments]    ${argument}    ${cluster_number}=1
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}_${cluster_number}/admin.conf
    ${output}    execute command localy    ${velero_path}velero ${argument}
    [Return]    ${output}

remove string from file
    [Arguments]    ${file}    ${string}
    ${contents}=    OperatingSystem.Get File    ${file}
    Remove File    ${file}
    Create File    ${file}
    @{lines}    Split To Lines    ${contents}
    FOR    ${line}    IN    @{lines}
        ${new_line}    String.Remove String    ${line}    ${string}
        Append To File    ${file}    ${new_line}\n
    END

add devel repo
    [Arguments]    ${alias}
    execute command with ssh    sudo zypper ar -C -G -f http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_SP1/ caasp_devel    ${alias}

modify string in file
    [Arguments]    ${file}    ${se}    ${re}
    ${contents}=    OperatingSystem.Get File    ${file}
    Remove File    ${file}
    Create File    ${file}
    @{lines}    Split To Lines    ${contents}
    FOR    ${line}    IN    @{lines}
        ${new_line}    String.Replace String    ${line}    ${se}    ${re}
        Append To File    ${file}    ${new_line}\n
    END

screenshot cluster status
    Run Keyword And Ignore Error    kubectl    get pods -A    screenshot=True
    Run Keyword And Ignore Error    kubectl    get svc -A    screenshot=True
    Run Keyword And Ignore Error    kubectl    get pvc -A    screenshot=True
    Run Keyword And Ignore Error    kubectl    get pv    screenshot=True

check string contain
    [Arguments]    ${string}    ${contain}
    ${status_cmd}    ${outptu}    Run Keyword And Ignore Error    Should Contain    ${string}    ${contain}
    ${status}    Set Variable If    "${status_cmd}"=="PASS"    True    False
    [Return]    ${status}

_kubectl configuration
    [Arguments]    ${arguments}    ${cluster_number}    ${screenshot}
    ${output}    ${rc}    execute command localy    kubectl ${arguments}    False
    Run Keyword if    ${rc}!=0 and not ${screenshot}    screenshot cluster status
    Should Be Equal As Integers    ${rc}    0    ${output}    values=False
    [Return]    ${output}
