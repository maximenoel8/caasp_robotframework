*** Settings ***
Library           Collections
Library           String

*** Variables ***
&{cluster_state}

*** Keywords ***
_add node to cluster state
    [Arguments]    ${type}    ${name}    ${ip}
    &{node_infos}    Create Dictionary    ip=${ip}    disable=False
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state}    ${type}
    &{node}    Run Keyword If    "${status}"=="PASS"    Create Dictionary    ${name}=${node_infos}    &{cluster_state["${type}"]}
    ...    ELSE    Create Dictionary    ${name}=${node_infos}
    Set To Dictionary    ${cluster_state}    ${type}=&{node}

_change node status in cluster state
    [Arguments]    ${type}    ${node_name}    ${status}    # has to be a boolean
    Set To Dictionary    ${cluster_state["${type}"]["${node_name}"]}    disable=${status}

_get node type
    [Arguments]    ${name}
    @{node}    Split String    ${name}    -
    ${type}    Get From List    ${node}    -2
    [Return]    ${type}

add worker to CS
    [Arguments]    ${name}    ${ip}
    _add node to cluster state    worker    ${name}    ${ip}

add master to CS
    [Arguments]    ${name}    ${ip}
    _add node to cluster state    master    ${name}    ${ip}

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
    ${type}    _get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    True

enable node in CS
    [Arguments]    ${name}
    ${type}    _get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    False
