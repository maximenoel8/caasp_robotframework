*** Settings ***
Resource          ../commands.robot
Resource          rpm_registry.robot
Resource          container_registry.robot
Resource          ../helper.robot

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
    enable customize rpms    ${rpm_url}
    import rpm repository    mirror
    import docker images    mirror

add mirror dns to nodes
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    execute command with ssh    sudo sh -c "echo '${AIRGAPPED_IP_OFFLINE} \ mirror.server.aws' >> /etc/hosts"    skuba_station_${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo sh -c "echo '${AIRGAPPED_IP_OFFLINE} \ mirror.server.aws' >> /etc/hosts"    ${node}
    END

deploy offline airgapped
    Set Global Variable    ${AIRGAPPED_IP_OFFLINE}    ${WORKSTATION_1}
    open ssh session    ${AIRGAPPED_IP_ONLINE}    alias=online_mirror    user=sles
    open ssh session    ${AIRGAPPED_IP_OFFLINE}    alias=mirror
    execute command with ssh    scp -i /home/sles/id_shared -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /home/sles/registry.tar.gz ${VM_USER}@${AIRGAPPED_IP_OFFLINE}:/home/${VM_USER}    alias=online_mirror
    execute command with ssh    scp -i /home/sles/id_shared -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /home/sles/rmt.tar.gz ${VM_USER}@${AIRGAPPED_IP_OFFLINE}:/home/${VM_USER}    alias=online_mirror
    generate certificates
    install mirror server
    set repo and packages
    populate rmt and docker repo offline for    ${REPOS_LIST}
    add CA to all server
    add rmt-server certificate to nodes
    add mirror dns to nodes
