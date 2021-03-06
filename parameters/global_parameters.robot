*** Variables ***
${CLUSTER}        ${EMPTY}
${MODE}           ${EMPTY}
${SKUBA_PULL_REQUEST}    ${EMPTY}
${PREFIX}         robotframework
${PLATFORM}       vmware
${KEEP}           False
${LOGDIR}         ${EMPTY}
${CHART_PULL_REQUEST}    ${EMPTY}
${NUMBER_OF_CLUSTER}    1
&{REPOS_LIST}
@{PACKAGES_LIST}    nfs-client
${PERMANENT_NFS_SERVER}    10.84.72.33
${OLD}            False
${UPGRADE}        False
${KUBERNETES_VERSION}    ${EMPTY}
&{cluster_state}
&{INCIDENT_REPO}
${RPM}            ${EMPTY}
${REGISTRY}       ${EMPTY}
&{LB_REPO_LIST}
${CONNEXION_UP}    False    # Create ssh session will be done only once during the tests
${CHECK_TERRAFORM}    False
${AIRGAPPED}      False
${AIRGAPPED_IP_ONLINE}    10.84.73.139
${VM_VERSION}     SP1
${CAASP_VERSION}    4
${AIRGAPPED_IP_OFFLINE}    ${EMPTY}
${HELM_VERSION}    2
${OIDC_CERT}      None
${skuba_station}    False
