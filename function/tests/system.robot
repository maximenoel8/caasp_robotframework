*** Settings ***
Resource          ../commands.robot
Resource          ../tools.robot

*** Keywords ***
skuba-update should be enabled
    [Arguments]    ${cluster_number}=1
    ${nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    systemctl list-timers | grep skuba-update    ${node}
    END
    step    Check skuba-update is enabled on all nodes

apparmor should be running and enabled on all the nodes
    [Arguments]    ${cluster_number}=1
    ${nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    systemctl -q is-active apparmor    ${node}
        execute command with ssh    systemctl -q is-enabled apparmor    ${node}
    END
    step    Check apparmor is enabled and running on all nodes

swap should be turn off
    [Arguments]    ${cluster_number}=1
    ${nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo swapon --noheadings --show    ${node}
    END
    step    swap is disabled
