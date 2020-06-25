*** Settings ***
Library           String
Resource          commands.robot
Library           Process
Resource          ../parameters/global_parameters.robot
Resource          vms_deployment/common.robot
Library           Collections

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
    Run Keyword And Ignore Error    Close All Connections

teardown_test
    Run Keyword And Ignore Error    dump cluster state
    Run Keyword And Ignore Error    Process.Terminate All Processes
    Run Keyword And Ignore Error    Close All Connections

get kubernetes charts
    [Arguments]    ${pull_request}=${EMPTY}
    ${status}    ${output}    Run Keyword And Ignore Error    OperatingSystem.Directory Should Exist    ${LOGDIR}/kubernetes-charts-suse-com
    Run Keyword If    "${status}"=="FAIL"    execute command localy    cd ${LOGDIR} && git clone git@github.com:SUSE/kubernetes-charts-suse-com.git
    Run Keyword If    "${status}"=="FAIL"    execute command localy    cd ${LOGDIR}/kubernetes-charts-suse-com && git fetch origin pull/${CHART_PULL_REQUEST}/head:customise && git checkout customise

setup environment
    check cluster exist
    check cluster deploy
    Set vm number
    Run Keyword Unless    "${CHART_PULL_REQUEST}"=="${EMPTY}"    get kubernetes charts
    Run Keyword Unless    '${RPM}'=='${EMPTY}'    create registry dictionnary
    Run Keyword Unless    "${REGISTRY}"=="${EMPTY}"    create container repository file

load vm ip
    ${status}    check cluster state exist
    Run Keyword if    "${status}"=="PASS"    load cluster state
    ${integrity_status}    check cluster state integrity
    Run Keyword if    "${status}"=="FAIL" or not ${integrity_status}    create cluster_state
    set global ip variable

generate cluster name
    ${random}    Generate Random String    4    [LOWER][NUMBERS]
    Set Global Variable    ${CLUSTER}    cluster-${random}

check cluster deploy
    [Arguments]    ${cluster_number}=1
    ${PLATFORM_DEPLOY}    ${output}    Run Keyword And Ignore Error    OperatingSystem.File Should Exist    ${LOGDIR}/cluster${cluster_number}.json
    Set Global Variable    ${PLATFORM_DEPLOY}

check cluster exist
    [Arguments]    ${cluster_number}=1
    ${CLUSTER_STATUS}    ${output}    Run Keyword And Ignore Error    OperatingSystem.Directory Should Exist    ${WORKDIR}/cluster_${cluster_number}
    Set Global Variable    ${CLUSTER_STATUS}

create registry dictionnary
    ${registries}    Split String    ${RPM}
    ...    AND
    ${length}    Get Length    ${registries}
    FOR    ${i}    IN RANGE    0    ${length}
        Set To Dictionary    ${INCIDENT_REPO}    INCIDENT${i}=${registries[0]}
    END
    Set Global Variable    ${INCIDENT_REPO}

create container repository file
    ${registries}    Split String    ${REGISTRY}
    ...    AND
    Create File    ${LOGDIR}/registries.conf
    Append To File    ${LOGDIR}/registries.conf    unqualified-search-registries = ["docker.io"]\n
    Append To File    ${LOGDIR}/registries.conf    \# Fallback registry for missing containers\n
    Append To File    ${LOGDIR}/registries.conf    \n[[registry]]\n
    Append To File    ${LOGDIR}/registries.conf    prefix = "registry.suse.com/caasp/v4" \n
    Append To File    ${LOGDIR}/registries.conf    location = "registry.suse.com/caasp/v4"\n\n
    FOR    ${reg}    IN    @{registries}
        Append To File    ${LOGDIR}/registries.conf    \n[[registry.mirror]]\n
        Append To File    ${LOGDIR}/registries.conf    location = "${reg}"\n
        Append To File    ${LOGDIR}/registries.conf    insecure = true\n
    END

restore /etc/hosts
    execute command localy    sudo cp ${LOGDIR}/hosts.backup /etc/hosts

setup environment for suite
    Run Keyword If    "${CLUSTER}"==""    generate cluster name
    Step    Cluster name is ${CLUSTER_PREFIX}
    Set Global Variable    ${WORKDIR}    ${CURDIR}/../workdir/${CLUSTER}
    Set Global Variable    ${LOGDIR}    ${WORKDIR}/logs
    Set Global Variable    ${TEMPLATE_TERRAFORM_DIR}    ${CURDIR}/../terraform
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
    setup environment
