*** Settings ***
Suite Setup       Given cluster running
Suite Teardown    teardown coredns
Resource          ../function/tests/coredns.robot
Resource          ../function/cluster_deployment.robot

*** Test Cases ***
coredns pods are ready
    [Tags]    release
    Then coredns replicats should be 2

kube-dns service exists
    [Tags]    release
    then check kube-dns service exists

can resolve kubernetes api IP from its internal FQDN
    [Tags]    release
    ${ip}    get kubernetes service ip
    resolve \ kubernetes.default.svc.cluster.local \ should contain ${ip}

can reverse resolve kubernetes api FQDN from its internal IP
    [Tags]    release
    ${ip}    get kubernetes service ip
    reverse resolving ${ip} should contain kubernetes.default.svc.cluster.local

testing pod dnsutils-netcat must be ready
    [Tags]    release
    When deploy dnsutils-netcat
    Then dnsutils-netcat should be deployed successfully

can create dns A and PTR entry for service
    [Tags]    release
    When deploy dnsutils-netcat
    And deploy dnsutils-netcat service
    ${ip}    and get dnsutils-netcat service ip
    Then resolve dnsutils-netcat.default.svc.cluster.local should contain ${ip}
    And reverse resolving 10.100.100.100 should contain dnsutils-netcat.default.svc.cluster.local

can create dns A and PTR entry for headless service
    [Tags]    release
    When deploy dnsutils-netcat
    And deploy dnsutils-netcat service headless
    ${ip}    and get dnsutils-netcat-headless service ip
    Then resolve dnsutils-netcat-headless.default.svc.cluster.local should contain ${ip}
    And reverse resolving ${ip} should contain dnsutils-netcat-headless.default.svc.cluster.local
