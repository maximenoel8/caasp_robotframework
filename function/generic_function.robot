*** Settings ***
Library           SSHLibrary
Library           OperatingSystem
Resource          ../parameters/global_parameters.robot
Resource          generic_function.robot
Resource          interaction_with_cluster_state_dictionnary.robot

*** Keywords ***
execute command with ssh
    [Arguments]    ${cmd}
    ${output}    ${stderr}    ${rc}    Execute Command    ${cmd}    return_stdout=True    return_stderr=True    return_rc=True    timeout=15m
    log    ${stderr}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${stderr}
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${output}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

execute command localy
    [Arguments]    ${cmd}
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${output}
    Should Be Equal As Integers    ${rc}    0    ${output}
    [Return]    ${output}

open ssh session
    Open Connection    ${SKUBA_STATION}
    Login With Public Key    ${VM_USER}    data/id_shared

kubectl
    [Arguments]    ${arguments}
    ${output}    execute command localy    kubectl ${arguments}
    [Return]    ${output}

skuba
    [Arguments]    ${arguments}    ${ssh}=False
    ${output}    Run Keyword If    ${ssh}    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba ${arguments}
    ...    ELSE    execute command localy    skuba ${arguments}
    [Return]    ${output}

helm
    [Arguments]    ${arguments}
    ${output}    execute command localy    helm ${arguments}
    [Return]    ${output}
