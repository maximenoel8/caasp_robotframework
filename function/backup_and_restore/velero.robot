*** Settings ***
Library           OperatingSystem
Resource          ../commands.robot
Resource          minio.robot
Resource          ../cluster_helpers.robot
Resource          ../../parameters/velero.robot
Resource          ../../parameters/minio.robot
Resource          wordpress.robot
Resource          ../setup_environment.robot

*** Variables ***

*** Keywords ***
create credentials file
    Create File    ${credential-velero-file}    [default]\n
    Append To File    ${credential-velero-file}    aws_access_key_id=${MINIO_ACCESS_KEY}\n
    Append To File    ${credential-velero-file}    aws_secret_access_key=${MINIO_SECRET_KEY}\n

velero server is deployed without volume snapshot configured
    helm    install --name velero --namespace kube-system --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${BUKET_MASTER} --set configuration.backupStorageLocation.config.region=minio --set configuration.backupStorageLocation.config.s3ForcePathStyle=true --set configuration.backupStorageLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set snapshotsEnabled=false --set-file credentials.secretContents.cloud=${credential-velero-file} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${plugin_aws_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins --wait --set image.repository=${velero_image} ${velero_chart}
    wait pods ready    -l name=velero -n kube-system

velero cli is installed
    ${status}    ${output}    Run Keyword And Ignore Error    velero    version
    Run Keyword If    "${status}"=="FAIL"    execute command localy    wget -P ${LOGDIR} https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/${velero_tar_name}.tar.gz
    Run Keyword If    "${status}"=="FAIL"    execute command localy    tar -xvzf ${LOGDIR}/${velero_tar_name}.tar.gz -C ${LOGDIR}

backup-location slave is set up
    velero    backup-location create slave --provider aws --bucket ${BUCKET_SLAVE} --config region=minio,s3ForcePathStyle=true,s3Url=${S3_bucket_url}

create backup on
    [Arguments]    ${backup_name}    ${location}=default    ${args}=${EMPTY}
    velero    backup create ${backup_name} ${args} --storage-location ${location}
    Set Suite Variable    ${backup_name}

backup should be successfull
    Wait Until Keyword Succeeds    5m    10s    check backup completed

create schedule backup on
    [Arguments]    ${location}

setup backup location on awss3
    velero    velero backup-location create awss3

velero server is deployed with volume snapshot
    [Arguments]    ${cluster_number}=1
    create credentials file
    helm    install --name velero --namespace velero --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${BUCKET_MASTER} --set configuration.backupStorageLocation.config.region=minio --set configuration.backupStorageLocation.config.s3ForcePathStyle=true --set configuration.backupStorageLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set snapshotsEnabled=true --set deployRestic=true --set configuration.volumeSnapshotLocation.name=default --set configuration.volumeSnapshotLocation.bucket=velero --set configuration.volumeSnapshotLocation.config.region=minio --set configuration.volumeSnapshotLocation.config.s3ForcePathStyle=true --set configuration.volumeSnapshotLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set-file credentials.secretContents.cloud=${credential-velero-file} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${aws_plugin_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins --set image.repository=${velero_image} --set configMaps.restic-restore-action-config.data.image=${restic_image} ${LOGDIR}/kubernetes-charts-suse-com/stable/velero    ${cluster_number}
    wait pods ready    -l name=velero -n velero    ${cluster_number}
    velero    client config set namespace=velero    ${cluster_number}

create restore from backup
    [Arguments]    ${backup_name}    ${cluster_number}=1
    Wait Until Keyword Succeeds    2min    10sec    check backup is present    ${backup_name}
    ${output}    Wait Until Keyword Succeeds    2min    10sec    velero    restore create --from-backup ${backup_name}    ${cluster_number}
    ${restore}    Split String    ${output}    \n
    ${restore_names}    Split String    ${restore[0]}    "
    Set Test Variable    ${restore_name}    ${restore_names[1]}

velero setup
    Set Test Variable    ${credential-velero-file}    ${LOGDIR}/credentials-velero
    Set Test Variable    ${velero_path}    ${LOGDIR}/${velero_tar_name}/

check backup completed
    ${output}    velero    backup describe ${backup_name}
    Should Contain    ${output}    Phase: \ Completed

check restore finish
    ${output}    velero    backup describe ${backup_name}
    Should Contain    ${output}    Phase: \ Completed

teardown velero
    Run Keyword And Ignore Error    velero    delete backup --confirm ${backup_name}
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        Run Keyword And Ignore Error    helm    delete --purge velero    ${cluster_number}
        Run Keyword And Ignore Error    wordpress is removed    ${cluster_number}
    END
    [Teardown]    teardown_test

check backup is present
    [Arguments]    ${backup}    ${cluster_number}=1
    ${backup_list}    velero    get backup    ${cluster_number}
    Should Contain    ${backup_list}    ${backup}
