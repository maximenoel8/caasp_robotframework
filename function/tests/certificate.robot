*** Settings ***
Resource          ../commands.robot
Library           ../../lib/base64_encoder.py
Resource          ../cluster_helpers.robot
Resource          monitoring/grafana_dashboard.robot
Library           DateTime
Library           ../../lib/openssl_library.py
Library           OperatingSystem
Resource          ../certificate_helper.robot
Resource          ../cluster_deployment.robot
Resource          monitoring/monitoring.robot

*** Keywords ***
deploy reloader
    step    deploy reloader
    helm    repo add stakater https://stakater.github.io/stakater-charts
    helm    repo update
    helm    install stakater/reloader --name reloader --namespace kube-system
    wait deploy    reloader-reloader -n kube-system

deploy cert-manager
    step    deploy cert-manager
    helm    repo add jetstack https://charts.jetstack.io
    helm    repo update
    helm    install jetstack/cert-manager --name cert-manager --namespace kube-system --version v0.15.0 --set installCRDs=true
    wait deploy    cert-manager -n kube-system

create and apply rotation certificate manifest for
    [Arguments]    ${service}    ${issuer}=kubernetes-ca    ${duration}=8760h    ${renew_before}=720h
    step    create rotation certificate manifest for ${service}
    backup tls secret manifest    ${service}
    ${SAN}    get san from cert    ${LOGDIR}/certificate/${service}/backup/${service}.crt
    ${common_name}    Set Variable If    "${service}"=="metrics-server"    metrics-server.kube-system.svc    ${service}
    _create certificate rotation manifest    ${service}    ${common_name}    ${SAN}    ${issuer}    ${duration}    ${renew_before}
    kubectl    apply -f ${LOGDIR}/${service}-certificate.yaml
    wait certificate ${service}-cert in kube-system is ready
    kubectl    rollout restart deployment/${service} -n kube-system
    wait deploy    ${service} -n kube-system

_create certificate rotation manifest
    [Arguments]    ${service}    ${common_name}    ${SAN}    ${issuer}=kubernetes-ca    ${duration}=8760    ${renew_before}=720
    ${dns_list}    Set Variable    ${SAN["dns"]}
    ${ip_list}    Set Variable    ${SAN["ip"]}
    ${lt_dns}    Get Length    ${dns_list}
    ${lt_ip}    Get Length    ${ip_list}
    ${manifest_dictionnary}    open yaml file    ${DATADIR}/manifests/certificate/template-certificate.yaml
    Set To Dictionary    ${manifest_dictionnary["metadata"]}    name=${service}-cert
    Set To Dictionary    ${manifest_dictionnary["metadata"]}    name=${service}-cert
    Set To Dictionary    ${manifest_dictionnary["spec"]}    secretName=${service}-cert
    Set To Dictionary    ${manifest_dictionnary["spec"]}    commonName=${common_name}
    Set To Dictionary    ${manifest_dictionnary["spec"]}    duration=${duration}
    Set To Dictionary    ${manifest_dictionnary["spec"]}    renewBefore=${renew_before}
    Set To Dictionary    ${manifest_dictionnary["spec"]["issuerRef"]}    name=${issuer}
    Run Keyword If    ${lt_ip} > 0    Set To Dictionary    ${manifest_dictionnary["spec"]}    ipAddresses=${ip_list}
    Run Keyword If    ${lt_dns} > 0    Set To Dictionary    ${manifest_dictionnary["spec"]}    dnsNames=${dns_list}
    ${manifest_stream}    Dump    ${manifest_dictionnary}
    Create File    ${LOGDIR}/${service}-certificate.yaml    ${manifest_stream}

annotate dex gangway and metrics secret for reload
    step    annotate dex, metrcis and gangway secret for reload
    kubectl    -n kube-system annotate deploy/oidc-dex secret.reloader.stakater.com/reload=oidc-dex-cert --overwrite
    kubectl    -n kube-system annotate deploy/oidc-gangway secret.reloader.stakater.com/reload=oidc-gangway-cert --overwrite
    kubectl    -n kube-system annotate deploy/metrics-server secret.reloader.stakater.com/reload=metrics-server-cert --overwrite

create tls secret to
    [Arguments]    ${service}    ${SAN}    ${namespace}=kube-system    ${duration}=6 days, 23 hours    ${ca}=False    ${ca_crt}=${WORKDIR}/cluster_1/pki/ca.crt    ${ca_key}=${WORKDIR}/cluster_1/pki/ca.key
    execute command localy    mkdir -p ${LOGDIR}/certificate/${service}
    create client config    ${service}    ${SAN}
    Run Keyword If    ${ca}    generate new certificate with CA signing request    ${service}    ${SAN}    ${ca_crt}    ${ca_key}    ${duration}
    ...    ELSE    generate new certificate without CA request    ${service}    ${SAN}    ${duration}
    create tls secret manifest    ${service}    ${DATADIR}/certificate/template-cert.yaml    ${namespace}    ${ca}    ca_crt=${ca_crt}
    kubectl    apply -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml

modify tls secret to
    [Arguments]    ${service}    ${namespace}=kube-system    ${duration}=6 days, 23 hours    ${ca}=False    ${ca_crt}=${WORKDIR}/cluster_1/pki/ca.crt    ${ca_key}=${WORKDIR}/cluster_1/pki/ca.key
    step    Modify tls secret for ${service}
    backup tls secret manifest    ${service}
    ${SAN}    get san from cert    ${LOGDIR}/certificate/${service}/backup/${service}.crt
    Run Keyword If    ${ca}    generate new certificate with CA signing request    ${service}    ${SAN}    ${ca_crt}    ${ca_key}    ${duration}
    ...    ELSE    generate new certificate without CA request    ${service}    ${SAN}    ${duration}
    create tls secret manifest    ${service}    ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml    ${namespace}    ca_crt=${ca_crt}
    replace tls secret and restart service    ${service}
    wait pods ready
    Run Keyword And Ignore Error    _modify expired date for secret    ${service}-cert    tls.crt    ${duration}

backup tls secret manifest
    [Arguments]    ${service}
    Create Directory    ${LOGDIR}/certificate/${service}/backup
    ${output}    kubectl    get secret ${service}-cert -n kube-system -o yaml
    Create File    ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml    ${output}
    ${dico_output}    load    ${output}
    ${tls_certificate}    Decode Base64    ${dico_output["data"]["tls.crt"]}
    Create File    ${LOGDIR}/certificate/${service}/backup/${service}.crt    ${tls_certificate}

create tls secret manifest
    [Arguments]    ${service}    ${file}    ${namespace}    ${ca}=True    ${ca_crt}=None
    ${extension}    Set Variable If    ${ca}    -cert    -tls
    ${service_crt}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.crt
    ${service_key}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.key
    ${ca_crt}    _encode file in base64    ${ca_crt}
    ${output}    OperatingSystem.Get File    ${file}
    ${manifest_dico}    Load    ${output}
    Set To Dictionary    ${manifest_dico["metadata"]}    name=${service}${extension}
    Set To Dictionary    ${manifest_dico["metadata"]}    namespace=${namespace}
    Set To Dictionary    ${manifest_dico["data"]}    tls.crt=${service_crt}
    Set To Dictionary    ${manifest_dico["data"]}    tls.key=${service_key}
    Run Keyword If    ${ca}    Set To Dictionary    ${manifest_dico["data"]}    ca.crt=${ca_crt}
    ...    ELSE    Remove From Dictionary    ${manifest_dico["data"]}    ca.crt
    ${dico}    Dump    ${manifest_dico}
    Create File    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    ${dico}

replace tls secret and restart service
    [Arguments]    ${service}    ${namespace}=kube-system
    kubectl    replace -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml
    kubectl    rollout restart deployment/${service} -n ${namespace}

check expired date for ${service} is sup to ${time}
    step    check expired date for ${service} is superior to ${time}
    backup tls secret manifest    ${service}
    ${certificate_time}    get_expiry_date    ${LOGDIR}/certificate/${service}/backup/${service}.crt
    ${convert_time}    Convert Date    ${certificate_time}    date_format=%Y%m%d%H%M%SZ
    ${current_time}    DateTime.Get Current Date    UTC
    ${expired_time}    DateTime.Subtract Date From Date    ${convert_time}    ${current_time}
    ${expired_time_verbose}    Convert Time    ${expired_time}    verbose
    ${result}    DateTime.Subtract Time From Time    ${expired_time}    ${time}
    Should Be True    ${result} > 0

kubelet server certificate should be signed by kubelet-ca for each nodes
    [Arguments]    ${cluster_number}=1
    ${master}    get master servers name    enable
    ${workers}    get worker servers name    enable
    ${nodes}    Combine Lists    ${master}    ${workers}
    FOR    ${node}    IN    @{nodes}
        ${server_ip}    get node ip from CS    ${node}
        addon kubelet server certificate is signed by kubelet-ca on ${server_ip} 10250 with ${CLUSTER_DIR}_${cluster_number}/pki/kubelet-ca.crt
    END

addon ${service} certificate is signed by ${issuer} on ${server_ip} ${port} with ${certificate}
    Create Directory    ${LOGDIR}/tmp
    ${authority}    Split String    ${certificate}
    ${issuer_from_file}    get_certificate_from_client    ${server_ip}    ${port}    ${LOGDIR}/tmp/${service}.crt
    Should Contain    ${issuer_from_file}    /CN=${issuer}
    ${status}    verify_certificate_chain    ${LOGDIR}/tmp/${service}.crt    ${authority}
    Should Be True    ${status}
    Comment    Remove File    ${LOGDIR}/tmp/${service}.crt

clean cert-manager
    step    clean cert-manager deployment
    Run Keyword And Ignore Error    helm    delete --purge reloader
    Run Keyword And Ignore Error    helm    delete --purge cert-manager
    Run Keyword And Ignore Error    kubectl    delete -f ${LOGDIR}/manifests/certificate/issuer.yaml
    Run Keyword And Ignore Error    kubectl    delete secret kubernetes-ca -n kube-system
    Run Keyword And Ignore Error    kubectl    delete secret ${issuer_CN} -n kube-system

backup certificate files from server
    [Arguments]    ${node}    ${cluster_number}=1
    execute command with ssh    mkdir -p /home/${VM_USER}/certificates-backup/${node}    ${node}
    execute command with ssh    sudo cp -p \ -R /etc/kubernetes/pki /home/${VM_USER}/certificates-backup/${node}    ${node}
    execute command with ssh    sudo chown \ -R ${VM_USER}:users /home/${VM_USER}/certificates-backup/${node}    ${node}
    execute command with ssh    cd /home/${VM_USER}&& tar -czvf certificates-backup.tar.gz certificates-backup    ${node}
    SSHLibrary.Get File    /home/${VM_USER}/certificates-backup.tar.gz    ${LOGDIR}/    recursive=True
    execute command localy    cd ${LOGDIR} && tar -xzvf certificates-backup.tar.gz
    Remove File    ${LOGDIR}/certificates-backup.tar.gz

certificate are correctly generated
    [Arguments]    ${node}    ${cluster_number}=1
    ${dico}    Load JSON From File    ${DATADIR}/monitoring/expected_value_grafana_certificates.json
    Set Test Variable    ${cer_dico}    ${dico["kubernetes"]}
    @{certificate_names}    Get Dictionary Keys    ${cer_dico}
    FOR    ${certificate_name}    IN    @{certificate_names}
        Continue For Loop If    "${certificate_name}"=="master" or "${certificate_name}"=="worker" or "${certificate_name}"=="etcd-ca" or "${certificate_name}"=="kubernetes" or "${certificate_name}"=="front-proxy-ca" or "${certificate_name}"=="kubelet-ca"
        ${issuer}    Set Variable    ${cer_dico["${certificate_name}"]["issuer"]}
        ${issuer_certificate}    Run Keyword If    "${issuer}"=="kubernetes"    Create List    ${CLUSTERDIR}_${cluster_number}/pki/ca.crt
        ...    ELSE IF    "${issuer}"=="etcd-ca"    Create List    ${CLUSTERDIR}_${cluster_number}/pki/etcd/ca.crt
        ...    ELSE IF    "${issuer}"=="front-proxy-ca"    Create List    ${CLUSTERDIR}_${cluster_number}/pki/front-proxy-ca.crt
        ${certificate_file}    Replace String    ${cer_dico["${certificate_name}"]["filename"]}    /etc/kubernetes    ${LOGDIR}/certificates-backup/${node}
        ${issuer_from_file}    get issuer    ${certificate_file}
        Should Be Equal    ${issuer_from_file}    /CN=${issuer}
        ${status}    verify certificate chain    ${certificate_file}    ${issuer_certificate}
        Should Be True    ${status}
        _check certificate type    ${certificate_name}    ${certificate_file}
    END

modify kucero command in manifest adding polling period and renew-before
    step    Modify kucero command to renew certificate immediately
    kubectl    get ds/kucero -o yaml -n kube-system > ${LOGDIR}/kucero-backup.yaml
    ${service}    OperatingSystem.Get File    ${LOGDIR}/kucero-backup.yaml
    ${dico}    Safe Load    ${service}
    ${values}    Get From Dictionary    ${dico["spec"]["template"]["spec"]["containers"][0]}    command
    Remove Values From List    ${values}    --polling-period=1m    --renew-before=8870h
    Append To List    ${values}    --polling-period=1m
    Append To List    ${values}    --renew-before=8870h
    Set To Dictionary    ${dico["spec"]["template"]["spec"]["containers"][0]}    command=${values}
    ${output}    Dump    ${dico}
    Create File    ${LOGDIR}/kucero.yaml    ${output}
    kubectl    apply -f ${LOGDIR}/kucero.yaml --force
    wait daemonset are ready    kucero

modify kucero command in manifest removing polling period and renew-before
    step    Reinitialize kucero conifguration
    kubectl    get ds/kucero -o yaml -n kube-system > ${LOGDIR}/kucero-backup.yaml
    ${service}    OperatingSystem.Get File    ${LOGDIR}/kucero-backup.yaml
    ${dico}    Safe Load    ${service}
    ${values}    Get From Dictionary    ${dico["spec"]["template"]["spec"]["containers"][0]}    command
    Remove Values From List    ${values}    --polling-period=1m    --renew-before=8870h
    Set To Dictionary    ${dico["spec"]["template"]["spec"]["containers"][0]}    command=${values}
    ${output}    Dump    ${dico}
    Create File    ${LOGDIR}/kucero.yaml    ${output}
    kubectl    apply -f ${LOGDIR}/kucero.yaml --force
    wait daemonset are ready    kucero

get number certificate files on ${node}
    [Documentation]    Return number of files in /etc/kubernetes
    ...    Return number of files in /etc/kubernetes/pki
    ...    Return number of files in /etc/kubernetes/pki/etcd
    ${cf_files}    ${cf_num}    get number of files in /etc/kubernetes on ${node}
    ${cert_root_files}    ${cert_root_num}    get number of files in /etc/kubernetes/pki on ${node}
    ${cert_etcd_files}    ${cert_etcd_num}    get number of files in /etc/kubernetes/pki/etcd on ${node}
    [Return]    ${cf_num}    ${cert_root_num}    ${cert_etcd_num}

kucero is running on master
    step    check kucero is running on masters
    wait daemonset are ready    kucero    namespace=kube-system
    ${pods_name}    wait podname    -l name=kucero -n kube-system
    ${number__of_pod_kucero}    Get Length    ${pods_name}
    ${number_of_master}    get number of nodes    role=master
    Should Be Equal    ${number__of_pod_kucero}    ${number_of_master}

current number of certificates are backuped
    step    save numbers of certificates before renew
    ${nodes}    get master servers name
    ${number_backup}    Create Dictionary
    FOR    ${node}    IN    @{nodes}
        ${numbers}    get number certificate files on ${node}
        ${temp_dico}    Create Dictionary    conf_file=${numbers[0]}    root_cert=${numbers[1]}    etcd_cert=${numbers[2]}
        Set To Dictionary    ${number_backup}    ${node}=${temp_dico}
    END
    [Return]    ${number_backup}

kucero has renewed certificate
    step    check certificate are renewed correctly in kucero logs
    @{pods}    wait podname    -l name=kucero -n kube-system
    FOR    ${pod}    IN    @{pods}
        Wait Until Keyword Succeeds    5min    10sec    check pod log contain    ${pod} -n kube-system    msg="Releasing lock"
    END

number of certificates is superior
    [Arguments]    ${backup_number}
    step    get current number of certificate
    ${new_certificate_number}    current number of certificates are backuped
    @{nodes}    get master servers name
    FOR    ${node}    IN    @{nodes}
        ${type}    get node type    ${node}
        Should Not Be Equal    ${new_certificate_number["${node}"]["conf_file"]}    ${backup_number["${node}"]["conf_file"]}
        Should Not Be Equal    ${new_certificate_number["${node}"]["root_cert"]}    ${backup_number["${node}"]["root_cert"]}
        Should Not Be Equal    ${new_certificate_number["${node}"]["etcd_cert"]}    ${backup_number["${node}"]["etcd_cert"]}
    END

certificate are correctly generated for all masters
    step    check certificates are correctly generated on master
    @{nodes}    get master servers name
    FOR    ${node}    IN    @{nodes}
        backup certificate files from server    ${node}
        certificate are correctly generated    ${node}
    END

serverTLSBootstrap exists in config map
    step    serverTLSbootstrap exists in config map
    ${version}    get kubernetes version    server    major
    ${output}    kubectl    get configmap kubelet-config-${version[0]} -n kube-system -o yaml
    ${dico_to}    Load    ${output}
    ${dico}    Load    ${dico_to["data"]["kubelet"]}
    Dictionary Should Contain Key    ${dico}    serverTLSBootstrap
    Should Be True    ${dico["serverTLSBootstrap"]}

serverTLSbootstrap is config in /var/lib/kubelet/config.yaml on all nodes
    step    check serverTLSbootsrap in config.yaml
    @{nodes}    get nodes name from CS
    FOR    ${node}    IN    @{nodes}
        ${output}    execute command with ssh    sudo cat /var/lib/kubelet/config.yaml    ${node}
        ${dico}    Load    ${output}
        Dictionary Should Contain Key    ${dico}    serverTLSBootstrap
        Should Be True    ${dico["serverTLSBootstrap"]}
    END

_check certificate type
    [Arguments]    ${certificate_name}    ${certificate_file}
    ${result}    get type    ${certificate_file}
    @{types}    Split String    ${result}    ,
    @{expected_types}    Split String    ${cer_dico["${certificate_name}"]["kind"]}    ,
    FOR    ${element}    IN    @{types}
        ${type}    Strip String    ${element}
        Should Contain Any    ${type}    @{expected_types}
    END

deleting kubelet-server-current.pem and restarting kubelet on ${node}
    step    delete server certificate and reboot kubelet
    execute command with ssh    sudo rm /var/lib/kubelet/pki/kubelet-server-current.pem    ${node}
    execute command with ssh    sudo systemctl restart kubelet    ${node}
    Wait Until Keyword Succeeds    2 min    5 sec    SSHLibrary.File Should Exist    /var/lib/kubelet/pki/kubelet-server-current.pem

csr is generated and approve for ${node}
    ${skuba_name}    get node skuba name    ${node}
    ${output}    kubectl    get csr -o yaml
    ${dico}    Load    ${output}
    ${last_generated_csr_dico}    Set Variable    ${dico["items"][0]}
    Should Be Equal    ${last_generated_csr_dico["spec"]["username"]}    system:node:${skuba_name}
    Should Be Equal    ${last_generated_csr_dico["spec"]["signerName"]}    kubernetes.io/kubelet-serving
    Should Be Equal    ${last_generated_csr_dico["status"]["conditions"][0]["type"]}    Approved
    Should Be Equal    ${last_generated_csr_dico["status"]["conditions"][0]["reason"]}    AutoApproved by kucero
    Should Be Equal    ${last_generated_csr_dico["status"]["conditions"][0]["message"]}    Auto approving kubelet serving certificate after SubjectAccessReview.

number of certificate in /var/lib/kubelet/pki is superior
    [Arguments]    ${ref_number}    ${node}
    ${number}    get number of files in /var/lib/kubelet/pki on ${CLUSTER_PREFIX}-1-master-0
    ${status}    Evaluate    ${number[1]} > ${ref_number}
    Should Be True    ${status}

${service} certificate CA signed is custom trusted CA certificate
    ${authority}    Create List    ${CLUSTER_DIR}_${cluster_number}/pki/kubelet-ca.crt
    ${issuer}    get_certificate_from_client    ${LOADBALANCER_IP}    32000    ${LOGDIR}/certificate-${server_ip}.crt
    Should Contain    ${issuer}    /CN=kubelet-ca
    ${status}    verify_certificate_chain    ${LOGDIR}/certificate-${server_ip}.crt    ${authority}
    Should Be True    ${status}

addon ${service} certificate is correctly generated in certificate status by ${issuer}
    ${output}    kubectl    get certificates ${service}-cert -n kube-system -o yaml
    ${certificate_dico}    Safe Load    ${output}
    Should Be Equal    ${certificate_dico["spec"]["commonName"]}    ${service}
    Should Be Equal    ${certificate_dico["spec"]["issuerRef"]["name"]}    ${issuer}
    Should Be Equal    ${certificate_dico["status"]["conditions"][0]["reason"]}    Ready
    Should Be True    ${certificate_dico["status"]["conditions"][0]["status"]}

setup certificate suite
    Given cluster running
    And setup test suite monitoring
    And helm is installed

updates kubeadm-config ConfigMap
    [Arguments]    ${service}=customize-kubernetes-ca    ${cluster_number}=1
    ${cm_kubeadm}    kubectl    get configmap -n kube-system kubeadm-config -o yaml
    ${kubeadm_file}    Safe Load    ${cm_kubeadm}
    ${cluster_config}    Safe Load    ${kubeadm_file["data"]["ClusterConfiguration"]}
    Set To Dictionary    ${cluster_config["apiServer"]["extraArgs"]}    oidc-ca-file=/etc/kubernetes/pki/oidc-ca.crt
    ${tmp_dico}    Safe Dump    ${cluster_config}
    Set To Dictionary    ${kubeadm_file["data"]}    ClusterConfiguration=${tmp_dico}
    ${data-kubeadm}    Safe Dump    ${kubeadm_file}
    Create File    ${LOGDIR}/kubeadm-config.yaml    ${data-kubeadm}
    kubectl    apply -f ${LOGDIR}/kubeadm-config.yaml
