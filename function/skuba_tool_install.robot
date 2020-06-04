*** Settings ***
Resource          commands.robot
Library           JSONLibrary
Library           String
Library           Collections
Resource          ../parameters/env.robot
Resource          cluster_helpers.robot
Resource          helm.robot
Resource          interaction_with_cluster_state_dictionnary.robot
Resource          upgrade/upgrade_workstation.robot
Resource          helper.robot
Resource          tools.robot
Resource          terraform_files_change.robot
Resource          airgaped/common_airgaped.robot

*** Keywords ***
install skuba
    [Arguments]    ${redeploy}=False
    step    installing skuba ...
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        Run Keyword If    ${AIRGAPPED}    Run Keywords    add airgapped certificate to nodes
        ...    AND    add mirror dns to nodes
        Run Keyword If    "${MODE}"=="${EMPTY}"    Skuba from pattern    ${cluster_number}
        ...    ELSE    _skuba from repo    ${cluster_number}
        Run Keyword if    "${PLATFORM}"=="vmware"    _disable firewall    ${cluster_number}
        Switch Connection    skuba_station_${cluster_number}
        Put File    data/id_shared    /home/${VM_USER}/    mode=0600
    END
    Run keyword if    "${MODE}"=="${EMPTY}" and '${RPM}'!='${EMPTY}' and not ${UPGRADE} and not ${redeploy} and ${CHECK_TERRAFORM}    check terrafrom are updated and redeploy if not

_skuba from pattern
    [Arguments]    ${cluster_number}
    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64    skuba_station_${cluster_number}
    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}    skuba_station_${cluster_number}
    Run Keyword If    ${OLD}    execute command with ssh    sudo zypper mr -d SUSE-CAASP-4.0-Updates    skuba_station_${cluster_number}
    execute command with ssh    sudo zypper -n in -t pattern SUSE-CaaSP-Management    skuba_station_${cluster_number}
    Run Keyword If    '${RPM}'!='${EMPTY}' and not ${UPGRADE}    add repo from incident and update    ${cluster_number}
    Run Keyword If    '${REGISTRY}'!='${EMPTY}' and not ${UPGRADE}    add container repo file to nodes    ${cluster_number}
    step    skuba is deployed with pattern

_skuba from repo
    [Arguments]    ${cluster_number}
    _install go git make    ${cluster_number}
    build skuba from repo    ${SKUBA_PULL_REQUEST}    cluster_number=${cluster_number}
    execute command with ssh    sudo zypper --non-interactive in kubernetes-client    alias=skuba_station_${cluster_number}
    step    skuba was build with ${MODE}

_change skuba branch
    [Arguments]    ${commit}    ${folder}    ${cluster_number}
    ${pull request}    Split String    ${commit}    -
    Run Keyword If    "${pull request[0]}"=="pull"    execute command with ssh    cd ${folder} && git fetch origin pull/${pull request[1]}/head:customise    alias=skuba_station_${cluster_number}
    ...    ELSE IF    "${pull request[0]}"=="tag"    execute command with ssh    cd ${folder} && git checkout tags/${pull request[1]} -b customise    alias=skuba_station_${cluster_number}
    ...    ELSE    Fail    wrong type

_disable firewall
    [Arguments]    ${cluster_number}
    run command on nodes    sudo systemctl stop firewalld    ${cluster_number}

_install go git make
    [Arguments]    ${cluster_number}
    execute command with ssh    sudo zypper addrepo https://download.opensuse.org/repositories/devel:languages:go/SLE_15_SP1/devel:languages:go.repo && sudo zypper -n --no-gpg-checks install go    skuba_station_${cluster_number}
    execute command with ssh    sudo zypper -n in git-core make    skuba_station_${cluster_number}

build skuba from repo
    [Arguments]    ${commit}    ${skuba_folder}=skuba    ${cluster_number}=1
    execute command with ssh    git clone https://github.com/SUSE/skuba.git ${skuba_folder}    skuba_station_${cluster_number}
    Run Keyword Unless    "${commit}"=="${EMPTY}"    _change skuba branch    ${commit}    ${skuba_folder}    ${cluster_number}
    Run Keyword If    "${MODE}"=="RELEASE"    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64    skuba_station_${cluster_number}
    Run Keyword If    "${MODE}"=="RELEASE"    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}    skuba_station_${cluster_number}
    ${args}    set variable if    "${MODE}"=="DEV"    ${EMPTY}    "${MODE}"=="STAGING"    staging    "${MODE}"=="RELEASE"    release
    execute command with ssh    cd ${skuba_folder} && make ${args}    skuba_station_${cluster_number}
    execute command with ssh    sudo ln -s /home/${VM_USER}/go/bin/skuba /usr/bin/    skuba_station_${cluster_number}

add repo from incident and update
    [Arguments]    ${cluster_number}
    Run Keyword If    ${UPGRADE} or ${AIRGAPPED}    _add repo from incident on    skuba_station_${cluster_number}
    ${incidents}    Get Dictionary Keys    ${INCIDENT_REPO}
    FOR    ${incident}    IN    @{incidents}
        update package on workstation    -r ${incident}    cluster_number=${cluster_number}
    END

add container repo file to nodes
    [Arguments]    ${cluster_number}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        Switch Connection    ${node}
        Put File    ${LOGDIR}/registries.conf    /home/${VM_USER}/registries.conf
        execute command with ssh    sudo mkdir -p /etc/containers    ${node}
        execute command with ssh    sudo cp /home/${VM_USER}/registries.conf /etc/containers/registries.conf    ${node}
        Run Keyword If    ${UPGRADE}    execute command with ssh    sudo systemctl restart crio    ${node}
    END

add vendor file
    [Arguments]    ${node}
    Switch Connection    ${node}
    Put File    ${DATADIR}/vendors.conf    /home/${VM_USER}/vendors.conf
    execute command with ssh    sudo cp /home/${VM_USER}/vendors.conf /etc/zypp/vendors.d/vendors.conf    ${node}

add vendor file to nodes
    [Arguments]    ${cluster_number}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        add vendor file    ${node}
    END

_add repo from incident on
    [Arguments]    ${node}
    add vendor file    ${node}
    ${incidents}    Get Dictionary Keys    ${INCIDENT_REPO}
    FOR    ${incident}    IN    @{incidents}
        Run Keyword And Ignore Error    execute command with ssh    sudo zypper ar -fG ${INCIDENT_REPO["${incident}"]} ${incident}    ${node}
    END
