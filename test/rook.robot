*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/tests/rook.robot

*** Test Cases ***
deploy rook on vmware
    [Tags]    release
    Pass Execution If    "${PLATFORM}" != "vmware"    rook deployment only vmware
    Given cluster running
    run commands on nodes    1    sudo SUSEConnect -p ses/7/x86_64 -r ${SES_KEY}
    set govc environment
    create disk on nodes
    refresh ssh session
    format disk to vms
    deploy rook common
    deploy rook operator
    deploy rook cluster
    deploy rook storage class
    deploy pod with pvc
