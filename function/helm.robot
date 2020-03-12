*** Settings ***
Resource          commands.robot

*** Keywords ***
helm is installed
    [Arguments]    ${cluster_number}=1
    ${status}    check helm already install    ${cluster_number}
    Run Keyword If    "${status}"=="FAIL"    install helm    ${cluster_number}

check helm already install
    [Arguments]    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    helm    version -s    ${cluster_number}
    [Return]    ${status}

install helm
    [Arguments]    ${cluster_number}=1
    ${helm_version}    helm    version -c --template "{{.Client.SemVer}}" | sed 's/^v//'    ${cluster_number}
    ${helm_image}    Set Variable    registry.suse.com/caasp/v4/helm-tiller:${helm_version}
    kubectl    create serviceaccount -n kube-system tiller    ${cluster_number}
    kubectl    create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller    ${cluster_number}
    helm    init --tiller-image ${helm_image} --service-account tiller --wait    ${cluster_number}
    helm    repo add suse-charts https://kubernetes-charts.suse.com    ${cluster_number}
