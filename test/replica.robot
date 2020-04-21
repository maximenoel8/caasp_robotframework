*** Settings ***
Resource          ../function/skuba_commands.robot
Resource          ../function/reboot.robot

*** Test Cases ***
dex_gangway_replicat
    Given cluster running
    Then replica dex and gangway are correctly distribued
    Then remove node    ${CLUSTER_PREFIX}-worker-2
    Then replica dex and gangway are correctly distribued
    Comment    Then remove node    ${CLUSTER_PREFIX}-worker-1    shutdown_first=True
    Then remove node    ${CLUSTER_PREFIX}-worker-1
    Then replica dex and gangway are correctly distribued
    Then reboot worker 0 and master 0 and wait server up
    Then replica dex and gangway are correctly distribued
    Then join    ${CLUSTER_PREFIX}-worker-2    after_remove=True
    Then replica dex and gangway are correctly distribued
    Then join    ${CLUSTER_PREFIX}-worker-1    after_remove=True
    Then replica dex and gangway are correctly distribued
