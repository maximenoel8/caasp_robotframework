*** Settings ***
Resource          generic_function.robot

*** Keywords ***
helm install
    ${helm_version}    execute command localy    helm version -c --template "{{.Client.SemVer}}" | sed 's/^v//'
    ${helm_image}    Set Variable    registry.suse.com/caasp/v4/helm-tiller:${helm_version}
    execute command localy    kubectl create serviceaccount -n kube-system tiller
    execute command localy    kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    execute command localy    helm init --tiller-image ${helm_image} --service-account tiller --wait
    execute command localy    helm repo add suse-charts https://kubernetes-charts.suse.com
