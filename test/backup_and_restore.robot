*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/backup_and_restore/bNr_helpers.robot
Resource          ../function/backup_and_restore/velero.robot
Resource          ../function/backup_and_restore/wordpress.robot

*** Test Cases ***
velero backup elastic search
    Given cluster running
    velero setup
    And add CA to all server
    And helm is installed
    And nfs client is deployed
    And velero cli is installed
    And velero server is deployed with volume snapshot
    And wordpress is deployed
    And copy file to wordpress pod
    And wordpress volumes volumes are annotated to be backed up
    When create backup on    backup-wp-pv-10    args=--include-namespaces wordpress
    then backup should be successfull
    when wordpress is removed
    Sleep    10
    and create restore from backup    backup-wp-pv-10
    Sleep    5
    and wordpress is up
    then check file exist in wordpress pod
