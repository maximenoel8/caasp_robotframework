*** Settings ***
Library           Collections

*** Keywords ***
add CA during terraform
    Append To List    ${PACKAGES_LIST}    ca-certificates-suse
    Set To Dictionary    ${REPOS_LIST}    suse_ca=http://download.suse.de/ibs/SUSE:/CA/SLE_15_SP1/

repo for skuba build
    &{repos}    Create Dictionary    sle_server_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Product-SLES/15-SP1/x86_64/product/    basesystem_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Basesystem/15-SP1/x86_64/product/    containers_pool=http://download.suse.de/ibs/SUSE/Products/SLE-Module-Containers/15-SP1/x86_64/product/    sle_server_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Product-SLES/15-SP1/x86_64/update/    basesystem_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Basesystem/15-SP1/x86_64/update/    containers_updates=http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Containers/15-SP1/x86_64/update/    &{REPOS_LIST}
    Set To Dictionary    ${REPOS_LIST}    &{repos}

repo for DEV
    Set To Dictionary    ${REPOS_LIST}    caasp_devel=http://download.suse.de/ibs/Devel:/CaaSP:/4.0/SLE_15_SP1/

repo for RELEASE
    Set To Dictionary    ${REPOS_LIST}    caasp_release=http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/standard/

repo for STAGING
    Set To Dictionary    ${REPOS_LIST}    caasp_staging=http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/CASP40/staging/

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
