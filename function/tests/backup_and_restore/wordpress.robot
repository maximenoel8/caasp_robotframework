*** Settings ***
Resource          ../../commands.robot
Resource          ../../cluster_helpers.robot
Resource          ../../../parameters/global_parameters.robot
Resource          ../../tools.robot
Resource          ../certificate.robot

*** Keywords ***
wordpress is deployed
    deploy mysql
    create wordpress certificate
    helm    install --name wordpress --namespace wordpress -f ${DATADIR}/wordpress/wordpress-values.yaml bitnami/wordpress
    wordpress is up
    step    wordpress is deployed with pv

wordpress is removed
    [Arguments]    ${cluster_number}=1
    Run Keyword And Ignore Error    helm    delete --purge wordpress    ${cluster_number}
    Run Keyword And Ignore Error    helm    delete --purge mysql    ${cluster_number}
    Run Keyword And Ignore Error    kubectl    delete namespace wordpress    ${cluster_number}
    Run Keyword And Ignore Error    kubectl    delete -f ${LOGDIR}/hpa-avg-cpu-value.yaml
    Run Keyword And Ignore Error    check wordpress pvc are deleted    ${cluster_number}
    step    Wordpress has been removed

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
    kubectl    cp ${DATADIR}/picture.png wordpress/${wordpress_pod_name}:/opt/bitnami/wordpress/wp-content/uploads/

check file exist in wordpress pod
    [Arguments]    ${cluster_number}=1
    ${output}    kubectl    -n wordpress exec -it ${wordpress_pod_name} -- ls /opt/bitnami/wordpress/wp-content/uploads/    ${cluster_number}
    Should Contain    ${output}    picture.png

wordpress volumes are annotated to be backed up
    kubectl    -n wordpress annotate pod/mysql-master-0 backup.velero.io/backup-volumes=data,config
    kubectl    -n wordpress annotate pod/${wordpress_pod_name} backup.velero.io/backup-volumes=wordpress-data

wordpress is up
    [Arguments]    ${cluster_number}=1
    ${wordpress_pod_name}    wait podname    -l app.kubernetes.io/name=wordpress -n wordpress    ${cluster_number}    timeout=20m
    Set Test Variable    ${wordpress_pod_name}
    wordpress pv are patch

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

deploy mysql
    step    Deploy mysql for wordpress
    helm    install --name mysql \ --namespace wordpress -f ${DATADIR}/wordpress/mysql_values.yaml bitnami/mysql --wait

create wordpress certificate
    ${dns}    Create List    wordpress.example.com
    ${ip}    Create List
    ${SAN}    Create Dictionary    dns=${dns}    ip=${ip}
    Run Keyword And Ignore Error    kubectl    create namespace wordpress
    create custom certificate to    wordpress    ${SAN}    wordpress
