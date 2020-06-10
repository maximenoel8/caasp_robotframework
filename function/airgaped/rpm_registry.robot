*** Settings ***
Resource          ../commands.robot
Resource          ../tests/certificate.robot
Resource          ../tools.robot
Resource          ../helper.robot

*** Keywords ***
enable offical rpm repositories

enable customize rpm
    [Arguments]    ${rpm_url}
    execute command with ssh    sudo rmt-cli repos custom add ${rpm_url} customize0    mirror
    ${output}    execute command with ssh    sudo rmt-cli repos custom list | grep customize0    mirror
    ${elements}    Split String    ${output}
    ${repository_id}    Set Variable    ${elements[1]}
    execute command with ssh    sudo rmt-cli repos custom enable ${repository_id}    mirror

install rmt-server
    Copy File    ${DATADIR}/airgapped/rmt.conf    ${LOGDIR}
    modify string in file    ${LOGDIR}/rmt.conf    MIRROR.USERNAME    ${MIRROR["username"]}
    modify string in file    ${LOGDIR}/rmt.conf    MIRROR.PASSWORD    ${MIRROR["password"]}
    execute command with ssh    sudo zypper -n in rmt-server    mirror
    Switch Connection    mirror
    Put Directory    ${LOGDIR}/certificate/rmt-server    /home/${VM_USER}    recursive=True
    Put file    ${LOGDIR}/rmt.conf    /home/${VM_USER}    mode=0644
    execute command with ssh    sudo cp /home/${VM_USER}/rmt.conf /etc/    mirror
    execute command with ssh    sudo cp /home/${VM_USER}/rmt-server/* /etc/rmt/ssl/    mirror
    execute command with ssh    sudo systemctl restart rmt-server    mirror
    execute command with ssh    sudo systemctl enable rmt-server    mirror
    Comment    ${output}    execute command with ssh    sudo systemctl status rmt-server-sync.timer    ${node}
    Comment    Should Contain    ${output}    active
    Comment    ${output}    execute command with ssh    sudo systemctl status rmt-server-mirror.timer    ${node}
    Comment    Should Contain    ${output}    active
    execute command with ssh    sudo cp /etc/rmt/ssl/ca.crt /etc/pki/trust/anchors/    mirror
    execute command with ssh    sudo update-ca-certificates    mirror

generate certificates
    ${service}    Set Variable    rmt-server
    create CA    ${service}    RMT Certificate Authority
    ${san_dns}    Create List    mirror.server.aws
    ${san_ip}    Create List    ${AIRGAPPED_IP}
    ${SAN}    Create Dictionary    dns=${san_dns}    ip=${san_ip}
    create client config    ${service}    ${SAN}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/${service}.key 2048
    execute command localy    openssl req -key ${LOGDIR}/certificate/${service}/${service}.key -new -sha256 -out ${LOGDIR}/certificate/${service}/${service}.csr -config ${LOGDIR}/certificate/${service}/${service}.conf -subj "/CN=${service}"
    execute command localy    openssl x509 -req -CA ${LOGDIR}/certificate/${service}/ca.crt -CAkey ${LOGDIR}/certificate/${service}/ca.key -CAcreateserial -in ${LOGDIR}/certificate/${service}/${service}.csr -out ${LOGDIR}/certificate/${service}/${service}.crt -days 10 -extensions v3_req -extfile ${LOGDIR}/certificate/${service}/${service}.conf

sync and mirror online
    execute command with ssh    sudo rmt-cli sync    mirror
    execute command with ssh    sudo rmt-cli mirror    mirror

export rpm repository
    ${SHARED}    Set Variable    /home/${VM_USER}
    execute command with ssh    mkdir -p ${SHARED}/rmt    mirror
    execute command with ssh    sudo chown _rmt:users ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export data ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export settings ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export repos ${SHARED}/rmt    mirror
    Switch Connection    mirror
    SSHLibrary.Get Directory    ${SHARED}/rmt    ${LOGDIR}    recursive=True

import rpm repository
    [Arguments]    ${node}
    ${SHARED}    Set Variable    /home/${VM_USER}
    Switch Connection    ${node}
    Put Directory    ${LOGDIR}/rmt    ${SHARED}    recursive=True
    execute command with ssh    sudo chown -R _rmt:users ${SHARED}/rmt    ${node}
    execute command with ssh    sudo rmt-cli import data ${SHARED}/rmt    ${node}
    execute command with ssh    sudo rmt-cli import repos ${SHARED}/rmt    ${node}
