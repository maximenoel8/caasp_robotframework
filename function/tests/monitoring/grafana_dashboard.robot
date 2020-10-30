*** Settings ***
Resource          ../selenium.robot

*** Variables ***
${kubernetes_etcd_certs_grafana_panels_webelemt}    ${EMPTY}
${kubeconfig_certs_grafana_panels_webelemt}    ${EMPTY}
${secret_certs_grafana_panels_webelemt}    ${EMPTY}
${exp_7d_grafana_panels_webelement}    ${EMPTY}
${exp_7dT30d_grafana_panels_webelement}    ${EMPTY}
${exp_30d_grafana_panels_webelement}    ${EMPTY}
${expected_panels_number}    6
@{expected_title}    Expiration within 1 month    Expiration within 1 and 3 months    Expiration after 3 months    Kubernetes and ETCD PKI Certs Expiry    Kubeconfig Certs Expiry    Secret PKI Certs Expiry
&{expected_data_full}

*** Keywords ***
selenium_grafana
    [Arguments]    ${cluster_number}=1
    step    checking grafana dashboard connexion
    ${profile}    get_firefox_profile
    Open Browser    url=https://grafana.example.com:32443    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    SeleniumLibrary.Location Should Be    https://grafana.example.com:32443/login
    Wait Until Element Is Visible    user
    Input Text    user    admin
    Input Text    password    linux
    Click Element    CSS:button[aria-label="Login button"]
    Wait Until Page Contains    Welcome to Grafana
    access certificate dashboard    ${cluster_number}

selenium_prometheus
    [Arguments]    ${cluster_number}=1
    ${profile}    get_firefox_profile
    Open Browser    url=https://admin:password@prometheus.example.com:32443    browser=headlessfirefox    remote_url=${SELENIUM_URL}    ff_profile_dir=${profile}
    ${location}    Get Location
    Wait Until Location Contains    prometheus.example.com:32443/graph    20
    Wait Until Page Contains    Prometheus
    [Teardown]    Close All Browsers

access certificate dashboard
    [Arguments]    ${cluster_number}=1
    step    checking certificates dashboard
    Go To    url=https://grafana.example.com:32443/dashboards
    Click Element    xpath://span[text()="SUSE CaaS Platform Certificates"]
    Comment    @{grafana_panels_webelements}    Get WebElements    css:grafana-panel
    @{grafana_panels_webelements}    Get WebElements    css:.panel-wrapper
    ${grafana_panels_length}    Get Length    ${grafana_panels_webelements}
    Should Be Equal As Integers    ${grafana_panels_length}    ${expected_panels_number}
    FOR    ${grafana_panel_element}    IN    @{grafana_panels_webelements}
        ${panel_element}    get child webelements    ${grafana_panel_element}    .panel-container .panel-title-container .panel-title-text
        ${panel_title}    Get Text    ${panel_element[0]}
        ${kubernetes_etcd_certs_grafana_panels_webelemt}    Set Variable If    "${panel_title}"=="Kubernetes and ETCD PKI Certs Expiry"    ${grafana_panel_element}    ${kubernetes_etcd_certs_grafana_panels_webelemt}
        ${kubeconfig_certs_grafana_panels_webelemt}    Set Variable If    "${panel_title}"=="Kubeconfig Certs Expiry"    ${grafana_panel_element}    ${kubeconfig_certs_grafana_panels_webelemt}
        ${secret_certs_grafana_panels_webelemt}    Set Variable If    "${panel_title}"=="Secret PKI Certs Expiry"    ${grafana_panel_element}    ${secret_certs_grafana_panels_webelemt}
        ${exp_7d_grafana_panels_webelement}    Set Variable If    "${panel_title}"=="Expiration within 1 month"    ${grafana_panel_element}    ${exp_7d_grafana_panels_webelement}
        ${exp_7dT30d_grafana_panels_webelement}    Set Variable If    "${panel_title}"=="Expiration within 1 and 3 months"    ${grafana_panel_element}    ${exp_7dT30d_grafana_panels_webelement}
        ${exp_30d_grafana_panels_webelement}    Set Variable If    "${panel_title}"=="Expiration after 3 months"    ${grafana_panel_element}    ${exp_30d_grafana_panels_webelement}
        Should Contain Any    ${panel_title}    @{expected_title}
    END
    ${node_number}    get number of nodes    ${cluster_number}
    ${master_number}    get number of nodes    ${cluster_number}    master
    _test kubernetes and etcd pki certs expiry panel    ${kubernetes_etcd_certs_grafana_panels_webelemt}    ${node_number}    ${master_number}
    _test kubeconfig certs expiry panel    ${kubeconfig_certs_grafana_panels_webelemt}    ${node_number}    ${master_number}
    _test secret pki certs expiry panel    ${secret_certs_grafana_panels_webelemt}    ${node_number}    ${master_number}
    _test expiration within 1 month panel    ${exp_7d_grafana_panels_webelement}    ${node_number}    ${master_number}
    _test expiration within 1 to 3 months panel    ${exp_7dT30d_grafana_panels_webelement}    ${node_number}    ${master_number}
    _test expiration after 3 months panel    ${exp_30d_grafana_panels_webelement}    ${node_number}    ${master_number}

_test expiration within 1 month panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    ${certificate_number}    get child webelements    ${panel_webelement}    .singlestat-panel-value-container span
    ${certificate_number_text}    Get Text    ${certificate_number[0]}
    Should Be Equal As Integers    ${certificate_number_text}    0

_test expiration within 1 to 3 months panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    ${certificate_number}    get child webelements    ${panel_webelement}    .singlestat-panel-value-container span
    ${certificate_number_text}    Get Text    ${certificate_number[0]}
    Should Be Equal As Integers    ${certificate_number_text}    0

_test expiration after 3 months panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    ${certificate_number}    get child webelements    ${panel_webelement}    .singlestat-panel-value-container span
    ${expected_number}    Evaluate    15 * ${master_number} + 6 * ${node_number} + 6 - ${expected_data_full["certificate_remove"]}
    ${certificate_number_text}    Get Text    ${certificate_number[0]}
    Should Not Be Equal As Integers    ${certificate_number_text}    0
    Should Be Equal As Integers    ${certificate_number_text}    ${expected_number}

_test kubernetes and etcd pki certs expiry panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    @{raws}    get child webelements    ${panel_webelement}    tbody tr
    ${raw_number}    Get Length    ${raws}
    ${expected_etcd_certificates_number}    Evaluate    4 * ${node_number} + 9 * \ ${master_number}
    Should Be Equal As Integers    ${raw_number}    ${expected_etcd_certificates_number}
    FOR    ${element}    IN    @{raws}
        _check expiration value for kubernetes and etcd panel    ${element}
    END

_test kubeconfig certs expiry panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    @{raws}    get child webelements    ${panel_webelement}    tbody tr
    ${raw_number}    Get Length    ${raws}
    ${expected_etcd_certificates_number}    Evaluate    2 * ${node_number} + 6 * ${master_number}
    Should Be Equal As Integers    ${raw_number}    ${expected_etcd_certificates_number}
    FOR    ${element}    IN    @{raws}
        _check value for kubeconfig    ${element}
    END

_test secret pki certs expiry panel
    [Arguments]    ${panel_webelement}    ${node_number}    ${master_number}
    @{raws}    get child webelements    ${panel_webelement}    tbody tr
    FOR    ${element}    IN    @{raws}
        _check value from json secrets    ${element}
    END

_check expiration value for kubernetes and etcd panel
    [Arguments]    ${raw}
    @{columns}    get child webelements    ${raw}    td
    ${lt}    Get Length    ${columns}
    Should Be Equal As Integers    ${lt}    5
    ${cn}    Get Text    ${columns[0]}
    @{known_cns}    Get Dictionary Keys    ${expected_data_full["kubernetes"]}
    Remove Values From List    ${known_cns}    master    worker
    ${status}    ${_}    Run Keyword And Ignore Error    Should Contain Any    ${cn}    @{known_cns}
    Run Keyword If    "${status}"=="FAIL"    _check value from json kubernetes and etcd for node cn    ${columns}
    Run Keyword If    "${status}"=="PASS"    _check value from json kubernetes and etcd    ${columns}

_check value from json kubernetes and etcd
    [Arguments]    ${values}
    ${cn}    Get Text    ${values[0]}
    ${sub_dico}    Set Variable    ${expected_data_full["kubernetes"]["${cn}"]}
    ${filename}    Get Text    ${values[1]}
    ${filename}    Split To Lines    ${filename}
    Should Be Equal    ${sub_dico["filename"]}    ${filename[0]}
    ${issuer}    Get Text    ${values[2]}
    Should Be Equal    ${sub_dico["issuer"]}    ${issuer}
    ${expiration}    Get Text    ${values[4]}
    Should Be Equal    ${sub_dico["expiration"]}    ${expiration}

_check value from json kubernetes and etcd for node cn
    [Arguments]    ${values}
    ${cn_value}    Get Text    ${values[0]}
    ${cn}    Split String    ${cn_value}    :
    ${lt}    Get Length    ${cn}
    ${node}    Set Variable If    ${lt}==1    ${cn[0]}    ${cn[2]}
    ${type}    get node type from skuba name    ${node}
    ${sub_dico}    Set Variable    ${expected_data_full["kubernetes"]["${type}"]}
    ${filename}    Get Text    ${values[1]}
    Should Contain Any    ${filename}    @{sub_dico["filename"]}
    ${issuer}    Get Text    ${values[2]}
    Should Contain Any    ${issuer}    @{sub_dico["issuer"]}
    ${expiration}    Get Text    ${values[4]}
    Should Be Equal    ${sub_dico["expiration"]}    ${expiration}

_check value for kubeconfig
    [Arguments]    ${raw}
    @{columns}    get child webelements    ${raw}    td
    ${lt}    Get Length    ${columns}
    Should Be Equal As Integers    ${lt}    4
    ${filename}    Get Text    ${columns[0]}
    ${nodename}    Get Text    ${columns[1]}
    ${cert_type}    Get Text    ${columns[2]}
    ${status}    ${output}    Run Keyword And Ignore Error    Element Should Be Visible    ${columns[3]}
    Return From Keyword If    "${status}"=="FAIL"
    ${expiration}    Get Text    ${columns[3]}
    ${type}    get node type from skuba name    ${nodename}
    Element Should Contain    ${columns[3]}    ${expected_data_full["kubeconfig"]["${type}"]["${cert_type}"]["expiration"]}
    Should Contain Any    ${filename}    @{expected_data_full["kubeconfig"]["${type}"]["${cert_type}"]["filename"]}
    Should Be Equal    ${expiration}    ${expected_data_full["kubeconfig"]["${type}"]["${cert_type}"]["expiration"]}

_check value from json secrets
    [Arguments]    ${raw}
    ${values}    get child webelements    ${raw}    td
    ${cn}    Get Text    ${values[0]}
    ${issuer}    Get Text    ${values[1]}
    ${keyname}    Get Text    ${values[2]}
    ${secretname}    Get Text    ${values[3]}
    ${secretnamespace}    Get Text    ${values[4]}
    ${expiration}    Get Text    ${values[5]}
    ${sub_dico}    Set Variable    ${expected_data_full["secret"]}
    Should Be Equal    ${sub_dico["issuer"]}    ${issuer}
    Should Be Equal    ${sub_dico["secret_namespace"]}    ${secretnamespace}
    Should Be Equal    ${sub_dico["${secretname}"]["${keyname}"]["cn"]}    ${cn}
    Should Be Equal    ${sub_dico["${secretname}"]["${keyname}"]["expiration"]}    ${expiration}

_modify expired date for secret
    [Arguments]    ${secretname}    ${keyname}    ${expiration}
    Log Dictionary    ${expected_data_full}
    Set To Dictionary    ${expected_data_full["secret"]["${secretname}"]["${keyname}"]}    expiration    ${expiration}
    ${certificate_to_remove}    Evaluate    ${expected_data_full["certificate_remove"]} +1
    Set To Dictionary    ${expected_data_full}    certificate_remove    ${${certificate_to_remove}}
