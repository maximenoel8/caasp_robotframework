*** Settings ***
Resource          ../commands.robot
Resource          ../tools.robot

*** Keywords ***
install sonobuoy
    execute command localy    wget https://api.github.com/repos/heptio/sonobuoy/releases/latest -O ${LOGDIR}/sonobuoy.json
    ${dico}    Load JSON From File    ${LOGDIR}/sonobuoy.json
    ${version}    Get From Dictionary    ${dico}    name
    ${values}    Remove String    ${version}    v
    execute command localy    wget https://github.com/vmware-tanzu/sonobuoy/releases/download/v${values}/sonobuoy_${values}_linux_386.tar.gz -O ${LOGDIR}/sonobuoy_${values}_linux_386.tar.gz
    execute command localy    tar -xvf ${LOGDIR}/sonobuoy_${values}_linux_386.tar.gz -C ${LOGDIR}

run sonobuoy
    step    run sonobuoy
    install sonobuoy
    sonobuoy    run --mode=certified-conformance --ssh-key="${DATADIR}/id_shared" --ssh-user=sles --wait

analyze sonobuoy result
    ${report}    sonobuoy    retrieve ${LOGDIR}
    ${result}    sonobuoy    e2e ${report}
    Should Contain    ${result}    failed tests: 0
