*** Settings ***
Resource          ../commands.robot
Resource          ../interaction_with_cluster_state_dictionnary.robot
Resource          upgrade_workstation.robot
Resource          ../cluster_helpers.robot

*** Keywords ***
kured config
    [Arguments]    ${mode}
    Run Keyword If    "${mode}"=="on"    kubectl    -n kube-system annotate ds kured weave.works/kured-node-lock-
    ...    ELSE IF    "${mode}"=="off"    kubectl    -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}'
    ...    ELSE    Log    to do

skuba update nodes
    kured config    off
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo systemctl start skuba-update    ${node}
    END

skuba addon upgrade
    skuba    addon upgrade plan    ssh=True
    skuba    addon upgrade apply    ssh=True
    wait pods ready

skuba upgrade node
    [Arguments]    ${server_name}
    ${server_ip}    get node ip from CS    ${server_name}
    skuba    node upgrade plan ${server_name}    ssh=True
    Wait Until Keyword Succeeds    30min    30s    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True    timeout=10min
    Comment    ${status}    ${output}    Run Keyword And Ignore Error    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True    timeout=10min
    Comment    ${status_connection}    Run Keyword If    "${status}"=="FAIL"    check string contain    ${output}    connect: connection refused
    ...    ELSE    Set Variable    False
    Comment    Run Keyword If    ${status_connection}    skuba upgrade node    ${server_name}
    Comment    ...
    ...    ELSE IF    "${status}"=="FAIL" and not ${status_connection}    Fail    Upgrade fail on ${server_name}
    Comment    execute command with ssh    sudo systemctl restart kubelet    ${server_name}
    Comment    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True

skuba upgrade all nodes
    ${masters}    get master servers name
    FOR    ${master}    IN    @{masters}
        skuba upgrade node    ${master}
        wait reboot
    END
    ${workers}    get worker servers name
    FOR    ${worker}    IN    @{workers}
        skuba upgrade node    ${worker}
    END
    wait until node version are the same
    ${cluster_status}    skuba    cluster upgrade plan    ssh=True
    Should Contain    ${cluster_status}    Congratulations! You are already at the latest version available

upgrade cluster
    ${passed}    ${output}    Run Keyword And Ignore Error    upgrade workstation
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba addon upgrade
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba upgrade all nodes
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba addon upgrade
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    wait nodes are ready
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    wait pods ready
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    [Teardown]    set global variable    ${UPGRADE}    False
