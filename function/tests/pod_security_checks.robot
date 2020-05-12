*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../setup_environment.robot
Resource          ../tools.robot

*** Keywords ***
PodSecurityPolicy is enabled on master
    step    enabling PSP on master
    ${output}    execute command with ssh    sudo grep 'enable-admission-plugins=.*PodSecurityPolicy' /etc/kubernetes/manifests/kube-apiserver.yaml    bootstrap_master_1
    Should Not Be Empty    ${output}

any user can access unprivileged psp
    step    check any user can access unprivileged psp
    kubectl    auth can-i use psp/suse.caasp.psp.unprivileged --as=any-user | grep -x yes

any user can not access privileged psp
    step    check any user can NOT access privileged psp
    kubectl    auth can-i use psp/suse.caasp.psp.privileged --as=any-user | grep -x no

deployment uses hostNetwork
    kubectl    apply -f "${DATADIR}/nginx/nginx-hostnetwork-deployment.yaml" --wait

deployment is not allowed
    ${output}    kubectl    get deployment nginx-hostnetwork-deployment -o jsonpath='{.status.conditions[*].message}'
    Should Contain    ${output}    unable to validate against any pod security policy: [spec.securityContext.hostNetwork: Invalid value: true: Host network is not allowed to be used]

patching deployment to not use hostNetwork
    kubectl    patch deployment nginx-hostnetwork-deployment -p '{"spec":{"template":{"spec":{"hostNetwork":false}}}}'
    wait deploy    nginx-hostnetwork-deployment

deployment is allow
    kubectl    get deployment -l app=nginx-psp -o jsonpath='{.items[*].status.readyReplicas}' | grep '1'

teardown psp
    kubectl    delete deployment nginx-hostnetwork-deployment
    [Teardown]    teardown_test
