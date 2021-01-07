*** Settings ***
Suite Setup       setup certificate suite
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/certificate.robot
Resource          ../function/tests/monitoring/monitoring.robot

*** Test Cases ***
check kubelet server certificate is the one signed by kubelet-ca for each nodes
    [Tags]    release
    Then kubelet server certificate should be signed by kubelet-ca for each nodes

check cert-manager correctly do the certificate rotation for dex and gangway when certificate is expired
    [Tags]    release    4.5    smoke
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    and create kubernetes CA issuer secret
    When create and apply rotation certificate manifest for    oidc-dex    duration=12h    renew_before=6h
    and create and apply rotation certificate manifest for    oidc-gangway
    Then addon oidc-dex_cert certificate is correctly generated in certificate status by kubernetes-ca
    And addon oidc-gangway_cert certificate is correctly generated in certificate status by kubernetes-ca
    Then check expired date for oidc-gangway_cert is sup to 720 hours
    And check expired date for oidc-dex_cert is sup to 6 hours
    When modify tls secret to    oidc-dex    duration=6 hours, 2 minutes    ca=True
    step    waiting 3 minutes
    And sleep    3 minutes
    Then check expired date for oidc-dex_cert is sup to 11 hours
    [Teardown]    clean cert-manager

check kucero is correctly renewing certificates
    [Tags]    v4.5    smoke
    [Setup]    refresh ssh session
    And kucero is running on master
    Comment    And serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    Comment    And serverTLSBootstrap exists in config map
    ${current_files_number}    And current number of certificates are backuped
    When modify kucero command in manifest adding polling period and renew-before
    And kucero has renewed certificate
    Comment    Then number of certificates is superior    ${current_files_number}
    Comment    And certificate are correctly generated for all masters
    sleep    5min
    And serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    Comment    And serverTLSBootstrap exists in config map
    [Teardown]    modify kucero command in manifest removing polling period and renew-before

check csr server is correctly generated new kubelet certificate
    [Setup]    refresh ssh session
    ${node}    Set Variable    ${CLUSTER_PREFIX}-1-master-0
    And kucero is running on master
    And serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    And serverTLSBootstrap exists in config map
    ${current_files_number}    and get number of files in /var/lib/kubelet/pki on ${node}
    When deleting kubelet-server-current.pem and restarting kubelet on ${node}
    then csr is generated and approve for ${node}
    And number of certificate in /var/lib/kubelet/pki is superior    ${current_files_number[1]}    ${node}

check oidc-dex and oidc-gangway signed by custom CA certificate and key are correctly manage by cert-manager
    [Tags]    release    smoke
    Set Test Variable    ${issuer_CN}    noca-kubernetes-ca
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    And create CA    ${issuer_CN}
    and create kubernetes CA issuer secret    ${LOGDIR}/certificate/${issuer_CN}    ${issuer_CN}
    When create and apply rotation certificate manifest for    oidc-dex    ${issuer_CN}    12h    6h
    And create and apply rotation certificate manifest for    oidc-gangway    ${issuer_CN}    12h    6h
    Then addon oidc-dex_cert certificate is correctly generated in certificate status by ${issuer_CN}
    And addon oidc-gangway_cert certificate is correctly generated in certificate status by ${issuer_CN}
    And addon oidc-dex certificate is signed by ${issuer_CN} on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt
    And addon oidc-ganway certificate is signed by ${issuer_CN} on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt
    [Teardown]    clean cert-manager

check oidc-dex and oidc-gangway signed by custom CA certificate signed by kubernetes-ca and key are correctly manage by cert-manager
    [Tags]    release
    Set Test Variable    ${issuer_CN}    customize-kubernetes-ca
    and deploy reloader
    and annotate dex gangway and metrics secret for reload
    and deploy cert-manager
    And create CA with CA signing request    ${issuer_CN}
    and create kubernetes CA issuer secret    ${LOGDIR}/certificate/${issuer_CN}    ${issuer_CN}
    When create and apply rotation certificate manifest for    oidc-dex    ${issuer_CN}    12h    6h
    And create and apply rotation certificate manifest for    oidc-gangway    ${issuer_CN}    12h    6h
    Then addon oidc-dex_cert certificate is correctly generated in certificate status by ${issuer_CN}
    And addon oidc-gangway_cert certificate is correctly generated in certificate status by ${issuer_CN}
    And addon oidc-dex certificate is signed by ${issuer_CN} on ${IP_LB_1} 32000 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt ${CLUSTERDIR}_1/pki/ca.crt
    And addon oidc-ganway certificate is signed by ${issuer_CN} on ${IP_LB_1} 32001 with ${LOGDIR}/certificate/${issuer_CN}/ca.crt ${CLUSTERDIR}_1/pki/ca.crt
    [Teardown]    clean cert-manager

check cert-manager rotation with CA within certificate
    Comment    and deploy reloader
    Comment    and annotate dex gangway and metrics secret for reload
    Comment    and deploy cert-manager
    and create kubernetes CA issuer secret
    When create and apply rotation certificate manifest for    oidc-dex    duration=12h    renew_before=6h
    and create and apply rotation certificate manifest for    oidc-gangway
    Then addon oidc-dex_cert certificate is correctly generated in certificate status by kubernetes-ca
    And addon oidc-gangway_cert certificate is correctly generated in certificate status by kubernetes-ca
    Then check expired date for oidc-gangway_cert is sup to 720 hours
    And check expired date for oidc-dex_cert is sup to 6 hours
    When modify tls secret to    oidc-dex    duration=5 hours    ca=True
    step    waiting 3 minutes
    And sleep    3 minutes
    Then check expired date for oidc-dex_cert is sup to 11 hours

cert-manager renew certificates cilium 1.5
    Given cluster running
    and helm is installed
    load vm ip
    kubectl    annotate --overwrite daemonset/cilium -n kube-system secret.reloader.stakater.com/reload=cilium-secret
    kubectl    label --overwrite secret cilium-secret -n kube-system caasp.suse.com/skuba-addon=true
    and create kubernetes CA issuer secret    issuer_name=etcd-ca    certificate_folder=${CLUSTERDIR}_1/pki/etcd
    When create and apply rotation certificate manifest for    cilium    duration=12h    renew_before=6h    issuer=etcd-ca    secret_name=cilium-secret    extension=secret
    Then addon cilium_cert certificate is correctly generated in certificate status by etcd-ca
    Then check expired date for cilium_secret is sup to 7 hours
    When modify tls secret to    cilium    duration=6 hours, 2 minutes    ca=True    extension=secret    ca_crt=${CLUSTERDIR}_1/pki/etcd/ca.crt    ca_key=${CLUSTERDIR}_1/pki/etcd/ca.key
    step    waiting 3 minutes
    And sleep    3 minutes
    Then check expired date for cilium_secret is sup to 11 hours
