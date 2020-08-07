*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/rbac.robot

*** Test Cases ***
389ds authentication with oidc customize day1
    Pass Execution If    "${OIDC_CERT}" == "None"    OIDC was not set day1
    Given cluster running
    Set Test Variable    ${issuer_CN}    oidc-ca
    And addon oidc-dex certificate is signed by ${issuer_CN} on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/${issuer_CN}/oidc-ca.crt
    And addon oidc-ganway certificate is signed by ${issuer_CN} on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/${issuer_CN}/oidc-ca.crt
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds
    Then authentication with skuba CI (users)    ${issuer_CN}
    [Teardown]    clean 389ds server

389ds authentication
    [Tags]    release
    Pass Execution If    "${OIDC_CERT}" != "None"    Using oidc customize
    Given cluster running
    And helm is installed
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean 389ds server

openldap authentication
    [Tags]    release
    Pass Execution If    "${OIDC_CERT}" != "None"    Using oidc customize
    Given cluster running
    And helm is installed
    And openldap server is deployed
    And users has been added to    openldap
    And dex is configured for    openldap
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean up openldap

389ds authentication with dex configure using kustomize
    Pass Execution If    "${OIDC_CERT}" != "None"    Using oidc customize
    Given cluster running
    And helm is installed
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds    patch=True
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean 389ds server

static password authentication
    [Tags]    release
    Pass Execution If    "${OIDC_CERT}" != "None"    Using oidc customize
    Given cluster running
    And dex is configured for    static password
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean static password

389ds authentication using oidc customize certificates
    Pass Execution If    "${OIDC_CERT}" != "None"    Using oidc customize
    Set Test Variable    ${issuer_CN}    customize-kubernetes-ca
    Set Test Variable    ${file_name}    oidc-ca
    Given cluster running
    And helm is installed
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds
    And create CA    ${issuer_CN}    file_name=${file_name}
    When modify tls secret to    oidc-dex    ca=True    ca_crt=${LOGDIR}/certificate/${issuer_CN}/${file_name}.crt    ca_key=${LOGDIR}/certificate/${issuer_CN}/${file_name}.key
    When modify tls secret to    oidc-gangway    ca=True    ca_crt=${LOGDIR}/certificate/${issuer_CN}/${file_name}.crt    ca_key=${LOGDIR}/certificate/${issuer_CN}/${file_name}.key
    add certificate to nodes    ${issuer_CN}     ${file_name}
    And addon oidc-dex certificate is signed by ${issuer_CN} on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/${issuer_CN}/${file_name}.crt
    And addon oidc-ganway certificate is signed by ${issuer_CN} on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/${issuer_CN}/${file_name}.crt
    And updates kubeadm-config ConfigMap
    Then authentication with skuba CI (group)    customize=${issuer_CN}    file_name=${file_name}
    Then authentication with skuba CI (users)    customize=${issuer_CN}    file_name=${file_name}
    Comment    Then authentication with WebUI user
    [Teardown]    clean 389ds server
