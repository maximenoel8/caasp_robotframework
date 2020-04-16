*** Settings ***
Resource          ../commands.robot
Library           ../../lib/yaml_editor.py
Resource          ../cluster_helpers.robot
Resource          ../setup_environment.robot

*** Variables ***
${MESSAGE}        Sample component log entry.
@{components}     kubelet    crio    wickedd    kernel

*** Keywords ***
setup rsyslog server
    Copy File    ${DATADIR}/centralized_logging/mtls-verify-peer-values.yaml    ${LOGDIR}/mtls-verify-peer-values.yaml
    Modify Add Value    ${LOGDIR}/mtls-verify-peer-values.yaml    logs osSystem enabled    true
    Modify Add Value    ${LOGDIR}/mtls-verify-peer-values.yaml    logs kubernetesSystem enabled    true
    Modify Add Value    ${LOGDIR}/mtls-verify-peer-values.yaml    logs kubernetesControlPlane enabled    true
    Modify Add Value    ${LOGDIR}/mtls-verify-peer-values.yaml    logs kubernetesUserNamespaces enabled    true
    Remove Key    ${LOGDIR}/mtls-verify-peer-values.yaml    logs kubernetesUserNamespaces exclude

rsyslog is deployed
    kubectl    apply --filename="${DATADIR}/centralized_logging/rsyslog/rsyslog-server-configmap-mtls-verify-peer.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-secret.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-deployment.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-service.yaml" --wait
    setup rsyslog server
    helm    install -n log-agent-rsyslog suse-charts/log-agent-rsyslog --values "${LOGDIR}/mtls-verify-peer-values.yaml"
    check rsyslog is deployed
    sleep    30

messages are log on peer
    FOR    ${component}    IN    @{components}
        execute command with ssh    /usr/bin/logger -t ${component} ${MESSAGE}    alias=bootstrap_master_1
    END
    sleep    30

get journalctl log
    ${journalctl_output}    execute command with ssh    sudo journalctl --since -20m --no-pager
    [Return]    ${journalctl_output}

logs should exist on rsyslog-server
    get journalctl log
    ${rsyslog_server}    wait podname    -l app=rsyslog-server
    ${centralized_log}    kubectl    exec ${rsyslog_server} -- cat /var/log/messages-tcp-rfc5424
    ${podlogs}    Wait Until Keyword Succeeds    180    10    check message in rsyslog log    ${rsyslog_server}
    FOR    ${component}    IN    @{components}
        Should Contain    ${podlogs}    ${component}
    END
    [Return]    ${centralized_log}

check message in rsyslog log
    [Arguments]    ${rsyslog_server}
    ${podlogs}    kubectl    exec ${rsyslog_server} -- grep '${MESSAGE}' /var/log/messages-tcp-rfc5424
    [Return]    ${podlogs}

teardown centralized log
    Run Keyword And Ignore Error    helm    delete --purge log-agent-rsyslog
    Run Keyword And Ignore Error    kubectl    delete --filename="${DATADIR}/centralized_logging/rsyslog/rsyslog-server-configmap-mtls-verify-peer.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-secret.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-deployment.yaml","${DATADIR}/centralized_logging/rsyslog/rsyslog-server-service.yaml"
    [Teardown]    teardown_test

check rsyslog is deployed
    wait deploy    rsyslog-server
