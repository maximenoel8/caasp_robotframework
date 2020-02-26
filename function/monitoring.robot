*** Settings ***
Resource          commands.robot
Resource          cluster_helpers.robot

*** Keywords ***
grafana is deployed
    helm    install --name grafana suse-charts/grafana --namespace monitoring --values ${DATADIR}/grafana-config-values.yaml
    wait_deploy    -n monitoring grafana

Checking prometheus-server health
    ${output}    kubectl    logs -n monitoring -l "app=prometheus,component=server" -c prometheus-server
    Should Contain    ${output}    Server is ready to receive web requests

Checking prometheus-alertmanager health
    ${output}    kubectl    logs -n monitoring -l "app=prometheus,component=alertmanager" -c prometheus-alertmanager
    Should Contain    ${output}    item=msg=Listening address=:

Checking prometheus-kube-state-metrics health
    ${output}    kubectl    logs -n monitoring -l "app=prometheus,component=kube-state-metrics"
    Should Contain    ${output}    Starting kube-state-metrics self metrics server
    BuiltIn.Should Not Match    ${output}    ^E[0-9]{4}

Checking prometheus-pushgateway health
    ${output}    kubectl    logs -n monitoring -l "app=prometheus,component=pushgateway"
    Should Contain    ${output}    item=msg=\"Listening on :

Checking grafana server health
    ${output}    kubectl    logs -n monitoring -l "app=grafana" -c grafana
    Should Contain    ${output}    HTTP Server Listen

Checking grafana dashboard health
    ${output}    kubectl    logs -n monitoring -l "app=grafana" -c grafana-sc-dashboard
    Should Contain    ${output}    Working on configmap monitoring/prometheus-server

grafana should be healthy
    Checking grafana server health
    Checking grafana dashboard health

prometheus should be healthy
    Checking prometheus-alertmanager health
    Checking prometheus-kube-state-metrics health
    Checking prometheus-pushgateway health
    Checking prometheus-server health

grafana dashboard should be accessible
    Log    TODO

prometheus dashboard should be accessible
    Log    TODO

Expose prometheus server

Expose grafana server

prometheus is deployed
    helm    install --name prometheus suse-charts/prometheus --namespace monitoring --values ${DATADIR}/prometheus-config-values.yaml
    wait_deploy    -n monitoring prometheus-server
    wait_deploy    -n monitoring prometheus-alertmanager
    wait_deploy    -n monitoring prometheus-kube-state-metrics
    wait_deploy    -n monitoring prometheus-pushgateway

cleaning monitoring
    helm    delete prometheus --purge
    helm    delete grafana --purge
