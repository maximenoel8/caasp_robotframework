*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot
Resource          ../parameters/tool_parameters.robot
Resource          ../parameters/vm_deployment.robot

*** Keywords ***
nfs client is deployed
    [Arguments]    ${server_ip}=${NFS_IP}    ${path}=${NFS_PATH}    ${mode}=Delete    ${cluster_number}=1
    Comment    ${nfs_ip}    Set Variable If    "${PLATFORM}"=="openstack"    ${PERMANENT_NFS_SERVER}    ${BOOTSTRAP_MASTER_1}
    ${nfs_ip}    Set Variable    ${PERMANENT_NFS_SERVER}
    Set Global Variable    ${nfs_ip}
    Set Global Variable    ${nfs_path}    /home/${VM_USER}/nfs/pv_folder
    Set Variable    ${server_ip}    ${nfs_ip}
    ${output}    kubectl    get pod -l app=nfs-client-provisioner -o name    cluster_number=${cluster_number}
    Run Keyword If    "${output}"=="${EMPTY}"    helm    install stable/nfs-client-provisioner --name nfs --set nfs.server="${server_ip}" --set nfs.path="${path}" --set storageClass.defaultClass=true --set storageClass.reclaimPolicy="${mode}"    cluster_number=${cluster_number}
    wait pods ready    -l app=nfs-client-provisioner    cluster_number=${cluster_number}
    step    Storage default class is setup for nfs

nfs server is deployed
    ${exist}    ${configure}    ${run}    _check nfs server install, configure and running
    Run Keyword If    not ${exist}    execute command with ssh    sudo zypper -n in nfs-kernel-server
    Run Keyword If    not ${configure}    execute command with ssh    mkdir -p /home/${VM_USER}/nfs/pv_folder
    Run Keyword If    not ${configure}    execute command with ssh    sudo chown nobody:nogroup /home/${VM_USER}/nfs/pv_folder
    Run Keyword If    not ${configure}    execute command with ssh    sudo sh -c 'echo "/home/${VM_USER}/nfs/pv_folder \ \ \ \ \ \ \ *(rw,no_root_squash,sync,no_subtree_check)" >> /etc/exports'
    Run Keyword If    not ${configure}    execute command with ssh    sudo exportfs -a
    Run Keyword If    not ${run} or not ${configure}    execute command with ssh    sudo systemctl restart nfs-server
    Run Keyword If    not ${run} or not ${configure}    sleep    15

_check nfs server install, configure and running
    ${status}    ${output}    Run Keyword And Ignore Error    execute command with ssh    sudo systemctl status nfs-server
    ${exports_value}    execute command with ssh    cat /etc/exports
    ${export_status}    ${output}    Run Keyword And Ignore Error    Should Contain    ${exports_value}    /home/${VM_USER}/nfs/pv_folder
    ${exist_status}    ${output}    Run Keyword And Ignore Error    Should Not Contain    ${output}    Unit nfs-server.service could not be found.
    ${run_status}    ${output}    Run Keyword And Ignore Error    Should Contain    ${output}    active    ignore_case=True
    ${exist_status}    Set Variable If    "${exist_status}"=="FAIL"    False    True
    ${run_status}    Set Variable If    "${run_status}"=="FAIL"    False    True
    ${export_status}    Set Variable If    "${export_status}"=="FAIL"    False    True
    [Return]    ${run_status}    ${export_status}    ${run_status}

storageclass is deployed
    [Arguments]    ${cluster_number}=1
    Comment    Run Keyword If    "${PLATFORM}"=="vmware" and ${cluster_number}==1    nfs server is deployed
    Run Keyword If    ( "${PLATFORM}"=="vmware" and not ${CPI_VSPHERE} ) or "${PLATFORM}"=="openstack"    nfs client is deployed    cluster_number=${cluster_number}
    Run Keyword If    "${PLATFORM}"=="vmware" and ${CPI_VSPHERE}    deploy storagedefault on vsphere    cluster_number=${cluster_number}
    Run Keyword If    "${PLATFORM}"=="aws"    deploy storagedefault on aws    cluster_number=${cluster_number}
    Run Keyword If    "${PLATFORM}"=="azure"    deploy storagedefault on azure    cluster_number=${cluster_number}

deploy storagedefault on aws
    [Arguments]    ${cluster_number}
    kubectl    apply -f ${DATADIR}/cpi/aws-default-storageclass.yaml    cluster_number=${cluster_number}
    step    Storage default class is setup for aws

deploy storagedefault on vsphere
    [Arguments]    ${cluster_number}
    kubectl    apply -f ${DATADIR}/cpi/vsphere-default-storageclass.yaml    cluster_number=${cluster_number}
    step    Storage default class is setup for vsphere

resolv dns
    [Arguments]    ${dns}
    ${result}    execute command localy    nslookup ${dns}
    ${results}    Split To Lines    ${result}
    ${elements}    Split String    ${results[4]}
    ${ip}    Set Variable    ${elements[1]}
    [Return]    ${ip}

step
    [Arguments]    ${message}
    ${message}    Evaluate    "\\033[1;92m${message}\\033[0m"
    Log    \n${message}    console=yes

deploy httpbin
    kubectl    apply -f ${DATADIR}/manifests/httpbin
    wait pods ready    -l app=httpbin

deploy tblshoot
    kubectl    apply -f ${DATADIR}/manifests/tblshoot
    wait pods ready    -l app=tblshoot

get number of files in ${directory} on ${node}
    [Documentation]    Return file lists and number of element in directory on specific node
    Switch Connection    ${node}
    ${list}    SSHLibrary.List Files In Directory    ${directory}
    ${lt}    Get Length    ${list}
    [Return]    ${list}    ${lt}

deploy storagedefault on azure
    [Arguments]    ${cluster_number}
    kubectl    apply -f ${DATADIR}/cpi/azure-default-storageclass.yaml    cluster_number=${cluster_number}
    step    Storage default class is setup for azure

format disk to vms
    [Arguments]    ${cluster_number}=1
    step    Format disk on vms
    run commands on nodes    ${cluster_number}    sudo zypper -n install lvm2    sudo sgdisk --zap-all /dev/sdb

deploy pod with pvc
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/csi/rbd/pvc.yaml
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/csi/rbd/pod.yaml
    wait pods ready    csirbd-demo-pod
