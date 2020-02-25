*** Settings ***
Library           OperatingSystem
Resource          ../commands.robot
Resource          ../../parameters/global_parameters.robot
Library           String
Library           Collections
Resource          ../../parameters/env.robot

*** Keywords ***
get skuba tool
    OperatingSystem.Remove Directory    ${WORKDIR}/skuba    True
    execute command localy    git clone https://github.com/SUSE/skuba.git ${WORKDIR}/skuba
    execute command localy    cd ${WORKDIR}/skuba && git checkout ${GIT_BRANCH}

get terraform configuration
    Copy Directory    ${WORKDIR}/skuba/ci/infra/${PLATFORM}    ${TERRAFORMDIR}

run terraform
    execute command localy    cd ${TERRAFORMDIR} && terraform init
    execute command localy    eval `ssh-agent -s` && ssh-add ${DATADIR}/id_shared && cd ${TERRAFORMDIR} && terraform apply --auto-approve
    Copy File    ${TERRAFORMDIR}/terraform.tfstate    ${LOGDIR}/cluster.json

configure registration auto tfvars vmware
    ${terraform_tvars}    OperatingSystem.Get File    ${TERRAFORMDIR}/registration.auto.tfvars
    ${terraform_tvars}    Replace String    ${terraform_tvars}    \#caasp_registry_code = ""    caasp_registry_code = "${CAASP_KEY}"
    Create File    ${TERRAFORMDIR}/registration.auto.tfvars    ${terraform_tvars}

clean cluster
    [Arguments]    ${cluster_name}=${EMPTY}
    Run Keyword If    "${cluster_name}"=="${EMPTY}"    clean all cluster
    ...    ELSE    execute command localy    cd ${CURDIR}/../../workdir/${cluster_name}/terraform && terraform destroy --auto-approve

clean all cluster
    ${clusters_dir}    OperatingSystem.List Directories In Directory    ${CURDIR}/../../workdir
    FOR    ${cluster_dir}    IN    @{clusters_dir}
        Run Keyword And Ignore Error    execute command localy    cd ${CURDIR}/../../workdir/${cluster_dir}/terraform && terraform destroy --auto-approve
    END

set repo and packages
    @{repos}=    Set Variable    sle_server_pool = "http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-SP1/x86_64/product/"    basesystem_pool = "http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-SP1/x86_64/product/"    containers_pool = "http://download.suse.de/ibs/SUSE/Products/SLE-Module-Containers/15-SP1/x86_64/product/"    sle_server_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-SP1/x86_64/update/"    basesystem_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-SP1/x86_64/update/"    containers_updates = "http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Containers/15-SP1/x86_64/update/"
    Run Keyword If    "${MODE}"=="DEV" or "${MODE}"=="STAGING"    Append To List    ${repos}    suse_ca = "http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP1/"
    Run Keyword If    "${MODE}"=="DEV"    Append To List    ${repos}    caasp_devel = "http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_SP1/"
    ...    ELSE IF    "${MODE}"=="STAGING"    Append To List    ${repos}    caasp_staging = "http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/staging/"
    ...    ELSE IF    "${MODE}"=="RELEASE"    Append To List    ${repos}    caasp_release = "http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/standard/"
    ${repo_string}    Set Variable    ${repos[0]}
    FOR    ${repo}    IN    @{repos}
        Continue For Loop If    '${repo}'=='${repos[0]}'
        ${repo_string}    Set Variable    ${repo},\n\t${repo_string}
    END
    Set Global Variable    ${REPOS_LIST}    ${repo_string}
    Set Global Variable    ${PACKAGES_LIST}    "ca-certificates-suse"

configure terraform file common
    [Arguments]    ${tfvar_variabe}
    ${terraform_tvars}    Replace String    ${tfvar_variabe}    masters = 1    masters = ${VM_NUMBER[0]}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    workers = 2    workers = ${VM_NUMBER[1]}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    repositories = {}    repositories = {\n\t${REPOS_LIST}\n}
    ${terraform_tvars}    Replace String    ${terraform_tvars}    packages = [    packages = [${PACKAGES_LIST},\n
    ${terraform_tvars}    Replace String    ${terraform_tvars}    authorized_keys = [    authorized_keys = [ "${SSH_PUB_KEY}" ,
    [Return]    ${terraform_tvars}
