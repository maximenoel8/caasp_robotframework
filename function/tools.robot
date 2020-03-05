*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot
Resource          ../parameters/tool_parameters.robot

*** Keywords ***
nfs client is deployed
    [Arguments]    ${server_ip}=${NFS_IP}    ${path}=${NFS_PATH}    ${mode}=Delete
    ${output}    kubectl    get pod -l app=nfs-client-provisioner -o name
    Run Keyword If    "${output}"=="${EMPTY}"    helm    install stable/nfs-client-provisioner --name nfs --set nfs.server="${server_ip}" --set nfs.path="${path}" --set storageClass.defaultClass=true --set storageClass.reclaimPolicy="${mode}"
    wait pods    -l app=nfs-client-provisioner
