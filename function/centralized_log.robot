*** Settings ***
Resource          commands.robot

*** Keywords ***
rsyslog is deployed
    helm    install suse-charts/log-agent-rsyslog --name rsyslog --wait

rsyslog is deleted
    helm    delete --purge rsyslog
