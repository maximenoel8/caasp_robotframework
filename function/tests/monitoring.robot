*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          selenium.robot
Resource          ../setup_environment.robot

*** Keywords ***
grafana is deployed
    kubectl    apply -f ${DATADIR}/monitoring/grafana-datasources.yaml
    helm    install --name grafana suse-charts/grafana --namespace monitoring --values ${DATADIR}/monitoring/grafana-config-values.yaml
    wait_deploy    -n monitoring grafana    15m

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
    Expose grafana server
    deploy selenium pod
    selenium_grafana

prometheus dashboard should be accessible
    Expose prometheus server
    deploy selenium pod
    selenium_prometheus

Expose prometheus server
    ${prometheus_port}    expose service    service prometheus-pushgateway    9091    monitoring
    Set Test Variable    ${prometheus_port}

Expose grafana server
    ${grafanaPort}    expose service    deployment grafana    3000    monitoring
    Set Test Variable    ${grafanaPort}

prometheus is deployed
    helm    install --name prometheus suse-charts/prometheus --namespace monitoring --values ${DATADIR}/monitoring/prometheus-config-values.yaml
    add certficate exporter
    wait_deploy    -n monitoring prometheus-server    15m
    wait_deploy    -n monitoring prometheus-alertmanager    15m
    wait_deploy    -n monitoring prometheus-kube-state-metrics    15m
    wait_deploy    -n monitoring prometheus-pushgateway    15m

cleaning monitoring
    Run Keyword And Ignore Error    helm    delete prometheus --purge
    Run Keyword And Ignore Error    helm    delete grafana --purge
    Run Keyword And Ignore Error    kubectl    delete namespace monitoring
    [Teardown]    teardown_test

grafana is deployed custom
    helm    install --name grafana --namespace monitoring --values ./grafana-config-values.yaml --set downloadDashboardsImage.repository=registry.suse.de/devel/caasp/4.0/staging/4.1.2/suse_sle-15-sp1_update_products_casp40_update_containers/caasp/v4/curl --set downloadDashboardsImage.pullPolicy=Always --set initChownData.image.repository=registry.suse.de/devel/caasp/4.0/staging/4.1.2/suse_sle-15-sp1_update_products_casp40_update_containers/caasp/v4/busybox --set initChownData.image.pullPolicy=Always --set sidecar.image=registry.suse.de/devel/caasp/4.0/staging/4.1.2/suse_sle-15-sp1_update_products_casp40_update_containers/caasp/v4/k8s-sidecar:0.1.75 --set sidecar.imagePullPolicy=Always grafana

add certficate exporter
    helm    install --name cert-exporter --namespace monitoring --set image.repository=registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/cert-exporter ${LOGDIR}/kubernetes-charts-suse-com/stable/cert-exporter/ --wait
    kubectl    label --overwrite secret oidc-dex-cert -n kube-system caasp.suse.com/skuba-addon=true
    kubectl    label --overwrite secret oidc-gangway-cert -n kube-system caasp.suse.com/skuba-addon=true

deploy dashboard
    kubectl    apply -f https://raw.githubusercontent.com/jenting/caasp-monitoring/caasp-certs/grafana-dashboards-caasp-certificates.yaml

reboot cert-exporter
    kubectl    rollout restart deployment/cert-exporter-node -n monitoring
