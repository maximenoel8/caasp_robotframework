*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot
Resource          reboot.robot
Resource          helper.robot
Resource          tools.robot
Resource          ../parameters/vm_deployment.robot
Resource          vms_deployment/main_keywork.robot

*** Keywords ***
replica dex and gangway are correctly distribued
    step    check dex and gangway correctly are replicate
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
    step    remove ${node_name} from cluster
    ${ip}    get node ip from CS    ${node_name}
    ${skuba_node}    get node skuba name    ${node_name}
    Run Keyword If    ${shutdown_first}    reboot or shutdown server    ${ip}    shutdown
    ${remove_output}    skuba    node remove --drain-timeout 5m ${skuba_node}    True
    Should Contain    ${remove_output}    node ${skuba_node} successfully removed from the cluster
    ${nodes_output}    kubectl    get nodes -o name
    Should Not Contain    ${nodes_output}    ${node_name}
    sleep    2
    wait pods ready
    disable node in cs    ${node_name}

unmask kubelet
    [Arguments]    ${ip}
    open ssh session    ${ip}    temporary
    execute command with ssh    sudo systemctl unmask kubelet    temporary
    [Teardown]    Close Connection

join node
    [Arguments]    ${node}    ${cluster}=cluster_1    ${ip}=auto    ${after_remove}=False
    ${cluster_number}    get cluster number    ${cluster}
    open ssh session    ${WORKSTATION_${cluster_number}}    ${node}
    ${node exist}    check node exit in CS    ${node}    ${cluster_number}
    ${node disable}    Run Keyword If    ${node exist}    check node disable    ${node}    ${cluster_number}
    ${ip}    Run Keyword If    ${node exist} and "${ip}"=="auto"    get node ip from CS    ${node}    ${cluster_number}
    ...    ELSE    Set Variable    ${ip}
    ${type}    get node type    ${node}
    ${skuba_name}    get node skuba name    ${node}    ${cluster_number}
    Run Keyword If    ${node exist} and not ${node disable}    Fail    Worker already part of the cluster !
    ...    ELSE IF    ${node exist} and ${node disable} and ${after_remove}    Run Keywords    unmask kubelet    ${ip}
    ...    AND    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${skuba_name}    True
    ...    AND    wait nodes are ready
    ...    AND    wait pods ready
    ...    AND    enable node in CS    ${node}
    ...    ELSE IF    ${node exist} and ${node disable} and not ${after_remove}    initiale join    ${skuba_name}    ${ip}    ${type}
    ...    ELSE    Run Keywords    skuba    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${skuba_name}    True
    ...    AND    add node to cluster state    ${node}    ${ip}

initiale join
    [Arguments]    ${node}    ${ip}    ${type}
    ${output}    skuba_write    node join --role ${type} --user ${VM_USER} --sudo --target ${ip} ${node}
    Append To File    ${LOGDIR}/deployment/${node}    ${output}\n

start bootstrap
    [Arguments]    ${node}    ${cluster}
    ${cluster_number}    get cluster number    ${cluster}
    _check bootstrap retry    ${cluster_number}
    open ssh session    ${WORKSTATION__${cluster_number}}    ${node}
    init cluster    ${node}    ${cluster_number}
    ${master_0_name}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-master-0    ${cluster_number}
    ${output}    skuba_write    node bootstrap --user ${VM_USER} --sudo --target ${cluster_state["${cluster}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]} ${master_0_name}
    Append To File    ${LOGDIR}/deployment/${CLUSTER_PREFIX}-${cluster_number}-master-0    ${output}\n

_check bootstrap retry
    [Arguments]    ${cluster_number}
    ${status}    ${output}    Run Keyword And Ignore Error    Variable Should Exist    ${RETRY_${cluster_number}}
    Run Keyword If    "${status}"=="FAIL"    Set Global Variable    ${RETRY_${cluster_number}}    0
    Run Keyword If    ${RETRY_${cluster_number}} == 4    Fail    Bootstrap fail after 4 retry
    ${current_retry}    Evaluate    ${RETRY_${cluster_number}}+1
    Set Global Variable    ${RETRY_${cluster_number}}    ${current_retry}
    sleep    20

init cluster
    [Arguments]    ${alias}    ${cluster_number}=1
    ${extra_args}    Set Variable If    "${PLATFORM}"=="aws" or"${PLATFORM}"=="azure"    --cloud-provider ${PLATFORM}    ${EMPTY}
    ${extra_args}    Set Variable If    "${PLATFORM}"=="vmware" and ${CPI_VSPHERE}    --cloud-provider vsphere    ${extra_args}
    ${extra_args}    Set Variable If    "${MODE}"=="DEV" and "${KUBERNETES_VERSION}"!="${EMPTY}"    --kubernetes-version ${KUBERNETES_VERSION} ${extra_args}    ${extra_args}
    Run Keyword And Ignore Error    execute command with ssh    rm -rf cluster    ${alias}
    execute command with ssh    skuba cluster init ${extra_args} --control-plane ${IP_LB_${cluster_number}} cluster    ${alias}
    Run Keyword If    ${CPI_VSPHERE}    _setup vsphere cloud configuration    ${cluster_number}
    Run Keyword If    "${PLATFORM}"=="azure"    _setup azure cloud configuration    ${cluster_number}
