*** Settings ***
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          ../parameters/global_parameters.robot
Library           SSHLibrary

*** Keywords ***
open ssh session
    [Arguments]    ${server}    ${alias}=default    ${proxy_cmd}=${EMPTY}    ${cluster_number}=1    ${user}=default
    ${user}    Set Variable If    "${user}"=="default"    ${VM_USER}    ${user}
    ${server_ip}    Run Keyword If    "${alias}"=="default"    get node ip from CS    ${server}    ${cluster_number}
    ...    ELSE    Set Variable    ${server}
    ${alias}    Set Variable If    "${alias}"=="default"    ${server}    ${alias}
    Open Connection    ${server_ip}    alias=${alias}    timeout=120
    Run Keyword If    "${proxy_cmd}"=="${EMPTY}"    Login With Public Key    ${user}    data/id_shared
    ...    ELSE    Login With Public Key    ${user}    data/id_shared    proxy_cmd=${proxy_cmd}

refresh ssh session
    [Arguments]    ${cluster_number}=1
    step    refresh ssh session
    Close All Connections
    create ssh session with workstation and nodes

create ssh session with workstation and nodes
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        open ssh session    ${BOOTSTRAP_MASTER_${cluster_number}}    alias=bootstrap_master_${cluster_number}
        open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}
        create ssh session for masters    ${cluster_number}
        create ssh session for workers    ${cluster_number}
    END
    Set Global Variable    ${CONNEXION_UP}    True

create ssh session for masters
    [Arguments]    ${cluster_number}
    @{nodes}    get master servers name    cluster_number=${cluster_number}
    FOR    ${node}    IN    @{nodes}
        open ssh session    ${node}    cluster_number=${cluster_number}
    END

create ssh session for workers
    [Arguments]    ${cluster_number}
    @{nodes}    get worker servers name    cluster_number=${cluster_number}
    FOR    ${node}    IN    @{nodes}
        ${ip}    get node ip from CS    ${node}
        ${proxy}    Set Variable If    "${PLATFORM}"=="aws" or "${PLATFORM}"=="azure"    ssh -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l ${VM_USER} -i ${DATADIR}/id_shared -W ${ip}:22 ${WORKSTATION_${cluster_number}}    ${EMPTY}
        open ssh session    ${node}    proxy_cmd=${proxy}    cluster_number=${cluster_number}
    END

create ssh session for workstation
    open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}
