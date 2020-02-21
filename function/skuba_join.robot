*** Settings ***
Resource          generic_function.robot
Library           Collections
Resource          skuba_tool_install.robot
Resource          helpers.robot
Resource          infra_setup/main_keywork.robot

*** Keywords ***
join all nodes
    @{masters}=    Copy List    ${MASTER_IP}
    Remove From List    ${masters}    0
    ${count}    Evaluate    1
    FOR    ${ip}    IN    @{masters}
        join    ${SUFFIX}-${CLUSTER}-master-${count}    ${ip}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Evaluate    0
    FOR    ${ip}    IN    @{WORKER_IP}
        join    ${SUFFIX}-${CLUSTER}-worker-${count}    ${ip}
        ${count}    Evaluate    ${count}+1
    END
    Log    Bootstrap finish

bootstrap
    execute command with ssh    skuba cluster init --control-plane ${IP_LB} cluster
    skuba    node bootstrap --user ${VM_USER} --sudo --target ${SKUBA_STATION} ${SUFFIX}-${CLUSTER}-master-0 -v 10    True
    add node to cluster state    ${SUFFIX}-${CLUSTER}-master-0    ${SKUBA_STATION}
    Get Directory    cluster    ${WORKDIR}    recursive=true

cluster running
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    deploy cluster vms
    get VM IP
    open ssh session    ${SKUBA_STATION}    alias=skuba_station
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    bootstrap
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    join all nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait_nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait_pods
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait_cillium

replica dex and gangway are correctly distribued
    ${dexreplicat}    Set Variable    3
    ${gangwayreplicat}    Set Variable    3
    ${nodes}    kubectl    get nodes -o name
    ${nodes_list}    Split String    ${nodes}    \n
    ${number of nodes}    Get Length    ${nodes_list}
    Run Keyword If    ${number of nodes} >= ${dexreplicat}    check replicat for    -l app=oidc-dex -n kube-system    ${dexreplicat}
    Run Keyword If    ${number of nodes} >= ${gangwayreplicat}    check replicat for    -l app=oidc-gangway -n kube-system    ${gangwayreplicat}

remove node
    [Arguments]    ${node_name}
    ${remove_output}    skuba    node remove ${node_name}    True
    Should Contain    ${remove_output}    node ${node_name} successfully removed from the cluster
    ${nodes_output}    kubectl    get nodes -o name
    Should Not Contain    ${nodes_output}    ${node_name}
    wait_pods
    disable node in cs    ${node_name}

join
    [Arguments]    ${name}    ${ip}=auto
    ${node exist}    check node exit in CS    ${name}
    ${node disable}    Run Keyword If    ${node exist}    check node disable    ${name}
    ${ip}    Run Keyword If    ${node exist} and "${ip}"=="auto"    get node ip from CS    ${name}
    ...    ELSE    Set Variable    ${ip}
    ${type}    get node type    ${name}
    Run Keyword If    ${node exist} and not ${node disable}    Fail    Worker already part of the cluster !
    ...    ELSE IF    ${node exist} and ${node disable}    Run Keywords    skuba    ${ip}
    ...    AND    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${name}    True
    ...    AND    enable node in CS    ${name}
    ...    ELSE    Run Keywords    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${name}    True
    ...    AND    add node to cluster state    ${name}    ${ip}

unmask kubelet
    [Arguments]    ${ip}
    open ssh session    ${ip}    temporary
    execute command with ssh    sudo systemctl unmask kubelet    temporary
    [Teardown]    Close Connection
