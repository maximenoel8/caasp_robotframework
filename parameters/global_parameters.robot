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
&{REPOS_LIST}     suse_ca=http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP1/
@{PACKAGES_LIST}    nfs-client    ca-certificates-suse
${PERMANENT_NFS_SERVER}    10.84.72.33
