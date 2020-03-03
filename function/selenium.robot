*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot
Library           ../lib/firefox_profile.py
Library           SeleniumLibrary

*** Keywords ***
selenium_download
    [Arguments]    ${source}    ${destination}
    ${selenium_pod}    wait podname    -l app=selenium
    kubectl    cp ${selenium_pod}:/home/seluser/Downloads/${source} ${destination}
    kubectl    exec ${selenium_pod} rm /home/seluser/Downloads/${source}

selenium_authentication
    [Arguments]    ${user}    ${password}=password
    ${profile}    get_firefox_profile
    Open Browser    url=https://${IP_LB}:32001/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    Location Should Be    https://${IP_LB}:32001/
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
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    get deploy selenium
    Run Keyword If    "${status}"=="FAIL"    kubectl    create deployment selenium --image=selenium/standalone-firefox:3.141.59-xenon
    Run Keyword If    "${status}"=="FAIL"    kubectl    expose deployment selenium --port=4444 --type=NodePort
    Run Keyword If    "${status}"=="FAIL"    wait deploy    selenium
    ${node port}    kubectl    get svc/selenium -o json | jq '.spec.ports[0].nodePort'
    Set Global Variable    ${SELENIUM_URL}    http://${BOOSTRAP_MASTER}:${node port}/wd/hub

selenium_grafana
    ${profile}    get_firefox_profile
    Open Browser    url=http://${BOOSTRAP_MASTER}:${grafanaPort}/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    SeleniumLibrary.Location Should Be    http://${BOOSTRAP_MASTER}:${grafanaPort}/login
    Wait Until Element Is Visible    username
    Input Text    username    admin
    Input Text    password    linux
    Click Element    CSS:button[type=submit]
    Wait Until Page Contains    Home Dashboard

selenium_prometheus
    ${profile}    get_firefox_profile
    Open Browser    url=http://${BOOSTRAP_MASTER}:${prometheus_port}/    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    SeleniumLibrary.Location Should Be    http://${BOOSTRAP_MASTER}:${prometheus_port}
    Wait Until Page Contains    Metrics
