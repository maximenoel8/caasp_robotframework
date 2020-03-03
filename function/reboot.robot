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
    wait nodes
    wait pods
    [Teardown]    Close Connection

wait server up
    [Arguments]    ${ip}
    Wait Until Keyword Succeeds    10min    15sec    check ssh connection    ${ip}

reboot worker 0 and master 0 and wait server up
    reboot or shutdown server    ${cluster_state["worker"]["${CLUSTER_PREFIX}-worker-0"]["ip"]}
    reboot or shutdown server    ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]}
    wait server up    ${cluster_state["worker"]["${CLUSTER_PREFIX}-worker-0"]["ip"]}
    wait server up    ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]}
    Wait Until Keyword Succeeds    10min    30    wait nodes
    wait pods
    reinitialize skuba session
