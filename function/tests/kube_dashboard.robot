*** Settings ***
Resource          ../cluster_helpers.robot
Resource          ../commands.robot
Resource          ../selenium.robot
Resource          ../setup_environment.robot

*** Keywords ***
kubernetes dashboard is deployed
    kubectl    apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml --wait
    wait deploy    kubernetes-dashboard -n kubernetes-dashboard
    ${node_port}    expose service    svc kubernetes-dashboard    8443    kubernetes-dashboard
    Set Test Variable    ${dashboard_url}    https://${BOOTSTRAP_MASTER_1}:${node_port}

fail to login authorized user without admin rights and list namespaces
    ${token_generic}    _get token for    kubernetes-dashboard    kubernetes-dashboard
    ${status}    selenium_kube_dashboard    ${token_generic}
    Should Be Equal    ${status}    False

create a service account for dashboard and grant access to kube-system namespace
    kubectl    create serviceaccount my-admin-user -n kube-system
    kubectl    create clusterrolebinding my-admin-user -n kube-system --clusterrole=cluster-admin --serviceaccount=kube-system:my-admin-user

_get token for
    [Arguments]    ${service_account}    ${namespace}=default
    ${serviceaccount}    kubectl    get serviceaccount ${service_account} -n ${namespace} -o jsonpath="{.secrets[0].name}"
    ${token_generic}    kubectl    get secret ${serviceaccount} -o jsonpath="{.data.token}" -n ${namespace} | base64 -d
    [Return]    ${token_generic}

login authorized user with admin rights and list namespaces
    ${token_generic}    _get token for    my-admin-user    kube-system
    log    ${token_generic}
    ${status}    selenium_kube_dashboard    ${token_generic}
    Should Be True    ${status}

teardown kube dashboard
    Run Keyword And Ignore Error    kubectl    delete serviceaccount my-admin-user -n kube-system
    Run Keyword And Ignore Error    kubectl    delete clusterrolebinding my-admin-user
    Run Keyword And Ignore Error    kubectl    delete -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml --wait
    Run Keyword And Ignore Error    kubectl    delete namespace kubernetes-dashboard
    [Teardown]    teardown_test
