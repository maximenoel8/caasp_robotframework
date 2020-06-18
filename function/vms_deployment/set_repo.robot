*** Settings ***
Library           Collections

*** Keywords ***
add CA during terraform
    Append To List    ${PACKAGES_LIST}    ca-certificates-suse
    Set To Dictionary    ${REPOS_LIST}    suse_ca=http://download.suse.de/ibs/SUSE:/CA/SLE_15_${VM_VERSION}/

repo for skuba build
    &{repos}    Create Dictionary    sle_server_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-${VM_VERSION}/x86_64/product/    basesystem_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-${VM_VERSION}/x86_64/product/    containers_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Containers/15-${VM_VERSION}/x86_64/product/    sle_server_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-${VM_VERSION}/x86_64/update/    basesystem_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-${VM_VERSION}/x86_64/update/    containers_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Containers/15-${VM_VERSION}/x86_64/update/    serverapps_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Server-Applications/15-${VM_VERSION}/x86_64/update/    sle15${VM_VERSION}_pool=http://download.suse.de/ibs/SUSE:/SLE-15-${VM_VERSION}:/GA/standard/    sle15${VM_VERSION}_update=http://download.suse.de/ibs/SUSE:/SLE-15-${VM_VERSION}:/Update/standard/    sle15_debuginfo_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15/x86_64/product_debug/    sle15${VM_VERSION}_debuginfo_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-${VM_VERSION}/x86_64/product_debug/    serverapps_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Server-Applications/15-${VM_VERSION}/x86_64/product/    &{REPOS_LIST}
    Set To Dictionary    ${REPOS_LIST}    &{repos}
    &{repos_lb}    Create Dictionary    sle_server_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-${VM_VERSION}/x86_64/product/    basesystem_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-${VM_VERSION}/x86_64/product/    sle_server_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-${VM_VERSION}/x86_64/update/    basesystem_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-${VM_VERSION}/x86_64/update/    ha_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Product-HA/15-${VM_VERSION}/x86_64/product/    ha_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Product-HA/15-${VM_VERSION}/x86_64/update/
    Set To Dictionary    ${LB_REPO_LIST}    &{repos_lb}

repo for DEV
    Run keyword if    ${CAASP_VERSION}==4    Set To Dictionary    ${REPOS_LIST}    caasp_devel=http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_${VM_VERSION}/    ELSE IF ${CAASP_VERSION}==5 and "${VM_VERSION}"=="SP2"    Set To Dictionary    ${REPOS_LIST}    caasp_devel=http://download.suse.de/ibs/Devel:/CaaSP:/5/SLE_15_${VM_VERSION}/
    ...    ELSE    log    Caasp 5 can not be deploy with sles sp1    ERROR

repo for RELEASE
    Run keyword if    ${CAASP_VERSION}==4 and "${VM_VERSION}"=="SP1"    Set To Dictionary    ${REPOS_LIST}    caasp_release=http://download.suse.de/ibs/SUSE:/SLE-15-${VM_VERSION}:/Update:/Products:/CASP40/standard/    ELSE IF ${CAASP_VERSION}==5 and "${VM_VERSION}"=="SP2"    Set To Dictionary    ${REPOS_LIST}    caasp_release=http://download.suse.de/ibs/SUSE:/SLE-15-${VM_VERSION}:/Update:/Products:/CaaSP:/5/standard/
    ...    ELSE    log    caasp ${CAASP_VERSION} can not be deploy with sles ${VM_VERSION}    ERROR

repo for STAGING
    Run keyword if    ${CAASP_VERSION}==4 and "${VM_VERSION}"=="SP1"    Set To Dictionary    ${REPOS_LIST}    caasp_staging=http://download.suse.de/ibs/SUSE:/SLE-15-${VM_VERSION}:/Update:/Products:/CASP40/staging/    ELSE IF ${CAASP_VERSION}==5 and "${VM_VERSION}"=="SP2"    Set To Dictionary    ${REPOS_LIST}    caasp_staging=http://download.suse.de/ibs/SUSE:/SLE-15-SP2:/Update:/Products:/CaaSP:/5/staging/
    ...    ELSE    log    caasp ${CAASP_VERSION} can not be deploy with sles ${VM_VERSION}    ERROR

repo for pattern new version
    Set To Dictionary    ${REPOS_LIST}    &{INCIDENT_REPO}

set repo and packages
    Run Keyword If    "${MODE}"!="${EMPTY}"    Run Keywords    repo for skuba build
    ...    AND    add CA during terraform
    Run Keyword If    "${MODE}"=="${EMPTY}" and '${RPM}'!='${EMPTY}' and '${REGISTRY}'!='${EMPTY}' and not ${UPGRADE}    Run Keywords    repo for pattern new version
    ...    AND    add CA during terraform
    Run Keyword If    "${MODE}"=="${EMPTY}" and '${RPM}'!='${EMPTY}' and '${REGISTRY}'=='${EMPTY}' and not ${UPGRADE}    repo for pattern new version
    Run Keyword If    "${MODE}"=="${EMPTY}" and '${RPM}'!='${EMPTY}' and '${REGISTRY}'!='${EMPTY}' and ${UPGRADE}    add CA during terraform
    Run Keyword If    "${MODE}"=="DEV"    repo for DEV
    ...    ELSE IF    "${MODE}"=="STAGING"    repo for STAGING
    ...    ELSE IF    "${MODE}"=="RELEASE"    repo for RELEASE
