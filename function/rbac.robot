*** Settings ***
Resource          generic_function.robot
Library           ../lib/yaml_editor.py

*** Keywords ***
389ds server installed
    Modify Add Value    workdir/file.yaml    items 0 quantity    4

authentication with skuba CI (group)
    Run Keyword And Ignore Error    execute command localy    kubectl delete rolebinding italiansrb
    kubectl    create rolebinding italiansrb --clusterrole=admin --group=Italians
    Sleep    30
    skuba    auth login -u tesla@suse.com -p password -s https://${IP_LB}:32000 -r "${WORKDIR}/cluster/pki/ca.crt" -c tesla.conf
    kubectl    --kubeconfig=tesla.conf auth can-i get rolebindings | grep -x yes
    kubectl    delete rolebinding italiansrb

authentication with skuba CI (users)
    Run Keyword And Ignore Error    kubectl    delete rolebinding curierb eulerrb
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    Sleep    30
    skuba    auth login -u curie@suse.com -p password -s https://${IP_LB}:32000 -r "${WORKDIR}/cluster/pki/ca.crt" -c curie.conf
    kubectl    --kubeconfig=curie.conf auth can-i list pods | grep -x yes
    kubectl    --kubeconfig=curie.conf auth can-i delete pods | grep -x no
    skuba    auth login -u euler@suse.com -p password -s https://${IP_LB}:32000 -r "${WORKDIR}/cluster/pki/ca.crt" -c euler.conf
    kubectl    --kubeconfig=euler.conf auth can-i delete pods | grep -x yes
    kubectl    --kubeconfig=euler.conf auth can-i get rolebindings | grep -x no
    kubectl    --kubeconfig=euler.conf get rolebindings | grep Forbidden
    kubectl    delete rolebinding curierb eulerrb
    Remove File    ${WORKDIR}/curie.conf
    Remove File    ${WORKDIR}/euler.conf

authentication with WebUI user
    #  step "Authentication users with selenium"
    #  info "Clean existing roles"
    kubectl   delete rolebinding curierb eulerrb || true
    #  info "Create roles"
    kubectl    create rolebinding curierb --clusterrole=view --user=curie@suse.com
    kubectl    create rolebinding eulerrb --clusterrole=edit --user=euler@suse.com
    sleep     30
    #  info 'WebUI kubeconfig (gangway) with VIEW role'
    #  $TESTDIR/selenium-auth.py -i $IP_LB -u curie@suse.com
    selenium_download     kubeconf.txt curie.conf
    kubectl   --kubeconfig=curie.conf auth can-i list pods | grep -x yes
    kubectl   --kubeconfig=curie.conf auth can-i delete pods | grep -x no
    #  info 'WebUI kubeconfig (gangway) with EDIT role'
    #  $TESTDIR/selenium-auth.py -i $IP_LB -u euler@suse.com
    selenium_download     kubeconf.txt euler.conf
    kubectl   --kubeconfig=euler.conf auth can-i delete pods | grep -x yes
    kubectl   --kubeconfig=euler.conf auth can-i get rolebindings | grep -x no
    kubectl   --kubeconfig=euler.conf get rolebindings | grep Forbidden
    #  info 'Clean role binding'
    kubectl   delete rolebinding curierb eulerrb
    Remove File    ${WORKDIR}/curie.conf
    Remove File    ${WORKDIR}/euler.conf