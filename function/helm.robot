*** Settings ***
Resource          commands.robot
Resource          tools.robot

*** Keywords ***
helm is installed
    [Arguments]    ${cluster_number}=1
    ${status}    check helm already install    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL"    install helm    ${cluster_number}
    ${suse_charts}    set variable if    "${CHART_PULL_REQUEST}"=="${EMPTY}"    suse-charts    ${LOGDIR}/kubernetes-charts-suse-com/stable
    Set Global Variable    ${suse_charts}

check helm already install
    [Arguments]    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    helm    version    ${cluster_number}
    [Return]    ${status}

install helm
    [Arguments]    ${cluster_number}=1
    ${helm_full_version}    helm    version -c --template "{{.Client.SemVer}}" | sed 's/^v//'    ${cluster_number}
    ${helm_image}    Set Variable    registry.suse.com/caasp/v4/helm-tiller:${helm_full_version}
    Run Keyword If    ${HELM_VERSION}==2    kubectl    create serviceaccount -n kube-system tiller    ${cluster_number}
    Run Keyword If    ${HELM_VERSION}==2    kubectl    create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller    ${cluster_number}
    Run Keyword If    ${HELM_VERSION}==2    helm    init --tiller-image ${helm_image} --service-account tiller --wait    ${cluster_number}
    helm    repo add suse-charts https://kubernetes-charts.suse.com    ${cluster_number}
    helm    repo add bitnami https://charts.bitnami.com/bitnami    ${cluster_number}
    helm    repo add stable https://kubernetes-charts.storage.googleapis.com
    step    helm is installed
