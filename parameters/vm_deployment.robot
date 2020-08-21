*** Settings ***
Resource          vmware_deployment.robot

*** Variables ***
${VM_USER}        sles
${NUMBER}         1:2
${CPI_VSPHERE}    False    # For vmware : use vsphere as a storage class. Will set to true cpi_enable in terraform file
${DNS_HOSTNAME}    False    # For vmware, option to get hostname by dns
