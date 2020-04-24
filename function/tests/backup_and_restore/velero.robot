*** Settings ***
Library           OperatingSystem
Resource          ../../commands.robot
Resource          minio.robot
Resource          ../../cluster_helpers.robot
Resource          ../../../parameters/velero.robot
Resource          ../../../parameters/minio.robot
Resource          wordpress.robot
Resource          ../../setup_environment.robot

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
    ${random}    String.Generate Random String    4    [NUMBERS]
    Set Suite Variable    ${backup_name}    ${backup_name}-${random}
    velero    backup create ${backup_name} ${args} --storage-location ${location}

backup should be successfull
    Wait Until Keyword Succeeds    5m    10s    check backup completed

create schedule backup on
    [Arguments]    ${location}

setup backup location on awss3
    velero    velero backup-location create awss3

velero server is deployed with volume snapshot for
    [Arguments]    ${bucket_provider}    ${cluster_number}=1
    Run Keyword if    "${bucket_provider}" == "minio"    velero deployment for minio    ${cluster_number}
    ...    ELSE IF    "${bucket_provider}" == "aws"    velero deployment for aws    ${cluster_number}
    ...    ELSE IF    "${bucket_provider}" == "gcp"    velero deployment for gcp    ${cluster_number}
    ...    ELSE IF    "${bucket_provider}" == "azure"    velero deployment for azure    ${cluster_number}
    ...    ELSE    Fail    Wrong provider bucket provider${bucket_provider}
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
    [Arguments]    ${bucket_type}=default
    Run Keyword And Ignore Error    velero    delete backup --confirm ${backup_name}
    Run Keyword And Ignore Error    Run Keyword If    "${bucket_type}"=="aws" or "${bucket_type}"=="minio"    execute command localy    ${LOGDIR}/mc rm --recursive --force ${bucket_type}/${bucket}
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    Evaluate    ${i}+1
        Run Keyword And Ignore Error    helm    delete --purge velero    ${cluster_number}
        Run Keyword And Ignore Error    helm    delete --purge wordpress    ${cluster_number}
        Run Keyword And Ignore Error    kubectl    delete namespace wordpress    ${cluster_number}
        Run Keyword And Ignore Error    Remove File    ${credential-velero-file}
    END
    [Teardown]    teardown_test

check backup is present
    [Arguments]    ${backup}    ${cluster_number}=1
    ${backup_list}    velero    get backup    ${cluster_number}
    Should Contain    ${backup_list}    ${backup}

velero server is deployed with volume snapeshot aws
    create credentials file
    helm    install --name velero --namespace velero --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${BUCKET_MASTER} --set configuration.backupStorageLocation.config.region=minio --set configuration.backupStorageLocation.config.s3ForcePathStyle=true --set configuration.backupStorageLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set snapshotsEnabled=true --set deployRestic=true --set configuration.volumeSnapshotLocation.name=default --set configuration.volumeSnapshotLocation.bucket=velero --set configuration.volumeSnapshotLocation.config.region=minio --set configuration.volumeSnapshotLocation.config.s3ForcePathStyle=true --set configuration.volumeSnapshotLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set-file credentials.secretContents.cloud=${credential-velero-file} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${aws_plugin_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins --set image.repository=${velero_image} --set configMaps.restic-restore-action-config.data.image=${restic_image} ${LOGDIR}/kubernetes-charts-suse-com/stable/velero    ${cluster_number}
    wait pods ready    -l name=velero -n velero    ${cluster_number}
    velero    client config set namespace=velero    ${cluster_number}

velero deployment for minio
    [Arguments]    ${cluster_number}
    create credentials file
    helm    install --name velero --namespace velero --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${bucket} --set configuration.backupStorageLocation.config.region=minio --set configuration.backupStorageLocation.config.s3ForcePathStyle=true --set configuration.backupStorageLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set snapshotsEnabled=true --set deployRestic=true --set configuration.volumeSnapshotLocation.name=default --set configuration.volumeSnapshotLocation.bucket=velero --set configuration.volumeSnapshotLocation.config.region=minio --set configuration.volumeSnapshotLocation.config.s3ForcePathStyle=true --set configuration.volumeSnapshotLocation.config.s3Url=${MINIO_MASTER_SERVER_URL} --set-file credentials.secretContents.cloud=${credential-velero-file} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${aws_plugin_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins suse-charts/velero    ${cluster_number}

velero deployment for aws
    [Arguments]    ${cluster_number}
    create credentials file
    helm    install --name velero --namespace velero --set configuration.provider=aws --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${bucket} --set configuration.backupStorageLocation.config.region=${aws_region} --set snapshotsEnabled=true --set deployRestic=true --set configuration.volumeSnapshotLocation.name=default --set configuration.volumeSnapshotLocation.config.region=${aws_region} --set initContainers[0].name=velero-plugin-for-aws --set initContainers[0].image=${aws_plugin_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins --set-file credentials.secretContents.cloud=${credential-velero-file} suse-charts/velero    ${cluster_number}

velero deployment for gcp
    [Arguments]    ${cluster_number}
    Set Suite Variable    ${bucket}    ${BUCKET_MASTER}-gcp
    helm    install --name velero --namespace velero --set configuration.provider=gcp --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${bucket} --set snapshotsEnabled=true --set deployRestic=true --set configuration.volumeSnapshotLocation.name=default --set-file credentials.secretContents.cloud=${DATADIR}/${gcp_credential_file} --set initContainers[0].name=velero-plugin-for-gcp --set initContainers[0].image=${gcp_plugin_image} --set initContainers[0].volumeMounts[0].mountPath=/target --set initContainers[0].volumeMounts[0].name=plugins suse-charts/velero    ${cluster_number}

velero deployment for azure
    [Arguments]    ${cluster_number}
    _create azure credentials file
    ${bucket}    Set Variable    velero
    helm    install --name velero --namespace velero --set configuration.provider=azure \ --set configuration.backupStorageLocation.name=default --set configuration.backupStorageLocation.bucket=${bucket} \ --set snapshotsEnabled=true --set deployRestic=true \ --set configuration.backupStorageLocation.bucket=velero \ --set configuration.backupStorageLocation.config.resourceGroup=${AZURE.resource_group} \ --set configuration.backupStorageLocation.config.storageAccount=${AZURE.storage_account} \ --set configuration.volumeSnapshotLocation.name=default \ --set-file credentials.secretContents.cloud=${credential-velero-file} \ --set initContainers[0].name=velero-plugin-for-microsoft-azure \ --set initContainers[0].image=${azure_plugin_image} \ --set initContainers[0].volumeMounts[0].mountPath=/target \ --set initContainers[0].volumeMounts[0].name=plugins suse-charts/velero    ${cluster_number}

_create azure credentials file
    Create File    ${credential-velero-file}    AZURE_SUBSCRIPTION_ID=${AZURE.subscription_id}\n
    Append To File    ${credential-velero-file}    AZURE_TENANT_ID=${AZURE.tenant_id}\n
    Append To File    ${credential-velero-file}    AZURE_CLIENT_ID=${AZURE.client_id}\n
    Append To File    ${credential-velero-file}    AZURE_CLIENT_SECRET=${AZURE.client_secret}\n
    Append To File    ${credential-velero-file}    AZURE_RESOURCE_GROUP=${AZURE.resource_group}\n
    Append To File    ${credential-velero-file}    AZURE_CLOUD_NAME=${AZURE.cloud_name}\n
