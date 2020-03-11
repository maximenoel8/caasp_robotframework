*** Settings ***
Resource          common.robot

*** Keywords ***
setup aws
    clone skuba locally
    copy terraform configuration from skuba folder
