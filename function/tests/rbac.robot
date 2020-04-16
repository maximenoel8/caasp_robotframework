*** Settings ***
Resource          ../commands.robot
Library           ../../lib/yaml_editor.py
Resource          ../../parameters/389ds_parameters.robot
Resource          ../cluster_helpers.robot
Library           SSHLibrary
Resource          ../selenium.robot
Library           ../../lib/firefox_profile.py
Resource          ../setup_environment.robot

*** Keywords ***
389ds server is deployed
    Remove Directory    ${LOGDIR}/389dss    true
    Copy Directory    ${DATADIR}/389dss    ${LOGDIR}/389dss
    Modify Add Value    ${LOGDIR}/389dss/389ds-deployment.yaml    spec template spec containers 0 image    ${DS_IMAGE}
    kubectl    create -f "${LOGDIR}/389dss"
    Wait Until Keyword Succeeds    3min    10s    check_pod_log_contain    -l app=dirsrv-389ds -n kube-system    INFO - slapd_daemon - Listening on All Interfaces port 636 for LDAPS requests

authentication with skuba CI (group)
    [Arguments]    ${cluster_number}=1
    Run Keyword And Ignore Error    kubectl    delete rolebinding italiansrb
    kubectl    create rolebinding italiansrb --clusterrole=admin --group=Italians
    Sleep    30
    skuba    auth login -u tesla@suse.com -p password -s https://${IP_LB_${cluster_number}}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c tesla.conf    True
    SSHLibrary.Get File    /home/${VM_USER}/cluster/tesla.conf    ${LOGDIR}/tesla.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/tesla.conf
    kubectl    --kubeconfig=${LOGDIR}/tesla.conf auth can-i get rolebindings | grep -x yes
    kubectl    delete rolebinding italiansrb

authentication with skuba CI (users)
    [Arguments]    ${cluster_number}=1
    [Timeout]    4 minutes
    Run Keyword And Ignore Error    kubectl    delete rolebinding curierb eulerrb
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    Sleep    30
    skuba    auth login -u curie@suse.com -p password -s https://${IP_LB_${cluster_number}}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c curie.conf    True
    SSHLibrary.Get File    /home/${VM_USER}/cluster/curie.conf    ${LOGDIR}/curie.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/curie.conf
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i delete pods | grep -x no
    skuba    auth login -u euler@suse.com -p password -s https://${IP_LB_${cluster_number}}:32000 -r "/home/${VM_USER}/cluster/pki/ca.crt" -c euler.conf    True
    SSHLibrary.Get File    /home/${VM_USER}/cluster/euler.conf    ${LOGDIR}/euler.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/euler.conf
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i get rolebindings | grep -x no
    Run Keyword And Expect Error    STARTS: Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io is forbidden:    kubectl    --kubeconfig=${LOGDIR}/euler.conf get rolebindings
    kubectl    delete rolebinding curierb eulerrb
    Remove File    {LOGDIR}/curie.conf
    Remove File    {LOGDIR}/euler.conf

authentication with WebUI user
    deploy selenium pod
    Run Keyword And Ignore Error    kubectl    delete rolebinding curierb eulerrb || true
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    sleep    30
    selenium_authentication    curie@suse.com
    selenium_download    kubeconf    ${LOGDIR}/curie.conf
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i delete pods | grep -x no
    selenium_authentication    euler@suse.com
    selenium_download    kubeconf    ${LOGDIR}/euler.conf
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i get rolebindings | grep -x no
    Run Keyword And Expect Error    STARTS: Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io is forbidden:    kubectl    --kubeconfig=${LOGDIR}/euler.conf get rolebindings
    kubectl    delete rolebinding curierb eulerrb
    Remove File    ${LOGDIR}/curie.conf
    Remove File    ${LOGDIR}/euler.conf

users has been added to
    [Arguments]    ${type}    ${cluster_number}=1
    Run Keyword If    "${type}"=="openldap"    _add user for ldap
    ...    ELSE IF    "${type}"=="389ds"    execute command localy    LDAPTLS_REQCERT=allow ldapadd -v -H ldaps://${BOOTSTRAP_MASTER_${cluster_number}}:${DS_NODE_PORT} -D "${DS_ADMIN}" -f "${DATADIR}/ldap_389ds.ldif" -w "${DS_DM_PASSWORD}"
    ...    ELSE    Fail    Wrong value for ldap type

dex is configured for
    [Arguments]    ${type}
    kubectl    get cm oidc-dex-config -n kube-system -o yaml >"${LOGDIR}/dex-config.yaml"
    Copy File    ${LOGDIR}/dex-config.yaml    ${LOGDIR}/dex-config-ori.yaml
    Run Keyword If    "${type}"=="openldap"    _configure dex file config for openldap
    ...    ELSE IF    "${type}"=="389ds"    _configure dex file config for 389ds
    ...    ELSE IF    "${type}"=="static password"    _configure dex file config for static password
    ...    ELSE    Fail    Wrong ldap type
    kubectl    apply -f "${LOGDIR}/dex-config.yaml"
    kubectl    delete pod -n kube-system -l app=oidc-dex --wait
    wait pods ready    -l app=oidc-dex -n kube-system

clean 389ds server
    kubectl    delete -f "${DATADIR}/389dss"
    teardown_test

openldap server is deployed
    helm    install --name ldap --set adminPassword=admin --set env.LDAP_DOMAIN=example.com stable/openldap

_add user for ldap
    ${ldap_pod}    wait podname    -l app=openldap
    execute command localy    cat "${DATADIR}/ldap.ldif" | kubectl exec -i ${ldap_pod} -- ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin

_configure dex file config for 389ds
    ${ldap_pod}    wait podname    -l app=dirsrv-389ds -n kube-system
    ${output}    kubectl    --namespace=kube-system exec -it "${ldap_pod}" -- bash -c "cat /etc/dirsrv/ssca/ca.crt | base64 | awk \'{print}\' ORS=\'\'"
    ${root_certificate}    Split String    ${output}    \n
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 id    389ds
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 name    389ds
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config host    ${HOST}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config ca    ${root_certificate[1]}    True
    Remove Key    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config insecureNoSSL
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config bindDN    ${DS_ADMIN}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config bindPW    ${DS_DM_PASSWORD}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config userSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config groupSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config groupSearch filter    (objectClass=groupOfNames)
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | enablePasswordDB    false

_configure dex file config for openldap
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 id    openLDAP
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 name    openLDAP
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config bindDN    cn=admin,dc=example,dc=com
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config bindPW    admin
    Remove Key    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config ca
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config insecureNoSSL    true    True
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config host    ldap-openldap.default.svc
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config userSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config groupSearch filter    (objectClass=groupOfUniqueNames)
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config groupSearch baseDN    ${DS_SUFFIX}
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors 0 config groupSearch groupAttr    uniqueMember
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | enablePasswordDB    false

clean up openldap
    helm    delete --purge ldap
    [Teardown]    teardown_test

_configure dex file config for static password
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | enablePasswordDB    true    True
    Modify Add Value    ${LOGDIR}/dex-config.yaml    data config.yaml | staticPasswords    ${DATADIR}/users_static_password.yaml    True
    Remove Key    ${LOGDIR}/dex-config.yaml    data config.yaml | connectors

clean static password
    kubectl    apply -f ${LOGDIR}/dex-config-ori.yaml --force
    kubectl    delete pod -n kube-system -l app=oidc-dex --wait
    wait pods ready    -l app=oidc-dex -n kube-system
    [Teardown]    teardown_test
