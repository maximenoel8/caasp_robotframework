*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/tests/pod_security_checks.robot

*** Test Cases ***
nginx can not be deployed with hostNetwork enable
    [Tags]    release
    Given cluster running
    And PodSecurityPolicy is enabled on master
    Then any user can access unprivileged psp
    And any user can not access privileged psp
    When deployment uses hostNetwork
    Then deployment is not allowed
    When patching deployment to not use hostNetwork
    Then deployment is allow
    [Teardown]    teardown psp
