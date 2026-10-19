#!/usr/bin/env bash
# Replaces generated lab certificate files and builds broker keystores and a shared truststore. Run inside the LedgerFlow TLS tools Docker container (OpenSSL and keytool bundled).
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail
umask 077

OUT="security/tls"
PASSWORD="ledgerflow"
mkdir -p "${OUT}"
rm -f "${OUT}"/*.key "${OUT}"/*.crt "${OUT}"/*.csr "${OUT}"/*.p12 "${OUT}"/*.srl "${OUT}"/*.cnf
rm -f "${OUT}"/keystore-creds "${OUT}"/key-creds "${OUT}"/truststore-creds

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "${OUT}/ca.key" \
  -out "${OUT}/ca.crt" \
  -subj "/CN=LedgerFlow-Kafka-CA"

for broker in broker-1 broker-2 broker-3; do
  cat > "${OUT}/${broker}.cnf" <<CONF
subjectAltName=DNS:${broker},DNS:localhost,IP:127.0.0.1
extendedKeyUsage=serverAuth,clientAuth
CONF
  openssl req -newkey rsa:2048 -nodes \
    -keyout "${OUT}/${broker}.key" \
    -out "${OUT}/${broker}.csr" \
    -subj "/CN=${broker}"
  openssl x509 -req -days 3650 \
    -in "${OUT}/${broker}.csr" \
    -CA "${OUT}/ca.crt" -CAkey "${OUT}/ca.key" -CAcreateserial \
    -extfile "${OUT}/${broker}.cnf" \
    -out "${OUT}/${broker}.crt"
  openssl pkcs12 -export \
    -name "${broker}" \
    -in "${OUT}/${broker}.crt" \
    -inkey "${OUT}/${broker}.key" \
    -certfile "${OUT}/ca.crt" \
    -out "${OUT}/${broker}.keystore.p12" \
    -passout "pass:${PASSWORD}"
done

keytool -importcert -noprompt \
  -alias ledgerflow-ca \
  -file "${OUT}/ca.crt" \
  -keystore "${OUT}/truststore.p12" \
  -storetype PKCS12 \
  -storepass "${PASSWORD}"

# The official Apache Kafka Docker image reads the following files from
# /etc/kafka/secrets to configure broker SSL. The values are filenames,
# not literal passwords, in KAFKA_SSL_*_CREDENTIALS.
printf '%s\n' "${PASSWORD}" > "${OUT}/keystore-creds"
printf '%s\n' "${PASSWORD}" > "${OUT}/key-creds"
printf '%s\n' "${PASSWORD}" > "${OUT}/truststore-creds"

cat > "${OUT}/client-ssl.properties" <<EOF2
security.protocol=SSL
ssl.truststore.location=/etc/ledgerflow/security/truststore.p12
ssl.truststore.password=${PASSWORD}
ssl.truststore.type=PKCS12
EOF2

echo "✓ TLS material generated under ${OUT}"
