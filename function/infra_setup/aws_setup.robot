*** Settings ***
Resource          common.robot

*** Keywords ***
setup aws
    get skuba tool
    get terraform configuration
