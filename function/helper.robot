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
    [Arguments]    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_${VM_VERSION}/SUSE:CA.repo    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ref    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper -n in ca-certificates-suse    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo update-ca-certificates    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo systemctl restart crio    ${node}

add CA to all server
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        add CA to server    ${node}
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

add CA certificate to vm
    [Arguments]    ${service}    ${node}
    Switch Connection    ${node}
    Put File    ${LOGDIR}/certificate/${service}/ca.crt    /home/${VM_USER}/
    execute command with ssh    sudo cp /home/${VM_USER}/ca.crt /etc/pki/trust/anchors/    ${node}
    execute command with ssh    sudo update-ca-certificates

add ${service} certificate to nodes
    @{nodes}    get nodes name from CS
    add CA certificate to vm    ${service}    skuba_station_1
    FOR    ${node}    IN    @{nodes}
        add CA certificate to vm    ${service}    ${node}
    END
