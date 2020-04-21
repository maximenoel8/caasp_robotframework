*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../interaction_with_cluster_state_dictionnary.robot
Resource          ../setup_environment.robot

*** Keywords ***
nginx is deployed
    helm    install --name nginx-ingress --namespace nginx-ingress suse-charts/nginx-ingress --values ${DATADIR}/nginx/nginx-ingress-config-values.yaml
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

resources pear and apple are deployed
    kubectl    apply -f ${DATADIR}/nginx/nginx-pear.yaml --wait
    kubectl    apply -f ${DATADIR}/nginx/nginx-apple.yaml --wait
    wait pods ready    -l app=nginx-apple
    wait pods ready    -l app=nginx-pear

nginx ingress is patched
    kubectl    apply -f ${DATADIR}/nginx/nginx-ingress-rewrite.yaml --wait
    Sleep    10

service should be accessible
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:30443 | grep 'default backend - 404'
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:30443/apple | grep apple
    execute command localy    curl -skL https://${BOOTSTRAP_MASTER_1}:30443/pear | grep pear

teardown nginx testcase
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-ingress-rewrite.yaml
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-apple.yaml
    Run Keyword And Ignore Error    kubectl    delete -f $DATADIR/nginx-pear.yaml
    Run Keyword And Ignore Error    helm    delete nginx-ingress --purge
