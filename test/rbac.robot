*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/helm.robot
Resource          ../function/rbac.robot

*** Test Cases ***
389ds authentication
    Given cluster running
    And helm install
    And 389ds server is deployed
    And users has been added to    389ds
    And dex is configured for    389ds
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean 389ds server

openldap authentication
    Given cluster running
    And helm install
    And openldap server is deployed
    And users has been added to    openldap
    And dex is configured for    openldap
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    clean up openldap

static password authentication
    Given cluster running
    And dex is configured for    static password
    Then authentication with skuba CI (users)
    Then authentication with WebUI user
    [Teardown]    _restore_dex_after_static_password
