*** Settings ***
Resource          ../cluster_helpers.robot

*** Keywords ***
deploy rook common
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/common.yaml

deploy rook operator
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/operator.yaml
    wait pods ready    -n rook-ceph -l app=rook-ceph-operator
    wait pods ready    -n rook-ceph -l app=rook-discover

deploy rook cluster
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/cluster.yaml
    wait pods ready    -n rook-ceph -l app=rook-ceph-osd

deploy rook storage class
    kubectl    apply -f ${DATADIR}/manifests/rook/7/ceph/csi/rbd/storageclass.yaml
