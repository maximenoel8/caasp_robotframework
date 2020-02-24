*** Settings ***
Resource          commands.robot
Library           JSONLibrary
Library           String
Library           Collections
Resource          ../parameters/env.robot
Resource          cluster_helpers.robot

*** Keywords ***
install skuba
    Run Keyword If    "${MODE}"=="${EMPTY}"    Skuba from pattern
    ...    ELSE IF    "${MODE}"=="DEV"    Skuba devel
    SSHLibrary.Put File    data/id_shared    /home/${VM_USER}/    mode=0600

get VM IP
    ${ip_dictionnary}=    Load JSON From File    ${LOGDIR}/cluster.json
    Set Global Variable    ${MASTER_IP}    ${ip_dictionnary["modules"][0]["outputs"]["ip_masters"]["value"]}
    Set Global Variable    ${WORKER_IP}    ${ip_dictionnary["modules"][0]["outputs"]["ip_workers"]["value"]}
    Set Global Variable    ${SKUBA_STATION}    ${MASTER_IP[0]}
    ${status}    ${output}    Run Keyword And Ignore Error    Dictionary Should Contain Key    ${ip_dictionnary}    ip_load_balancer
    ${IP_LB}    Set Variable If    "${status}"=="FAIL"    ${MASTER_IP[0]}    ${ip_dictionnary["modules"]["outputs"][0]["ip_load_balancer"]["value"]}
    Set Global Variable    ${IP_LB}
    create cluster_state    ${MASTER_IP}    ${WORKER_IP}
    add lb to CS    ${IP_LB}

setup environment
    ${random}    Generate Random String    4    [LOWER][NUMBERS]
    ${CLUSTER}    Set Variable If    "${CLUSTER}"==""    cluster-${random}    ${CLUSTER}
    Set Global Variable    ${CLUSTER}
    Set Global Variable    ${WORKDIR}    ${CURDIR}/../workdir/${CLUSTER}
    check cluster exist
    Set Global Variable    ${LOGDIR}    ${WORKDIR}/logs
    Set Global Variable    ${CLUSTERDIR}    ${WORKDIR}/cluster
    Set Global Variable    ${DATADIR}    ${CURDIR}/../data
    Set Global Variable    ${TERRAFORMDIR}    ${WORKDIR}/terraform
    Set Global Variable    ${CLUSTER_PREFIX}    ${PREFIX}-${CLUSTER}
    Create Directory    ${LOGDIR}
    Set Environment Variable    HELM_HOME    ${WORKDIR}/helm
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}/admin.conf
    ${SSH_PUB_KEY}    OperatingSystem.Get File    ${DATADIR}/id_shared.pub
    ${SSH_PUB_KEY}    Remove String    ${SSH_PUB_KEY}    \n
    Set Global Variable    ${SSH_PUB_KEY}
    Set vm number

_skuba from pattern
    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64
    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}
    execute command with ssh    sudo zypper -n in \ -t pattern SUSE-CaaSP-Management

_skuba devel
    execute command with ssh    sudo zypper addrepo https://download.opensuse.org/repositories/devel:languages:go/SLE_15_SP1/devel:languages:go.repo && sudo zypper -n --no-gpg-checks install go
    execute command with ssh    sudo zypper -n in git-core make
    execute command with ssh    git clone https://github.com/SUSE/skuba.git
    Run Keyword Unless    "${pull_request}"=="${EMPTY}"    execute command with ssh    cd skuba && git fetch origin pull/${PULL_REQUEST}/head:customise && git checkout customise
    execute command with ssh    cd skuba && \ make
    execute command with ssh    sudo ln -s /home/${VM_USER}/go/bin/skuba /usr/local/bin/

set vm number
    ${VM_NUMBER}    Split String    ${NUMBER}    :
    ${length}    Get Length    ${VM_NUMBER}
    ${extra_server}    Set Variable If    ${length}==3    ${VM_NUMBER[2]}
    Set Global Variable    ${VM_NUMBER}
