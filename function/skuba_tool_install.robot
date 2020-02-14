*** Settings ***
Resource          generic_function.robot
Library           JSONLibrary
Library           String
Library           Collections
Resource          ../parameters/env.robot

*** Keywords ***
install skuba
    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64
    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}
    execute command with ssh    sudo zypper -n in \ -t pattern SUSE-CaaSP-Management
    SSHLibrary.Put File    data/id_shared    /home/${VM_USER}/    mode=0600

get VM IP
    ${random}    Generate Random String    4    [LOWER][UPPER]
    Set Global Variable    ${WORKDIR}    ${CURDIR}/../workdir/cluster-${random}
    Set Global Variable    ${LOGDIR}    ${WORKDIR}/logs
    Set Global Variable    ${CLUSTERDIR}    ${WORKDIR}/cluster
    Set Global Variable    ${DATADIR}    ${WORKDIR}/data
    Create Directory    ${LOGDIR}
    Set Environment Variable    HELM_HOME    ${WORKDIR}/helm
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}/admin.conf
    Copy File    workdir/cluster.json    ${WORKDIR}/logs
    ${ip_dictionnary}=    Load JSON From File    ${LOGDIR}/cluster.json
    ${key}    Get Dictionary Keys    ${ip_dictionnary}
    ${value}    Get From Dictionary    ${ip_dictionnary}    ip_masters
    Set Global Variable    ${MASTER_IP}    ${ip_dictionnary["ip_masters"]["value"]}
    Set Global Variable    ${WORKER_IP}    ${ip_dictionnary["ip_workers"]["value"]}
    Set Global Variable    ${SKUBA_STATION}    ${MASTER_IP[0]}
    Set Global Variable    ${LB}    ${MASTER_IP[0]}
