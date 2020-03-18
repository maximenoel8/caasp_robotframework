*** Settings ***
Resource          ../commands.robot
Resource          ../cluster_helpers.robot
Resource          ../../parameters/global_parameters.robot

*** Keywords ***
wordpress is deployed
    helm    install --name wordpress --namespace wordpress --set ingress.enabled=true,ingress.hosts[0].name=wordpress.jaws.jio.com \ --set service.type=NodePort --set service.nodePorts.http=30800 --set service.nodePorts.https=30880 --set wordpressUsername=admin --set wordpressPassword=password stable/wordpress
    wordpress is up
    wordpress pv are patch

wordpress is removed
    [Arguments]    ${cluster_number}=1
    helm    delete --purge wordpress    ${cluster_number}
    kubectl    delete namespace wordpress    ${cluster_number}
    check wordpress pvc are deleted    ${cluster_number}

check wordpress pvc are deleted
    [Arguments]    ${cluster_number}=1
    Wait Until Keyword Succeeds    3min    10sec    check wordpress pvc name is null    ${cluster_number}
    Wait Until Keyword Succeeds    3min    10sec    check wordpress pv exist    ${cluster_number}

check wordpress pvc name is null
    [Arguments]    ${cluster_number}=1
    ${output}    get ressource name    -n wordpress    pvc    ${cluster_number}
    Should Be Empty    ${output}
    [Return]    ${output}

file copy to wordpress pod
    kubectl    cp ${DATADIR}/picture.png wordpress/${wordpress_pod_name}:/opt/bitnami/wordpress/wp-content/uploads/2020/03/

check file exist in wordpress pod
    [Arguments]    ${cluster_number}=1
    ${output}    kubectl    -n wordpress exec -it ${wordpress_pod_name} -- ls /opt/bitnami/wordpress/wp-content/uploads/2020/03/    ${cluster_number}
    Should Contain    ${output}    picture.png

wordpress volumes are annotated to be backed up
    kubectl    -n wordpress annotate pod/wordpress-mariadb-0 backup.velero.io/backup-volumes=data,config
    kubectl    -n wordpress annotate pod/${wordpress_pod_name} backup.velero.io/backup-volumes=wordpress-data

wordpress is up
    [Arguments]    ${cluster_number}=1
    ${wordpress_pod_name}    wait podname    -l app.kubernetes.io/name=wordpress -n wordpress    ${cluster_number}
    Set Test Variable    ${wordpress_pod_name}

check wordpress pv exist
    [Arguments]    ${cluster_number}=1
    ${status}    ${output}    Run Keyword And Ignore Error    kubectl    get pv | grep wordpress    ${cluster_number}
    Should Be Equal As Strings    ${status}    FAIL

wordpress pv are patch
    ${output}    kubectl    get pvc -n wordpress
    ${result}    Split To Lines    ${output}
    Should Not Contain    ${result}    No resources found    No PVC found
    FOR    ${element}    IN    @{result}
        ${value}    Split String    ${element}
        Continue For Loop If    "${value[0]}"=="NAME"
        kubectl    patch pvc ${value[0]} -p '{"metadata":{"finalizers":null}}' -n wordpress
        kubectl    patch pv ${value[2]} -p '{"metadata":{"finalizers":null}}' -n wordpress
    END
