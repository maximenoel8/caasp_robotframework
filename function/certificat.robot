*** Settings ***
Resource          commands.robot

*** Keywords ***
kubelet server certificate should be signed by kubelet-ca for each node
    ${master}    get master servers name
    ${workers}    get worker servers name
    ${nodes}    Combine Lists    ${master}    ${workers}
    FOR    ${node}    IN    @{nodes}
        ${ip}    get node ip from CS    ${node}
        check kubelet server certificate is signed by kubelet-ca    ${ip}
    END

check kubelet server certificate is signed by kubelet-ca
    [Arguments]    ${server_ip}
    ${output}    openssl    s_client -connect ${server_ip}:10250 -CAfile ${CLUSTERDIR}/pki/kubelet-ca.crt <<< "Q"
    Should Contain    ${output}    CN = kubelet-ca
    Should Contain    ${output}    Verify return code: 0 (ok)
