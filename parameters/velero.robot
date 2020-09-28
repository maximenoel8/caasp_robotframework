*** Settings ***
Resource          global_parameters.robot

*** Variables ***
${credential-velero-file}    ${LOGDIR}/credentials-velero
${velero_version}    v1.4.2
${velero_path}    ${LOGDIR}/${velero_tar_name}/
${velero_tar_name}    velero-${velero_version}-linux-amd64
${S3_bucket_url}    http://10.84.72.33:9000
${velero_chart}    ${LOGDIR}/kubernetes-charts-suse-com/stable/velero
${restic_image}    registry.suse.de/devel/caasp/4.5/containers/containers/caasp/v4.5/velero-restic-restore-helper
${velero_image}    registry.suse.de/devel/caasp/4.5/containers/containers/caasp/v4.5/velero
${aws_plugin_image}    registry.suse.de/devel/caasp/4.5/containers/cr/containers/caasp/v4.5/velero-plugin-for-aws:1.1.0
${aws_region}     eu-central-1
${gcp_credential_file}    suse-css-qa-dfb2316ddd52.json
${gcp_plugin_image}    registry.suse.de/devel/caasp/4.5/containers/cr/containers/caasp/v4.5/velero-plugin-for-gcp:1.1.0
${azure_plugin_image}    registry.suse.de/devel/caasp/4.5/containers/cr/containers/caasp/v4.5/velero-plugin-for-microsoft-azure:1.1.0
${backup_name}    ${EMPTY}
