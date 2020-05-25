*** Settings ***
Suite Setup       setup test suite cilium
Suite Teardown    teardown testsuite cilium
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/cilium.robot

*** Test Cases ***
check L3-L4 policy
    [Tags]    release
    then node is able to land    tiefighter
    and node is able to land    xwing
    when l3 l4 policiy is deployed
    then node is able to land    tiefighter
    and node is not able to land    xwing
    [Teardown]    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_policy.yaml

check L7 policy
    [Tags]    release
    Then PUT request create error    tiefighter
    When l7 policy is deployed
    Then PUT request is denied    tiefighter
    And node is able to land    tiefighter
    [Teardown]    kubectl    delete -f https://raw.githubusercontent.com/cilium/cilium/v1.6/examples/minikube/sw_l3_l4_l7_policy.yaml

check cilium version
    [Tags]    release
    Then cilium version should be    1.6.6

check cilium uses CRD instead of etcd
    [Tags]    release
    Then cilium-config should contain crd setting
    And cilium-config should not contain etcd config

http traffic is allowed without network policy
    [Tags]    release
    [Setup]    clean all network policies
    [Template]    check http traffic
    DELETE    /anything/allowed    200
    DELETE    /anything/not-allowed    200
    GET    /anything/allowed    200
    GET    /anything/not-allowed    200
    PUT    /anything/allowed    200
    PUT    /anything/not-allowed    200

dns traffic is allowed without network policy
    [Tags]    release
    [Setup]    clean all network policies
    [Template]    dns traffic is allowed
    one.one.one.one    1.1.1.1
    one.one.one.one    1.0.0.1
    dns.google    8.8.8.8
    localhost    127.0.0.1

dns traffic is forbidden by the default network policy
    [Tags]    release
    [Setup]    apply a default network policy to deny all traffic
    [Template]    dns traffic is forbidden
    one.one.one.one    1.1.1.1
    one.one.one.one    1.0.0.1
    dns.google    8.8.8.8
    localhost    127.0.0.1

dns is allowed by network policy
    [Tags]    release
    [Setup]    apply network policy to allow DNS traffic
    [Template]    dns traffic is allowed
    one.one.one.one    1.1.1.1
    one.one.one.one    1.0.0.1
    dns.google    8.8.8.8
    localhost    127.0.0.1

http traffic is still not allowed by the default network policy
    [Tags]    release
    [Setup]    apply a default network policy to deny all traffic
    [Template]    check http traffic
    DELETE    /anything/allowed    000command terminated with exit code 28
    GET    /anything/allowed    000command terminated with exit code 28
    PUT    /anything/allowed    000command terminated with exit code 28

http traffic is allowed by network policy at layer 3
    [Tags]    release
    [Setup]    apply network policy to allow http traffic at layer 3
    [Template]    check http traffic
    DELETE    /anything/allowed    200
    DELETE    /anything/not-allowed    200
    GET    /anything/allowed    200
    GET    /anything/not-allowed    200
    PUT    /anything/allowed    200
    PUT    /anything/not-allowed    200

http traffic is filtered by network policy at layer 7
    [Tags]    release
    [Setup]    apply network policy to allow http traffic with Layer 7 filtering
    [Template]    check http traffic
    DELETE    /anything/allowed    200
    DELETE    /anything/not-allowed    403
    GET    /anything/allowed    200
    GET    /anything/not-allowed    403
    PUT    /anything/allowed    200
    PUT    /anything/not-allowed    403
