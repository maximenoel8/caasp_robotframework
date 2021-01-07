*** Settings ***
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          ../parameters/global_parameters.robot
Library           SSHLibrary
Resource          tools.robot

*** Keywords ***
open ssh session
    [Arguments]    ${server}    ${alias}=default    ${cluster_number}=1    ${user}=default    ${timeout}=120
    [Documentation]    Create ssh session to vm and set it to an alias that can be pass in arguments
    ...
    ...    Can create ssh session through bastion
    ${user}    Set Variable If    "${user}"=="default"    ${VM_USER}    ${user}
    ${server_ip}    Run Keyword If    "${alias}"=="default"    get node ip from CS    ${server}    ${cluster_number}
    ...    ELSE    Set Variable    ${server}
    ${resolv_ip}    _check ip resolvable    ${server_ip}
    ${alias}    Set Variable If    "${alias}"=="default"    ${server}    ${alias}
    Open Connection    ${server_ip}    alias=${alias}    timeout=${timeout}
    Run Keyword If    ${resolv_ip}    Login With Public Key    ${user}    ${DATADIR}/id_shared
    ...    ELSE    _login with proxy    ${server_ip}    ${user}    ${cluster_number}

refresh ssh session
    [Arguments]    ${cluster_number}=1
    step    refresh ssh session
    Close All Connections
    create ssh session with workstation and nodes

create ssh session with workstation and nodes
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        open ssh session    ${BOOTSTRAP_MASTER_${cluster_number}}    alias=bootstrap_master_${cluster_number}
        Run Keyword If    ${skuba_station}    open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}
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
        open ssh session    ${node}    cluster_number=${cluster_number}
    END

create ssh session for workstation
    open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}

_do I need proxy
    [Arguments]    ${node}
    ${type}    get node type    ${node}
    ${status}    Set Variable If    ("${PLATFORM}"=="aws" or "${PLATFORM}"=="azure") and "${type}"=="worker"    True    False
    [Return]    ${status}

_login with proxy
    [Arguments]    ${server_ip}    ${user}    ${cluster_number}
    ${proxy_cmd}    Set Variable    ssh -o BatchMode=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l ${VM_USER} -i ${DATADIR}/id_shared -W ${server_ip}:22 ${WORKSTATION_${cluster_number}}
    Login With Public Key    ${user}    ${DATADIR}/id_shared    proxy_cmd=${proxy_cmd}

_check ip resolvable
    [Arguments]    ${ip}
    ${status}    ${output}    Run Keyword And Ignore Error    resolv dns    ${ip}
    ${status_ping}    ${output_ping}    Run Keyword And Ignore Error    execute command localy    ping -c 1 ${ip}
    Return From Keyword If    "${status}"=="PASS" or "${status_ping}"=="PASS"    True
    Should Contain    ${output}    server can't find
    ${status}    Set Variable    False
    [Return]    ${status}
