*** Settings ***
Resource          ../function/cluster_helpers.robot
Resource          ../function/helm.robot
Resource          ../parameters/global_parameters.robot
Resource          ../function/tools.robot
Resource          ../parameters/tool_parameters.robot
Resource          ../function/setup_environment.robot
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/monitoring/grafana_dashboard.robot
Resource          ../function/tests/selenium.robot
Resource          ../function/tests/nginx.robot
Resource          ../function/tests/backup_and_restore/wordpress.robot
Resource          ../function/tests/load_test.robot
Resource          ../function/terraform_files_change.robot
Resource          ../function/airgaped/container_registry.robot
Resource          ../function/tests/backup_and_restore/etcdctl.robot
Resource          ../function/tests/backup_and_restore/bNr_helpers.robot
Resource          ../function/airgaped/common_airgaped.robot

*** Test Cases ***
deploy cluster
    [Tags]    upgrade    release    backup    join
    Given cluster running
    And helm is installed
    [Teardown]    teardown deploy

deploy double cluster
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL"    deploy cluster vms
    load vm ip
    create ssh session with workstation and nodes
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    install skuba
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    cluster is deployed
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait nodes are ready
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait pods ready
    Run Keyword If    "${CLUSTER_STATUS}" == "FAIL"    wait cillium
    wait nodes are ready    cluster_number=2
    wait pods ready    cluster_number=2
    wait cillium    cluster_number=2

deploy bare server
    [Tags]    bare
    ${cluster_number}    Set Variable    1
    set infra env parameters
    Run Keyword If    "${PLATFORM_DEPLOY}" == "FAIL" and ${cluster_number}==1    deploy cluster vms
    load vm ip

airgapped offline server
    load vm ip
    create ssh session with workstation and nodes
    generate certificates
    install mirror server
    populate rmt and docker repo offline for    http://download.suse.de/ibs/SUSE:/Maintenance:/15196/SUSE_Updates_SUSE-CAASP_4.0_x86_64/

airgapped online server
    load vm ip
    create ssh session with workstation and nodes
    generate certificates
    install mirror server
    enable customize rpm    http://download.suse.de/ibs/SUSE:/Maintenance:/15196/SUSE_Updates_SUSE-CAASP_4.0_x86_64/
    sync and mirror online
    export rpm repository
    copy docker images with skopeo    official=False    custom_filter=15196
    backup docker images

load ip
    load vm ip

*** Keywords ***
teardown deploy
    Run Keyword If Test Failed    Fatal Error
    [Teardown]    teardown_test
