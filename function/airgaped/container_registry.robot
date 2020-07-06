*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../commands.robot

*** Keywords ***
get container list from official repo
    ${registries}    execute command localy    reg ls registry.suse.com | grep caasp/v4
    Log    ${registries}
    ${registry_list}    convert reg output to images list    ${registries}    registry.suse.com
    [Return]    ${registry_list}

get container list from customize repo
    [Arguments]    ${registry}    ${filter}
    Create Session    ${registry}    https://${registry}    verify=False
    ${result}    RequestsLibrary.Get Request    ${registry}    /v2/_catalog
    @{repo_list}    Set Variable    ${result.json()["repositories"]}
    ${registry_list}    Create List
    FOR    ${repo}    IN    @{repo_list}
        ${STATUS}    ${_}    Run Keyword And Ignore Error    Should Contain    ${repo}    ${filter}
        Continue For Loop If    "${STATUS}"=="FAIL"
        ${registry_list}    _get containers version    ${registry}    ${repo}    ${registry_list}
    END
    [Teardown]    Delete All Sessions
    [Return]    ${registry_list}

convert reg output to images list
    [Arguments]    ${registries}    ${register_url}
    @{registries_list}    Split To Lines    ${registries}
    ${images}    create list
    FOR    ${registry}    IN    @{registries_list}
        ${registry}    Remove String    ${registry}    ,
        ${elements}    Split String    ${registry}
        ${lt}    Get Length    ${elements}
        Run Keyword If    ${lt}<2    log    Image for ${elements[0]} is skipped because it has no tag    WARN
        Continue For Loop If    ${lt}<2
        Append To List    ${images}    ${register_url}/${elements[0]}:${elements[1]}
    END
    log    ${images}
    [Return]    ${images}

deploy docker registry - docker
    execute command with ssh    sudo systemctl enable --now docker.service
    execute command with ssh    sudo docker pull registry.suse.com/sles12/registry:2.6.2
    Set Global Variable    ${SHARED}    /home/${VM_USER}
    execute command with ssh    sudo docker save -o /${SHARED}/registry.tar registry.suse.com/sles12/registry:2.6.2
    execute command with ssh    docker run -d -p 5000:5000 --restart=always --name registry \ -v /etc/docker/registry:/etc/docker/registry:ro \ -v /etc/rmt/ssl:/etc/rmt/ssl:ro \ -v /var/lib/registry:/var/lib/registry registry.suse.com/sles12/registry:2.6.2

install tools on mirror server
    execute command with ssh    sudo zypper -n in docker helm-mirror skopeo rsync    mirror

copy docker images with skopeo
    [Arguments]    ${official}=True    ${custom_filter}=default
    ${list1}    Run Keyword If    ${official}    get container list from official repo
    ...    ELSE    Create List
    ${list2}    Run Keyword If    "${custom_filter}"!="default"    get container list from customize repo    registry.suse.de    ${custom_filter}
    ...    ELSE    Create List
    @{list_images}    Combine Lists    ${list1}    ${list2}
    Set Global Variable    ${REG_PORT}    5000
    FOR    ${image}    IN    @{list_images}
        Run Keyword And Ignore Error    execute command with ssh    sudo skopeo copy docker://${image} docker://${AIRGAPPED_IP_ONLINE}:${REG_PORT}/${image} --src-tls-verify=false    mirror
    END
    ${output}    execute command localy    curl -k https://${AIRGAPPED_IP_ONLINE}:${REG_PORT}/v2/_catalog
    log    ${output}

deploy docker registry
    execute command with ssh    sudo systemctl enable --now docker    mirror
    execute command with ssh    sudo docker pull registry.suse.com/sles12/registry:2.6.2    mirror
    Switch Connection    mirror
    Put File    ${DATADIR}/airgapped/config.yml    /home/${VM_USER}/
    execute command with ssh    sudo mkdir -p /etc/docker/registry    mirror
    execute command with ssh    sudo cp /home/${VM_USER}/config.yml /etc/docker/registry/config.yml    mirror
    execute command with ssh    sudo docker run -d -p 30500:5000 --restart=always --name registry \ -v /etc/docker/registry:/etc/docker/registry:ro \ -v /etc/rmt/ssl:/etc/rmt/ssl:ro \ -v /var/lib/registry:/var/lib/registry registry.suse.com/sles12/registry:2.6.2    mirror

backup docker images
    ${SHARED}    Set Variable    /home/${VM_USER}
    execute command with ssh    mkdir -p /${SHARED}/registry    mirror
    execute command with ssh    rsync -aP /var/lib/registry/ ${SHARED}/registry/    mirror
    execute command with ssh    cd ${SHARED} && tar -czvf registry.tar.gz registry    mirror
    Comment    Switch Connection    mirror
    Comment    SSHLibrary.Get File    ${SHARED}/registry.tar.gz    ${LOGDIR}/

import docker images
    [Arguments]    ${node}
    ${SHARED}    Set Variable    /home/${VM_USER}
    Comment    Switch Connection    ${node}
    Comment    Put file    ${LOGDIR}/registry.tar.gz    ${SHARED}
    execute command with ssh    tar -xzvf ${SHARED}/registry.tar.gz    ${node}
    execute command with ssh    sudo rsync -aP ${SHARED}/registry/ /var/lib/registry/    ${node}

deploy docker registry package
    execute command with ssh    sudo SUSEConnect --product PackageHub/15.1/x86_64    mirror
    execute command with ssh    sudo zypper refresh    mirror
    execute command with ssh    sudo zypper -n install docker-distribution-registry    mirror
    Switch Connection    mirror
    Put File    ${DATADIR}/airgapped/config.yml    /home/${VM_USER}/
    execute command with ssh    sudo cp /home/${VM_USER}/config.yml /etc/registry/config.yml    mirror
    execute command with ssh    sudo systemctl restart registry    mirror
    execute command with ssh    sudo systemctl enable registry    mirror

_get containers version
    [Arguments]    ${registry}    ${repo}    ${registry_list}
    ${tag_result}    RequestsLibrary.Get Request    ${registry}    /v2/${repo}/tags/list
    @{tags_lists}    Set Variable    ${tag_result.json()["tags"]}
    FOR    ${tag}    IN    @{tags_lists}
        ${status}    ${_}    Run Keyword And Ignore Error    Should Not Contain    ${tag}    build
        Continue For Loop If    "${tag}"=="beta" or "${status}"=="FAIL"
        Append To List    ${registry_list}    ${registry}/${repo}:${tag}
    END
    [Return]    ${registry_list}
