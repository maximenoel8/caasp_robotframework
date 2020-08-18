*** Settings ***
Resource          ../commands.robot
Resource          ../interaction_with_cluster_state_dictionnary.robot
Resource          upgrade_workstation.robot
Resource          ../cluster_helpers.robot
Resource          skuba_update.robot

*** Keywords ***
skuba update nodes
    kured config    off
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo systemctl start skuba-update    ${node}
    END

skuba addon upgrade
    [Arguments]    ${cluster_number}=1
    step    upgrade addon ...
    skuba    addon upgrade plan    ssh=True    cluster_number=${cluster_number}
    skuba    addon upgrade apply    ssh=True    cluster_number=${cluster_number}
    wait nodes are ready    cluster_number=${cluster_number}
    wait pods ready    cluster_number=${cluster_number}
    step    addon upgraded

skuba upgrade node
    [Arguments]    ${server_name}    ${cluster_number}=1
    step    Upgrade ${server_name} with skuba ...
    ${server_ip}    get node ip from CS    ${server_name}    cluster_number=${cluster_number}
    ${node}    get node skuba name    ${server_name}
    skuba    cluster upgrade localconfig    ssh=True    cluster_number=${cluster_number}
    Wait Until Keyword Succeeds    2min    10sec    skuba    node upgrade plan ${node}    ssh=True    cluster_number=${cluster_number}
    Wait Until Keyword Succeeds    30min    30s    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True    timeout=10min    cluster_number=${cluster_number}
    Comment    ${status}    ${output}    Run Keyword And Ignore Error    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True    timeout=10min
    Comment    ${status_connection}    Run Keyword If    "${status}"=="FAIL"    check string contain    ${output}    connect: connection refused
    ...    ELSE    Set Variable    False
    Comment    Run Keyword If    ${status_connection}    skuba upgrade node    ${server_name}
    Comment    ...
    ...    ELSE IF    "${status}"=="FAIL" and not ${status_connection}    Fail    Upgrade fail on ${server_name}
    Comment    execute command with ssh    sudo systemctl restart kubelet    ${server_name}
    Comment    skuba    node upgrade apply -t ${server_ip} -u sles -s    ssh=True

skuba upgrade all nodes
    [Arguments]    ${cluster_number}=1
    step    Upgrade nodes with skuba ...
    @{masters}    get master servers name    cluster_number=${cluster_number}
    FOR    ${master}    IN    @{masters}
        skuba upgrade node    ${master}    cluster_number=${cluster_number}
        wait reboot    cluster_number=${cluster_number}
    END
    ${workers}    get worker servers name    cluster_number=${cluster_number}
    FOR    ${worker}    IN    @{workers}
        skuba upgrade node    ${worker}    cluster_number=${cluster_number}
    END
    wait until node version are the same    cluster_number=${cluster_number}

upgrade cluster
    [Arguments]    ${cluster_number}=1
    step    upgrade cluster
    Comment    migrate cluster from SP1 to SP2    cluster_number=${cluster_number}
    Comment    ${passed}    ${output}    Run Keyword And Ignore Error    upgrade workstation    cluster_number=${cluster_number}
    Comment    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba-update nodes    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba addon upgrade    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba upgrade all nodes    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    skuba addon upgrade    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    wait nodes are ready    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    ${passed}    ${output}    Run Keyword And Ignore Error    wait pods ready    cluster_number=${cluster_number}
    Run Keyword If    "${passed}"=="FAIL"    Fatal Error    ${output}
    step    Successfully upgrade cluster
    [Teardown]    set global variable    ${UPGRADE}    False

check upgrade completed
    [Arguments]    ${cluster_number}=1
    ${lastest_version}    execute command with ssh    skuba cluster images | tail -1 | cut -d' ' -f1    alias=skuba_station_${cluster_number}
    ${skuba_output}    skuba    cluster upgrade plan    True    cluster_number=${cluster_number}
    Should Contain    ${skuba_output}    Current Kubernetes cluster version: ${lastest_version}
    Should Contain    ${skuba_output}    Latest Kubernetes version: ${lastest_version}
    Should Contain    ${skuba_output}    All nodes match the current cluster version: ${lastest_version}
    Should Contain    ${skuba_output}    Addons at the current cluster version ${lastest_version} are up to date.
    ${nodes}    get nodes name from CS    cluster_number=${cluster_number}
    Comment    _check rpm are installed    skuba_station_${cluster_number}
    FOR    ${node}    IN    @{nodes}
        ${skuba_name}    get node skuba name    ${node}
        ${output}    skuba    node upgrade plan ${skuba_name}    True    cluster_number=${cluster_number}
        Should Contain    ${output}    Node ${skuba_name} is up to date
        Comment    _check rpm are installed    ${node}
    END

_check rpm are installed
    [Arguments]    ${node}
    @{INCIDENTS}    Get Dictionary Keys    ${INCIDENT_REPO}
    FOR    ${INCIDENT}    IN    @{INCIDENTS}
        Run Keyword And Expect Error    1 != 0    execute command with ssh    zypper se -s -r ${INCIDENT} | grep -v pattern | grep -v iproute2 | grep ^v    ${node}
    END
