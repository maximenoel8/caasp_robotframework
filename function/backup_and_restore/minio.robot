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
    Write    MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY} MINIO_SECRET_KEY=${MINIO_SECRET_KEY} ${minio_server_path}/minio server ${minio_server_path}/bucket &
    Read Until    https://docs.min.io/docs/dotnet-client-quickstart-guide
    Set Suite Variable    ${MINIO_MASTER_SERVER_URL}    http://${BOOSTRAP_MASTER_1}:9000

install minio client localy
    execute command localy    curl https://dl.min.io/client/mc/release/linux-amd64/mc --output ${LOGDIR}/mc
    execute command localy    chmod +x ${LOGDIR}/mc

minio is deployed and setup
    open ssh session    ${BOOSTRAP_MASTER_1}    minio_session
    Switch Connection    minio_session
    ${status}    ${output}    Run Keyword And Ignore Error    check minio is correctly deploy and have a bucket
    Run Keyword If    "${status}"=="FAIL"    install and start minio server on master0
    Run Keyword If    "${status}"=="FAIL"    install minio client localy
    Run Keyword If    "${status}"=="FAIL"    mc configure minio server
    Set Global Variable    ${BUCKET_MASTER}    ${BUCKET_MASTER}-minio
    Run Keyword If    "${status}"=="FAIL"    setup minio bucket with minio client    minio    ${BUCKET_MASTER}

setup minio bucket with minio client
    [Arguments]    ${provider}    ${bucket_name}
    ${args}    Set Variable If    "${provider}"=="s3"     --region ${aws_region}    "${EMPTY}"
    execute command localy    ${LOGDIR}/mc mb ${args} -p ${provider}/${bucket_name}

check minio is correctly deploy and have a bucket
    ${ouput}    execute command with ssh    ps aux | grep minio | grep -v "grep"    minio_session    check_rc=False
    ${status}    ${output}    Run Keyword If    "${ouput}" != "${EMPTY}"    Run Keyword And Ignore Error    execute command localy    ${LOGDIR}/mc ls minio | grep ${BUCKET_MASTER}
    Should Be Equal As Strings    ${status}    PASS

mc configure aws server
    execute command localy    ${LOGDIR}/mc config host add s3 https://s3.amazonaws.com ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4

mc configure minio server
    execute command localy    ${LOGDIR}/mc config host add minio ${MINIO_MASTER_SERVER_URL} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

aws bucket is setup
    install minio client localy
    mc configure aws server
    Set Global Variable    ${BUCKET_MASTER}    ${BUCKET_MASTER}-aws
    setup minio bucket with minio client    s3    ${BUCKET_MASTER}
