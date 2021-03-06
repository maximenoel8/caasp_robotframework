*** Settings ***
Library           OperatingSystem
Resource          commands.robot
Library           String
Library           Collections
Resource          govc.robot
Resource          tools.robot
Library           yaml
Resource          helper.robot
Resource          ../parameters/general_information.robot
Resource          vms_deployment/terraform.robot

*** Keywords ***
wait nodes are ready
    [Arguments]    ${nodes}=${EMPTY}    ${cluster_number}=1
    kubectl    wait nodes --all --for=condition=ready --timeout=10m ${nodes}    ${cluster_number}

wait reboot
    [Arguments]    ${cluster_number}=1
    Wait Until Keyword Succeeds    600s    30s    kubectl    cluster-info    ${cluster_number}

wait pods ready
    [Arguments]    ${arguments}=${EMPTY}    ${cluster_number}=1
    Run Keyword If    "${arguments}"=="${EMPTY}"    wait all pods are running    ${cluster_number}
    Return From Keyword If    "${arguments}"=="${EMPTY}"    PASS
    ${status}    Wait Until Keyword Succeeds    3x    2min    _wait pod ready    ${arguments}    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL"    Fail    waiting for pods with argument ${arguments} fail

wait cillium
    [Arguments]    ${cluster_number}=1
    ${cilium_pod_names}    wait podname    -l k8s-app=cilium -n kube-system    ${cluster_number}
    ${number_cillium_pods}    Get Length    ${cilium_pod_names}
    ${cillium_pod_status}    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status    ${cluster_number}
    ${controler_status}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *([0-9]+)/    1
    ${controler_status_2}    Get Regexp Matches    ${cillium_pod_status}    Controller Status: *[0-9]+/([0-9]+)    1
    Should Be Equal    ${controler_status}    ${controler_status_2}    Controller status unhealthy
    Wait Until Keyword Succeeds    600s    15s    kubectl    -n kube-system exec ${cilium_pod_names[0]} -- cilium status | grep -E "^Cluster health:\\s+(${number_cillium_pods})/\\1 reachable"    ${cluster_number}

wait podname
    [Arguments]    ${args}    ${cluster_number}=1    ${timeout}=10m
    ${output}    kubectl    wait pods --for=condition=ready --timeout=${timeout} ${args} -o name    ${cluster_number}
    ${output}    Remove String    ${output}    pod/
    ${pod_names}    Split String    ${output}    \n
    ${length}    Get Length    ${pod_names}
    ${pod_name}    Set Variable If    ${length}==1    ${pod_names[0]}    ${pod_names}
    [Return]    ${pod_name}

get ressource name
    [Arguments]    ${args}    ${ressource_type}    ${cluster_number}=1
    @{names}    Create List
    ${output}    kubectl    get ${ressource_type} ${args} -o name    ${cluster_number}
    ${element_names}    Split String    ${output}    \n
    FOR    ${element_name}    IN    @{element_names}
        ${element_parts}    Split String    ${element_name}    /
        Collections.Append To List    ${names}    ${element_parts[-1]}
    END
    ${length}    Get Length    ${element_names}
    ${ressource_name}    Set Variable If    ${length}==1    ${names[0]}    ${names}
    [Return]    ${ressource_name}

check replicat for
    [Arguments]    ${args}    ${number_replicat}
    ${ouput}    kubectl    describe pods ${args}
    ${nodes_list}    Get Regexp Matches    ${ouput}    Node: *(.*)/.*\n    1
    ${length}    Get Length    ${nodes_list}
    Should Be Equal As Integers    ${length}    ${number_replicat}    Number of ${args} not equal to replicat
    List Should Not Contain Duplicates    ${nodes_list}    ${args} are not correctly replicate

check pod log contain
    [Arguments]    ${args}    ${expected_value}
    ${output}    kubectl    logs ${args}
    Should Contain    ${output}    ${expected_value}

wait deploy
    [Arguments]    ${arg}    ${timeout}=8m
    kubectl    wait deployment --for=condition=available --timeout=${timeout} ${arg}

wait all pods are running
    [Arguments]    ${cluster_number}=1
    ${pods}    get pod list and try restart crashpod    ${cluster_number}
    FOR    ${i}    IN RANGE    1    60
        ${output}    kubectl    get pods --no-headers -n kube-system -o wide | grep -vw Completed | grep -vw Terminating    ${cluster_number}
        ${status}    ${pod}    check pods running    ${output}
        Exit For Loop If    ${status}
        Sleep    15
    END
    Run Keyword If    not ${status}    Fail    Pod ${pod} not running
    Comment    FOR    ${element}    IN    @{pods}
    Comment    \    ${key}    Split String    ${element}
    Comment    \    ${status}    ${output}    Run Keyword If    "${key[2]}"!="Running"    Run Keyword And Ignore Error    kubectl    wait pods --for=condition=ready --timeout=10m ${key[0]} -n kube-system    ${cluster_number}
    Comment    \    Exit For Loop If    "${status}"=="FAIL"
    Comment    END
    Comment    ${status pod not found}    Run Keyword If    "${status}"=="FAIL"    check string contain    ${output}    Error from server (NotFound): pods
    ...    ELSE    Set Variable    False
    Comment    Run Keyword If    ${status pod not found}    wait all pods are running    ${cluster_number}

expose service
    [Arguments]    ${service}    ${port}    ${namespace}=default
    ${service_string}    Split String    ${service}    ${SPACE}
    ${service_name}    Set Variable    ${service_string[-1]}
    kubectl    expose ${service} --port=${port} --type=NodePort -n ${namespace} --name="expose-${service_name}"
    ${node port}    kubectl    get svc/expose-${service_name} -n ${namespace} -o json | jq '.spec.ports[0].nodePort'
    [Return]    ${nodePort}

wait job
    [Arguments]    ${arguments}    ${condition}    ${cluster_number}=1
    kubectl    wait job --for=condition=${condition} --timeout=5m ${arguments}    ${cluster_number}

wait pod deleted
    [Arguments]    ${arguments}    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    wait pods --for=delete --timeout=5m ${arguments}    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL" and "${output}"!="error: no matching resources found"    Fail    ${output}

restart CrashLoopBack pod
    [Arguments]    ${pods}    ${cluster_number}=1
    ${length}    Get Length    ${pods}
    ${status}    Set Variable    True
    FOR    ${pod}    IN    @{PODS}
        ${elements}    Split String    ${pod}
        Run Keyword If    "${elements[2]}"=="CrashLoopBackOff"    kubectl    delete pod ${elements[0]} -n kube-system    ${cluster_number}
        Continue For Loop If    not ${status}
        ${status}    Set Variable If    "${elements[2]}"=="CrashLoopBackOff"    False    True
    END
    [Return]    ${status}

get node description
    [Arguments]    ${cluster_number}=1
    ${output}    kubectl    get nodes -o json    cluster_number=${cluster_number}
    Create File    ${LOGDIR}/node_description.json    ${output}
    ${node_json}    Load JSON From File    ${LOGDIR}/node_description.json
    Log Dictionary    ${node_json}
    &{node description}    Create Dictionary
    FOR    ${item}    IN    @{node_json["items"]}
        Set To Dictionary    ${node description}    ${item["metadata"]["name"]}=${item["status"]}
    END
    Log Dictionary    ${node description}
    [Return]    ${node description}

check nodes version are equal
    [Arguments]    ${fail_status}=False    ${cluster_number}=1
    ${dictionnary}    get node description    cluster_number=${cluster_number}
    ${nodes}    Get Dictionary Keys    ${dictionnary}
    ${previous_version}    Set Variable    ${EMPTY}
    FOR    ${node}    IN    @{NODES}
        ${version}    Set Variable    ${dictionnary["${node}"]["nodeInfo"]["kubeletVersion"]}
        ${status}    Set Variable If    "${version}"!="${previous_version}" and not "${previous_version}"=="${EMPTY}"    False    True
        Exit For Loop If    not ${status}
        ${previous_version}    Set Variable    ${version}
    END
    Run Keyword If    ${fail_status}    Should Be True    ${status}
    [Return]    ${status}

wait until node version are the same
    [Arguments]    ${cluster_number}=1
    Wait Until Keyword Succeeds    5min    15sec    check nodes version are equal    True    cluster_number=${cluster_number}

get pod list and try restart crashpod
    [Arguments]    ${cluster_number}
    FOR    ${i}    IN RANGE    1    10
        ${output}    kubectl    get pods --no-headers -n kube-system -o wide | grep -vw Completed | grep -vw Terminating    ${cluster_number}
        @{pods}    Split To Lines    ${output}
        ${status}    restart CrashLoopBack pod    ${pods}    ${cluster_number}
        Exit For Loop If    ${status}
        Sleep    20
    END
    [Return]    ${pods}

check pods running
    [Arguments]    ${output}
    ${lines}    Split To Lines    ${output}
    FOR    ${line}    IN    @{lines}
        ${elements}    Split String    ${line}
        ${status}    Set Variable If    "${elements[2]}"=="Running"    True    False
        Exit For Loop If    not ${status}
        ${number_pod_running}    Get Regexp Matches    ${elements[1]}    ([0-9]+)/([0-9]+)    1    2
        ${status}    Set Variable If    ${number_pod_running[0][0]}==${number_pod_running[0][1]}    True    False
        Exit For Loop If    not ${status}
    END
    ${pod}    Set Variable if    not ${status}    ${elements[0]}    ${EMPTY}
    [Return]    ${status}    ${pod}

kured config
    [Arguments]    ${args}    ${cluster_number}=1
    Run Keyword If    "${args}"=="on"    kubectl    -n kube-system annotate ds kured weave.works/kured-node-lock-    ${cluster_number}
    ...    ELSE IF    "${args}"=="off"    kubectl    -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}'    ${cluster_number}
    ...    ELSE    _patch kured    ${args}

_patch kured
    [Arguments]    ${args}
    ${patch}    Set Variable    { "spec": { "template": { "spec": { "containers": [ { "name": "kured", "command": [ "/usr/bin/kured", "${args}" ] } ] } } } }
    kubectl    -n kube-system patch ds kured -p '${patch}'

get ${service} service ip
    ${ip}    kubectl    get svc ${service} -ojsonpath={.spec.clusterIP}
    Should Match Regexp    ${ip}    ^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$
    [Return]    ${ip}

wait ${type} ${name} in ${namespace} is ready
    FOR    ${i}    IN RANGE    0    60
        sleep    5
        ${result}    kubectl    get ${type} ${name} -n ${namespace}
        ${lines}    Split To Lines    ${result}
        ${elements}    Split String    ${lines[1]}
        Should Be Equal    ${elements[0]}    ${name}
        ${status}    Set Variable If    "${elements[1]}"=="True"    True    False
        Exit For Loop If    ${status}
    END
    Should Not Be Equal    ${i}    59

get kubernetes version
    [Arguments]    ${type}=all    ${format}=minor    # format can be minor ( return 1.x.x ) or major ( return 1.x )
    [Documentation]    type can be server or client
    ...    format can be major or minor
    ${result}    kubectl    version --short
    @{lines}    Split To Lines    ${result}
    ${versions}    Create Dictionary
    FOR    ${line}    IN    @{lines}
        ${element}    Split String    ${line}
        ${version}    Remove String    ${element[2]}    v
        ${sub_version}    Split String    ${version}    .
        Run Keyword If    "${element[0]}"=="Client"    Set To Dictionary    ${versions}    client_minor=${version}    client_major=${sub_version[0]}.${sub_version[1]}
        ...    ELSE IF    "${element[0]}"=="Server"    Set To Dictionary    ${versions}    server_minor=${version}    server_major=${sub_version[0]}.${sub_version[1]}
    END
    ${output}    Run Keyword If    "${type}"=="all" and "${format}"=="minor"    Create List    ${versions["client_minor"]}    ${versions["server_minor"]}
    ...    ELSE IF    "${type}"=="all" and "${format}"=="major"    Create List    ${versions["client_major"]}    ${versions["server_major"]}
    ...    ELSE IF    "${type}"!="all"    Create List    ${versions["${type}_${format}"]}
    [Return]    ${output}

wait daemonset are ready
    [Arguments]    ${name}    ${namespace}=kube-system    ${cluster_number}=1
    FOR    ${i}    IN RANGE    0    60
        sleep    5
        ${result}    kubectl    get ds ${name} -n ${namespace}    ${cluster_number}
        ${lines}    Split To Lines    ${result}
        ${elements}    Split String    ${lines[1]}
        Should Be Equal    ${elements[0]}    ${name}
        ${status}    Set Variable If    ${elements[1]}==${elements[3]}    True    False
        Exit For Loop If    ${status}
    END
    Should Not Be Equal    ${i}    59

patch vm provider for all nodes
    step    Patch vm provider
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        ${UUID}    get ${node} UUID
        ${skuba_name}    get node skuba name    ${node}
        kubectl    patch node ${skuba_name} -p "{\\"spec\\":{\\"providerID\\":\\"vsphere://${UUID}\\"}}"
    END

save kubeadm-config to local machine as ${file}
    kubectl    -n kube-system get cm/kubeadm-config -o yaml > ${LOGDIR}/${file}

edit and apply ${file} for vsphere provider
    ${kubeadmin}    open yaml file    ${LOGDIR}/${file}
    ${cluster_config}    Safe Load    ${kubeadmin["data"]["ClusterConfiguration"]}
    ${extra_args}    Create Dictionary    cloud-config=/etc/kubernetes/vsphere.conf    cloud-provider=vsphere
    ${extra_volume}    Create Dictionary    hostPath=/etc/kubernetes/vsphere.conf    mountPath=/etc/kubernetes/vsphere.conf    name=cloud-config    pathType=FileOrCreate    readOnly=${true}
    ${extra_args_dic}    Convert To Dictionary    ${extra_args}
    ${extra_volume_dic}    Convert To Dictionary    ${extra_volume}
    ${extra_vol_list}    Create List    ${extra_volume_dic}
    ${extra_vol_list_2}    Copy List    ${extra_vol_list}    deepcopy=True
    Set To Dictionary    ${cluster_config["apiServer"]["extraArgs"]}    &{extra_args_dic}
    Set To Dictionary    ${cluster_config["apiServer"]}    extraVolumes=${extra_vol_list}
    Set To Dictionary    ${cluster_config["controllerManager"]}    extraArgs=${extra_args_dic}
    Set To Dictionary    ${cluster_config["controllerManager"]}    extraVolumes=${extra_vol_list_2}
    ${cluster_config_dump}    Dump    ${cluster_config}
    Set To Dictionary    ${kubeadmin["data"]}    ClusterConfiguration=${cluster_config_dump}
    ${kubeadmin_dump}    Dump    ${kubeadmin}
    Create File    ${LOGDIR}/${file}    ${kubeadmin_dump}
    kubectl    apply -f ${LOGDIR}/${file} --force

update control-plane on masters
    @{masters}    get master servers name
    FOR    ${master}    IN    @{masters}
        execute command with ssh    sudo kubeadm upgrade node phase control-plane --etcd-upgrade=false    ${master}
    END

_wait pod ready
    [Arguments]    ${arguments}    ${cluster_number}
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    wait pods --for=condition=ready --timeout=6m ${arguments}    ${cluster_number}
    Run Keyword if    "${status}"=="FAIL"    Should Not Contain    ${output}    no matching resources found
    [Return]    ${status}

get pods container version
    Log Dictionary    ${containers_list}
    @{containers}    Get Dictionary Keys    ${containers_list}
    FOR    ${container}    IN    @{containers}
        ${version}    _get container version and check all containers has the same    ${container}
        write cluster containers version in CS    ${container}    ${version}
    END
    ${skuba_version}    skuba    version    True
    ${split_skuba_verison}    Split To Lines    ${skuba_version}
    ${skuba_version_without}    Remove String    ${split_skuba_verison[-1]}    "
    write cluster containers version in CS    skuba    ${skuba_version_without}
    ${terraform_version}    ${status}    Run Keyword And Ignore Error    terraform version
    write cluster containers version in CS    terraform    ${terraform_version}
    dump cluster state
    Set Global Variable    ${CLUSTER_STATUS}    PASS

_get container version and check all containers has the same
    [Arguments]    ${container}
    ${yaml}    kubectl    get pods -l ${containers_list["${container}"]} \ -o yaml -n kube-system
    ${container_dictionnary}    yaml.Safe Load    ${yaml}
    ${lg}    Get Length    ${container_dictionnary["items"]}
    ${container_image}    Set Variable    ${container_dictionnary["items"][0]["spec"]["containers"][0]["image"]}
    ${string_container}    Split String    ${container_image}    :
    ${container_version}    Set Variable    ${string_container[-1]}
    FOR    ${i}    IN RANGE    ${lg}
        ${tmp_container_image}    Set Variable    ${container_dictionnary["items"][${i}]["spec"]["containers"][0]["image"]}
        Should Be Equal    ${container_image}    ${tmp_container_image}
    END
    [Return]    ${container_version}
