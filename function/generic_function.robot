*** Settings ***
Library           SSHLibrary
Library           OperatingSystem

*** Keywords ***
execute command with ssh
    [Arguments]    ${cmd}
    ${output}    ${stderr}    ${rc}    Execute Command    ${cmd}    return_stdout=True    return_stderr=True    return_rc=True    timeout=15m
    log    ${stderr}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${stderr}
    Should Be Equal As Integers    ${rc}    0
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${output}
    [Return]    ${output}

execute command localy
    [Arguments]    ${cmd}
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    log    ${output}    repr=true    formatter=repr
    Append To File    ${LOGDIR}/console.log    ${output}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

open ssh session
    Open Connection    ${SKUBA_STATION}
    Login With Public Key    ${VM_USER}    data/id_shared

kubectl
    [Arguments]    ${arguments}
    ${output}    execute command localy    kubectl ${arguments}
    [Return]    ${output}

skuba
    [Arguments]    ${arguments}
    ${output}    execute command localy    skuba ${arguments}
    [Return]    ${output}

helm
    [Arguments]    ${arguments}
    ${output}    execute command localy    helm ${arguments}
    [Return]    ${output}
