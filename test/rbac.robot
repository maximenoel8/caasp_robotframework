*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/rbac.robot

*** Test Cases ***
389ds authentication
    [Tags]    release
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
    Given cluster running
    And dex is configured for    static password
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean static password

389ds authentication using oidc customize certificates
    Set Test Variable    ${issuer_CN}    customize-kubernetes-ca
    Given cluster running
    And helm is installed
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds
    And create CA    ${issuer_CN}
    When modify tls secret to    oidc-dex    ca=True    ca_crt=${LOGDIR}/certificate/${issuer_CN}/ca.crt    ca_key=${LOGDIR}/certificate/${issuer_CN}/ca.key
    When modify tls secret to    oidc-gangway    ca=True    ca_crt=${LOGDIR}/certificate/${issuer_CN}/ca.crt    ca_key=${LOGDIR}/certificate/${issuer_CN}/ca.key
    add ${issuer_CN} certificate to nodes
    When modify tls secret to    oidc-dex    ca=True
    When modify tls secret to    oidc-gangway    ca=True
    And addon oidc-dex certificate is signed by ${issuer_CN} on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt
    And addon oidc-ganway certificate is signed by ${issuer_CN} on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt
    And updates kubeadm-config ConfigMap
    Then authentication with skuba CI (group)    False
    Then authentication with skuba CI (users)    False
    Then authentication with WebUI user
    [Teardown]    clean 389ds server
