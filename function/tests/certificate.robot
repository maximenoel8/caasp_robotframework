*** Settings ***
Resource          ../commands.robot
Library           ../../lib/base64_encoder.py
Library           ../../lib/yaml_editor.py

*** Keywords ***
backup certificate configuration
    [Arguments]    ${service}
    execute command localy    mkdir -p ${LOGDIR}/certificate/${service}/backup
    kubectl    get secret ${service}-cert -n kube-system -o yaml > ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml
    execute command localy    cat ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml | grep tls.crt | awk '{print $2}' | base64 --decode | tee ${LOGDIR}/certificate/${service}/backup/${service}.crt > /dev/null
    execute command localy    cat ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml | grep tls.key | awk '{print $2}' | base64 --decode | tee ${LOGDIR}/certificate/${service}/backup/${service}.key > /dev/null

get SAN ip and dns
    [Arguments]    ${service}
    ${ip_status}    ${ip_value}    Run Keyword And Ignore Error    execute command localy    openssl x509 -noout -text -in ${LOGDIR}/certificate/${service}/backup/${service}.crt | grep -oP '(?<=IP Address:)[^,]+'
    ${dns_status}    ${dns_value}    Run Keyword And Ignore Error    execute command localy    openssl x509 -noout -text -in ${LOGDIR}/certificate/${service}/backup/${service}.crt | grep -oP '(?<=DNS:)[^,]+'
    @{san_ip}    Run Keyword If    "${ip_status}"=="PASS"    Split To Lines    ${ip_value}
    ...    ELSE    Create List
    @{san_dns}    Run Keyword If    "${dns_status}"=="PASS"    Split To Lines    ${dns_value}
    ...    ELSE    Create List
    ${SAN}    Create Dictionary    dns=${san_dns}    ip=${san_ip}
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
    [Arguments]    ${service}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/${service}.key 2048
    execute command localy    openssl req -key ${LOGDIR}/certificate/${service}/${service}.key \ -new -sha256 -out ${LOGDIR}/certificate/${service}/${service}.csr -config ${LOGDIR}/certificate/${service}/${service}.conf -subj "/CN=${service}"
    execute command localy    openssl x509 -req -CA ${WORKDIR}/cluster_1/pki/ca.crt -CAkey ${WORKDIR}/cluster_1/pki/ca.key -CAcreateserial -in ${LOGDIR}/certificate/${service}/${service}.csr -out ${LOGDIR}/certificate/${service}/${service}.crt -days 10 -extensions v3_req -extfile ${LOGDIR}/certificate/${service}/${service}.conf

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
    [Arguments]    ${service}    ${namespace}=kube-system
    backup certificate configuration    ${service}
    ${san}    get SAN ip and dns    ${service}
    Comment    create CA    ${service}
    create client config    ${service}    ${san}
    generate new certificate with CA signing request    ${service}
    create certificate secret file    ${service}    ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml    ${namespace}
    replace new secret    ${service}

create CA
    [Arguments]    ${service}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/ca.key 2048
    execute command localy    openssl req -key ${LOGDIR}/certificate/${service}/ca.key -new -x509 -days 10 -sha256 -config ${DATADIR}/certificate/ca.conf -out ${LOGDIR}/certificate/${service}/ca.crt -subj "/CN=kubernetes-customize"

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
    Comment    Run Keyword If    ${ca}    create CA    ${service}
    Run Keyword If    ${ca}    generate new certificate with CA signing request    ${service}
    ...    ELSE    generate new certificate without CA request    ${service}
    create certificate secret file    ${service}    ${DATADIR}/certificate/template-cert.yaml    ${namespace}    ${ca}
    kubectl    apply -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml

generate new certificate without CA request
    [Arguments]    ${service}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/${service}.key 2048
    execute command localy    openssl req -x509 -key ${LOGDIR}/certificate/${service}/${service}.key -new -out ${LOGDIR}/certificate/${service}/${service}.crt -config ${LOGDIR}/certificate/${service}/${service}.conf -subj "/CN=${service}" -extensions v3_req

replace certificate to service
    [Arguments]    ${service}    ${namespace}
    backup certificate configuration    ${service}
    ${SAN}    get SAN ip and dns    ${service}
    create custom certificate to    ${service}    ${SAN}    ${namespace}    True
    replace new secret    ${service}
