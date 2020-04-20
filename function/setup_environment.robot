*** Settings ***
Library           String
Resource          commands.robot
Resource          cluster_helpers.robot
Library           Process

*** Keywords ***
set vm number
    ${VM_NUMBER}    Split String    ${NUMBER}    :
    ${length}    Get Length    ${VM_NUMBER}
    ${extra_server}    Set Variable If    ${length}==3    ${VM_NUMBER[2]}
    Set Global Variable    ${VM_NUMBER}

set global ip variable
    Log Dictionary    ${cluster_state}
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        Set Global Variable    ${BOOTSTRAP_MASTER_${cluster_number}}    ${cluster_state["cluster_${cluster_number}"]["master"]["${CLUSTER_PREFIX}-${cluster_number}-master-0"]["ip"]}
        Set Global Variable    ${WORKSTATION_${cluster_number}}    ${cluster_state["cluster_${cluster_number}"]["workstation"]}
        Set Global Variable    ${IP_LB_${cluster_number}}    ${cluster_state["cluster_${cluster_number}"]["lb"]["ip"]}
    END

teardown_suite
    Run Keyword And Ignore Error    Copy Files    ${OUTPUT_DIR}/*    ${LOGDIR}
    Run Keyword And Ignore Error    Run Keyword Unless    ${KEEP}    clean cluster    ${cluster}

teardown_test
    Run Keyword And Ignore Error    dump cluster state
    Run Keyword And Ignore Error    Close All Connections
    Run Keyword And Ignore Error    Process.Terminate All Processes

get kubernetes charts
    [Arguments]    ${pull_request}=${EMPTY}
    ${status}    ${output}    Run Keyword And Ignore Error    OperatingSystem.Directory Should Exist    ${LOGDIR}/kubernetes-charts-suse-com
    Run Keyword If    "${status}"=="FAIL"    execute command localy    cd ${LOGDIR} && git clone git@github.com:SUSE/kubernetes-charts-suse-com.git
    Run Keyword If    "${status}"=="FAIL"    execute command localy    cd ${LOGDIR}/kubernetes-charts-suse-com && git fetch origin pull/${CHART_PULL_REQUEST}/head:customise && git checkout customise

add CA to server
    [Arguments]    ${ip}
    open ssh session    ${ip}    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP1/SUSE:CA.repo    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ref    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper -n in ca-certificates-suse    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo update-ca-certificates    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo systemctl restart crio    tempo
    [Teardown]    Close Connection

add CA to all server
    [Arguments]    ${cluster_number}=1
    @{masters}    Collections.Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["master"]}
    @{workers}    Collections.Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["worker"]}
    @{nodes}    Combine Lists    ${masters}    ${workers}
    FOR    ${node}    IN    @{nodes}
        ${ip}    get node ip from CS    ${node}    ${cluster_number}
        add CA to server    ${ip}
    END

setup environment
    Run Keyword If    "${CLUSTER}"==""    create cluster folder
    Log    ${CLUSTER}    console=yes    level=HTML
    Set Global Variable    ${WORKDIR}    ${CURDIR}/../workdir/${CLUSTER}
    Set Global Variable    ${LOGDIR}    ${WORKDIR}/logs
    Set Global Variable    ${TEMPLATE_TERRAFORM_DIR}    ${CURDIR}/../terraform
    check cluster exist
    check cluster deploy
    Set Global Variable    ${CLUSTERDIR}    ${WORKDIR}/cluster
    Set Global Variable    ${DATADIR}    ${CURDIR}/../data
    Set Global Variable    ${TERRAFORMDIR}    ${WORKDIR}/terraform
    Set Global Variable    ${CLUSTER_PREFIX}    ${PREFIX}-${CLUSTER}
    Create Directory    ${LOGDIR}
    Set Environment Variable    HELM_HOME    ${WORKDIR}/helm
    Set Environment Variable    KUBECONFIG    ${CLUSTERDIR}/admin.conf
    execute command localy    chmod 0600 ${DATADIR}/id_shared
    ${SSH_PUB_KEY}    OperatingSystem.Get File    ${DATADIR}/id_shared.pub
    ${SSH_PUB_KEY}    Remove String    ${SSH_PUB_KEY}    \n
    Set Global Variable    ${SSH_PUB_KEY}
    Set vm number
    Run Keyword Unless    "${CHART_PULL_REQUEST}"=="${EMPTY}"    get kubernetes charts

load vm ip
    ${status}    check cluster state exist
    Run Keyword if    "${status}"=="PASS"    load cluster state
    ${integrity_status}    check cluster state integrity
    Run Keyword if    "${status}"=="FAIL" or not ${integrity_status}    create cluster_state
    set global ip variable

create cluster folder
    ${random}    Generate Random String    4    [LOWER][NUMBERS]
    Set Global Variable    ${CLUSTER}    cluster-${random}
    Log    ${CLUSTER}    console=yes    level=HTML

open bootstrap session
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        open ssh session    ${BOOTSTRAP_MASTER_${cluster_number}}    alias=bootstrap_master_${cluster_number}
        open ssh session    ${WORKSTATION_${cluster_number}}    alias=skuba_station_${cluster_number}
    END
    @{nodes}    get master servers name
    FOR    ${node}    IN    @{nodes}
        open ssh session    ${node}
    END
    @{nodes}    get worker servers name
    FOR    ${node}    IN    @{nodes}
        Exit For Loop If    "${PLATFORM}"=="aws"
        open ssh session    ${node}
    END
