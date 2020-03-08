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
    Run Keyword If    "${MODE}"=="${EMPTY}"    Skuba from pattern
    ...    ELSE IF    "${MODE}"=="DEV"    Skuba devel
    SSHLibrary.Put File    data/id_shared    /home/${VM_USER}/    mode=0600

_skuba from pattern
    execute command with ssh    sudo SUSEConnect -p sle-module-containers/15.1/x86_64
    execute command with ssh    sudo SUSEConnect -p caasp/4.0/x86_64 -r ${CAASP_KEY}
    execute command with ssh    sudo zypper -n in \ -t pattern SUSE-CaaSP-Management

_skuba devel
    execute command with ssh    sudo zypper addrepo https://download.opensuse.org/repositories/devel:languages:go/SLE_15_SP1/devel:languages:go.repo && sudo zypper -n --no-gpg-checks install go
    execute command with ssh    sudo zypper -n in git-core make
    execute command with ssh    git clone https://github.com/SUSE/skuba.git
    Run Keyword Unless    "${SKUBA_PULL_REQUEST}=="${EMPTY}"    execute command with ssh    cd skuba && git fetch origin pull/${SKUBA_PULL_REQUEST}/head:customise && git checkout customise
    execute command with ssh    cd skuba && \ make
    execute command with ssh    sudo ln -s /home/${VM_USER}/go/bin/skuba /usr/local/bin/
