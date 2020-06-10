*** Settings ***
Resource          ../commands.robot
Resource          rpm_registry.robot
Resource          container_registry.robot

*** Keywords ***
install mirror server
    install rmt-server
    install tools on mirror server
    Run Keyword If    "${PLATFORM}"=="aws"    deploy docker registry package
    ...    ELSE    deploy docker registry
    deploy reverse proxy

deploy reverse proxy
    Switch Connection    mirror
    Put File    ${DATADIR}/airgapped/mirror-server-https.conf    /home/${VM_USER}
    execute command with ssh    sudo cp /home/${VM_USER}/mirror-server-https.conf /etc/nginx/vhosts.d    mirror
    execute command with ssh    sudo systemctl restart nginx    mirror

populate rmt and docker repo offline for
    [Arguments]    ${rpm_url}
    enable customize rpm    ${rpm_url}
    import rpm repository    mirror
    import docker images    mirror

add airgapped certificate to nodes
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    add airgapped certificate to vm    skuba_station_${cluster_number}
    FOR    ${node}    IN    @{nodes}
        add airgapped certificate to vm    ${node}
    END

add mirror dns to nodes
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    execute command with ssh    sudo sh -c "echo '${AIRGAPPED_IP} \ mirror.server.aws' >> /etc/hosts"    skuba_station_${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo sh -c "echo '${AIRGAPPED_IP} \ mirror.server.aws' >> /etc/hosts"    ${node}
    END

add airgapped certificate to vm
    [Arguments]    ${node}
    Switch Connection    ${node}
    Put File    ${LOGDIR}/certificate/rmt-server/ca.crt    /home/${VM_USER}/
    execute command with ssh    sudo cp /home/${VM_USER}/ca.crt /etc/pki/trust/anchors/    ${node}
    execute command with ssh    sudo update-ca-certificates
