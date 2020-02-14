*** Settings ***
Library           OperatingSystem

*** Variables ***
${DS_ADMIN}         "cn=Directory Manager"
${DS_NODE_PORT}     "30636"
${HOST}             "dirsrv-389ds.kube-system.svc.cluster.local:636"

*** Keywords ***
Set config variables
    ${DS_DM_PASSWORD}    Evaluate    os.environ.get("DS_DM_PASSWORD", "admin1234")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_SUFFIX}    Evaluate    os.environ.get("DS_SUFFIX", "dc=example,dc=com")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_IMAGE}    Evaluate    os.environ.get("DS_IMAGE", "registry.suse.com/caasp/v4/389-ds:1.4.0")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_ADDRESS}    Evaluate    os.environ.get("DS_ADDRESS", "127.0.0.1")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_DM_PASSWORD}    Evaluate    os.environ.get("DS_DM_PASSWORD", "admin1234")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_DM_PASSWORD}    Evaluate    os.environ.get("DS_DM_PASSWORD", "admin1234")
    Set Global Variable    ${DS_DM_PASSWORD}
    ${DS_DM_PASSWORD}    Evaluate    os.environ.get("DS_DM_PASSWORD", "admin1234")
    Set Global Variable    ${DS_DM_PASSWORD}


