*** Settings ***
Suite Setup       setup certificate suite
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/certificate.robot
Resource          ../function/tests/monitoring/monitoring.robot

*** Test Cases ***
Check kubelet server certificate is the one signed by kubelet-ca for each node
    [Tags]    release
    Then kubelet server certificate should be signed by kubelet-ca for each node

certificate rotation for dex and gangway
    [Tags]    release
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    and create kubernetes CA issuer secret
    When create and apply rotation certificate manifest for    oidc-dex    duration=12h    renew_before=6h
    and create and apply rotation certificate manifest for    oidc-gangway
    Then addon oidc-dex certificate is correctly generated in certificate status by kubernetes-ca
    And addon oidc-gangway certificate is correctly generated in certificate status by kubernetes-ca
    Then check expired date for oidc-gangway is sup to 720 hours
    And check expired date for oidc-dex is sup to 6 hours
    When modify tls secret to    oidc-dex    duration=6 hours, 2 minutes    ca=True
    step    waiting 3 minutes
    And sleep    3 minutes
    Then check expired date for oidc-dex is sup to 11 hours
    [Teardown]    clean cert-manager

check kucero is correctly renewing certificate
    And kucero is running on master
    And serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    And serverTLSBoostrap exists in config map
    ${current_files_number}    And current number of certificates are backuped
    When modify kucero command in manifest adding polling period and renew-before
    And kucero has renewed certificate
    Then number of certificates is superior    ${current_files_number}
    And certificate are correctly generated for all masters
    [Teardown]    modify kucero command in manifest removing polling period and renew-before

check csr server
    ${node}    Set Variable    ${CLUSTER_PREFIX}-1-master-0
    And kucero is running on master
    And serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    And serverTLSBoostrap exists in config map
    ${current_files_number}    and get number of files in /var/lib/kubelet/pki on ${node}
    When deleting kubelet-server-current.pem and restarting kubelet on ${node}
    then csr is generated and approve for ${node}
    And number of certificate in /var/lib/kubelet/pki is superior    ${current_files_number[1]}    ${node}

oidc-dex and oidc-gangway signed by custom CA certificate and key
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    and create CA    custom-kubernetes-ca
    and create kubernetes CA issuer secret    ${LOGDIR}/certificate/custom-kubernetes-ca    custom-kubernetes-ca
    When create and apply rotation certificate manifest for    oidc-dex    custom-kubernetes-ca    12h    6h
    And create and apply rotation certificate manifest for    oidc-gangway    custom-kubernetes-ca    12h    6h
    Then addon oidc-dex certificate is correctly generated in certificate status by custom-kubernetes-ca
    And addon oidc-gangway certificate is correctly generated in certificate status by custom-kubernetes-ca
    And oidc-dex certificate is signed by custom-kubernetes-ca on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/custom-kubernetes-ca/ca.crt
    And oidc-ganway certificate is signed by custom-kubernetes-ca on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/custom-kubernetes-ca/ca.crt
    [Teardown]    clean cert-manager
