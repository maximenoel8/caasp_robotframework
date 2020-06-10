*** Settings ***
Resource          ../commands.robot
Library           ../../lib/base64_encoder.py
Library           ../../lib/yaml_editor.py
Resource          ../cluster_helpers.robot
Resource          monitoring/grafana_dashboard.robot
Library           DateTime
Library           ../../lib/openssl_library.py
Library           OperatingSystem

*** Keywords ***
backup certificate configuration
    [Arguments]    ${service}
    execute command localy    mkdir -p ${LOGDIR}/certificate/${service}/backup
    kubectl    get secret ${service}-cert -n kube-system -o yaml > ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml
    execute command localy    cat ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml | grep tls.crt | awk '{print $2}' | base64 --decode | tee ${LOGDIR}/certificate/${service}/backup/${service}.crt > /dev/null
    execute command localy    cat ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml | grep tls.key | awk '{print $2}' | base64 --decode | tee ${LOGDIR}/certificate/${service}/backup/${service}.key > /dev/null

get SAN ip and dns
    [Arguments]    ${service}
    ${SAN}    get_san_from_cert    ${LOGDIR}/certificate/${service}/backup/${service}.crt
    Log Dictionary    ${SAN}
    [Return]    ${SAN}

create client config
    [Arguments]    ${service}    ${SAN}
    Copy File    ${DATADIR}/certificate/server.conf    ${LOGDIR}/certificate/${service}/${service}.conf
    ${count}    Set Variable    1
    FOR    ${ip}    IN    @{SAN["ip"]}
        Append To File    ${LOGDIR}/certificate/${service}/${service}.conf    IP.${count} = ${ip}\n
        ${count}    Evaluate    ${count} + 1
    END
    ${count}    Set Variable    1
    FOR    ${dns}    IN    @{SAN["dns"]}
        Append To File    ${LOGDIR}/certificate/${service}/${service}.conf    DNS.${count} = ${dns}\n
        ${count}    Evaluate    ${count} + 1
    END

generate new certificate with CA signing request
    [Arguments]    ${service}    ${san}    ${expired_date}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${expired_date}
    generate_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/${service}.crt    ${LOGDIR}/certificate/${service}/${service}.key    ${WORKDIR}/cluster_1/pki/ca.crt    ${WORKDIR}/cluster_1/pki/ca.key    ${start_date}    ${end_date}    ${san}

replace new secret
    [Arguments]    ${service}    ${namespace}=kube-system
    kubectl    replace -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml
    kubectl    rollout restart deployment/${service} -n ${namespace}

_encode file in base64
    [Arguments]    ${file}
    ${value}    OperatingSystem.Get File    ${file}
    ${encode_value}    Encode Base64    ${value}
    [Return]    ${encode_value}

add custom certificate to
    [Arguments]    ${service}    ${expired_date}=6 days, 23 hours    ${namespace}=kube-system
    backup certificate configuration    ${service}
    ${san}    get SAN ip and dns    ${service}
    generate new certificate with CA signing request    ${service}    ${san}    ${expired_date}
    create certificate secret file    ${service}    ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml    ${namespace}
    replace new secret    ${service}
    wait pods ready
    _modify expired date for secret    ${service}-cert    tls.crt    ${expired_date}

create CA
    [Arguments]    ${service}    ${CN}=kubernetes-customize
    execute command localy    mkdir -p ${LOGDIR}/certificate/${service}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/ca.key 2048
    execute command localy    openssl req -key ${LOGDIR}/certificate/${service}/ca.key -new -x509 -days 10 -sha256 -config ${DATADIR}/certificate/ca.conf -out ${LOGDIR}/certificate/${service}/ca.crt -subj "/CN=${CN}"

create certificate secret file
    [Arguments]    ${service}    ${file}    ${namespace}    ${ca}=True
    ${service_crt}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.crt
    ${service_key}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.key
    ${ca_crt}    _encode file in base64    ${WORKDIR}/cluster_1/pki/ca.crt
    Copy File    ${file}    ${LOGDIR}/certificate/${service}/${service}-cert.yaml
    ${extension}    Set Variable If    ${ca}    -cert    -tls
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    metadata name    ${service}${extension}
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    metadata namespace    ${namespace}
    Run Keyword If    ${ca}    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data ca.crt    ${ca_crt}
    Run Keyword If    not ${ca}    yaml_editor.Remove Key    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data ca.crt
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data tls.crt    ${service_crt}
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data tls.key    ${service_key}

create custom certificate to
    [Arguments]    ${service}    ${SAN}    ${namespace}    ${ca}=False
    execute command localy    mkdir -p ${LOGDIR}/certificate/${service}
    create client config    ${service}    ${SAN}
    Run Keyword If    ${ca}    generate new certificate with CA signing request    ${service}    ${SAN}
    ...    ELSE    generate new certificate without CA request    ${service}    ${SAN}
    create certificate secret file    ${service}    ${DATADIR}/certificate/template-cert.yaml    ${namespace}    ${ca}
    kubectl    apply -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml

generate new certificate without CA request
    [Arguments]    ${service}    ${san}    ${expired_date}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${expired_date}
    generate_self_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/${service}.crt    ${LOGDIR}/certificate/${service}/${service}.key    ${start_date}    ${end_date}    ${san}

replace certificate to service
    [Arguments]    ${service}    ${namespace}
    backup certificate configuration    ${service}
    ${SAN}    get SAN ip and dns    ${service}
    create custom certificate to    ${service}    ${SAN}    ${namespace}    True
    replace new secret    ${service}

generate start_date and end_date
    [Arguments]    ${expired_time}
    ${expired_time}    String.Remove String    ${expired_time}    ,
    ${start_date} =    Get Current Date    UTC    exclude_millis=yes    result_format=%Y%m%d%H%M%S
    ${end_date} =    Add Time To Date    ${start_date}    ${expired_time}    exclude_millis=yes    result_format=%Y%m%d%H%M%S
    ${start_date} =    Set Variable    ${start_date[2:]}Z
    ${end_date} =    Set Variable    ${end_date[2:]}Z
    [Return]    ${start_date}    ${end_date}

deploy reloader
    helm    repo add stakater https://stakater.github.io/stakater-charts
    helm    repo update
    helm    install stakater/reloader --name reloader --namespace kube-system
    wait deploy    reloader-reloader -n kube-system

deploy cert-manager
    helm    repo add jetstack https://charts.jetstack.io
    helm    repo update
    helm    install jetstack/cert-manager --name cert-manager --namespace kube-system --version v0.15.0 --set installCRDs=true
    wait deploy    cert-manager -n kube-system

annotate dex gangway and metrics secret for reload
    kubectl    -n kube-system annotate deploy/oidc-dex secret.reloader.stakater.com/reload=oidc-dex-cert --overwrite
    kubectl    -n kube-system annotate deploy/oidc-gangway secret.reloader.stakater.com/reload=oidc-gangway-cert --overwrite
    kubectl    -n kube-system annotate deploy/metrics-server secret.reloader.stakater.com/reload=metrics-server-cert --overwrite

create kubernetes CA issuer secret
    [Arguments]    ${cluster_number}=1
    kubectl    create secret tls kubernetes-ca --cert=${CLUSTERDIR}_${cluster_number}/pki/ca.crt --key=${CLUSTERDIR}_${cluster_number}/pki/ca.key -n kube-system    ${cluster_number}
    Wait Until Keyword Succeeds    2 min    5 sec    kubectl    apply -f ${DATADIR}/manifests/certificate/issuer.yaml    ${cluster_number}

create certificate rotation manifest
    [Arguments]    ${service}    ${common_name}    ${SAN}    ${duration}=8760    ${renew_before}=720
    ${dns_list}    Set Variable    ${SAN["dns"]}
    ${ip_list}    Set Variable    ${SAN["ip"]}
    ${lt_dns}    Get Length    ${dns_list}
    ${lt_ip}    Get Length    ${ip_list}
    ${manifest}    OperatingSystem.Get File    ${DATADIR}/manifests/certificate/template-certificate.yaml
    ${manifest_dictionnary}    Safe Load    ${manifest}
    Set To Dictionary    ${manifest_dictionnary["metadata"]}    name=${service}-cert
    Set To Dictionary    ${manifest_dictionnary["spec"]}    secretName=${service}-cert
    Set To Dictionary    ${manifest_dictionnary["spec"]}    commonName=${common_name}
    Set To Dictionary    ${manifest_dictionnary["spec"]}    duration=${duration}
    Set To Dictionary    ${manifest_dictionnary["spec"]}    renewBefore=${renew_before}
    Run Keyword If    ${lt_ip} > 0    Set To Dictionary    ${manifest_dictionnary["spec"]}    ipAddresses=${ip_list}
    Run Keyword If    ${lt_dns} > 0    Set To Dictionary    ${manifest_dictionnary["spec"]}    dnsNames=${dns_list}
    ${manifest_stream}    Dump    ${manifest_dictionnary}
    Create File    ${LOGDIR}/${service}-certificate.yaml    ${manifest_stream}

create and apply rotation certificate manifest for
    [Arguments]    ${service}    ${duration}=8760h    ${renew_before}=720h
    backup certificate configuration    ${service}
    ${SAN}    get SAN ip and dns    ${service}
    ${common_name}    Set Variable If    "${service}"=="metrics-server"    metrics-server.kube-system.svc    ${service}
    create certificate rotation manifest    ${service}    ${common_name}    ${SAN}    ${duration}    ${renew_before}
    kubectl    apply -f ${LOGDIR}/${service}-certificate.yaml

check expired date for ${service} is sup to ${time}
    backup certificate configuration    ${service}
    ${certificate_time}    get_expiry_date    ${LOGDIR}/certificate/${service}/backup/${service}.crt
    ${convert_time}    Convert Date    ${certificate_time}    date_format=%Y%m%d%H%M%SZ
    ${current_time}    DateTime.Get Current Date    UTC
    ${expired_time}    DateTime.Subtract Date From Date    ${convert_time}    ${current_time}
    ${result}    DateTime.Subtract Time From Time    ${expired_time}    ${time}
    Should Be True    ${result} > 0

clean cert-manager
    Run Keyword And Ignore Error    helm    delete --purge reloader
    Run Keyword And Ignore Error    helm    delete --purge cert-manager
    Run Keyword And Ignore Error    kubectl    delete -f ${DATADIR}/manifests/certificate/issuer.yaml
    Run Keyword And Ignore Error    kubectl    delete secret kubernetes-ca -n kube-system

kubelet server certificate should be signed by kubelet-ca for each node
    ${master}    get master servers name    enable
    ${workers}    get worker servers name    enable
    ${nodes}    Combine Lists    ${master}    ${workers}
    FOR    ${node}    IN    @{nodes}
        ${ip}    get node ip from CS    ${node}
        check kubelet server certificate is signed by kubelet-ca    ${ip}
    END

check kubelet server certificate is signed by kubelet-ca
    [Arguments]    ${server_ip}    ${cluster_number}=1
    ${output}    openssl    s_client -connect ${server_ip}:10250 -CAfile /home/${VM_USER}/cluster/pki/kubelet-ca.crt <<< "Q"
    Should Contain    ${output}    issuer=/CN=kubelet-ca
    Should Contain    ${output}    Verify return code: 0 (ok)
