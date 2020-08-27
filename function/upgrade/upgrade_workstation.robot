*** Settings ***
Resource          ../commands.robot
Resource          ../reboot.robot
Resource          ../skuba_tool_install.robot
Resource          upgrade_nodes.robot
Resource          ../terraform_files_change.robot

*** Keywords ***
_upgrade skuba from skuba repo
    _delete current skuba
    build skuba from repo    ${UPGRADE-COMMIT}    skuba_upgrade

upgrade workstation
    [Arguments]    ${cluster_number}
    refresh ssh session
    step    upgrade the worksation ...
    Run Keyword If    '${RPM}'!='${EMPTY}'    add repo from incident and update    ${cluster_number}
    Run Keyword If    "${MODE}"=="${EMPTY}" and '${RPM}'!='${EMPTY}' and '${REGISTRY}'!='${EMPTY}'    check diff from current terraform files with updated workstation
    Run Keyword If    '${RPM}'!='${EMPTY}'    add repo to nodes    ${cluster_number}
    Run Keyword If    '${REGISTRY}'!='${EMPTY}'    add container repo file to nodes    ${cluster_number}
    Comment    _enable update package
    Comment    _upgrade skuba from skuba repo
    update package on workstation
    step    ... upgrade done for workstation

_delete current skuba
    ${path}    execute command with ssh    which skuba    skuba_station_${cluster_number}
    execute command with ssh    sudo rm ${path}    skuba_station_${cluster_number}

_check reboot needed
    [Arguments]    ${output}
    ${result}    Get Lines Containing String    ${output}    System reboot required
    ${length}    Get Length    ${result}
    ${status}    Set Variable If    ${length}==0    False    True
    [Return]    ${status}

update workstation

update package on workstation
    [Arguments]    ${args}=${EMPTY}    ${cluster_number}=1
    ${output}    execute command with ssh    sudo zypper -n update ${args}    skuba_station_${cluster_number}
    ${reboot_needed}    _check reboot needed    ${output}
    Run Keyword If    ${reboot_needed}    reboot or shutdown server    ${WORKSTATION_${cluster_number}}
    Run Keyword If    ${reboot_needed}    wait server up    ${WORKSTATION_${cluster_number}}
    Run Keyword If    ${reboot_needed}    refresh ssh session    ${cluster_number}

_enable update package
    execute command with ssh    sudo zypper mr -e SUSE-CAASP-4.0-Updates
