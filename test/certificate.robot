*** Settings ***
Suite Setup       setup test suite monitoring
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/certificate.robot
Resource          ../function/tests/monitoring/monitoring.robot

*** Test Cases ***
Check kubelet server certificate is the one signed by kubelet-ca for each node
    [Tags]    release
    Given cluster running
    Then kubelet server certificate should be signed by kubelet-ca for each node

certificate rotation for dex and gangway
    [Tags]    release
    Given cluster running
    And helm is installed
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    and create kubernetes CA issuer secret
    When create and apply rotation certificate manifest for    oidc-dex    12h    6h
    and create and apply rotation certificate manifest for    oidc-gangway
    And add custom certificate to    oidc-dex    6 hours 2 minutes
    Then check expired date for oidc-dex is sup to 6 hours
    And check expired date for oidc-gangway is sup to 720 hours
    when sleep    3 minutes
    Then check expired date for oidc-dex is sup to 11 hours
    [Teardown]    clean cert-manager
