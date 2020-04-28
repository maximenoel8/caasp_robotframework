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
