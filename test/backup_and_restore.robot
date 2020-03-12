*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/backup_and_restore/bNr_helpers.robot
Resource          ../function/backup_and_restore/velero.robot
Resource          ../function/backup_and_restore/wordpress.robot
Resource          ../function/setup_environment.robot

*** Test Cases ***
velero backup wordpress
    Given cluster running
    And velero setup
    And add CA to all server
    And helm is installed
    And nfs client is deployed
    And velero cli is installed
    And velero server is deployed with volume snapshot
    And wordpress is deployed
    And copy file to wordpress pod
    And wordpress volumes volumes are annotated to be backed up
    When create backup on    ${cluster}    args=--include-namespaces wordpress
    then backup should be successfull
    when wordpress is removed
    and create restore from backup    ${backup_name}
    Sleep    10sec
    and wordpress is up
    then check file exist in wordpress pod
    [Teardown]    teardown velero

velero migrate wordpress from cluster 1 to 2
    Given cluster running
    and cluster running    2
    and velero setup
    And add CA to all server    1
    And add CA to all server    2
    And helm is installed    1
    And helm is installed    2
    And nfs client is deployed    cluster_number=1
    And nfs client is deployed    cluster_number=2
    And velero cli is installed
    And velero server is deployed with volume snapshot    1
    And velero server is deployed with volume snapshot    2
    And wordpress is deployed
    And copy file to wordpress pod
    And wordpress volumes volumes are annotated to be backed up
    When create backup on    ${cluster}    args=--include-namespaces wordpress
    then backup should be successfull
    when create restore from backup    ${backup_name}    cluster_number=2
    Sleep    10sec
    and wordpress is up    2
    then check file exist in wordpress pod    2
    [Teardown]    teardown velero
