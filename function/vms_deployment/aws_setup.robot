*** Settings ***
Resource          common.robot

*** Keywords ***
configure terraform tvars aws
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{vmware_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Set To Dictionary    ${vmware_dico}    iam_profile_master    caasp-k8s-master-vm-profile
        Set To Dictionary    ${vmware_dico}    iam_profile_worker    caasp-k8s-worker-vm-profile
        Set To Dictionary    ${vmware_dico}    aws_region    eu-central-1
        Set To Dictionary    ${vmware_dico}    aws_access_key    ${AWS_ACCESS_KEY}
        Set To Dictionary    ${vmware_dico}    aws_secret_key    ${AWS_SECRET_KEY}
        Set To Dictionary    ${vmware_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Comment    Set To Dictionary    ${vmware_dico}    caasp_registry_code    ${CAASP_KEY}
        Comment    Set To Dictionary    ${vmware_dico}    repositories    ${repo_list}
        Comment    Collections.Remove From List    ${PACKAGES_LIST}    1
        ${vmware_dico}    configure terraform file common    ${vmware_dico}
        _create tvars json file    ${vmware_dico}    ${cluster_number}
    END
