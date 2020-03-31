*** Settings ***
Resource          global_parameters.robot

*** Variables ***
${credential-velero-file}    ${LOGDIR}/credentials-velero
${velero_version}    v1.3.1
${velero_path}    ${LOGDIR}/${velero_tar_name}/
${velero_tar_name}    velero-${velero_version}-linux-amd64
${S3_bucket_url}    http://10.84.72.33:9000
${velero_chart}    ${LOGDIR}/kubernetes-charts-suse-com/stable/velero
${restic_image}    registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-restic-restore-helper:1.3.1
${velero_image}    registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero
${aws_plugin_image}    registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-plugin-for-aws:1.0.1
${aws_region}     eu-central-1
${gcp_credential_file}    suse-css-qa-2ec5b9ab3db9.json
${gcp_plugin_image}    registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-plugin-for-gcp:1.0.1
${azure_plugin_image}    registry.suse.de/devel/caasp/4.0/containers/containers/caasp/v4/velero-plugin-for-microsoft-azure:1.0.1
