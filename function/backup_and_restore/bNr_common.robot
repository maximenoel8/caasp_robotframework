*** Settings ***
Resource          ../commands.robot

*** Keywords ***
annotate volume to be backed up
    [Arguments]    ${resource_args}    ${backup_name}
    kubectl    annotate pod/${resource_args} backup.velero.io/backup-volumes=${backup_name}
