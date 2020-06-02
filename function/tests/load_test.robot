*** Settings ***
Resource          ../commands.robot
Resource          certificate.robot
Resource          ../cluster_helpers.robot
Library           ../../lib/yaml_editor.py

*** Keywords ***
deploy locust
    [Arguments]    ${cluster_number}=1
    create tls certificate for locust
    helm    install ${DATADIR}/locust-kubernetes/loadtest-chart/ --namespace locust --name locust --set hostAliases.ip=${BOOTSTRAP_MASTER_${cluster_number}}    ${cluster_number}

create tls certificate for locust
    ${dns}    Create List    locust.example.com
    ${ip}    Create List
    ${SAN}    Create Dictionary    dns=${dns}    ip=${ip}
    Run Keyword And Ignore Error    kubectl    create namespace locust
    create custom certificate to    locust    ${SAN}    locust

swarm load test
    [Arguments]    ${nb_users}    ${hatch_rate}
    step    Starting load test : max client ${nb_users} \ - hatch rate : ${hatch_rate} new clients per sec
    kubectl    run --generator=run-pod/v1 startlocust --image=djbingham/curl --restart='OnFailure' -i --tty --rm --command -- curl -X POST -F 'locust_count=${nb_users}' -F 'hatch_rate=${hatch_rate}' http://locust-master.locust.svc.cluster.local:8089/swarm

stop load test
    step    stop load test
    kubectl    run --generator=run-pod/v1 stoplocuts --generator=run-pod/v1 --image=djbingham/curl --restart='OnFailure' -i --tty --rm --command -- curl http://locust-master.locust.svc.cluster.local:8089/stop

fail rate should be inferior to
    [Arguments]    ${fail_acceptance}=5
    ${locust_master}    wait podname    -l component=locust-master -n locust
    ${output}    kubectl    logs ${locust_master} -n locust
    ${lines}    Split To Lines    ${output}
    ${last_get}    Set Variable    ${lines[-3]}
    ${total}    Set Variable    ${lines[-1]}
    ${last_get_values}    Split String    ${last_get}
    ${total_values}    Split String    ${total}
    Should Be Equal    ${last_get_values[0]}    GET
    Should Be Equal    ${total_values[0]}    Total
    ${fail_percentage_last_get}    String.Get Regexp Matches    ${last_get_values[3]}    \\((\\d+.\\d+)\%\\)    1
    ${fail_percentage_total}    String.Get Regexp Matches    ${total_values[2]}    \\((\\d+.\\d+)%\\)    1
    ${fail_acceptance_status_last_get}    Evaluate    ${fail_percentage_last_get[0]} <= ${fail_acceptance}
    ${fail_acceptance_status_total}    Evaluate    ${fail_percentage_total[0]} <= ${fail_acceptance}
    Should Be True    ${fail_acceptance_status_last_get}    Fails rate is too hight ${fail_percentage_last_get[0]}%
    Should Be True    ${fail_acceptance_status_total}    Fails rate is too hight ${fail_percentage_total[0]}%

locust is deployed
    [Arguments]    ${cluster_number}=1
    step    deploying locust solution
    ${output}    kubectl    get pod -l app=loadtest -n locust -o name    cluster_number=${cluster_number}
    ${status}    ${_}    Run Keyword And Ignore Error    Should Not Be Empty    ${output}
    Run Keyword If    "${status}"=="FAIL"    deploy locust    cluster_number=${cluster_number}
    wait deploy    -n locust --all

run load testing
    [Arguments]    ${nb_clients}    ${hatch_rate}    ${running_time}=default
    swarm load test    ${nb_clients}    ${hatch_rate}
    ${running_time}    Run Keyword If    "${running_time}"=="default"    Evaluate    ${nb_clients} / ${hatch_rate} + 30
    ...    ELSE    Set Variable    ${running_time}
    sleep    ${running_time}
    stop load test

teardown suite load test
    Run Keyword And Ignore Error    helm    delete --purge locust
    Run Keyword And Ignore Error    kubectl    delete namespace locust

hpa is apply on
    [Arguments]    ${service}
    step    Applying hpa for avg cpu to ${service}
    Copy File    ${DATADIR}/hpa-avg-cpu-value.yaml    ${LOGDIR}
    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    metadata namespace    ${service}
    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    spec maxReplicas    ${15}
    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    spec scaleTargetRef kind    Deployment
    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    spec scaleTargetRef name    ${service}
    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    spec metrics 0 resource target averageValue    500m
    Comment    Modify Add Value    ${LOGDIR}/hpa-avg-cpu-value.yaml    spec behavior scaleDown stabilizationWindowSeconds    ${30}
    kubectl    apply -f ${LOGDIR}/hpa-avg-cpu-value.yaml

number of pods for should be sup to
    [Arguments]    ${namespace}    ${minimum_pod}
    ${output}    kubectl    get pods -n ${namespace}
    ${lines}    Split To Lines    ${output}
    ${lines_lgt}    Get Length    ${lines}
    ${status}    Evaluate    ${lines_lgt} >= ${minimum_pod}
    Should Be True    ${status}

number of pods for should be inf to
    [Arguments]    ${namespace}    ${minimum_pod}
    ${output}    kubectl    get pods -n ${namespace}
    ${lines}    Split To Lines    ${output}
    ${lines_lgt}    Get Length    ${lines}
    ${status}    Evaluate    ${lines_lgt} <= ${minimum_pod}
    Should Be True    ${status}
