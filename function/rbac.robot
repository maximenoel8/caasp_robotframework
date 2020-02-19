*** Settings ***
Resource          generic_function.robot
Library           ../lib/yaml_editor.py
Resource          ../parameters/389ds_parameters.robot
Resource          helpers.robot
Library           SSHLibrary

*** Keywords ***
389ds server installed
    Copy Directory    ${DATADIR}/389dss    ${LOGDIR}
    set 389ds variables
    Modify Add Value    ${LOGDIR}/389dss/389ds-deployment.yaml    spec template spec containers 0 image    ${DS_IMAGE}
    kubectl    create -f "${LOGDIR}/389dss"
    Sleep    30
    ${ldap_pod}    wait_podname    -l app=dirsrv-389ds -n kube-system
    ${root_certificate}    kubectl    --namespace=kube-system exec -it "${ldap_pod}" -- bash -c "cat /etc/dirsrv/ssca/ca.crt | base64 | awk '{print}' ORS=''"

authentication with skuba CI (group)
    Run Keyword And Ignore Error    kubectl    delete rolebinding italiansrb
    kubectl    create rolebinding italiansrb --clusterrole=admin --group=Italians
    Sleep    30
    skuba    auth login -u tesla@suse.com -p password -s https://${IP_LB}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c tesla.conf    True
    SSHLibrary.Get File    tesla.conf    ${LOGDIR}/tesla.conf
    kubectl    --kubeconfig=${LOGDIR}/tesla.conf auth can-i get rolebindings | grep -x yes
    kubectl    delete rolebinding italiansrb

authentication with skuba CI (users)
    Run Keyword And Ignore Error    kubectl    delete rolebinding curierb eulerrb
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    Sleep    30
    skuba    auth login -u curie@suse.com -p password -s https://${IP_LB}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c curie.conf    True
    SSHLibrary.Get File    curie.conf    ${LOGDIR}/curie.conf
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i delete pods | grep -x no
    skuba    auth login -u euler@suse.com -p password -s https://${IP_LB}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c euler.conf    True
    SSHLibrary.Get File    euler.conf    ${LOGDIR}/euler.conf
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i get rolebindings | grep -x no
    kubectl    --kubeconfig=${LOGDIR}/euler.conf get rolebindings | grep Forbidden
    kubectl    delete rolebinding curierb eulerrb
    Remove File    {LOGDIR}/curie.conf
    Remove File    {LOGDIR}/euler.conf

authentication with WebUI user
    #    step "Authentication users with selenium"
    #    info "Clean existing roles"
    kubectl    delete rolebinding curierb eulerrb || true
    #    info "Create roles"
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    sleep    30
    #    info 'WebUI kubeconfig (gangway) with VIEW role'
    #    $TESTDIR/selenium-auth.py -i $IP_LB -u curie@suse.com
    selenium_download    kubeconf.txt curie.conf
    kubectl    --kubeconfig=curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=curie.conf auth can-i delete pods | grep -x no
    #    info 'WebUI kubeconfig (gangway) with EDIT role'
    #    $TESTDIR/selenium-auth.py -i $IP_LB -u euler@suse.com
    selenium_download    kubeconf.txt euler.conf
    kubectl    --kubeconfig=euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=euler.conf auth can-i get rolebindings | grep -x no
    kubectl    --kubeconfig=euler.conf get rolebindings | grep Forbidden
    #    info 'Clean role binding'
    kubectl    delete rolebinding curierb eulerrb
    Remove File    ${WORKDIR}/curie.conf
    Remove File    ${WORKDIR}/euler.conf

users has been added to ldap
    execute command localy    LDAPTLS_REQCERT=allow ldapadd -v -H ldaps://${MASTER_IP[0]}:${DS_NODE_PORT} -D ${DS_ADMIN} -f ${DATADIR}/ldap_389ds.ldif -w ${DS_DM_PASSWORD}

dex is configured
    kubectl    get cm oidc-dex-config -n kube-system -o yaml >"${LOGPATH}/dex-config.yaml"
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 id    389ds
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 name    389ds
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config host    ${HOST}
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config ca    ${root_certificate}    True
    remove_key    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config insecureNoSSL
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config bindDN    ${DS_ADMIN}
    Modify Add Value    ${LOGPATH/dex-config.yaml}    "data config.yaml | connectors 0 config bindPW"    ${DS_DM_PASSWORD}
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config userSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config groupSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGPATH/dex-config.yaml}    data config.yaml | connectors 0 config groupSearch filter    (objectClass=groupOfNames)
    kubectl    apply -f "${LOGDIR}/dex-config.yaml"
    kubectl    delete pod -n kube-system -l app=oidc-dex --wait
    wait_pods    -l app=oidc-dex -n kube-system
