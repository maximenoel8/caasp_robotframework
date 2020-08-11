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

get cluster number
    [Arguments]    ${cluster}
    ${out}    Split String    ${cluster}    _
    ${cluster_number}    Set Variable    ${out[-1]}
    [Return]    ${cluster_number}

run commands on nodes
    [Arguments]    ${cluster_number}=1    @{cmd}
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        run commands on node    ${node}    @{cmd}
    END

open yaml file
    [Arguments]    ${yaml_file}
    ${output}    OperatingSystem.Get File    ${yaml_file}
    @{lines}    Split To Lines    ${output}
    ${dico}    Create Dictionary
    ${data}    Set Variable
    FOR    ${line}    IN    @{lines}
        ${status_comment}    ${_}    Run Keyword And Ignore Error    Should Not Start With    ${line}    \#
        ${status_data}    ${_}    Run Keyword And Ignore Error    Should Not Be Empty    ${data}
        ${status_seperate_ line}    ${_}    Run Keyword And Ignore Error    Should Be Equal    ${line}    ---
        Continue For Loop If    "${status_comment}"=="FAIL"
        ${dico}    Run Keyword if    "${status_seperate_ line}"=="PASS" and "${status_data}"=="PASS"    create sub yaml dico    ${dico}    ${data}
        ...    ELSE    Set Variable    ${dico}
        ${data}    Set Variable if    "${status_seperate_ line}"=="PASS"    ${EMPTY}    ${data}\n${line}
    END
    ${keys}    Collections.Get Dictionary Keys    ${dico}
    ${lt}    Get Length    ${keys}
    ${dico}    Run Keyword If    ${lt}==0    Safe Load    ${output}
    ...    ELSE    Set Variable    ${dico}
    [Return]    ${dico}

create sub yaml dico
    [Arguments]    ${dico}    ${data}
    ${tmp_dico}    Safe Load    ${data}
    Set To Dictionary    ${dico}    ${tmp_dico["kind"]}=${tmp_dico}
    [Return]    ${dico}

write yaml file
    [Arguments]    ${path}    ${dico}    ${separate}=False
    ${keys}    Get Dictionary Keys    ${dico}
    ${data}    Set Variable
    ${separate_line}    Set Variable    ---
    FOR    ${key}    IN    @{keys}
        ${output}    Dump    ${dico["${key}"]}
        ${data}    Set Variable    ${data}${separate_line}\n${output}
    END
    Create File    ${path}    ${data}

run commands on node
    [Arguments]    ${node}    @{cmd}
    FOR    ${command}    IN    @{cmd}
        execute command with ssh    ${command}    ${node}
    END
