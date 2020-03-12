*** Settings ***
Resource          global_parameters.robot

*** Variables ***
${credential-velero-file}    ${LOGDIR}/credentials-velero
${velero_version}    v1.3.1
${velero_path}    ${LOGDIR}/${velero_tar_name}/
${velero_tar_name}    velero-${velero_version}-linux-amd64
${S3_bucket_url}    http://10.84.72.33:9000
${velero_plugin_aws_image}    velero/velero-plugin-for-aws:v1.0.1
${velero_chart}    vmware-tanzu/velero
