*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/backup_and_restore/velero.robot
Resource          ../function/backup_and_restore/wordpress.robot
Resource          ../function/setup_environment.robot
Resource          ../function/backup_and_restore/etcdctl.robot
Resource          ../function/backup_and_restore/bNr_helpers.robot
Resource          ../function/centralized_log.robot

*** Test Cases ***
velero backup wordpress
    [Tags]    backup
    Given cluster running
    And velero setup
    And add CA to all server
    And helm is installed
    And nfs server is deployed
    And nfs client is deployed
    And velero cli is installed
    And minio is deployed and setup
    And velero server is deployed with volume snapshot
    And wordpress is deployed
    And file copy to wordpress pod
    And wordpress volumes are annotated to be backed up
    When create backup on    ${cluster}    args=--include-namespaces wordpress
    Then backup should be successfull
    When wordpress is removed
    And create restore from backup    ${backup_name}
    Sleep    10sec
    And wordpress is up
    Then check file exist in wordpress pod
    [Teardown]    teardown velero

velero migrate wordpress from cluster 1 to 2
    [Tags]    backup
    Run Keyword If    ${NUMBER_OF_CLUSTER} < 2    Fail    Need two cluster for this test
    Given cluster running
    and cluster running    2
    and velero setup
    And add CA to all server    1
    And add CA to all server    2
    And helm is installed    1
    And helm is installed    2
    And nfs server is deployed
    And nfs client is deployed    cluster_number=1
    And nfs client is deployed    cluster_number=2
    And velero cli is installed
    And velero server is deployed with volume snapshot    1
    And velero server is deployed with volume snapshot    2
    And wordpress is deployed
    And file copy to wordpress pod
    And wordpress volumes are annotated to be backed up
    When create backup on    ${cluster}    args=--include-namespaces wordpress
    then backup should be successfull
    when create restore from backup    ${backup_name}    cluster_number=2
    Sleep    10sec
    and wordpress is up    2
    then check file exist in wordpress pod    2
    [Teardown]    teardown velero

etcd-backup
    [Tags]    backup
    Given cluster running
    And etcd-backup job is executed
    [Teardown]    teardown etcdctl

Restore all master nodes - etcd cluster and data
    [Tags]    backup
    Given cluster running
    And helm is installed
    And rsyslog is deployed
    And etcd-backup job is executed
    And install etcdctl on masters
    And stop etcd ressource on all masters
    And purge etcd data on all masters
    When restore etcd data on    master-0
    And start etcd ressource on    master-0
    Then check master started in etcdctl list    master-0
    When add master to the etcd member list with etcdctl    master-1
    And start etcd ressource on    master-1
    Then check master started in etcdctl list    master-1
    and wait nodes are ready
    and delete etcd-backup job
    and wait pods ready
    [Teardown]    teardown etcdctl
