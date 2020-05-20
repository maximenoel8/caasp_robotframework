*** Variables ***
${node_port}      30444
@{hostnames}      grafana.example.com    k8s-dashboard.cluster.com    prometheus.example.com    prometheus-alertmanager.example.com
${SELENIUM_URL}    ${EMPTY}