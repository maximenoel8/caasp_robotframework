*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/helm.robot
Resource          ../function/rbac.robot

*** Test Cases ***
389ds authentication
    [Setup]    set 389ds variables
    Given cluster running
    And helm install
    And 389ds server installed
    And users has been added to ldap
    And dex is configured
    Then authentication with skuba CI (group)
    Then authentication with skuba CI (users)
