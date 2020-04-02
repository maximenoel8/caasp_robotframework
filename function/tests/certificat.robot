*** Settings ***
Resource          ../commands.robot

*** Keywords ***
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
