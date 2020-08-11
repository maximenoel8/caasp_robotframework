*** Settings ***
Resource          ../function/cluster_deployment.robot
Resource          ../function/govc.robot

*** Test Cases ***
Enable vSphere cloud provider on running cluster
    Given cluster running
    And platform is vmware
    set vmware env variables
    set govc environment
    create cluster folder
    move all nodes to cluster folder
    enable disk.UUI for all nodes
    patch vm provider for all nodes
    refresh ssh session
    copy vsphere cloud configuration to all nodes
    save kubeadm-config to local machine as kubeadm-config.yaml
    edit and apply kubeadm-config.yaml for vsphere provider
    update kubelet on masters
    update control-plane on masters
    update kubelet on workers
