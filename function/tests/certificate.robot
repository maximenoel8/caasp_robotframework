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
    Create File    ${LOGDIR}/certificate/${service}/${service}.conf    [req]\n req_extensions = v3_req\n distinguished_name = req_distinguished_name\n \n [req_distinguished_name]\n \n [ v3_req ]\n basicConstraints = CA:FALSE\n keyUsage = nonRepudiation, digitalSignature, keyEncipherment\n subjectAltName = @alt_names\n \n [alt_names]\n
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

generate new certificate
    [Arguments]    ${service}
    execute command localy    openssl genrsa -out ${LOGDIR}/certificate/${service}/${service}.key 2048
    execute command localy    openssl req -key ${LOGDIR}/certificate/${service}/${service}.key \ -new -sha256 -out ${LOGDIR}/certificate/${service}/${service}.csr -config ${LOGDIR}/certificate/${service}/${service}.conf -subj "/CN=${service}"
    execute command localy    openssl x509 -req -CA ${WORKDIR}/cluster_1/pki/ca.crt -CAkey ${WORKDIR}/cluster_1/pki/ca.key -CAcreateserial -in ${LOGDIR}/certificate/${service}/${service}.csr -out ${LOGDIR}/certificate/${service}/${service}.crt -days 10 -extensions v3_req -extfile ${LOGDIR}/certificate/${service}/${service}.conf

replace new secret
    [Arguments]    ${service}
    ${service_crt}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.crt
    ${service_key}    _encode file in base64    ${LOGDIR}/certificate/${service}/${service}.key
    ${ca}    _encode file in base64    ${WORKDIR}/cluster_1/pki/ca.crt
    Copy File    ${LOGDIR}/certificate/${service}/backup/${service}-cert.yaml    ${LOGDIR}/certificate/${service}/${service}-cert.yaml
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data ca.crt    ${ca}
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data tls.crt    ${service_crt}
    Modify Add Value    ${LOGDIR}/certificate/${service}/${service}-cert.yaml    data tls.key    ${service_key}
    kubectl    replace -f ${LOGDIR}/certificate/${service}/${service}-cert.yaml
    kubectl    rollout restart deployment/${service} -n kube-system

_encode file in base64
    [Arguments]    ${file}
    ${value}    OperatingSystem.Get File    ${file}
    ${encode_value}    Encode Base64    ${value}
    [Return]    ${encode_value}

add custom certificate to
    [Arguments]    ${service}
    backup certificate configuration    ${service}
    ${san}    get SAN ip and dns    ${service}
    create client config    ${service}    ${san}
    generate new certificate    ${service}
    replace new secret    ${service}
