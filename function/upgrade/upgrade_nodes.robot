*** Settings ***
Resource          ../commands.robot
Resource          ../skuba_tool_install.robot
Library           SSHLibrary

*** Keywords ***
add repo to nodes
    [Arguments]    ${cluster_number}
    Get Connections
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        _add repo from incident on    ${node}
    END

migrate node from SP1 to SP2
    [Arguments]    ${node}
    step    Upgrade ${node} from SP1 to SP2 ...
    Comment    run commands on node    ${node}    sudo SUSEConnect --cleanup    sudo SUSEConnect -r INTERNAL-USE-ONLY-2bc2-45b7    sudo SUSEConnect -p sle-module-basesystem/15.1/x86_64    sudo SUSEConnect -p sle-module-containers/15.1/x86_64    sudo SUSEConnect -p caasp/4.0/x86_64 -r INTERNAL-USE-ONLY-f9c5-17d1
    run commands on node    ${node}    sudo zypper -n install zypper-migration-plugin    sudo zypper migration -nl --allow-vendor-change --replacefiles
    ${ip}    get node ip from CS    ${node}
    step    ${node} upgraded to SP2, wait for reboot ...
    reboot and wait server up    ${ip}

migrate cluster from SP1 to SP2
    [Arguments]    ${cluster_number}=1
    Comment    migrate node from SP1 to SP2    skuba_station_${cluster_number}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        migrate node from SP1 to SP2    ${node}
    END
    refresh ssh session
