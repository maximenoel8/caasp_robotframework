*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../../parameters/global_parameters.robot

*** Keywords ***
wordpress is deployed
    helm    install --name wordpress --namespace wordpress --set ingress.enabled=true,ingress.hosts[0].name=wordpress.jaws.jio.com \ --set service.type=NodePort --set service.nodePorts.http=30800 --set service.nodePorts.https=30880 --set wordpressUsername=admin --set wordpressPassword=password stable/wordpress
    wordpress is up

wordpress is removed
    helm    delete --purge wordpress
    kubectl    delete namespace wordpress
    check wordpress pvc are deleted

check wordpress pvc are deleted
    Wait Until Keyword Succeeds    3min    10sec    check wordpress pvc name is null
    Wait Until Keyword Succeeds    3min    10sec    check wordpress pv exist

check wordpress pvc name is null
    ${output}    get ressource name    -n wordpress    pvc
    Should Be Empty    ${output}
    [Return]    ${output}

copy file to wordpress pod
    kubectl    cp ${DATADIR}/picture.png wordpress/${wordpress_pod_name}:/opt/bitnami/wordpress/wp-content/uploads/2020/03/

check file exist in wordpress pod
    ${output}    kubectl    -n wordpress exec -it ${wordpress_pod_name} -- ls /opt/bitnami/wordpress/wp-content/uploads/2020/03/
    Should Contain    ${output}    picture.png

wordpress volumes volumes are annotated to be backed up
    kubectl    -n wordpress annotate pod/wordpress-mariadb-0 backup.velero.io/backup-volumes=data,config
    kubectl    -n wordpress annotate pod/${wordpress_pod_name} backup.velero.io/backup-volumes=wordpress-data

wordpress is up
    ${wordpress_pod_name}    wait podname    -l app.kubernetes.io/name=wordpress -n wordpress
    Set Test Variable    ${wordpress_pod_name}

check wordpress pv exist
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    get pv | grep wordpress
    Should Be Equal As Strings    ${status}    FAIL
