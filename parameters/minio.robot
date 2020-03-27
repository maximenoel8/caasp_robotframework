*** Settings ***
Resource          env.robot

*** Variables ***
${MINIO_ACCESS_KEY}    ${AWS_ACCESS_KEY}
${MINIO_SECRET_KEY}    ${AWS_SECRET_KEY}
${BUCKET_MASTER}    caasp-velero-bucket
${MINIO_MASTER_SERVER_URL}    http://10.84.72.33:9000
${minio_server_path}    /home/${VM_USER}/minio_server
${minio_url_binary}    https://dl.min.io/server/minio/release/linux-amd64/minio
