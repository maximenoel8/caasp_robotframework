*** Settings ***
Resource          generic_function.robot
Library           Collections
Resource          skuba_tool_install.robot
Resource          helpers.robot

*** Keywords ***
join
    @{masters}=    Copy List    ${MASTER_IP}
    Remove From List    ${masters}    0
    ${count}    Evaluate    1
    FOR    ${ELEMENT}    IN    @{masters}
        ${output}=    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba node join --role master --user ${VM_USER} --sudo --target ${ELEMENT} mnoel-master-${count}
        ${count}    Evaluate    ${count}+1
    END
    ${count}    Evaluate    0
    FOR    ${ELEMENT}    IN    @{WORKER_IP}
        ${output}=    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba \ node join --role worker --user ${VM_USER} --sudo --target ${ELEMENT} mnoel-worker-${count}
        ${count}    Evaluate    ${count}+1
    END
    Log    Bootstrap finish

bootstrap
    execute command with ssh    skuba cluster init --control-plane ${LB} cluster
    execute command with ssh    eval `ssh-agent -s` && ssh-add /home/${VM_USER}/id_shared && cd cluster && skuba node bootstrap --user ${VM_USER} --sudo --target ${SKUBA_STATION} mnoel-master-00 -v 10
    Get Directory    cluster    ${WORKDIR}    recursive=true

cluster running
    get VM IP
    open ssh session
    install skuba
    bootstrap
    join
    wait_nodes
    wait_pods
    wait_cillium
