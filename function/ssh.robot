*** Settings ***
Resource          interaction_with_cluster_state_dictionnary.robot
Library           SSHLibrary
Resource          ../parameters/global_parameters.robot

*** Keywords ***
open ssh session
    [Arguments]    ${server}    ${alias}=default    ${cluster_number}=1
    ${server_ip}    Run Keyword If    "${alias}"=="default"    get node ip from CS    ${server}    ${cluster_number}
    ...    ELSE    Set Variable    ${server}
    ${alias}    Set Variable If    "${alias}"=="default"    ${server}    ${alias}
    Open Connection    ${server_ip}    alias=${alias}
    Login With Public Key    ${VM_USER}    data/id_shared

reinitialize skuba session
    [Arguments]    ${cluster_number}=1
    Close All Connections
    create ssh session with workstation and nodes

create ssh session with workstation and nodes
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        open ssh session    ${BOOTSTRAP_MASTER_${cluster_number}}    alias=bootstrap_master_${cluster_number}
        open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}
        Run Keyword If    ${AIRGAPPED}    open ssh session    ${AIRGAPPED_IP}    alias=mirror
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
    Switch Connection    skuba_station_${cluster_number}
    FOR    ${node}    IN    @{nodes}
        Run Keyword If    "${PLATFORM}"=="aws"    create ssh session for worker on aws    ${node}    cluster_number=${cluster_number}
        ...    ELSE    open ssh session    ${node}    cluster_number=${cluster_number}
    END

create ssh session for workstation
    open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}

create ssh session for worker on aws
    [Arguments]    ${node}    ${cluster_number}=1
    ${elements}    Split String    ${node}    -
    ${index}    Set Variable    ${elements[-1]}
    ${lg}    Get Length    ${index}
    ${index}    Set Variable If    ${lg}==1    ${index}00    ${lg}==2    ${index}0    ${lg}==3    ${index}
    ${node_ip}    get node ip from CS    ${node}    ${cluster_number}
    Create Local Ssh Tunnel    31${index}    ${node_ip}    22    127.0.0.1
    Open Connection    127.0.0.1    port=31${index}    alias=${node}
    Login With Public Key    ${VM_USER}    ${DATADIR}/id_shared
