*** Settings ***
Resource          ../commands.robot
Library           Process
Resource          ../../parameters/minio.robot

*** Variables ***

*** Keywords ***
install and start minio server on master0
    ${status}    ${output}    Run Keyword And Ignore Error    SSHLibrary.Directory Should Not Exist    ${minio_server_path}
    Run Keyword if    "${status}"=="PASS"    execute command with ssh    mkdir ${minio_server_path}    minio_session
    Run Keyword if    "${status}"=="PASS"    execute command with ssh    curl ${minio_url_binary} --output ${minio_server_path}/minio    minio_session
    Run Keyword if    "${status}"=="PASS"    execute command with ssh    chmod +x ${minio_server_path}/minio    minio_session
    Run Keyword if    "${status}"=="PASS"    execute command with ssh    mkdir ${minio_server_path}/bucket    minio_session
    Write    MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY} MINIO_SECRET_KEY=${MINIO_SECRET_KEY} ${minio_server_path}/minio \ server ${minio_server_path}/bucket &
    Set Suite Variable    ${MINIO_MASTER_SERVER_URL}    http://${BOOSTRAP_MASTER_1}:9000

install minio client on local
    execute command localy    curl https://dl.min.io/client/mc/release/linux-amd64/mc --output ${LOGDIR}/mc
    execute command localy    chmod +x ${LOGDIR}/mc
    execute command localy    ${LOGDIR}/mc config host add velero ${MINIO_MASTER_SERVER_URL} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

minio is deployed and setup
    open ssh session    ${BOOSTRAP_MASTER_1}    minio_session
    Switch Connection    minio_session
    ${status}    ${output}    Run Keyword And Ignore Error    check minio is correctly deploy and have a bucket
    Run Keyword If    "${status}"=="FAIL"    install and start minio server on master0
    Run Keyword If    "${status}"=="FAIL"    install minio client on local
    Run Keyword If    "${status}"=="FAIL"    setup minio bucket with minio client    ${BUCKET_MASTER}

setup minio bucket with minio client
    [Arguments]    ${bucket_name}
    execute command localy    ${LOGDIR}/mc mb -p velero/${bucket_name}

check minio is correctly deploy and have a bucket
    ${output}    execute command with ssh    ps aux | grep minio    minio_session
    ${result}    Split To Lines    ${output}
    ${length}    Get Length    ${result}
    ${output}    Run Keyword If    ${length} > 2    execute command localy    ${LOGDIR}/mc ls velero
    ...    ELSE    Set Variable    ${EMPTY}
    Should Not Be Empty    ${output}
