*** Settings ***
Resource          cluster_helpers.robot
Library           ../lib/directory_diff.py
Resource          vms_deployment/common.robot
Resource          vms_deployment/main_keywork.robot
Resource          cluster_deployment.robot

*** Keywords ***
check diff from current terraform files with updated workstation
    [Arguments]    ${cluster_number}=1
    copy terraform files in temporary directory    ${cluster_number}
    ${diff}    compare_directory_and_get_diff    ${TERRAFORMDIR}/temporary    ${TEMPLATE_TERRAFORM_DIR}/${PLATFORM}
    Log Dictionary    ${diff}
    ${lt_diff}    Get Length    ${diff["file_diff"]}
    ${lt_missing_from}    Get Length    ${diff["only_from"]}
    ${lt_missing_to}    Get Length    ${diff["only_to"]}
    Run Keyword If    ${lt_diff}!=0    Log    File difference ${diff["file_diff"]}    WARN
    Run Keyword If    ${lt_missing_from}!=0    Log    File only in left ${diff["only_from"]}    WARN
    Run Keyword If    ${lt_missing_to}!=0    Log    File only in right ${diff["only_to"]}    WARN
    Return From Keyword If    ${lt_diff}==0 and ${lt_missing_from}==0 and ${lt_missing_to}==0    False
    ${status}    Set Variable    True
    [Return]    ${status}

copy terraform files in temporary directory
    [Arguments]    ${cluster_number}=1
    Switch Connection    skuba_station_${cluster_number}
    Get Directory    /usr/share/caasp/terraform/${PLATFORM}    ${TERRAFORMDIR}/temporary    recursive=True

redeploy with new terraforms files
    ${status}    check diff from current terraform files with updated workstation
    Copy Directory    ${TERRAFORMDIR}/cluster_1    ${TERRAFORMDIR}/backup
    clean cluster    ${cluster}
    execute command localy    rm -rf ${TERRAFORMDIR}/cluster_1
    deploy cluster vms    True
    load vm ip
    create ssh session with workstation and nodes
    install skuba    True

warning about terraform files

copy terraform from temporay
    log    ${NUMBER_OF_CLUSTER}
    ${limit}    Evaluate    ${NUMBER_OF_CLUSTER}+1
    FOR    ${cluster_number}    IN RANGE    1    ${limit}
        Copy Directory    ${TERRAFORMDIR}/temporary    ${TERRAFORMDIR}/cluster_${cluster_number}
    END

check terrafrom are updated and redeploy if not
    ${status}    check diff from current terraform files with updated workstation
    Run Keyword If    ${status}    redeploy with new terraforms files
