*** Settings ***
Library           OperatingSystem
Library           String
Resource          common.robot

*** Variables ***
${image_uri}      http://download.suse.de/ibs/home:/thehejik:/branches:/Devel:/JeOS:/SLE-15-SP1/images/SLES15-SP1-JeOS.x86_64-kvm-and-xen.qcow2
${libvirt_uri}    qemu+ssh://thehejik@zeus.qa.suse.cz/system
${bridge}         br0

*** Keywords ***
configure terraform tfvars libvirt
    FOR    ${i}    IN RANGE    ${NUMBER_OF_CLUSTER}
        ${cluster_number}    evaluate    ${i}+1
        &{libevirt_dico}    Convert Tvars To Dico    ${TERRAFORMDIR}/cluster_${cluster_number}/terraform.tfvars.example
        Set To Dictionary    ${libevirt_dico}    libvirt_uri    ${libvirt_uri}
        Set To Dictionary    ${libevirt_dico}    image_uri    ${image_uri}
        Set To Dictionary    ${libevirt_dico}    bridge    ${bridge}
        Set To Dictionary    ${libevirt_dico}    stack_name    ${CLUSTER_PREFIX}-${cluster_number}
        Set To Dictionary    ${libevirt_dico}    master_memory    ${4096}
        Set To Dictionary    ${libevirt_dico}    worker_memory    ${4096}
        Set To Dictionary    ${libevirt_dico}    worker_disk_size    ${80}
        ${libevirt_dico}    configure terraform file common    ${libevirt_dico}
        _create tvars json file    ${libevirt_dico}    ${cluster_number}
    END
