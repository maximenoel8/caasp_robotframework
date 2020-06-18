*** Settings ***
Resource          commands.robot
Library           ../lib/base64_encoder.py
Library           ../lib/openssl_library.py
Resource          helper.robot
Library           DateTime
Resource          tools.robot

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
    [Arguments]    ${service}    ${san}    ${duration}=6 days, 23 hours
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/${service}.crt    ${LOGDIR}/certificate/${service}/${service}.key    ${WORKDIR}/cluster_1/pki/ca.crt    ${WORKDIR}/cluster_1/pki/ca.key    ${start_date}    ${end_date}    ${san}

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

create CA
    [Arguments]    ${service}    ${duration}=87600 hours
    Create Directory    ${LOGDIR}/certificate/${service}
    ${start_date}    ${end_date}    generate start_date and end_date    ${duration}
    generate_self_signed_ssl_certificate    ${service}    ${LOGDIR}/certificate/${service}/ca.crt    ${LOGDIR}/certificate/${service}/ca.key    ${start_date}    ${end_date}    CA=True
