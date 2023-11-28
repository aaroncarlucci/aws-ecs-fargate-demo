#!/bin/bash

set -e

echo "Provisioning SSL certificate from SSM..."
echo "$SSL_KEY" > /etc/ssl/private/key.pem
echo "$SSL_CERT" > /etc/ssl/certs/cert.pem

if [[ -z ${1} ]]; then
    echo "Starting nginx..."
    exec $(which nginx) -g "daemon off;" ${EXTRA_ARGS}
else
    exec "$@"
fi
