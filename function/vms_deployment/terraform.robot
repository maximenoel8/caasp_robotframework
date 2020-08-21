*** Settings ***
Resource          ../commands.robot

*** Keywords ***
terraform destroy
    [Arguments]    ${terraform_directory}
    execute command localy    eval `ssh-agent -s` && ssh-add ${DATADIR}/id_shared && cd ${terraform_directory} && terraform destroy --auto-approve
    [Teardown]    clean terraform variable    ${terraform_directory}

terraform apply
    [Arguments]    ${cluster}
    ${temp}    Split String    ${cluster}    _
    ${cluster_number}    Set Variable    ${temp[-1]}
    ${args}    Set Variable If    "${PLATFORM}"=="libvirt"    -parallelism=1    ${EMPTY}
    execute command localy    eval `ssh-agent -s` && ssh-add ${DATADIR}/id_shared && cd ${TERRAFORMDIR}/${cluster} && terraform apply --auto-approve ${args}
    Copy File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfstate    ${LOGDIR}/cluster${cluster_number}.json

clean terraform variable
    [Arguments]    ${directory}
    Run Keyword And Ignore Error    Remove File    ${directory}/terraform.tfvars.json
    Run Keyword And Ignore Error    Remove File    ${directory}/registration.auto.tfvars

terraform destroy all cluster
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        terraform destroy    ${TERRAFORMDIR}/cluster_${cluster_number}
    END

terraform version
    [Arguments]    ${cluster_number}=1
    ${output}    execute command with ssh    terraform version    skuba_station_${cluster_number}
    ${lines}    Split To Lines    ${output}
    ${version}    Set Variable    ${lines[0]}
    [Return]    ${version}
