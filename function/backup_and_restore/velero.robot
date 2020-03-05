*** Settings ***
Library           OperatingSystem
Resource          ../commands.robot
Resource          minio.robot
Resource          ../cluster_helpers.robot
Resource          ../../parameters/velero.robot
Resource          ../../parameters/minio.robot

*** Variables ***

*** Keywords ***
create credentials file
    Create File    ${credential-velero-file}    [default]\n
    Append To File    ${credential-velero-file}    aws_access_key_id=${MINIO_ACCESS_KEY}\n
    Append To File    ${credential-velero-file}    aws_secret_access_key=${MINIO_SECRET_KEY}\n

velero server is deployed without volume snapshot configured
    helm    install --name velero --namespace kube-system --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${BUKET_MASTER} --set configuration.backupStorageLocation.config.region=minio --set configuration.backupStorageLocation.config.s3ForcePathStyle=true --set configuration.backupStorageLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set snapshotsEnabled=false --set-file credentials.secretContents.cloud=${credential-velero-file} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${velero_plugin_aws_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins --wait ${velero_chart}
    wait pods    -l name=velero -n kube-system

velero cli is installed
    ${status}    ${output}    Run Keyword And Ignore Error    velero    version
    Run Keyword If    "${status}"=="FAIL"    execute command localy    wget -P ${LOGDIR} https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/${velero_tar_name}.tar.gz
    Run Keyword If    "${status}"=="FAIL"    execute command localy    tar -xvzf ${LOGDIR}/${velero_tar_name}.tar.gz -C ${LOGDIR}

backup-location slave is set up
    velero    backup-location create slave --provider aws --bucket ${BUCKET_SLAVE} --config region=minio,s3ForcePathStyle=true,s3Url=${S3_bucket_url}

create backup on
    [Arguments]    ${backup_name}    ${location}=default    ${args}=${EMPTY}
    velero    backup create ${backup_name} ${args} --storage-location ${location}
    Set Test Variable    ${backup_name}

backup should be successfull
    Wait Until Keyword Succeeds    5m    10s    check backup completed

create schedule backup on
    [Arguments]    ${location}

setup backup location on awss3
    velero    velero backup-location create awss3

velero server is deployed with volume snapshot
    create credentials file
    helm    install \ \ \ \ \ --name velero \ \ \ \ \ --namespace kube-system \ \ \ \ \ --set configuration.provider=aws \ \ \ \ \ --set configuration.backupStorageLocation.name=default \ \ \ \ \ --set configuration.backupStorageLocation.bucket=velero \ \ \ \ \ --set configuration.backupStorageLocation.config.region=minio \ \ \ \ \ --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \ \ \ \ \ --set configuration.backupStorageLocation.config.s3Url=http://10.84.72.33:9000 \ \ \ \ \ --set snapshotsEnabled=true \ \ \ \ \ --set deployRestic=true \ \ \ --set configuration.volumeSnapshotLocation.name=default \ \ \ --set configuration.volumeSnapshotLocation.bucket=velero \ \ \ --set configuration.volumeSnapshotLocation.config.region=minio \ \ \ --set configuration.volumeSnapshotLocation.config.s3ForcePathStyle=true \ \ \ --set configuration.volumeSnapshotLocation.config.s3Url=http://10.84.72.33:9000 \ \ \ \ \ --set-file credentials.secretContents.cloud=${credential-velero-file} \ \ \ \ \ --set initContainers[0].name=velero-plugin-for-aws \ \ \ \ \ --set initContainers[0].image=registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-plugin-for-aws:1.0.1 \ \ \ \ \ --set initContainers[0].volumeMounts[0].mountPath=/target \ \ \ \ \ --set initContainers[0].volumeMounts[0].name=plugins \ \ \ \ \ --set image.repository=registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero \ \ \ \ \ --set configMaps.restic-restore-action-config.data.image=registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-restic-restore-helper:1.3.0 \ \ \ \ \ ${LOGDIR}/kubernetes-charts-suse-com/stable/velero
    wait pods    -l name=velero -n kube-system
    velero    client config set namespace=kube-system

create restore from backup
    [Arguments]    ${backup_name}
    ${output}    velero    restore create --from-backup ${backup_name}
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