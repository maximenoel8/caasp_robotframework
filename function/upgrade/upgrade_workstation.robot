*** Settings ***
Resource          ../commands.robot
Resource          ../reboot.robot
Resource          ../skuba_tool_install.robot

*** Keywords ***
_upgrade skuba from skuba repo
    _delete current skuba
    build skuba from repo    ${UPGRADE-COMMIT}    skuba_upgrade

upgrade workstation
    _enable update package
    Comment    _upgrade skuba from skuba repo
    update package on workstation

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
    reinitialize skuba session    ${cluster_number}

_enable update package
    execute command with ssh    sudo zypper mr -e SUSE-CAASP-4.0-Updates
