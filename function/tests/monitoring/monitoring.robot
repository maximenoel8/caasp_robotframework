*** Settings ***
Resource          ../../commands.robot
Resource          ../../cluster_helpers.robot
Resource          grafana_dashboard.robot
Resource          ../../setup_environment.robot
Resource          ../certificate.robot
Resource          ../selenium.robot

*** Keywords ***
grafana is deployed
    kubectl    apply -f ${DATADIR}/monitoring/grafana-datasources.yaml
    helm    install --name grafana suse-charts/grafana --namespace monitoring --values ${DATADIR}/monitoring/grafana-config-values.yaml
    wait_deploy    -n monitoring grafana    15m
    kubectl    apply -f ${DATADIR}/monitoring/ingress-grafana.yaml

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
    Comment    Expose grafana server
    selenium is deployed
    selenium_grafana

prometheus dashboard should be accessible
    Comment    Expose prometheus server
    selenium is deployed
    selenium_prometheus

Expose prometheus server
    ${prometheus_port}    expose service    service prometheus-pushgateway    9091    monitoring
    Set Test Variable    ${prometheus_port}

Expose grafana server
    ${grafanaPort}    expose service    deployment grafana    3000    monitoring
    Set Test Variable    ${grafanaPort}

prometheus is deployed
    create monitoring certificate
    helm    install --name prometheus suse-charts/prometheus --namespace monitoring --values ${DATADIR}/monitoring/prometheus-config-values.yaml
    add certificate exporter
    wait_deploy    -n monitoring prometheus-server    15m
    wait_deploy    -n monitoring prometheus-alertmanager    15m
    wait_deploy    -n monitoring prometheus-kube-state-metrics    15m
    wait_deploy    -n monitoring prometheus-pushgateway    15m

cleaning monitoring
    Comment    Run Keyword And Ignore Error    helm    delete prometheus --purge
    Comment    Run Keyword And Ignore Error    helm    delete grafana --purge
    Comment    Run Keyword And Ignore Error    kubectl    delete namespace monitoring
    Comment    Run Keyword And Ignore Error    helm    del --purge cert-exporter
    Run Keyword And Ignore Error    Close All Browsers
    [Teardown]    teardown_test

add certificate exporter
    kubectl    label --overwrite secret oidc-dex-cert -n kube-system caasp.suse.com/skuba-addon=true
    kubectl    label --overwrite secret oidc-gangway-cert -n kube-system caasp.suse.com/skuba-addon=true
    helm    install --name cert-exporter --namespace monitoring --set image.repository=registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/cert-exporter ${LOGDIR}/kubernetes-charts-suse-com/stable/cert-exporter/ --wait

deploy dashboard
    kubectl    apply -f https://raw.githubusercontent.com/jenting/caasp-monitoring/caasp-certs/grafana-dashboards-caasp-certificates.yaml

reboot cert-exporter
    kubectl    rollout restart deployment cert-exporter-addon -n monitoring
    kubectl    rollout restart ds cert-exporter-node -n monitoring

create monitoring certificate
    ${dns}    Create List    prometheus.example.com    prometheus-alertmanager.example.com    grafana.example.com
    ${ip}    Create List
    ${SAN}    Create Dictionary    dns=${dns}    ip=${ip}
    Run Keyword And Ignore Error    kubectl    create namespace monitoring
    create custom certificate to    monitoring    ${SAN}    monitoring
    kubectl    create secret generic -n monitoring prometheus-basic-auth --from-file=${DATADIR}/monitoring/auth

reboot grafana
    kubectl    rollout restart -n monitoring deployment grafana
    wait_deploy    -n monitoring grafana    15m
