*** Settings ***
Library           Collections
Library           String
Library           JSONLibrary

*** Variables ***
&{cluster_state}

*** Keywords ***
add node to cluster state
    [Arguments]    ${name}    ${ip}    ${disable}=False
    ${type}    get node type    ${name}
    &{node_infos}    Create Dictionary    ip=${ip}    disable=${disable}
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state}    ${type}
    &{node}    Run Keyword If    "${status}"=="PASS"    Create Dictionary    ${name}=${node_infos}    &{cluster_state["${type}"]}
    ...    ELSE    Create Dictionary    ${name}=${node_infos}
    Set To Dictionary    ${cluster_state}    ${type}=&{node}

_change node status in cluster state
    [Arguments]    ${type}    ${node_name}    ${status}    # has to be a boolean
    Set To Dictionary    ${cluster_state["${type}"]["${node_name}"]}    disable=${status}

get node type
    [Arguments]    ${name}
    @{node}    Split String    ${name}    -
    ${type}    Get From List    ${node}    -2
    [Return]    ${type}

add lb to CS
    [Arguments]    ${ip}
    &{lb}    Create Dictionary    ip=${ip}
    Set To Dictionary    ${cluster_state}    lb=${lb}

add extra machine to CS
    [Arguments]    @{ips}
    &{machines}    Create Dictionary    ips_list=@{ips}
    Set To Dictionary    ${cluster_state}    extra_machines=${machines}

get extra machine ip and pop from CS
    @{ips_list}    Copy List    ${cluster_state["extra_machines"]["ips_list"]}
    ${length}    Get Length    ${ips_list}
    Should Not Be Equal As Integers    ${length}    0    Fresh Machine list is empty
    ${new_ip}    Remove From List    ${ips_list}    0
    Set To Dictionary    ${cluster_state["extra_machines"]}    ips_list=${ips_list}
    [Return]    ${new_ip}

disable node in cs
    [Arguments]    ${name}
    ${type}    get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    True

enable node in CS
    [Arguments]    ${name}
    ${type}    get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    False

check node exit in CS
    [Arguments]    ${name}
    ${type}    get node type    ${name}
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["${type}"]}    ${name}
    ${status}    Set Variable If    "${status}"=="PASS"    True    False
    ${status}    Convert To Boolean    ${status}
    [Return]    ${status}

get node ip from CS
    [Arguments]    ${name}
    ${type}    get node type    ${name}
    ${ip}    Get From Dictionary    ${cluster_state["${type}"]["${name}"]}    ip
    [Return]    ${ip}

check node disable
    [Arguments]    ${name}
    ${type}    get node type    ${name}
    ${status}    Get From Dictionary    ${cluster_state["${type}"]["${name}"]}    disable
    ${status}    Convert To Boolean    ${status}
    [Return]    ${status}

create cluster_state
    ${ip_dictionnary}=    Load JSON From File    ${LOGDIR}/cluster.json
    ${count}    Set Variable    0
    FOR    ${ip}    IN    @{ip_dictionnary["modules"][0]["outputs"]["ip_masters"]["value"]}
        add node to cluster state    ${CLUSTER_PREFIX}-master-${count}    ${ip}    True
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Set Variable    0
    FOR    ${ip}    IN    @{ip_dictionnary["modules"][0]["outputs"]["ip_workers"]["value"]}
        add node to cluster state    ${CLUSTER_PREFIX}-worker-${count}    ${ip}    True
        ${count}    Evaluate    ${count}+1
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["master"]["${CLUSTER_PREFIX}-master-0"]["ip"]}    ${ip_dictionnary["modules"]["outputs"][0]["ip_load_balancer"]["value"]}
    add lb to CS    ${IP_LB}
    [Return]    ${cluster_state}

load cluster state
    &{cluster_state_temp}    JSONLibrary.Load JSON From File    ${LOGDIR}/cluster_state.json
    Set To Dictionary    ${cluster_state}    &{cluster_state_temp}
