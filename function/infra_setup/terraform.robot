*** Settings ***
Resource          ../commands.robot

*** Keywords ***
terraform destroy
    [Arguments]    ${cluster_name}
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        execute command localy    cd ${CURDIR}/../../workdir/${cluster_name}/terraform/cluster_${cluster_number} && terraform destroy --auto-approve
    END

terraform apply
    [Arguments]    ${cluster}
    ${temp}    Split String    ${cluster}    _
    ${cluster_number}    Set Variable    ${temp[-1]}
    execute command localy    eval `ssh-agent -s` && ssh-add ${DATADIR}/id_shared && cd ${TERRAFORMDIR}/${cluster} && terraform apply --auto-approve
    Copy File    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfstate    ${LOGDIR}/cluster${cluster_number}.json
