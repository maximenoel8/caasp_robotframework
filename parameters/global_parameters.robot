*** Variables ***
${VM_USER}        sles
${CLUSTER}        ${EMPTY}
${MODE}           ${EMPTY}
${SKUBA_PULL_REQUEST}    ${EMPTY}
${PREFIX}         robotframework
${GIT_BRANCH}     release-caasp-4.1.0
${PLATFORM}       vmware
${NUMBER}         1:2
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
${CP_vsphere}     False
${CONNEXION_UP}    False
${CHECK_TERRAFORM}    True
