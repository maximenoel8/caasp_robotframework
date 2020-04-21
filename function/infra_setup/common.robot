*** Settings ***
Library           OperatingSystem
Resource          ../commands.robot
Resource          ../../parameters/global_parameters.robot
Library           String
Library           Collections
Resource          ../../parameters/env.robot
Library           Process
Resource          terraform.robot
Library           ../../lib/convert_tvars_to_json.py
Resource          ../helper.robot

*** Keywords ***
clone skuba locally
    OperatingSystem.Remove Directory    ${WORKDIR}/skuba    True
    execute command localy    git clone https://github.com/SUSE/skuba.git ${WORKDIR}/skuba
    execute command localy    cd ${WORKDIR}/skuba && git checkout ${GIT_BRANCH}

copy terraform configuration from skuba folder
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        Copy Directory    ${TEMPLATE_TERRAFORM_DIR}/${PLATFORM}    ${TERRAFORMDIR}/cluster_${cluster_number}
    END
    Comment    Remove Directory    ${WORKDIR}/skuba    True

run terraform
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        ${tf_version}    execute command localy    terraform version
        log    ${tf_version}
        execute command localy    cd ${TERRAFORMDIR}/cluster_${cluster_number} && terraform init
        terraform apply    cluster_${cluster_number}
    END

configure registration auto tfvars vmware
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        ${terraform_tvars}    OperatingSystem.Get File    ${TERRAFORMDIR}/cluster_${cluster_number}/registration.auto.tfvars
        ${terraform_tvars}    Replace String    ${terraform_tvars}    \#caasp_registry_code = ""    caasp_registry_code = "${CAASP_KEY}"
        Create File    ${TERRAFORMDIR}/cluster_${cluster_number}/registration.auto.tfvars    ${terraform_tvars}
    END

clean cluster
    [Arguments]    ${cluster_name}=${EMPTY}
    Run Keyword If    "${cluster_name}"=="${EMPTY}"    clean all cluster
    ...    ELSE    terraform destroy    ${cluster_name}

clean all cluster
    ${clusters_dir}    OperatingSystem.List Directories In Directory    ${CURDIR}/../../workdir
    FOR    ${cluster_dir}    IN    @{clusters_dir}
        Run Keyword And Ignore Error    terraform destroy    ${cluster_dir}
    END

set repo and packages
    &{repos}    Create Dictionary    sle_server_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-SP1/x86_64/product/    basesystem_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-SP1/x86_64/product/    containers_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Containers/15-SP1/x86_64/product/    sle_server_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-SP1/x86_64/update/    basesystem_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-SP1/x86_64/update/    containers_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Containers/15-SP1/x86_64/update/    &{REPOS_LIST}
    Run Keyword If    "${MODE}"=="DEV" or "${MODE}"=="STAGING"    Set To Dictionary    ${repos}    suse_ca=http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP1/
    Run Keyword If    "${MODE}"=="DEV"    Set To Dictionary    ${repos}    caasp_devel=http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_SP1/
    ...    ELSE IF    "${MODE}"=="STAGING"    Set To Dictionary    ${repos}    caasp_staging=http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/staging/
    ...    ELSE IF    "${MODE}"=="RELEASE"    Set To Dictionary    ${repos}    caasp_release=http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/standard/
    Run Keyword If    "${MODE}"=="DEV"    Set To Dictionary    ${repos}    caasp_devel=http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_SP1/
    Set Global Variable    ${REPOS_LIST}    ${repos}
    Append To List    ${PACKAGES_LIST}    ca-certificates-suse

configure terraform file common
    [Arguments]    ${vmware_dico}
    ${master_vm}    Evaluate    ${${VM_NUMBER[0]}}+1
    Set To Dictionary    ${vmware_dico}    masters    ${master_vm}
    Set To Dictionary    ${vmware_dico}    workers    ${${VM_NUMBER[1]}}
    ${status}    ${packages}    Run Keyword And Ignore Error    Get From Dictionary    ${vmware_dico}    packages
    @{packages}    Run Keyword If    "${status}"=="FAIL"    Create List
    ${PACKAGES_LIST}    Run Keyword If    "${packages}"!="${EMPTY}"    Combine Lists    ${PACKAGES_LIST}    ${packages}
    ...    ELSE    Set Variable    ${PACKAGES_LIST}
    Set To Dictionary    ${vmware_dico}    packages    ${PACKAGES_LIST}
    @{authorized_keys}    Create List    ${SSH_PUB_KEY}
    Set To Dictionary    ${vmware_dico}    authorized_keys    ${authorized_keys}
    [Return]    ${vmware_dico}

check terraform finish successfully
    [Arguments]    ${cluster}
    ${expected value}    Set Variable    Apply complete!
    ${result}    Get Process Result    ${cluster}
    Log    ${result.stdout}
    Log    ${result.stderr}
    ${status}    ${output}    Run Keyword And Ignore Error    Should Contain    ${result.stdout}    ${expected value}
    ${status}    Set Variable If    "${status}"=="PASS"    True    False

check all terraform finish
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        check terraform finish successfully    cluster_${cluster_number}
        Copy File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfstate    ${LOGDIR}/cluster${cluster_number}.json
    END

_create tvars json file
    [Arguments]    ${dico}    ${cluster_number}
    log    ${dico}
    Log Dictionary    ${dico}
    ${dico_json}    Convert Dictionary To Json    ${dico}
    Log    ${dico_json}
    Create File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.json    ${dico_json}
