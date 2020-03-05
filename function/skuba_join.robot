*** Settings ***
Resource          commands.robot
Library           Collections
Resource          skuba_tool_install.robot
Resource          cluster_helpers.robot
Resource          infra_setup/main_keywork.robot
Library           JSONLibrary
Resource          reboot.robot
Resource          tools.robot

*** Keywords ***
join all nodes
    @{masters}=    Get Dictionary Keys    ${cluster_state["master"]}
    Remove From List    ${masters}    0
    ${count}    Evaluate    1
    FOR    ${master}    IN    @{masters}
        join    ${master}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Evaluate    0
    ${workers}    Get Dictionary Keys    ${cluster_state["worker"]}
    FOR    ${worker}    IN    @{workers}
        join    ${worker}
        ${count}    Evaluate    ${count}+1
    END
    Log    Bootstrap finish
    dump cluster state

bootstrap
    Comment    --kubernetes-version 1.15.2
    execute command with ssh    skuba cluster init --control-plane ${IP_LB} cluster
    skuba    node bootstrap --user ${VM_USER} --sudo --target ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]} ${CLUSTER_PREFIX}-master-0    True
    enable node in CS    ${CLUSTER_PREFIX}-master-0
    Get Directory    cluster    ${WORKDIR}    recursive=true

cluster running
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL"    deploy cluster vms
    load vm ip
    open ssh session    ${BOOSTRAP_MASTER}    alias=skuba_station
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    bootstrap
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    join all nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait pods
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait cillium

replica dex and gangway are correctly distribued
    ${dexreplicat}    Set Variable    3
    ${gangwayreplicat}    Set Variable    3
    Comment    TODO: add ready option
    ${nodes}    kubectl    get nodes -o name
    ${nodes_list}    Split String    ${nodes}    \n
    ${number of nodes}    Get Length    ${nodes_list}
    Run Keyword If    ${number of nodes} >= ${dexreplicat}    check replicat for    -l app=oidc-dex -n kube-system    ${dexreplicat}
    Run Keyword If    ${number of nodes} >= ${gangwayreplicat}    check replicat for    -l app=oidc-gangway -n kube-system    ${gangwayreplicat}

remove node
    [Arguments]    ${node_name}    ${shutdown_first}=False
    ${ip}    get node ip from CS    ${node_name}
    Run Keyword If    ${shutdown_first}    reboot or shutdown server    ${ip}    shutdown
    ${remove_output}    skuba    node remove --drain-timeout 2m ${node_name}    True
    Should Contain    ${remove_output}    node ${node_name} successfully removed from the cluster
    ${nodes_output}    kubectl    get nodes -o name
    Should Not Contain    ${nodes_output}    ${node_name}
    wait pods
    disable node in cs    ${node_name}

join
    [Arguments]    ${name}    ${ip}=auto    ${after_remove}=False
    ${node exist}    check node exit in CS    ${name}
    ${node disable}    Run Keyword If    ${node exist}    check node disable    ${name}
    ${ip}    Run Keyword If    ${node exist} and "${ip}"=="auto"    get node ip from CS    ${name}
    ...    ELSE    Set Variable    ${ip}
    ${type}    get node type    ${name}
    Run Keyword If    ${node exist} and not ${node disable}    Fail    Worker already part of the cluster !
    ...    ELSE IF    ${node exist} and ${node disable} and ${after_remove}    Run Keywords    unmask kubelet    ${ip}
    ...    AND    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${name}    True
    ...    AND    wait nodes
    ...    AND    wait pods
    ...    AND    enable node in CS    ${name}
    ...    ELSE IF    ${node exist} and ${node disable} and not ${after_remove}    Run Keywords    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${name}    True
    ...    AND    enable node in CS    ${name}
    ...    ELSE    Run Keywords    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${name}    True
    ...    AND    add node to cluster state    ${name}    ${ip}

unmask kubelet
    [Arguments]    ${ip}
    open ssh session    ${ip}    temporary
    execute command with ssh    sudo systemctl unmask kubelet    temporary
    [Teardown]    Close Connection
