*** Settings ***
Library           Collections
Library           String
Library           JSONLibrary
Library           OperatingSystem
Resource          ../parameters/vm_deployment.robot

*** Variables ***

*** Keywords ***
add node to cluster state
    [Arguments]    ${name}    ${ip}    ${disable}=False    ${dns}=default    ${cluster_number}=1    ${local_ip}=default
    ${type}    get node type    ${name}
    ${skuba_name}    Set Variable If    "${dns}"=="default"    ${name}    ${dns}
    &{node_infos}    Create Dictionary    ip=${ip}    disable=${disable}    skuba_name=${skuba_name}    local_ip=${local_ip}
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["cluster_${cluster_number}"]}    ${type}
    &{node}    Run Keyword If    "${status}"=="PASS"    Create Dictionary    ${name}=${node_infos}    &{cluster_state["cluster_${cluster_number}"]["${type}"]}
    ...    ELSE    Create Dictionary    ${name}=${node_infos}
    Set To Dictionary    ${cluster_state["cluster_${cluster_number}"]}    ${type}=&{node}

_change node status in cluster state
    [Arguments]    ${type}    ${node_name}    ${status}    ${cluster_number}    # has to be a boolean
    Set To Dictionary    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${node_name}"]}    disable=${status}

get node type
    [Arguments]    ${name}
    @{node}    Split String    ${name}    -
    ${type}    Get From List    ${node}    -2
    [Return]    ${type}

add lb to CS
    [Arguments]    ${ip}    ${cluster_number}=1
    &{lb}    Create Dictionary    ip=${ip}
    Set To Dictionary    ${cluster_state["cluster_${cluster_number}"]}    lb=${lb}

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
    [Arguments]    ${name}    ${cluster_number}=1
    ${type}    get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    True    ${cluster_number}

enable node in CS
    [Arguments]    ${name}    ${cluster_number}=1
    ${type}    get node type    ${name}
    _change node status in cluster state    ${type}    ${name}    False    ${cluster_number}

check node exit in CS
    [Arguments]    ${name}    ${cluster_number}=1
    ${type}    get node type    ${name}
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["cluster_${cluster_number}"]["${type}"]}    ${name}
    ${status}    Set Variable If    "${status}"=="PASS"    True    False
    ${status}    Convert To Boolean    ${status}
    [Return]    ${status}

get node ip from CS
    [Arguments]    ${name}    ${cluster_number}=1
    Return From Keyword If    "${name}"=="skuba_station_${cluster_number}"    ${cluster_state["cluster_${cluster_number}"]["workstation"]}
    ${type}    get node type    ${name}
    ${ip}    Get From Dictionary    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${name}"]}    ip
    [Return]    ${ip}

check node disable
    [Arguments]    ${name}    ${cluster_number}=1
    ${type}    get node type    ${name}
    ${status}    Get From Dictionary    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${name}"]}    disable
    ${status}    Convert To Boolean    ${status}
    [Return]    ${status}

create cluster_state
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${var}    Evaluate    ${i}+1
        create cluster state for    ${var}
    END
    [Return]    ${cluster_state}

load cluster state
    &{cluster_state_temp}    JSONLibrary.Load JSON From File    ${LOGDIR}/cluster_state.json
    Set To Dictionary    ${cluster_state}    &{cluster_state_temp}

dump cluster state
    ${cluster_state_string}    Convert To String    ${cluster_state}
    ${cluster_state_string}    Replace String    ${cluster_state_string}    '    "
    ${status}    ${value}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["cluster_1"]}    master
    Run Keyword If    "${status}"=="PASS"    Create File    ${LOGDIR}/cluster_state.json    ${cluster_state_string}

get master servers name
    [Arguments]    ${with_status}=all    ${cluster_number}=1    # ( all | enable | disable )
    ${master_keys}    _get node name    with_status=${with_status}    type=master    cluster_number=${cluster_number}
    [Return]    ${master_keys}

get worker servers name
    [Arguments]    ${with_status}=all    ${cluster_number}=1    # ( all | enable | disable )
    ${worker_keys}    _get node name    with_status=${with_status}    type=worker    cluster_number=${cluster_number}
    [Return]    ${worker_keys}

create first cluster_state level
    [Arguments]    ${cluster_number}
    &{version}    Create Dictionary
    &{cluster}    Create Dictionary    platform=${PLATFORM}    versions=&{version}
    Collections.Set To Dictionary    ${cluster_state}    cluster_${cluster_number}=${cluster}

_create cluster_state terraform 11 for
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    ${count}    Set Variable    0
    ${length}    Get Length    ${ip_dictionnary["modules"][0]["outputs"]["ip_masters"]["value"]}
    ${length}    Evaluate    ${length}-1
    FOR    ${ip}    IN    @{ip_dictionnary["modules"][0]["outputs"]["ip_masters"]["value"]}
        Run Keyword If    ${count}==${length}    Run Keywords    add workstation    ${ip}    ${cluster_number}
        ...    AND    Exit For Loop
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-master-${count}    ${ip}    True    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Set Variable    0
    FOR    ${ip}    IN    @{ip_dictionnary["modules"][0]["outputs"]["ip_workers"]["value"]}
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-worker-${count}    ${ip}    True    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["modules"][0]["outputs"]}    ip_load_balancer
    Comment    ${IP_LB}    Set Variable    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["modules"][0]["outputs"]["ip_load_balancer"]["value"][0]}
    add lb to CS    ${IP_LB}    ${cluster_number}
    [Return]    ${cluster_state}

get nodes name from CS
    [Arguments]    ${cluster_number}=1
    @{masters}    get master servers name    cluster_number=${cluster_number}
    @{workers}    get worker servers name    cluster_number=${cluster_number}
    @{nodes}    Combine Lists    ${masters}    ${workers}
    [Return]    ${nodes}

_create cluster_state terraform 12 for
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    @{masters}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    @{workers}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_workers"]["value"]}
    ${count}    Set Variable    0
    ${length}    Get Length    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    ${length}    Evaluate    ${length}-1
    FOR    ${key}    IN    @{masters}
        Run Keyword If    ${count}==${length}    Run Keywords    add workstation    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    ${cluster_number}
        ...    AND    Exit For Loop
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    True    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    FOR    ${key}    IN    @{workers}
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_workers"]["value"]["${key}"]}    True    cluster_number=${cluster_number}
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["outputs"]}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["outputs"]["ip_load_balancer"]["value"]["${CLUSTER_PREFIX}-${cluster_number}-lb"]}
    add lb to CS    ${IP_LB}    ${cluster_number}

create cluster state for
    [Arguments]    ${cluster_number}=1
    ${ip_dictionnary}=    Load JSON From File    ${LOGDIR}/cluster${cluster_number}.json
    create first cluster_state level    ${cluster_number}
    Run Keyword If    "${ip_dictionnary["terraform_version"]}"=="0.11.11"    _create cluster_state terraform 11 for    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${PLATFORM}"=="openstack"    _create cluster_state for openstack    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${PLATFORM}"=="aws"    _create cluster_state for aws    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${PLATFORM}"=="vmware"    _create_cluster_state_for_vmware    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${PLATFORM}"=="azure"    _create cluster_state for azure    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE    Fail    Wrong platform file
    Comment    Run Keyword If    "${ip_dictionnary["terraform_version"]}"=="0.11.11"    _create cluster_state terraform 11 for    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${ip_dictionnary["terraform_version"]}"=="0.12.19" and not "${PLATFORM}"=="aws"    _create cluster_state terraform 12 for    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE IF    "${PLATFORM}"=="aws"    _create cluster_state for aws    ${ip_dictionnary}    ${cluster_number}
    ...    ELSE    Fail    Wrong platform file

_create cluster_state for aws
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    @{aws_masters_key}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["control_plane_public_ip"]["value"]}
    @{aws_workers_key}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["nodes_private_dns"]["value"]}
    ${count}    Set Variable    0
    ${length}    Get Length    ${aws_masters_key}
    ${length}    Evaluate    ${length}-1
    FOR    ${key}    IN    @{aws_masters_key}
        Run Keyword If    ${count}==${length}    Run Keywords    add workstation    ${ip_dictionnary["outputs"]["control_plane_public_ip"]["value"]["${key}"]}    ${cluster_number}
        ...    AND    Exit For Loop
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-master-${count}    ${ip_dictionnary["outputs"]["control_plane_public_ip"]["value"]["${key}"]}    True    ${ip_dictionnary["outputs"]["control_plane_private_dns"]["value"]["${key}"]}    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Set Variable    0
    FOR    ${key}    IN    @{aws_workers_key}
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-worker-${count}    ${ip_dictionnary["outputs"]["nodes_private_dns"]["value"]["${key}"]}    True    ${ip_dictionnary["outputs"]["nodes_private_dns"]["value"]["${key}"]}    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["outputs"]}    elb_address
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["outputs"]["elb_address"]["value"]}
    add lb to CS    ${IP_LB}    ${cluster_number}

check cluster state exist
    ${status}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster_state.json
    [Return]    ${status}

check cluster state integrity
    ${clusters}    Get Dictionary Keys    ${cluster_state}
    ${cluster_length}    Get Length    ${clusters}
    Return From Keyword If    "${cluster_length}"==0    False
    FOR    ${cluster}    IN    @{clusters}
        ${keys}    Get Dictionary Keys    ${cluster_state["${cluster}"]}
        ${status_master}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["${cluster}"]}    master
        ${status_worker}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["${cluster}"]}    worker
        ${status_lb}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${cluster_state["${cluster}"]}    lb
        Return From Keyword If    "${status_master}"=="FAIL" or "${status_worker}"=="FAIL" or "${status_lb}"=="FAIL"    False
    END
    Return From Keyword    True
    [Return]    ${status}

_get node name
    [Arguments]    ${with_status}    ${type}    ${cluster_number}
    ${node_keys}    Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["${type}"]}
    log    ${with_status}
    FOR    ${node}    IN    @{node_keys}
        BuiltIn.Exit For Loop If    "${with_status}"=="all"
        ${status}    Set Variable if    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${node}"]["disable"]}    disable    enable
        Run Keyword If    "${with_status}"!="${status}"    Remove Values From List    ${node_keys}    ${node}
    END
    [Return]    ${node_keys}

get node skuba name
    [Arguments]    ${node_name}    ${cluster_number}=1
    ${type}    get node type    ${node_name}
    ${skuba_name}    Set Variable    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${node_name}"]["skuba_name"]}
    [Return]    ${skuba_name}

add workstation
    [Arguments]    ${ip}    ${cluster_number}
    Set To Dictionary    ${cluster_state["cluster_${cluster_number}"]}    workstation=${ip}

get number of nodes
    [Arguments]    ${cluster_number}=1    ${role}=all
    ${nodes}    Run Keyword If    "${role}"=="all"    get nodes name from CS    ${cluster_number}
    ...    ELSE IF    "${role}"=="worker"    get worker servers name    cluster_number=${cluster_number}
    ...    ELSE IF    "${role}"=="master"    get master servers name    cluster_number=${cluster_number}
    ...    ELSE    Fail    Wrong role ${role}
    ${length}    Get Length    ${nodes}
    [Return]    ${length}

_create_cluster_state_for_vmware
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    @{masters}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    @{workers}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_workers"]["value"]}
    ${count}    Set Variable    0
    ${length}    Get Length    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    ${length}    Evaluate    ${length}-1
    FOR    ${key}    IN    @{masters}
        Run Keyword If    ${count}==${length}    Run Keywords    add workstation    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    ${cluster_number}
        ...    AND    Exit For Loop
        Comment    ${hostname_octet}    _get_hostname_vmware    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}
        Comment    ${hostname}    Set Variable If    ${DNS_HOSTNAME}    ${hostname_octet}    ${key}
        ${hostname}    Set Variable    ${key}
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    True    ${hostname}    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    FOR    ${key}    IN    @{workers}
        Comment    ${hostname_octet}    _get_hostname_vmware    ${ip_dictionnary["outputs"]["ip_workers"]["value"]["${key}"]}
        Comment    ${hostname}    Set Variable If    ${DNS_HOSTNAME}    ${hostname_octet}    ${key}
        ${hostname}    Set Variable    ${key}
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_workers"]["value"]["${key}"]}    True    ${hostname}    cluster_number=${cluster_number}
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["outputs"]}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["outputs"]["ip_load_balancer"]["value"]["${CLUSTER_PREFIX}-${cluster_number}-lb-0"]}
    add lb to CS    ${IP_LB}    ${cluster_number}

_get_hostname_vmware
    [Arguments]    ${ip}
    @{digits}    Split String    ${ip}    .
    ${hostname}    Set Variable
    FOR    ${digit}    IN    @{digits}
        ${lt}    Get Length    ${digit}
        ${first_digit}    Set Variable If    ${lt}==1    00${digit}    ${lt}==2    0${digit}    ${lt}==3    ${digit}
        ${hostname}    Set Variable    ${hostname}${first_digit}
    END
    [Return]    ${hostname}

get all nodes skuba_name from CS
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    cluster_number=${cluster_number}
    ${skuba_names}    Create List
    FOR    ${node}    IN    @{nodes}
        ${skuba_name}    get node skuba name    ${node}
        Append To List    ${skuba_names}    ${skuba_name}
    END
    [Return]    ${skuba_names}

get node type from skuba name
    [Arguments]    ${skuba_name}
    @{nodes}    get nodes name from CS
    ${type}    Set Variable    None
    FOR    ${node}    IN    @{nodes}
        ${name}    get node skuba name    ${node}
        Continue For Loop If    "${skuba_name}"!="${name}"
        ${type}    get node type    ${node}
        Exit For Loop If    "${skuba_name}"=="${name}"
    END
    Run Keyword If    "${type}"=="None"    Fail    Skuba name ${skuba_name} doesn't exist
    [Return]    ${type}

_create cluster_state for azure
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    @{azure_masters_key}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["masters_public_ip"]["value"]}
    @{azure_workers_key}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["workers_private_ip"]["value"]}
    ${count}    Set Variable    0
    ${length}    Get Length    ${azure_masters_key}
    ${length}    Evaluate    ${length}-1
    FOR    ${key}    IN    @{azure_masters_key}
        Run Keyword If    ${count}==${length}    Run Keywords    add workstation    ${ip_dictionnary["outputs"]["masters_public_ip"]["value"]["${key}"]}    ${cluster_number}
        ...    AND    Exit For Loop
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-master-${count}    ${ip_dictionnary["outputs"]["masters_public_ip"]["value"]["${key}"]}    True    ${key}    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Set Variable    0
    FOR    ${key}    IN    @{azure_workers_key}
        add node to cluster state    ${CLUSTER_PREFIX}-${cluster_number}-worker-${count}    ${ip_dictionnary["outputs"]["workers_private_ip"]["value"]["${key}"]}    True    ${key}    cluster_number=${cluster_number}
        ${count}    Evaluate    ${count}+1
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["outputs"]}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["outputs"]["ip_load_balancer"]["value"]["fqdn"]}
    add lb to CS    ${IP_LB}    ${cluster_number}

_create cluster_state for openstack
    [Arguments]    ${ip_dictionnary}    ${cluster_number}
    @{masters}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    @{workers}    Get Dictionary Keys    ${ip_dictionnary["outputs"]["ip_workers"]["value"]}
    ${count}    Set Variable    0
    ${length}    Get Length    ${ip_dictionnary["outputs"]["ip_masters"]["value"]}
    ${length}    Evaluate    ${length}-1
    FOR    ${key}    IN    @{masters}
        Run Keyword If    ${count}==${length} and ${skuba_station}    Run Keywords    add workstation    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    ${cluster_number}
        ...    AND    Exit For Loop
        ${local_ip}    _get local ip for openstack    ${ip_dictionnary}    ${key}
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_masters"]["value"]["${key}"]}    True    cluster_number=${cluster_number}    local_ip=${local_ip}
        ${count}    Evaluate    ${count}+1
    END
    FOR    ${key}    IN    @{workers}
        add node to cluster state    ${key}    ${ip_dictionnary["outputs"]["ip_workers"]["value"]["${key}"]}    True    cluster_number=${cluster_number}
    END
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary["outputs"]}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}    ${ip_dictionnary["outputs"]["ip_load_balancer"]["value"]["${CLUSTER_PREFIX}-${cluster_number}-lb"]}
    add lb to CS    ${IP_LB}    ${cluster_number}

_get local ip for openstack
    [Arguments]    ${dictionnary}    ${node}
    ${type}    get node type    ${node}
    FOR    ${element}    IN    @{dictionnary["resources"]}
        ${instances}    Set Variable If    "${element["name"]}"=="${type}" and "${element["type"]}"=="openstack_compute_instance_v2"    ${element["instances"]}
        Exit For Loop If    "${element["name"]}"=="${type}" and "${element["type"]}"=="openstack_compute_instance_v2"
    END
    FOR    ${instance}    IN    @{instances}
        ${ip}    Set Variable If    "${instance["attributes"]["name"]}"=="${node}"    ${instance["attributes"]["network"][0]["fixed_ip_v4"]}
        Exit For Loop If    "${instance["attributes"]["name"]}"=="${node}"
        log    ${ip}
    END
    [Return]    ${ip}

platform is ${platform}
    Should Be Equal    ${cluster_state["cluster_1"]["platform"]}    ${platform}

write cluster containers version in CS
    [Arguments]    ${container}    ${version}    ${cluster_number}=1
    Set To Dictionary    ${cluster_state["cluster_${cluster_number}"]["versions"]}    ${container}    ${version}

get skuba names by type
    [Arguments]    ${type}    ${cluster_number}=1
    @{node_keys}    Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["${type}"]}
    ${skuba_name}    Create List
    FOR    ${node}    IN    @{node_keys}
        Append To List    ${skuba_name}    ${cluster_state["cluster_${cluster_number}"]["${type}"]["${node}"]["skuba_name"]}
    END
    [Return]    ${skuba_name}
