*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot
Resource          reboot.robot
Resource          helper.robot

*** Variables ***
${CP_vsphere}     True

*** Keywords ***
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
    ...    AND    wait nodes
    ...    AND    wait pods
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
    _check bootstrap retry
    open ssh session    ${WORKSTATION__${cluster_number}}    ${node}
    init cluster    ${node}    ${cluster_number}
    ${master_0_name}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-master-0    ${cluster_number}
    ${output}    skuba_write    node bootstrap --user ${VM_USER} --sudo --target ${cluster_state["${cluster}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]} ${master_0_name}
    Create File    ${LOGDIR}/deployment/${CLUSTER_PREFIX}-${cluster_number}-master-0    ${output}\n

_check bootstrap retry
    ${status}    ${output}    Run Keyword And Ignore Error    Variable Should Exist    ${RETRY_${cluster}}
    Run Keyword If    "${status}"=="FAIL"    Set Global Variable    ${RETRY_${cluster}}    0
    Run Keyword If    ${RETRY_${cluster}} == 4    Fail    Bootstrap fail after 4 retry
    ${current_retry}    Evaluate    ${RETRY_${cluster}}+1
    Set Global Variable    ${RETRY_${cluster}}    ${current_retry}

init cluster
    [Arguments]    ${alias}    ${cluster_number}=1
    ${extra_args}    Set Variable If    "${platform}"=="aws"    --cloud-provider aws    ${EMPTY}
    ${extra_args}    Set Variable If    "${platform}"=="vmware" and ${CP_vsphere}    --cloud-provider vsphere    ${EMPTY}
    ${extra_args}    Set Variable If    "${mode}"=="DEV" and "${KUBERNETES_VERSION}"!="${EMPTY}"    --kubernetes-version ${KUBERNETES_VERSION} ${extra_args}    ${extra_args}
    Run Keyword And Ignore Error    execute command with ssh    rm -rf cluster    ${alias}
    execute command with ssh    skuba cluster init ${extra_args} --control-plane ${IP_LB_${cluster_number}} cluster    ${alias}
    Run Keyword If    ${CP_vsphere}    _setup vsphere cloud configuration    ${cluster_number}

_setup vsphere cloud configuration
    [Arguments]    ${cluster_number}
    Copy File    ${DATADIR}/vsphere.conf.template    ${LOGDIR}/vsphere.conf
    modify string in file    ${LOGDIR}/vsphere.conf    <user>    ${vmware["VSPHERE_USER"]}
    modify string in file    ${LOGDIR}/vsphere.conf    <password>    ${vmware["VSPHERE_PASSWORD"]}
    modify string in file    ${LOGDIR}/vsphere.conf    <stack>    ${CLUSTER_PREFIX}-${cluster_number}
    Put File    ${LOGDIR}/vsphere.conf    /home/${VM_USER}/cluster/cloud/vsphere/
