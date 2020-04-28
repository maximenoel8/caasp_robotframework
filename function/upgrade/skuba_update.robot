*** Settings ***
Resource          ../commands.robot
Resource          ../helper.robot
Resource          ../cluster_helpers.robot

*** Keywords ***
wait skuba-update inactive on
    [Arguments]    ${node}
    Wait Until Keyword Succeeds    300    10    check skuba-update is inactive    ${node}

check skuba-update is inactive
    [Arguments]    ${node}
    Run Keyword And Expect Error    inactive    execute command with ssh    sudo systemctl is-active skuba-update    ${node}

wait skuba-update inactive on all nodes
    [Arguments]    ${cluster_number}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        wait skuba-update inactive on    ${node}
    END

skuba-update nodes
    [Arguments]    ${cluster_number}
    run command on nodes    sudo skuba-update    ${cluster_number}
    kured config    on    ${cluster_number}
    kured config    --period=1m    ${cluster_number}
    wait until all nodes dont need reboot    ${cluster_number}
    wait reboot    ${cluster_number}
    Run Keyword And Ignore Error    kured config    off    ${cluster_number}

wait until node dont need reboot
    [Arguments]    ${node}    ${waiting_time}
    Switch Connection    ${node}
    Wait Until Keyword Succeeds    ${waiting_time}    60    SSHLibrary.File Should Not Exist    /var/run/reboot-needed

wait until all nodes dont need reboot
    [Arguments]    ${cluster_number}
    ${nodes}    get nodes name from CS    ${cluster_number}
    ${length}    Get Length    ${nodes}
    ${waiting_time}    Evaluate    ${length}*10*60
    FOR    ${node}    IN    @{nodes}
        wait until node dont need reboot    ${node}    ${waiting_time}
    END
