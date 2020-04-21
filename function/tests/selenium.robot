*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Library           ../../lib/firefox_profile.py
Library           SeleniumLibrary

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
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    get deploy selenium
    Run Keyword If    "${status}"=="FAIL"    kubectl    create deployment selenium --image=selenium/standalone-firefox:3.141.59-xenon
    Run Keyword If    "${status}"=="FAIL"    kubectl    expose deployment selenium --port=4444 --type=NodePort
    Run Keyword If    "${status}"=="FAIL"    wait deploy    selenium
    ${pod}    wait podname    -l app=selenium
    Wait Until Keyword Succeeds    2min    10sec    _check selenium grid up    ${pod}
    ${node port}    kubectl    get svc/selenium -o json | jq '.spec.ports[0].nodePort'
    Set Global Variable    ${SELENIUM_URL}    http://${BOOTSTRAP_MASTER_${cluster_number}}:${node port}/wd/hub

selenium_grafana
    [Arguments]    ${cluster_number}=1
    ${profile}    get_firefox_profile
    Open Browser    url=http://${BOOTSTRAP_MASTER_${cluster_number}}:${grafanaPort}/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    SeleniumLibrary.Location Should Be    http://${BOOTSTRAP_MASTER_${cluster_number}}:${grafanaPort}/login
    Wait Until Element Is Visible    username
    Input Text    username    admin
    Input Text    password    linux
    Click Element    CSS:button[type=submit]
    Wait Until Page Contains    Home Dashboard
    [Teardown]    Close All Browsers

selenium_prometheus
    [Arguments]    ${cluster_number}=1
    ${profile}    get_firefox_profile
    Open Browser    url=http://${BOOTSTRAP_MASTER_${cluster_number}}:${prometheus_port}/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    SeleniumLibrary.Location Should Be    http://${BOOTSTRAP_MASTER_${cluster_number}}:${prometheus_port}/
    Wait Until Page Contains    Metrics
    [Teardown]    Close All Browsers

_check selenium grid up
    [Arguments]    ${selenium_node}
    ${ouput}    kubectl    logs ${selenium_node}
    Should Contain    ${ouput}    INFO [SeleniumServer.boot] - Selenium Server is up and running on port 4444

selenium_kube_dashboard
    [Arguments]    ${token}
    ${profile}    get_firefox_profile
    Wait Until Keyword Succeeds    30sec    5sec    Open Browser    url=${dashboard_url}    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
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
