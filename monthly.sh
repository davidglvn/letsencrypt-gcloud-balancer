#!/bin/bash

set -e

# Set Load Balancer type
: ${TARGET_TYPE:=target-https-proxies}

# Set Staging server if parameter is set
USE_STAGING_SERVER="${USE_STAGING_SERVER+--server=https://acme-staging.api.letsencrypt.org/directory}"

# Lets Encrypt Renew
./lego_linux_amd64 $USE_STAGING_SERVER --dns-timeout 30 -m $LETSENCRYPT_EMAIL -dns gcloud $DOMAINS_LIST -a renew

# Create certificate chain
CERT=$(ls -1 /root/.lego/certificates | grep crt\$ | grep -m1 -v issuer)
CERT_ISSUER=$(ls -1 /root/.lego/certificates | grep crt\$ | grep -m1 issuer)
KEY=$(ls -1 /root/.lego/certificates | grep key\$)
cat /root/.lego/certificates/$CERT /root/.lego/certificates/$CERT_ISSUER > cert.crt

# Create name for new certificate in gcloud
CERT_ID=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 16 | head -n 1)-cert
OLD_CERT_ID=$(./google-cloud-sdk/bin/gcloud -q compute ${TARGET_TYPE} list --filter "name=${TARGET_PROXY}" --format="csv[no-heading](SSL_CERTIFICATES)")

# Generate new gcloud certificate and attach to https proxy
./google-cloud-sdk/bin/gcloud -q compute ssl-certificates create $CERT_ID --certificate=cert.crt --private-key=/root/.lego/certificates/$KEY
./google-cloud-sdk/bin/gcloud -q compute ${TARGET_TYPE} update $TARGET_PROXY --ssl-certificates $CERT_ID
rm cert.crt

# Remove old, unused certificate
./google-cloud-sdk/bin/gcloud -q compute ssl-certificates delete $OLD_CERT_ID
