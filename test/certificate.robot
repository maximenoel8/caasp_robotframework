*** Settings ***
Resource          ../function/skuba_join.robot
Resource          ../function/certificat.robot

*** Test Cases ***
Check kubelet server certificate is the one signed by kubelet-ca for each node
    [Tags]    release
    Given cluster running
    Then kubelet server certificate should be signed by kubelet-ca for each node
