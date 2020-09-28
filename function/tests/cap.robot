*** Settings ***
Resource          ../commands.robot
Resource          ../interaction_with_cluster_state_dictionnary.robot
Resource          ../tools.robot
Resource          ../vms_deployment/openstack_setup.robot

*** Variables ***
@{wildcard_domain}    omg.howdoi.website    xip.io    nip.io    lvh.me

*** Keywords ***
deploy cap old
    Create Directory    ${LOGDIR}/cap
    execute command localy    uuigen > ${LOGDIR}/cap/password
    ${wild_card_domain}    get wildcard domain
    ${domain}    Set Variable If    "${floating_ip}"=="${EMPTY}"    ${internal_ip}.${wild_card_domain}    ${floating_ip}.${wild_card_domain}

get wildcard domain
    step    Test the wildcard on localhost
    FOR    ${dns}    IN    @{wildcard_domain}
        ${status}    ${_}    Run Keyword And Ignore Error    execute command localy    ping -c 3 127.0.0.1.${dns}
        Run Keyword If    "${status}"=="FAIL"    log    ${dns} not available, checking the next...    WARN
        Continue For Loop If    "${status}"=="FAIL"
        Return From Keyword    ${dns}
    END
    Fail    No wildcard domain available, abording
    [Return]    ${dns}

deploy cap v1
    [Arguments]    ${cluster_number}=1
    ${sc}    kubectl    get sc -o json | jq -r '.items[0].metadata.name'
    @{workers}    get worker servers name
    ${ip}    get node ip from CS    ${workers[0]}
    step    install cap
    execute command localy    ${DATADIR}/deploy-cap/cap --deploy --internal-ip ${ip} --storage-class ${sc} -k ${CLUSTERDIR}_${cluster_number}/admin.conf
    kubectl    create configmap -n kube-system cap-values --from-literal=public-ip="${ip}" --from-literal=domain="${ip}.omg.howdoi.website" --from-literal=garden-rootfs-driver="overlay-xfs" --from-literal=platform=caasp4

test cap
    [Arguments]    ${cluster_number}=1
    step    test cap
    execute command localy    ${DATADIR}/deploy-cap/cap --test -k ${CLUSTERDIR}_${cluster_number}/admin.conf

destroy cap
    step    destroy cap
    execute command localy    ${DATADIR}/deploy-cap/cap --destroy

deploy cap v2
    [Arguments]    ${cluster_number}=1
    ${sc}    kubectl    get sc -o json | jq -r '.items[0].metadata.name'
    @{workers}    get worker servers name
    ${ip}    get node ip from CS    ${workers[0]}
    step    install cap
    execute command localy    cd ${DATADIR}/catapult && CLUSTER_NAME=${CLUSTER_PREFIX}-1 SCF_CHART=from_repo make kubecf tests-kubecf
    execute command localy    cd ${DATADIR}/catapult && CLUSTER_NAME=${CLUSTER_PREFIX}-1 SCF_CHART=from_repo make kubecf-login

create config cap v2
    [Arguments]    ${cluster_number}=1
    step    make config cap v2
    Run Keyword If    "${platform}"=="openstack"    add cap security group
    @{workers}    get worker servers name
    ${ip}    get node ip from CS    ${workers[0]}
    kubectl    create configmap -n kube-system cap-values --from-literal=public-ip="${ip}" --from-literal=domain="${ip}.omg.howdoi.website" --from-literal=garden-rootfs-driver="overlay-xfs" --from-literal=platform=caasp4
    execute command localy    cd ${DATADIR}/catapult && BACKEND=caasp4os CLUSTER_NAME=${CLUSTER_PREFIX}-1 KUBECFG=${CLUSTERDIR}_${cluster_number}/admin.conf make kubeconfig

deploy stratos
    step    deploy stratos
    execute command localy    cd ${DATADIR}/catapult && CLUSTER_NAME=${CLUSTER_PREFIX}-1 make stratos

cleanup cap v2
    step    Cleanup cap v2
    execute command localy    cd ${DATADIR}/catapult && CLUSTER_NAME=${CLUSTER_PREFIX}-1 SCF_CHART=from_repo make stratos-clean kubecf-clean
    kubectl    delete configmap -n kube-system cap-values
