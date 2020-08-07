*** Settings ***
Resource          ../commands.robot
Resource          ../../parameters/389ds_parameters.robot
Resource          ../cluster_helpers.robot
Library           SSHLibrary
Resource          selenium.robot
Library           ../../lib/firefox_profile.py
Resource          ../setup_environment.robot
Library           ../../lib/base64_encoder.py
Resource          ../skuba_commands.robot

*** Keywords ***
389ds server is deployed
    step    deploying 389ds service
    kubectl    create -f ${DATADIR}/manifests/389dss
    Wait Until Keyword Succeeds    3min    10s    check pod log contain    -l app=dirsrv-389ds -n kube-system    INFO - slapd_daemon - Listening on All Interfaces port 3636 for LDAPS requests

authentication with skuba CI (group)
    [Arguments]    ${customize}=False    ${file_name}=oidc-ca    ${cluster_number}=1
    step    checking authentification with CI ( group )
    Run Keyword And Ignore Error    kubectl    delete rolebinding italiansrb
    Run Keyword If    "${customize}" != "False"    copy customize oidc-ca to workstation    service=${customize}
    ${oidc_certificate_path}    Set Variable If    "${customize}" != "False"    /home/${VM_USER}/cluster/pki/${file_name}.crt    ${EMPTY}
    kubectl    create rolebinding italiansrb --clusterrole=admin --group=Italians
    Sleep    30
    skuba authentication    tesla    oidc_certificate=${oidc_certificate_path}
    SSHLibrary.Get File    /home/${VM_USER}/cluster/tesla.conf    ${LOGDIR}/tesla.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/tesla.conf
    kubectl    --kubeconfig=${LOGDIR}/tesla.conf auth can-i get rolebindings | grep -x yes
    kubectl    delete rolebinding italiansrb

authentication with skuba CI (users)
    [Arguments]    ${customize}=False    ${file_name}=oidc-ca    ${cluster_number}=1
    [Timeout]    4 minutes
    step    checking authentification with CI ( users )
    Run Keyword And Ignore Error    kubectl    delete rolebinding curierb eulerrb
    Run Keyword If    "${customize}" != False    copy customize oidc-ca to workstation    ${customize}
    ${oidc_certificate_path}    Set Variable If    "${customize}" != False    /home/${VM_USER}/cluster/pki/oidc-ca.crt    ${EMPTY}
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    Sleep    30
    skuba authentication    curie    oidc_certificate=${oidc_certificate_path}
    SSHLibrary.Get File    /home/${VM_USER}/cluster/curie.conf    ${LOGDIR}/curie.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/curie.conf
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/curie.conf auth can-i delete pods | grep -x no
    skuba authentication    euler    oidc_certificate=${oidc_certificate_path}
    SSHLibrary.Get File    /home/${VM_USER}/cluster/euler.conf    ${LOGDIR}/euler.conf
    execute command with ssh    rm /home/${VM_USER}/cluster/euler.conf
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=${LOGDIR}/euler.conf auth can-i get rolebindings | grep -x no
    Run Keyword And Expect Error    STARTS: Error from server (Forbidden): rolebindings.rbac.authorization.k8s.io is forbidden:    kubectl    --kubeconfig=${LOGDIR}/euler.conf get rolebindings
    kubectl    delete rolebinding curierb eulerrb
    Remove File    {LOGDIR}/curie.conf
    Remove File    {LOGDIR}/euler.conf

authentication with WebUI user
    step    checking authentification with WebUI ( user )
    selenium is deployed
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
    step    Adding users to ${type}
    Run Keyword If    "${type}"=="openldap"    _add user for ldap
    ...    ELSE IF    "${type}"=="389ds"    execute command localy    LDAPTLS_REQCERT=allow ldapadd -v -H ldaps://${BOOTSTRAP_MASTER_${cluster_number}}:${DS_NODE_PORT} -D "${DS_ADMIN}" -f "${DATADIR}/rbac/ldap_389ds.ldif" -w "${DS_DM_PASSWORD}"
    ...    ELSE    Fail    Wrong value for ldap type

dex is configured for
    [Arguments]    ${type}    ${patch}=False
    step    configure dex to use ${type}
    Run Keyword If    ${patch}    _config dex using kutomize    ${type}
    ...    ELSE    _config dex modifying current cm    ${type}
    kubectl    rollout restart deployment oidc-dex -n kube-system
    wait deploy    oidc-dex -n kube-system
    Comment    wait pods ready    -l app=oidc-dex -n kube-system

clean 389ds server
    step    clean 389ds service
    kubectl    delete -f "${DATADIR}/manifests/389dss"
    [Teardown]    teardown_test

openldap server is deployed
    step    deploying openldap server
    helm    install --name ldap --set adminPassword=admin --set env.LDAP_DOMAIN=example.com stable/openldap

_add user for ldap
    ${ldap_pod}    wait podname    -l app=openldap
    execute command localy    cat "${DATADIR}/rbac/ldap.ldif" | kubectl exec -i ${ldap_pod} -- ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin

clean up openldap
    step    clean ldap service
    helm    delete --purge ldap
    [Teardown]    teardown_test

clean static password
    step    clean static password
    kubectl    apply -f ${LOGDIR}/dex-config-ori.yaml --force
    kubectl    delete pod -n kube-system -l app=oidc-dex --wait
    wait pods ready    -l app=oidc-dex -n kube-system
    [Teardown]    teardown_test

_configure dex file config for 389ds
    [Arguments]    ${dico}
    ${sub_dico}    Safe Load    ${dico["data"]["config.yaml"]}
    Log Dictionary    ${sub_dico}
    ${ldap_pod}    wait podname    -l app=dirsrv-389ds -n kube-system
    ${output}    kubectl    --namespace=kube-system exec -it "${ldap_pod}" -- cat /etc/dirsrv/ssca/ca.crt
    ${root_certificate}    Encode Base64    ${output}
    Set To Dictionary    ${sub_dico["connectors"][0]}    id=389ds
    Set To Dictionary    ${sub_dico["connectors"][0]}    name=389ds
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    host=${HOST}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    ca=${root_certificate}
    Collections.Remove From Dictionary    ${sub_dico["connectors"][0]["config"]}    insecureNoSSL
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    bindDN=${DS_ADMIN}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    bindPW=${DS_DM_PASSWORD}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["userSearch"]}    baseDN=${DS_SUFFIX}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    baseDN=${DS_SUFFIX}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    filter=(objectClass=groupOfNames)
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    groupAttr=member
    Set To Dictionary    ${sub_dico}    enablePasswordDB=${false}
    ${new_dico}    Dump    ${sub_dico}
    Set To Dictionary    ${dico["data"]}    config.yaml=${new_dico}
    [Return]    ${dico}

_config dex using kutomize
    [Arguments]    ${type}
    ${dico}    open yaml file    ${CLUSTERDIR}_1/addons/dex/base/dex.yaml
    ${dico_config_map}    Set Variable    ${dico["ConfigMap"]}
    ${dico}    Run Keyword If    "${type}"=="openldap"    _configure dex file config for openldap    ${dico_config_map}
    ...    ELSE IF    "${type}"=="389ds"    _configure dex file config for 389ds    ${dico_config_map}
    ...    ELSE IF    "${type}"=="static password"    _configure dex file config for static password    ${dico_config_map}
    ...    ELSE    Fail    Wrong ldap type
    ${dico_final}    Dump    ${dico}
    Create File    ${CLUSTERDIR}_1/addons/dex/patches/dex-patch.yaml    ${dico_final}
    Copy File    ${DATADIR}/rbac/kustomization.yaml    ${CLUSTERDIR}_1/addons/dex/
    kubectl    apply -k ${CLUSTERDIR}_1/addons/dex/

_configure dex file config for openldap
    [Arguments]    ${dico}
    ${sub_dico}    Safe Load    ${dico["data"]["config.yaml"]}
    Log Dictionary    ${sub_dico}
    Set To Dictionary    ${sub_dico["connectors"][0]}    id=openLDAP
    Set To Dictionary    ${sub_dico["connectors"][0]}    name=openLDAP
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    host=ldap-openldap.default.svc
    Collections.Remove From Dictionary    ${sub_dico["connectors"][0]["config"]}    ca
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    insecureNoSSL=${true}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    bindDN=cn=admin,dc=example,dc=com
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]}    bindPW=admin
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["userSearch"]}    baseDN=${DS_SUFFIX}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    baseDN=${DS_SUFFIX}
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    filter=(objectClass=groupOfUniqueNames)
    Set To Dictionary    ${sub_dico["connectors"][0]["config"]["groupSearch"]}    groupAttr=uniqueMember
    Set To Dictionary    ${sub_dico}    enablePasswordDB=${false}
    ${new_dico}    Dump    ${sub_dico}
    Set To Dictionary    ${dico["data"]}    config.yaml=${new_dico}
    [Return]    ${dico}

_configure dex file config for static password
    [Arguments]    ${dico}
    ${user_config}    open yaml file    ${DATADIR}/rbac/users_static_password.yaml
    ${sub_dico}    Safe Load    ${dico["data"]["config.yaml"]}
    Set To Dictionary    ${sub_dico}    enablePasswordDB=${true}
    Set To Dictionary    ${sub_dico}    staticPasswords=${user_config}
    Collections.Remove From Dictionary    ${sub_dico}    connectors
    Log Dictionary    ${sub_dico}
    ${new_dico}    Dump    ${sub_dico}
    Set To Dictionary    ${dico["data"]}    config.yaml=${new_dico}
    [Return]    ${dico}

_config dex modifying current cm
    [Arguments]    ${type}
    kubectl    get cm oidc-dex-config -n kube-system -o yaml >"${LOGDIR}/dex-config.yaml"
    Copy File    ${LOGDIR}/dex-config.yaml    ${LOGDIR}/dex-config-ori.yaml
    ${dico_config_map}    open yaml file    ${LOGDIR}/dex-config.yaml
    ${dico}    Run Keyword If    "${type}"=="openldap"    _configure dex file config for openldap    ${dico_config_map}
    ...    ELSE IF    "${type}"=="389ds"    _configure dex file config for 389ds    ${dico_config_map}
    ...    ELSE IF    "${type}"=="static password"    _configure dex file config for static password    ${dico_config_map}
    ...    ELSE    Fail    Wrong ldap type
    ${dico_final}    Dump    ${dico}
    Create File    ${LOGDIR}/dex-config.yaml    ${dico_final}
    kubectl    apply -f ${LOGDIR}/dex-config.yaml
