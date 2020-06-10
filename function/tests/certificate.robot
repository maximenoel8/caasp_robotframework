*** Settings ***
Resource          ../commands.robot
Library           ../../lib/base64_encoder.py
Library           ../../lib/yaml_editor.py
Resource          ../cluster_helpers.robot
Resource          monitoring/grafana_dashboard.robot
Library           DateTime
Library           ../../lib/openssl_library.py

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
