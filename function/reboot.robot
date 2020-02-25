*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot

*** Keywords ***
reboot server
    [Arguments]    ${ip}
    open ssh session    ${ip}    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo reboot    tempo
    Run Keyword And Expect Error    REGEXP: (NoValidConnectionsError.*|timeout: timed out)    check ssh connection    ${ip}

check ssh connection
    [Arguments]    ${ip}
    SSHLibrary.Open Connection    ${ip}    timeout=20sec
    Login With Public Key    ${VM_USER}    data/id_shared
    Close Connection

reboot and wait server up
    [Arguments]    ${ip}
    reboot server    ${ip}
    wait server up    ${ip}
    wait_nodes
    wait_pods
    [Teardown]    Close Connection

wait server up
    [Arguments]    ${ip}
    Wait Until Keyword Succeeds    10min    15sec    check ssh connection    ${ip}

reboot worker 0 and master 0 and wait server up
    reboot server    ${cluster_state["worker"]["${CLUSTER_PREFIX}-worker-0"]["ip"]}
    reboot server    ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]}
    wait server up    ${cluster_state["worker"]["${CLUSTER_PREFIX}-worker-0"]["ip"]}
    wait server up    ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]}
    Wait Until Keyword Succeeds    10min    30    wait_nodes
    wait_pods
    reinitialize skuba session
