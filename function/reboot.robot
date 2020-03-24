*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot

*** Keywords ***
reboot or shutdown server
    [Arguments]    ${ip}    ${cmd}=reboot
    open ssh session    ${ip}    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo ${cmd}    tempo
    Run Keyword And Expect Error    REGEXP: (NoValidConnectionsError.*|timeout: timed out|SSHException: No existing session)    check ssh connection    ${ip}
    [Return]    Close session

check ssh connection
    [Arguments]    ${ip}
    SSHLibrary.Open Connection    ${ip}    timeout=30sec    alias=check_tempo
    Login With Public Key    ${VM_USER}    data/id_shared
    [Teardown]    Close Connection

reboot and wait server up
    [Arguments]    ${ip}
    reboot or shutdown server    ${ip}
    wait server up    ${ip}
    wait nodes are ready
    wait pods ready
    [Teardown]    Close Connection

wait server up
    [Arguments]    ${ip}
    Wait Until Keyword Succeeds    10min    15sec    check ssh connection    ${ip}

reboot worker 0 and master 0 and wait server up
    [Arguments]    ${cluster_number}=1
    reboot or shutdown server    ${cluster_state["cluster_${cluster_number}"]["worker"]["${CLUSTER_PREFIX}-${cluster_number}-worker-0"]["ip"]}
    reboot or shutdown server    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}
    wait server up    ${cluster_state["cluster_${cluster_number}"]["worker"]["${CLUSTER_PREFIX}-${cluster_number}-worker-0"]["ip"]}
    wait server up    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}
    Wait Until Keyword Succeeds    10min    30    wait nodes are ready
    wait pods ready
    reinitialize skuba session
