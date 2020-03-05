*** Settings ***
Resource          env.robot

*** Variables ***
${MINIO_ACCESS_KEY}    ${AWS_ACCESS_KEY}
${MINIO_SECRET_KEY}    ${AWS_SECRET_KEY}
${BUCKET_MASTER}    velero
${MINIO_MASTER_SERVER_URL}    http://10.84.72.33:9000
