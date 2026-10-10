#!/usr/bin/env bash
# Replaces generated lab certificate files and builds broker keystores and a shared truststore. Requires OpenSSL and keytool.
# Run from the repository root in Bash with the required lab services and tools available.
set -euo pipefail

OUT="security/tls"
PASSWORD="ledgerflow"
mkdir -p "${OUT}"
rm -f "${OUT}"/*.key "${OUT}"/*.crt "${OUT}"/*.csr "${OUT}"/*.p12 "${OUT}"/*.srl "${OUT}"/*.cnf

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

cat > "${OUT}/client-ssl.properties" <<EOF2
security.protocol=SSL
ssl.truststore.location=/etc/ledgerflow/security/truststore.p12
ssl.truststore.password=${PASSWORD}
ssl.truststore.type=PKCS12
EOF2

echo "✓ TLS material generated under ${OUT}"
