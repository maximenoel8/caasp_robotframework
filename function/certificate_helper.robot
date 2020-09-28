*** Settings ***
Resource          commands.robot
Library           ../lib/base64_encoder.py
Library           ../lib/openssl_library.py
Resource          helper.robot
Library           DateTime
Resource          tools.robot
Resource          skuba_commands.robot

*** Keywords ***
create kubernetes CA issuer secret
    [Arguments]    ${certificate_folder}=default    ${issuer_name}=default    ${cluster_number}=1
    step    create kubernetes CA issuer secret
    Create Directory    ${LOGDIR}/manifests/certificate/
    ${certificate_folder}    Set Variable If    "${certificate_folder}"=="default"    ${CLUSTERDIR}_${cluster_number}/pki    ${certificate_folder}
    ${issuer_dico}    open yaml file    ${DATADIR}/manifests/certificate/issuer.yaml
    ${issuer_name}    Set Variable If    "${issuer_name}"=="default"    kubernetes-ca    ${issuer_name}
    Set To Dictionary    ${issuer_dico["spec"]["ca"]}    secretName=${issuer_name}
    Set To Dictionary    ${issuer_dico["metadata"]}    name=${issuer_name}
    ${ouput}    Dump    ${issuer_dico}
    Create File    ${LOGDIR}/manifests/certificate/issuer.yaml    ${ouput}
    kubectl    create secret tls ${issuer_name} --cert=${certificate_folder}/ca.crt --key=${certificate_folder}/ca.key -n kube-system    ${cluster_number}
    Wait Until Keyword Succeeds    2 min    5 sec    kubectl    apply -f ${LOGDIR}/manifests/certificate/issuer.yaml    ${cluster_number}

generate start_date and end_date
    [Arguments]    ${expired_time}
    ${expired_time}    String.Remove String    ${expired_time}    ,
    ${start_date} =    Get Current Date    UTC    exclude_millis=yes    result_format=%Y%m%d%H%M%S
    ${end_date} =    Add Time To Date    ${start_date}    ${expired_time}    exclude_millis=yes    result_format=%Y%m%d%H%M%S
    ${start_date} =    Set Variable    ${start_date[2:]}Z
    ${end_date} =    Set Variable    ${end_date[2:]}Z
    [Return]    ${start_date}    ${end_date}

generate new certificate without CA request
    [Arguments]    ${service}    ${san}    ${duration}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_self_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/${service}.crt    ${LOGDIR}/certificate/${service}/${service}.key    ${start_date}    ${end_date}    ${san}

_encode file in base64
    [Arguments]    ${file}
    ${value}    OperatingSystem.Get File    ${file}
    log    ${value}
    ${encode_value}    Encode Base64    ${value}
    log    ${encode_value}
    [Return]    ${encode_value}

generate new certificate with CA signing request
    [Arguments]    ${service}    ${san}    ${ca_crt}    ${ca_key}    ${duration}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/${service}.crt    ${LOGDIR}/certificate/${service}/${service}.key    ${ca_crt}    ${ca_key}    ${start_date}    ${end_date}    ${san}

create CA
    [Arguments]    ${service}    ${cn}=default    ${duration}=87600 hours    ${file_name}=ca
    ${cn}    Set Variable If    "${cn}"=="default"    ${service}    ${cn}
    Create Directory    ${LOGDIR}/certificate/${service}
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_self_signed_ssl_certificate    ${cn}    ${LOGDIR}/certificate/${service}/${file_name}.crt    ${LOGDIR}/certificate/${service}/${file_name}.key    ${start_date}    ${end_date}    CA=True

create CA with CA signing request
    [Arguments]    ${service}    ${duration}=87600 hours
    Create Directory    ${LOGDIR}/certificate/${service}
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/ca.crt    ${LOGDIR}/certificate/${service}/ca.key    ${WORKDIR}/cluster_1/pki/ca.crt    ${WORKDIR}/cluster_1/pki/ca.key    ${start_date}    ${end_date}    CA=True

add CA certificate to vm
    [Arguments]    ${service}    ${node}    ${cert_name}=ca
    Switch Connection    ${node}
    Put File    ${LOGDIR}/certificate/${service}/${cert_name}.crt    /home/${VM_USER}/
    execute command with ssh    sudo cp /home/${VM_USER}/${cert_name}.crt /etc/pki/trust/anchors/    ${node}
    execute command with ssh    sudo update-ca-certificates

add certificate to nodes
    [Arguments]    ${service}    ${cert_name}=ca
    @{nodes}    get nodes name from CS
    add CA certificate to vm    ${service}    skuba_station_1    ${cert_name}
    FOR    ${node}    IN    @{nodes}
        add CA certificate to vm    ${service}    ${node}    ${cert_name}
    END

add CA to server
    [Arguments]    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_15_${VM_VERSION}/SUSE:CA.repo    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper ref    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo zypper -n in ca-certificates-suse    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo update-ca-certificates    ${node}
    Run Keyword And Ignore Error    execute command with ssh    sudo systemctl restart crio    ${node}

add CA to all server
    [Arguments]    ${cluster_number}=1
    @{nodes}    get nodes name from CS    ${cluster_number}
    FOR    ${node}    IN    @{nodes}
        add CA to server    ${node}
    END

signed existing csr
    [Arguments]    ${key_path}    ${csr_path}    ${crt_path}    ${ca_crt}    ${ca_key}    ${duration}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    signed_certificate_request    ${key_path}    ${csr_path}    ${crt_path}    ${ca_crt}    ${ca_key}    ${start_date}    ${end_date}

day 1 customize oidc certificate without oidc-ca key
    [Arguments]    ${alias}
    ${issuer_CN}    Set Variable    oidc-ca
    And create CA    ${issuer_CN}    file_name=${issuer_CN}
    skuba generate oidc certiticate request    ${alias}
    signed existing csr    ${LOGDIR}/pki/oidc-dex-server.key    ${LOGDIR}/pki/oidc-dex-server.csr    ${LOGDIR}/pki/oidc-dex-server.crt    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.crt    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.key
    signed existing csr    ${LOGDIR}/pki/oidc-gangway-server.key    ${LOGDIR}/pki/oidc-gangway-server.csr    ${LOGDIR}/pki/oidc-gangway-server.crt    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.crt    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.key
    Switch Connection    ${alias}
    Copy File    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.crt    ${LOGDIR}/pki
    Put Directory    ${LOGDIR}/pki    /home/${VM_USER}/cluster/    0644
    modify string in file    ${LOGDIR}/kubeadm-init.conf    /etc/kubernetes/pki/ca.crt    /etc/kubernetes/pki/oidc-ca.crt
    Put File    ${LOGDIR}/kubeadm-init.conf    /home/${VM_USER}/cluster

day 1 customize oidc certificate with oidc-ca key
    [Arguments]    ${alias}
    ${issuer_CN}    Set Variable    oidc-ca
    And create CA    ${issuer_CN}    file_name=${issuer_CN}
    Switch Connection    ${alias}
    SSHLibrary.Get File    /home/${VM_USER}/cluster/kubeadm-init.conf    ${LOGDIR}/kubeadm-init.conf
    execute command with ssh    mkdir -p /home/${VM_USER}/cluster/pki    ${alias}
    Put file    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.crt    /home/${VM_USER}/cluster/pki    0644
    Put file    ${LOGDIR}/certificate/${issuer_CN}/${issuer_CN}.key    /home/${VM_USER}/cluster/pki    0600
    modify string in file    ${LOGDIR}/kubeadm-init.conf    /etc/kubernetes/pki/ca.crt    /etc/kubernetes/pki/oidc-ca.crt
    Put File    ${LOGDIR}/kubeadm-init.conf    /home/${VM_USER}/cluster
