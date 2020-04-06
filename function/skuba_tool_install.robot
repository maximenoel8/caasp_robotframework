*** Settings ***
Resource          commands.robot
Library           JSONLibrary
Library           String
Library           Collections
Resource          ../parameters/env.robot
Resource          cluster_helpers.robot
Resource          helm.robot
Resource          interaction_with_cluster_state_dictionnary.robot

*** Keywords ***
install skuba
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        Run Keyword If    "${MODE}"=="${EMPTY}"    Skuba from pattern    ${cluster_number}
        ...    ELSE    Skuba devel    ${cluster_number}
        Put File    data/id_shared    /home/${VM_USER}/    mode=0600
    END

_skuba from pattern
    [Arguments]    ${cluster_number}
    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64    skuba_station_${cluster_number}
    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}    skuba_station_${cluster_number}
    execute command with ssh    sudo zypper -n in -t pattern SUSE-CaaSP-Management    skuba_station_${cluster_number}

_skuba devel
    [Arguments]    ${cluster_number}
    execute command with ssh    sudo zypper addrepo https://download.opensuse.org/repositories/devel:languages:go/SLE_15_SP1/devel:languages:go.repo && sudo zypper -n --no-gpg-checks install go    skuba_station_${cluster_number}
    execute command with ssh    sudo zypper -n in git-core make    skuba_station_${cluster_number}
    execute command with ssh    git clone https://github.com/SUSE/skuba.git    skuba_station_${cluster_number}
    Run Keyword Unless    "${SKUBA_PULL_REQUEST}"=="${EMPTY}"    _change skuba branch
    ${args}    set variable if    "${MODE}"=="DEV"    ${EMPTY}
    ...    "${MODE}"=="STAGING"    staging
    ...    "${MODE}"=="RELEASE"    release
    execute command with ssh    cd skuba && \ make ${args}    skuba_station_${cluster_number}
    execute command with ssh    sudo ln -s /home/${VM_USER}/go/bin/skuba /usr/local/bin/    skuba_station_${cluster_number}
    Run Keyword if    "${PLATFORM}"=="vmware"    _disable firewall    ${cluster_number}

_change skuba branch
    ${pull request}    Split String    ${SKUBA_PULL_REQUEST}    -
    Run Keyword If    "${pull request[0]}"=="pull"    cd skuba && git fetch origin pull/${pull request[1]}/head:customise && git checkout \ customise    execute command with ssh    git fetch origin pull/${pull request[1]}/head:customise
    ...    ELSE IF    "${pull request[0]}"=="tag"    execute command with ssh    cd skuba && git checkout tags/${pull request[1]} -b customise
    ...    ELSE    Fail    wrong type

_disable firewall
    [Arguments]    ${cluster_number}
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    sudo systemctl stop firewalld    ${node}
    END
