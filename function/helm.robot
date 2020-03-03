*** Settings ***
Resource          commands.robot

*** Keywords ***
helm is installed
    ${status}    check helm already install
    Run Keyword If    "${status}"=="FAIL"    install helm

check helm already install
    ${status}    ${output}    Run Keyword And Ignore Error    helm    version -s
    [Return]    ${status}

install helm
    ${helm_version}    helm    version -c --template "{{.Client.SemVer}}" | sed 's/^v//'
    ${helm_image}    Set Variable    registry.suse.com/caasp/v4/helm-tiller:${helm_version}
    kubectl    create serviceaccount -n kube-system tiller
    kubectl    create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    helm    init --tiller-image ${helm_image} --service-account tiller --wait
    helm    repo add suse-charts https://kubernetes-charts.suse.com
