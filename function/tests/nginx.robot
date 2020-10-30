*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../interaction_with_cluster_state_dictionnary.robot
Resource          ../setup_environment.robot
Resource          ../tools.robot

*** Keywords ***
nginx is deployed
    [Arguments]    ${cluster_number}=1
    step    deploying nginx service
    ${output}    kubectl    get pod -l app=nginx-ingress -n nginx-ingress -o name    cluster_number=${cluster_number}
    ${status}    ${_}    Run Keyword And Ignore Error    Should Not Be Empty    ${output}
    Run Keyword And Ignore Error    kubectl    create namespace nginx-ingress
    ${naming}    Set Variable If    ${HELM_VERSION}==2    --name nginx-ingress    nginx-ingress
    Run Keyword If    "${status}"=="FAIL"    helm    install --namespace nginx-ingress --values ${DATADIR}/nginx/nginx-ingress-config-values.yaml ${naming} ${suse_charts}/nginx-ingress    cluster_number=${cluster_number}
    wait deploy    -n nginx-ingress --all

can access nginx server
    execute command localy    curl ${BOOTSTRAP_MASTER_1}:${node_port} | grep 'Thank you'

teardown nginx
    kubectl    delete deploy,svc nginx
    [Teardown]    teardown_test

nginx is deployed old
    kubectl    create deployment nginx --image=nginx:stable-alpine
    @{workers}    get worker servers name
    ${length}    Get Length    ${workers}
    ${replicats}    Evaluate    ${length} * 2
    kubectl    scale deployment nginx --replicas=${replicats}
    wait deploy    nginx
    ${node_port}    expose service    deployment nginx    80
    Set Test Variable    ${node_port}
    step    nginx is deployed

resources pear and apple are deployed
    step    deploying pear and apple services
    kubectl    apply -f ${DATADIR}/nginx/nginx-pear.yaml --wait
    kubectl    apply -f ${DATADIR}/nginx/nginx-apple.yaml --wait
    wait pods ready    -l app=nginx-apple
    wait pods ready    -l app=nginx-pear
    step    ressource pear and apple are deployed

nginx ingress is patched
    kubectl    apply -f ${DATADIR}/nginx/nginx-ingress-rewrite.yaml --wait
    Sleep    5

service should be accessible
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:32443 | grep 'default backend - 404'
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:32443/apple | grep apple
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:32443/pear | grep pear

teardown nginx testcase
    ${purge}    Set Variable If    ${HELM_VERSION}==2    --purge    ${EMPTY}
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-ingress-rewrite.yaml
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-apple.yaml
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-pear.yaml
    Run Keyword And Ignore Error    helm    delete ${purge} nginx-ingress
    Run Keyword And Ignore Error    kubectl    delete deployment nginx
    [Teardown]    teardown_test

update /etc/hosts
    Copy File    /etc/hosts    ${LOGDIR}/hosts.backup
    Copy File    ${LOGDIR}/hosts.backup    ${LOGDIR}/hosts
    ${status}    ${output}    Run Keyword And Ignore Error    Should Match Regexp    ${BOOTSTRAP_MASTER_1}    ^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$
    ${ip}    Run Keyword If    "${status}"=="FAIL"    resolv dns    ${BOOTSTRAP_MASTER_1}
    ...    ELSE    Set Variable    ${BOOTSTRAP_MASTER_1}
    Append To File    ${LOGDIR}/hosts    ${ip} \ \ \ k8s-dashboard.cluster.com prometheus.example.com prometheus-alertmanager.example.com grafana.example.com
    execute command localy    sudo cp ${LOGDIR}/hosts /etc/hosts
