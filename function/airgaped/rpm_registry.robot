*** Settings ***
Resource          ../commands.robot
Resource          ../tests/certificate.robot
Resource          ../tools.robot
Resource          ../helper.robot

*** Keywords ***
enable offical rpm repositories

enable customize rpms
    [Arguments]    ${rpm_urls}
    Log Dictionary    ${rpm_urls}
    @{keys}    Get Dictionary Keys    ${rpm_urls}
    FOR    ${key}    IN    @{keys}
        _enable customize rpm    ${rpm_urls["${key}"]}    ${key}
    END

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
    execute command with ssh    sudo sed -i -e 's/\\[mysqld\\]/[mysqld]\\nskip-grant-tables/g' /etc/my.cnf    mirror
    execute command with ssh    sudo systemctl restart rmt-server    mirror
    execute command with ssh    sudo systemctl enable rmt-server    mirror
    Comment    ${output}    execute command with ssh    sudo systemctl status rmt-server-sync.timer    ${node}
    Comment    Should Contain    ${output}    active
    Comment    ${output}    execute command with ssh    sudo systemctl status rmt-server-mirror.timer    ${node}
    Comment    Should Contain    ${output}    active
    execute command with ssh    sudo cp /etc/rmt/ssl/ca.crt /etc/pki/trust/anchors/    mirror
    execute command with ssh    sudo update-ca-certificates    mirror

generate rmt certificates
    ${service}    Set Variable    rmt-server
    create CA    ${service}    RMT Certificate Authority
    ${san_dns}    Create List    mirror.server.aws
    ${san_ip}    Create List    ${AIRGAPPED_IP_OFFLINE}
    ${SAN}    Create Dictionary    dns=${san_dns}    ip=${san_ip}
    generate new certificate with CA signing request    ${service}    ${SAN}    ${LOGDIR}/certificate/${service}/ca.crt    ${LOGDIR}/certificate/${service}/ca.key

sync and mirror online
    execute command with ssh    sudo rmt-cli sync    mirror
    execute command with ssh    sudo rmt-cli mirror    mirror    timeout=120min

export rpm repository
    ${SHARED}    Set Variable    /home/${VM_USER}
    execute command with ssh    mkdir -p ${SHARED}/rmt    mirror
    execute command with ssh    sudo chown _rmt:users ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export data ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export settings ${SHARED}/rmt    mirror
    execute command with ssh    sudo rmt-cli export repos ${SHARED}/rmt    mirror
    Comment    Switch Connection    mirror
    Comment    SSHLibrary.Get Directory    ${SHARED}/rmt    ${LOGDIR}    recursive=True
    execute command with ssh    cd ${SHARED} && tar -czvf rmt.tar.gz rmt    mirror

import rpm repository
    [Arguments]    ${node}
    ${SHARED}    Set Variable    /home/${VM_USER}
    Comment    Switch Connection    ${node}
    Comment    Put Directory    ${LOGDIR}/rmt    ${SHARED}    recursive=True
    execute command with ssh    tar -xzvf ${SHARED}/rmt.tar.gz    ${node}
    execute command with ssh    sudo chown -R _rmt:users ${SHARED}/rmt    ${node}
    execute command with ssh    sudo rmt-cli import data ${SHARED}/rmt    ${node}
    execute command with ssh    sudo rmt-cli import repos ${SHARED}/rmt    ${node}

_enable customize rpm
    [Arguments]    ${rpm_url}    ${depo_name}
    execute command with ssh    sudo rmt-cli repos custom add ${rpm_url} ${depo_name}    mirror
    ${output}    execute command with ssh    sudo rmt-cli repos custom list | grep ${depo_name}    mirror
    ${elements}    Split String    ${output}
    ${repository_id}    Set Variable    ${elements[1]}
    execute command with ssh    sudo rmt-cli repos custom enable ${repository_id}    mirror
