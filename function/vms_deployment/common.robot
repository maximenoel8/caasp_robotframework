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
Resource          set_repo.robot
Resource          ../tools.robot

*** Keywords ***
clone skuba locally
    OperatingSystem.Remove Directory    ${WORKDIR}/skuba    True
    execute command localy    git clone https://github.com/SUSE/skuba.git ${WORKDIR}/skuba
    execute command localy    cd ${WORKDIR}/skuba && git checkout ${GIT_BRANCH}

copy terraform configuration
    log    ${NUMBER_OF_CLUSTER}
    ${limit}    Evaluate    ${NUMBER_OF_CLUSTER}+1
    FOR    ${cluster_number}    IN RANGE    1    ${limit}
        execute command localy    mkdir -p ${TERRAFORMDIR}/cluster_${cluster_number}
        execute command localy    cp -R ${TEMPLATE_TERRAFORM_DIR}/${PLATFORM}/* ${TERRAFORMDIR}/cluster_${cluster_number}
        create register scc file    ${TERRAFORMDIR}/cluster_${cluster_number}
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
        Create File    ${TERRAFORMDIR}/cluster_${cluster_number}/registration.auto.tfvars    caasp_registry_code = "${CAASP_KEY_V${CAASP_VERSION}}"
        Comment    ${terraform_tvars}    Replace String    ${terraform_tvars}    \#rmt_server_name = "rmt.example.com"    rmt_server_name = "saturn.qa.suse.cz"
    END

clean cluster
    [Arguments]    ${cluster_name}=${EMPTY}
    step    cleaning the cluster ...
    Run Keyword If    "${cluster_name}"=="${EMPTY}"    clean all cluster
    ...    ELSE    terraform destroy all cluster
    step    cluster has been destroyed

clean all cluster
    ${clusters_dir}    OperatingSystem.List Directories In Directory    ${CURDIR}/../../workdir
    FOR    ${cluster_dir}    IN    @{clusters_dir}
        Run Keyword And Ignore Error    terraform destroy    ${CURDIR}/../../workdir/${cluster_dir}/terraform/cluster_1
    END

configure terraform file common
    [Arguments]    ${terraform_dico}
    ${master_vm}    Evaluate    ${${VM_NUMBER[0]}}+1
    Set To Dictionary    ${terraform_dico}    masters    ${master_vm}
    Set To Dictionary    ${terraform_dico}    workers    ${${VM_NUMBER[1]}}
    @{authorized_keys}    Create List    ${SSH_PUB_KEY}
    Set To Dictionary    ${terraform_dico}    authorized_keys    ${authorized_keys}
    Comment    Set To Dictionary    ${terraform_dico}    lb_repositories    ${LB_REPO_LIST}
    [Return]    ${terraform_dico}

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

create register scc file
    [Arguments]    ${terraform_folder}
    ${sles_version}    Set Variable If    "${VM_VERSION}"=="SP1"    15.1    15.2
    ${scc_version}    Set Variable If    "${CAASP_VERSION}"=="4"    4.0    4.5
    Create File    ${terraform_folder}/cloud-init/register-scc.tpl    \ \ - [ SUSEConnect, -r, \$\{caasp_registry_code\} ]\n
    Append To File    ${terraform_folder}/cloud-init/register-scc.tpl    \ \ - [ SUSEConnect, -p, sle-module-containers/${sles_version}/x86_64 ]\n
    Append To File    ${terraform_folder}/cloud-init/register-scc.tpl    \ \ - [ SUSEConnect, -p, caasp/${scc_version}/x86_64, -r, \$\{caasp_registry_code\} ]\n
    Comment    Append To File    ${terraform_folder}/cloud-init/register-scc.tpl    \ \ - [ SUSEConnect, -p, ses/6/x86_64, -r, ${SES_KEY} ]

_update commands.tpl
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        Create File    ${TERRAFORMDIR}/cluster_${cluster_number}/cloud-init/commands.tpl    \ \ - echo ${AIRGAPPED_IP} mirror.server.aws > /etc/hosts\n
        Append To File    ${TERRAFORMDIR}/cluster_${cluster_number}/cloud-init/commands.tpl    \ \ - zypper -n install \$\{packages\}
    END

_create package list
    [Arguments]    ${terraform_dico}
    ${status}    ${packages}    Run Keyword And Ignore Error    Get From Dictionary    ${terraform_dico}    packages
    ${packages}    Run Keyword If    "${status}"=="FAIL"    Create List
    ...    ELSE    Set Variable    ${packages}
    ${PACKAGES_LIST}    Run Keyword If    "${packages}"!="${EMPTY}"    Combine Lists    ${PACKAGES_LIST}    ${packages}
    ...    ELSE    Set Variable    ${PACKAGES_LIST}
    Set To Dictionary    ${terraform_dico}    packages    ${PACKAGES_LIST}
