*** Settings ***
Library           String
Library           OperatingSystem
Resource          commands.robot
Library           yaml

*** Keywords ***
remove string from file
    [Arguments]    ${file}    ${string}
    ${contents}=    OperatingSystem.Get File    ${file}
    Remove File    ${file}
    Create File    ${file}
    @{lines}    Split To Lines    ${contents}
    FOR    ${line}    IN    @{lines}
        ${new_line}    String.Remove String    ${line}    ${string}
        Append To File    ${file}    ${new_line}\n
    END

add devel repo
    [Arguments]    ${alias}
    execute command with ssh    sudo zypper ar -C -G -f http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_${VM_VERSION}/ caasp_devel    ${alias}

modify string in file
    [Arguments]    ${file}    ${se}    ${re}
    ${contents}=    OperatingSystem.Get File    ${file}
    Remove File    ${file}
    Create File    ${file}
    @{lines}    Split To Lines    ${contents}
    FOR    ${line}    IN    @{lines}
        ${new_line}    String.Replace String    ${line}    ${se}    ${re}
        Append To File    ${file}    ${new_line}\n
    END

screenshot cluster status
    [Arguments]    ${cluster_number}=1
    Run Keyword And Ignore Error    kubectl    get pods -A    screenshot=True    cluster_number=${cluster_number}
    Run Keyword And Ignore Error    kubectl    get svc -A    screenshot=True    cluster_number=${cluster_number}
    Run Keyword And Ignore Error    kubectl    get pvc -A    screenshot=True    cluster_number=${cluster_number}
    Run Keyword And Ignore Error    kubectl    get pv    screenshot=True    cluster_number=${cluster_number}

check string contain
    [Arguments]    ${string}    ${contain}
    ${status_cmd}    ${outptu}    Run Keyword And Ignore Error    Should Contain    ${string}    ${contain}
    ${status}    Set Variable If    "${status_cmd}"=="PASS"    True    False
    [Return]    ${status}

add CA to server
    [Arguments]    ${ip}
    open ssh session    ${ip}    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_${VM_VERSION}/SUSE:CA.repo    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ref    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper -n in ca-certificates-suse    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo update-ca-certificates    tempo
    Run Keyword And Ignore Error    execute command with ssh    sudo systemctl restart crio    tempo
    [Teardown]    Close Connection

add CA to all server
    [Arguments]    ${cluster_number}=1
    @{masters}    Collections.Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["master"]}
    @{workers}    Collections.Get Dictionary Keys    ${cluster_state["cluster_${cluster_number}"]["worker"]}
    @{nodes}    Combine Lists    ${masters}    ${workers}
    FOR    ${node}    IN    @{nodes}
        ${ip}    get node ip from CS    ${node}    ${cluster_number}
        add CA to server    ${ip}
    END

get cluster number
    [Arguments]    ${cluster}
    ${out}    Split String    ${cluster}    _
    ${cluster_number}    Set Variable    ${out[-1]}
    [Return]    ${cluster_number}

run command on nodes
    [Arguments]    ${cmd}    ${cluster_number}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        execute command with ssh    ${cmd}    ${node}
    END

open yaml file
    [Arguments]    ${yaml_file}
    ${output}    OperatingSystem.Get File    ${yaml_file}
    ${dico}    Safe Load    ${output}
    [Return]    ${dico}
