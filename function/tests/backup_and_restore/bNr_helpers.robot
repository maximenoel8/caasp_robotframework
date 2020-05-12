*** Settings ***
Resource          ../../commands.robot
Resource          ../../cluster_helpers.robot
Resource          bNr_common.robot
Resource          ../../tools.robot

*** Keywords ***
elasticsearch is deployed
    helm    repo add elastic https://helm.elastic.co
    helm    install \ \ \ \ \ \ \ \ \ \ \ \ \ \ --name elasticsearch elastic/elasticsearch \ \ \ \ \ \ \ \ \ \ \ \ \ \ --set volumeClaimTemplate.storageClassName="nfs-client" \ \ \ \ \ \ \ \ \ \ \ \ \ \ --namespace kube-system
    ${elasticsearch_pods_name}    wait podname    -l app=elasticsearch-master -n kube-system
    Set Test Variable    ${elasticsearch_pods_name}

elasticsearch is removed
    helm    delete --purge elasticsearch
    ${pvc_list}    get ressource name    -l app=elasticsearch-master -n kube-system    pvc
    FOR    ${pvc}    IN    @{pvc_list}
        kubectl    delete pvc ${pvc} -n kube-system
    END

elasticsearch annotate volume to be backup
    FOR    ${es_pod}    IN    @{elasticsearch_pods_name}
        annotate volume to be backed up    ${es_pod} -n kube-system    elasticsearch-master
    END

load data in elasticsearch
    [Arguments]    ${cluster_number}=1
    kubectl    delete svc expose-elasticsearch-master-0 -n kube-system
    ${node_port}    expose service    pod elasticsearch-master-0    9200    kube-system
    Set Test Variable    ${node_port}
    execute command localy    cd ${LOGDIR} && git clone https://github.com/oliver006/elasticsearch-test-data
    execute command localy    pip3 install -r ${LOGDIR}/elasticsearch-test-data/requirements.txt
    execute command localy    python3 ${LOGDIR}/elasticsearch-test-data/es_test_data.py --es_url=http://${BOOTSTRAP_MASTER_${cluster_number}}:${node_port}

redeploy elasticsearch has data
    [Arguments]    ${cluster_number}=1
    kubectl    delete svc expose-elasticsearch-master-0 -n kube-system
    ${node_port}    expose service    pod elasticsearch-master-0    9200    kube-system
    ${output}    execute command localy    curl -XGET 'http://${BOOTSTRAP_MASTER_${cluster_number}}:${node_port}/test_data/_count' | jq -r .count
    Should Contain    ${output}    10000

stop etcd ressource on
    [Arguments]    ${alias}
    execute command with ssh    sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/    ${alias}

purge etcd data on
    [Arguments]    ${alias}
    execute command with ssh    sudo rm -rf /var/lib/etcd    ${alias}

start etcd ressource on
    [Arguments]    ${node}    ${cluster_number}=1
    execute command with ssh    sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/    ${CLUSTER_PREFIX}-${cluster_number}-${node}

stop etcd ressource on all masters
    @{masters}    get master servers name
    FOR    ${master}    IN    @{masters}
        stop etcd ressource on    ${master}
    END

purge etcd data on all masters
    @{masters}    get master servers name
    FOR    ${master}    IN    @{masters}
        purge etcd data on    ${master}
    END
    step    etcd is purged from all the master
