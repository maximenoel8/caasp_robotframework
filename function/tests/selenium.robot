*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Library           ../../lib/firefox_profile.py
Library           SeleniumLibrary
Library           ../../lib/yaml_editor.py
Resource          ../../parameters/selenium.robot
Library           yaml
Resource          ../tools.robot

*** Keywords ***
selenium_download
    [Arguments]    ${source}    ${destination}
    ${selenium_pod}    wait podname    -l app=selenium
    kubectl    cp ${selenium_pod}:/home/seluser/Downloads/${source} ${destination}
    kubectl    exec ${selenium_pod} rm /home/seluser/Downloads/${source}

selenium_authentication
    [Arguments]    ${user}    ${password}=password    ${cluster_number}=1
    ${profile}    get_firefox_profile
    Open Browser    url=https://${IP_LB_${cluster_number}}:32001/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    Location Should Be    https://${IP_LB_${cluster_number}}:32001/
    Wait Until Element Is Enabled    download-button
    Click Element    download-button
    Wait Until Element Is Visible    login
    Input Text    login    ${user}
    Input Text    password    ${password}
    Click Element    submit-login
    Wait Until Element Is Visible    link:Download Kubeconfig
    Click Element    link:Download Kubeconfig
    [Teardown]    Close All Browsers

deploy selenium pod
    [Arguments]    ${cluster_number}=1
    step    deploying selenium pod
    _configure selenium deployment    ${cluster_number}
    _configure selenium service
    kubectl    apply -f ${LOGDIR}/selenium    ${cluster_number}
    wait deploy    selenium
    ${pod}    wait podname    -l app=selenium    ${cluster_number}
    Wait Until Keyword Succeeds    2min    10sec    _check selenium grid up    ${pod}

_check selenium grid up
    [Arguments]    ${selenium_node}
    ${ouput}    kubectl    logs ${selenium_node}
    Should Contain    ${ouput}    INFO [SeleniumServer.boot] - Selenium Server is up and running on port 4444

selenium_kube_dashboard
    [Arguments]    ${token}
    ${profile}    get_firefox_profile
    Set Selenium Timeout    30sec
    Open Browser    url=${dashboard_url}    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    Wait Until Element Is Visible    xpath://div[contains(text(),"Kubernetes Dashboard")]
    Click Element    xpath://div[@class="mat-radio-label-content" and contains(text(), "Token")]
    Wait Until Element Is Visible    token
    Input Text    token    ${token}
    Click Element    CSS:button[type=submit]
    Wait Until Element Is Visible    xpath://div[@class='kd-toolbar-tools']
    Click Element    xpath://div//a/span[@class="mat-button-wrapper" and contains(text(), "Namespaces ")]
    @{namespaces}    Get WebElements    //kd-namespace-list/kd-card//mat-row/mat-cell/a
    ${length}    Get Length    ${namespaces}
    Return From Keyword If    ${length} <= 2    False
    ${access_namespace}    Set Variable    True
    FOR    ${element}    IN    @{namespaces}
        ${namespace_name}    get text    ${element}
        log    ${namespace_name}
    END
    [Return]    ${access_namespace}

_configure selenium deployment
    [Arguments]    ${cluster_number}
    execute command localy    rm -rf ${LOGDIR}/selenium
    Copy Directory    ${DATADIR}/selenium    ${LOGDIR}
    ${status}    ${output}    Run Keyword And Ignore Error    Should Match Regexp    ${BOOTSTRAP_MASTER_1}    ^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$
    ${IP_bootstrap}    Run Keyword If    "${status}"=="FAIL"    resolv dns    ${BOOTSTRAP_MASTER_1}
    ...    ELSE    Set Variable    ${BOOTSTRAP_MASTER_1}
    ${service}    OperatingSystem.Get File    ${LOGDIR}/selenium/selenium-deployment.yaml
    ${service_dico}    yaml.Safe Load    ${service}
    Set To Dictionary    ${service_dico["spec"]["template"]["spec"]["hostAliases"][0]}    hostnames=${hostnames}
    Set To Dictionary    ${service_dico["spec"]["template"]["spec"]["hostAliases"][0]}    ip=${IP_bootstrap}
    ${output}    yaml.Dump    ${service_dico}
    Create File    ${LOGDIR}/selenium/selenium-deployment.yaml    ${output}

_configure selenium service
    ${service}    OperatingSystem.Get File    ${LOGDIR}/selenium/selenium-service.yaml
    ${service_dico}    yaml.Safe Load    ${service}
    Set To Dictionary    ${service_dico["spec"]["ports"][0]}    nodePort=${${node_port}}
    ${output}    yaml.Dump    ${service_dico}
    Create File    ${LOGDIR}/selenium/selenium-service.yaml    ${output}

selenium is deployed
    [Arguments]    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    get deploy selenium    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL"    deploy selenium pod    ${cluster_number}
    Set Global Variable    ${SELENIUM_URL}    http://${BOOTSTRAP_MASTER_${cluster_number}}:${node port}/wd/hub

get child webelements
    [Arguments]    ${webelement}    ${css_selector}
    ${child_element}    Call Method    ${webelement}    find_elements_by_css_selector    ${css_selector}
    [Return]    ${child_element}
