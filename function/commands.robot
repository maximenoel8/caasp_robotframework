*** Settings ***
Library           SSHLibrary
Library           OperatingSystem
Resource          ../parameters/global_parameters.robot
Resource          commands.robot
Resource          interaction_with_cluster_state_dictionnary.robot

*** Keywords ***
execute command with ssh
    [Arguments]    ${cmd}    ${alias}=skuba_station
    ${connections}    SSHLibrary.Get Connections
    log    ${connections}
    Switch Connection    ${alias}
    ${output}    ${stderr}    ${rc}    Execute Command    ${cmd}    return_stdout=True    return_stderr=True    return_rc=True    timeout=15m
    log    ${stderr}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    \n\n${cmd} : ERROR :\n${stderr} \n
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    \n\n${cmd} : \n${output} \n
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

execute command localy
    [Arguments]    ${cmd}
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    \n\n${cmd} : \n${output} \n
    Should Be Equal As Integers    ${rc}    0    ${output}
    [Return]    ${output}

open ssh session
    [Arguments]    ${server}    ${alias}
    Open Connection    ${server}    alias=${alias}    timeout=20min
    Login With Public Key    ${VM_USER}    data/id_shared

kubectl
    [Arguments]    ${arguments}
    ${output}    execute command localy    kubectl ${arguments}
    [Return]    ${output}

skuba
    [Arguments]    ${arguments}    ${ssh}=False    ${debug}=10
    ${output}    Run Keyword If    ${ssh}    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba ${arguments} -v ${debug}
    ...    ELSE    execute command localy    skuba ${arguments}
    [Return]    ${output}

helm
    [Arguments]    ${arguments}
    ${output}    execute command localy    helm ${arguments}
    [Return]    ${output}

titi
    [Arguments]    ${1}    ${2}=defaul
    log    toto

reinitialize skuba session
    Switch Connection    skuba_station
    Close Connection
    open ssh session    ${BOOSTRAP_MASTER}    alias=skuba_station

openssl
    [Arguments]    ${cmd}
    ${output}    execute command localy    openssl ${cmd}
    [Return]    ${output}
