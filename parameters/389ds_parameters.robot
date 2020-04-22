*** Variables ***
${DS_ADMIN}       cn=Directory Manager
${DS_NODE_PORT}    30636
${HOST}           dirsrv-389ds.kube-system.svc.cluster.local:636
${DS_DM_PASSWORD}    admin1234
${DS_SUFFIX}      dc=example,dc=com
${DS_IMAGE}       registry.suse.com/caasp/v4/389-ds:1.4.0
