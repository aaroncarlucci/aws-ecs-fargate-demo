#!/bin/bash

set -e

echo "Retrieving SSL certificate from SSM..."
aws ssm get-parameter --name /terraform/aws-swan-demo/${ENVIRONMENT}/ssl-certificate-key --with-decryption --output text --query "Parameter.Value" > /etc/ssl/private/key.pem
aws ssm get-parameter --name /terraform/aws-swan-demo/${ENVIRONMENT}/ssl-certificate --with-decryption --output text --query "Parameter.Value" > /etc/ssl/certs/cert.pem

if [[ -z ${1} ]]; then
    echo "Starting nginx..."
    exec $(which nginx) -g "daemon off;" ${EXTRA_ARGS}
else
    exec "$@"
fi
