*** Settings ***
Resource          commands.robot
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          ../parameters/vmware_deployment.robot
Resource          tools.robot

*** Keywords ***
create cluster folder
    [Arguments]    ${cluster_number}=1
    govc    folder.create /${DATACENTER}/vm/${CLUSTER_PREFIX}-${cluster_number}-cluster

enable disk.UUI for all nodes
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        _enable disk.UUI for ${node}
    END

_enable disk.UUI for ${node}
    govc    vm.power -dc=${DATACENTER} -off ${node}
    govc    vm.change -dc=${DATACENTER} -vm=${node} -e="disk.enableUUID=1" && echo "Configured disk.enabledUUID: 1"
    govc    vm.power -dc=${DATACENTER} -on ${node}

move all nodes to cluster folder
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        _move node to cluster folder    ${node}    ${cluster_number}
    END

_move node to cluster folder
    [Arguments]    ${node}    ${cluster_number}=1
    govc    object.mv /${DATACENTER}/vm/${node} /${DATACENTER}/vm/${CLUSTER_PREFIX}-${cluster_number}-cluster

set govc environment
    Set Environment Variable    GOVC_USERNAME    ${VSPHERE_USER}
    Set Environment Variable    GOVC_PASSWORD    ${VSPHERE_PASSWORD}
    Set Environment Variable    GOVC_INSECURE    True
    Set Environment Variable    GOVC_DATACENTER    ${DATACENTER}
    Set Environment Variable    GOVC_HOST    ${VSPHERE_SERVER}
    Set Environment Variable    GOVC_URL    ${VSPHERE_SERVER}

get ${node} UUID
    Comment    govc    vm.info -json -dc=${DATACENTER} -vm.ipath="/${node}" > ${LOGDIR}/${node}.json
    govc    vm.info -json /${DATACENTER}/vm/${CLUSTER_PREFIX}-1-cluster/${node} > ${LOGDIR}/${node}.json
    ${vm_info}    JSONLibrary.Load JSON From File    ${LOGDIR}/${node}.json
    ${UUID}    Set Variable    ${vm_info["VirtualMachines"][0]["Config"]["Uuid"]}
    [Return]    ${UUID}

create disk on node
    [Arguments]    ${node}    ${size}=20GB
    step    Create disk of ${size} on ${node}
    govc    vm.disk.create -dc=${DATACENTER} -ds=3PAR -vm ${node} -name ${node}-mount/data.vmdk -size ${size}

create disk on nodes
    [Arguments]    ${disk_size}=20GB    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        create disk on node    ${node}    ${disk_size}
    END
