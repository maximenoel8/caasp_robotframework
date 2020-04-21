*** Settings ***
Resource          ../../commands.robot
Resource          ../../../parameters/global_parameters.robot
Library           ../../../lib/yaml_editor.py
Resource          ../../cluster_helpers.robot
Resource          ../../interaction_with_cluster_state_dictionnary.robot
Resource          ../../setup_environment.robot
Resource          ../centralized_logging.robot

*** Variables ***
${etcd_snapshot_path}    /home/${VM_USER}

*** Keywords ***
etcd-backup job is executed
    configure etcd-backup job
    kubectl    create -f ${LOGDIR}/snapshot_job.yaml
    wait job    etcd-backup -n kube-system    condition=complete
    SSHLibrary.Get File    ${etcd_snapshot_path}/etcd-snapshot-${cluster}.db    ${LOGDIR}/etcd-snapshot-${cluster}.db
    execute command with ssh    rm ${etcd_snapshot_path}/etcd-snapshot-${cluster}.db    alias=bootstrap_master_1

teardown etcdctl
    Run Keyword And Ignore Error    kubectl    delete jobs etcd-backup -n kube-system
    [Teardown]    teardown centralized log

configure etcd-backup job
    [Arguments]    ${cluster_number}=1
    ${etcd_image}    execute command with ssh    sudo grep image: /etc/kubernetes/manifests/etcd.yaml | awk '{print $2}'    alias=bootstrap_master_${cluster_number}
    Copy File    ${DATADIR}/snapshot_job.yaml    ${LOGDIR}
    Modify Add Value    ${LOGDIR}/snapshot_job.yaml    spec template spec containers 0 image    ${etcd_image}
    Modify Add Value    ${LOGDIR}/snapshot_job.yaml    spec template spec volumes 1 hostPath path    ${etcd_snapshot_path}
    Remove Key    ${LOGDIR}/snapshot_job.yaml    spec template spec nodeSelector
    ${master_name}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-master-0
    Modify Add Value    ${LOGDIR}/snapshot_job.yaml    spec template spec nodeName    ${master_name}    True
    Modify Add Value    ${LOGDIR}/snapshot_job.yaml    spec template spec containers 0 command    removechar["/bin/sh"]
    Modify Add Value    ${LOGDIR}/snapshot_job.yaml    spec template spec containers 0 args    removechar["-c", "etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key snapshot save /backup/etcd-snapshot-${cluster}.db"]
    remove string from file    ${LOGDIR}/snapshot_job.yaml    removechar

install etcdctl on node
    [Arguments]    ${alias}
    execute command with ssh    sudo zypper -n in etcdctl    ${alias}

restore etcd data on
    [Arguments]    ${node}    ${cluster_number}=1
    ${node_ip}    get node ip from CS    ${CLUSTER_PREFIX}-${cluster_number}-${node}
    Switch Connection    ${CLUSTER_PREFIX}-${cluster_number}-${node}
    Put File    ${LOGDIR}/etcd-snapshot-${cluster}.db    ${etcd_snapshot_path}/etcd-snapshot-${cluster}.db
    ${server_name}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-${node}
    ${node_ip}    Set Variable If    "${PLATFORM}"=="aws"    ${server_name}    ${node_ip}
    execute command with ssh    sudo ETCDCTL_API=3 etcdctl snapshot restore ${etcd_snapshot_path}/etcd-snapshot-${cluster}.db\ --data-dir /var/lib/etcd --name ${server_name} --initial-cluster ${server_name}=https://${NODE_IP}:2380 \ --initial-advertise-peer-urls https://${NODE_IP}:2380    alias=bootstrap_master_${cluster_number}

get etcd cluster member list with etcdctl
    [Arguments]    ${alias}=bootstrap_master_1
    ${output}    Wait Until Keyword Succeeds    2min    10sec    execute command with ssh    sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \ --cacert=/etc/kubernetes/pki/etcd/ca.crt \ --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \ --key=/etc/kubernetes/pki/etcd/healthcheck-client.key member list    ${alias}
    [Return]    ${output}

install etcdctl on masters
    @{masters}    get master servers name
    Get Connections
    FOR    ${master}    IN    @{masters}
        install etcdctl on node    ${master}
    END

check master started in etcdctl list
    [Arguments]    ${node}    ${cluster_number}=1
    Wait Until Keyword Succeeds    2min    15sec    check master status in etcdctl is started    ${node}    ${cluster_number}

add master to the etcd member list with etcdctl
    [Arguments]    ${master}    ${cluster_number}=1
    ${node_ip}    get node ip from CS    ${CLUSTER_PREFIX}-${cluster_number}-${master}
    ${server_name}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-${master}
    ${node_ip}    Set Variable If    "${PLATFORM}"=="aws"    ${server_name}    ${node_ip}
    execute command with ssh    sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \ --cacert=/etc/kubernetes/pki/etcd/ca.crt \ --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \ member add ${server_name} --peer-urls=https://${NODE_IP}:2380    alias=bootstrap_master_${cluster_number}

delete etcd-backup job
    kubectl    delete job etcd-backup -n kube-system
    wait pod deleted    -l job-name=etcd-backup -n kube-system

check master status in etcdctl is started
    [Arguments]    ${node}    ${cluster_number}=1
    ${output}    get etcd cluster member list with etcdctl
    ${node}    get node skuba name    ${CLUSTER_PREFIX}-${cluster_number}-${node}
    @{lines}    Split To Lines    ${output}
    FOR    ${line}    IN    @{lines}
        ${line}    Remove String    ${line}    ${SPACE}
        ${values}    Split String    ${line}    ,
        ${node_present}    Set Variable If    "${values[2]}"=="${node}"    True    False
        ${node_started}    Set Variable If    "${values[1]}"=="started" and ${node_present}    True    False
        Exit For Loop If    ${node_present}
    END
    Should Be Equal    ${node_started}    True
