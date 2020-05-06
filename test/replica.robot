*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/skuba_commands.robot

*** Test Cases ***
dex_gangway_replicat
    [Tags]    release
    Given cluster running
    Then replica dex and gangway are correctly distribued
    Then remove node    ${CLUSTER_PREFIX}-1-worker-2
    Then replica dex and gangway are correctly distribued
    Comment    Then remove node    ${CLUSTER_PREFIX}-worker-1    shutdown_first=True
    Then remove node    ${CLUSTER_PREFIX}-1-worker-1
    Then replica dex and gangway are correctly distribued
    Then reboot worker 0 and master 0 and wait server up
    Then replica dex and gangway are correctly distribued
    Then join node    ${CLUSTER_PREFIX}-1-worker-2    after_remove=True
    Then replica dex and gangway are correctly distribued
    Then join node    ${CLUSTER_PREFIX}-1-worker-1    after_remove=True
    Then replica dex and gangway are correctly distribued
