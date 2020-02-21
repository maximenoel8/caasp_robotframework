*** Settings ***
Resource          ../function/skuba_join.robot

*** Test Cases ***
dex_gangway_replicat
    Given cluster running
    Then replica dex and gangway are correctly distribued
    Then remove node    ${SUFFIX}-${CLUSTER}-worker-2
    Then replica dex and gangway are correctly distribued
    Then remove node    ${SUFFIX}-${CLUSTER}-worker-1
    Then replica dex and gangway are correctly distribued
    Then join    ${SUFFIX}-${CLUSTER}-worker-1
    Then replica dex and gangway are correctly distribued
    Then join    ${SUFFIX}-${CLUSTER}-worker-2
    Then replica dex and gangway are correctly distribued
