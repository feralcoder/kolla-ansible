#!/bin/bash

# CERT INSTRUCTIONS HERE: https://docs.openstack.org/octavia/latest/admin/guides/certificates.html
mkdir client_ca server_ca


# CREATE SERVER AUTHORITY
cd server_ca
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
# Create Server Key
openssl genrsa -aes256 -out private/ca.key.pem -passout file:/home/cliff/.password 4096
chmod 400 private/ca.key.pem
# Create Server Cert
openssl req -config ../openssl-feralcoder.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem  -passin file:/home/cliff/.password


# CREATE CLIENT AUTHORITY
cd ../client_ca
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
# Create Client Key
openssl genrsa -aes256 -out private/ca.key.pem -passout file:/home/cliff/.password 4096
chmod 400 private/ca.key.pem
# Create Client Cert
openssl req -config ../openssl-feralcoder.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem -passin file:/home/cliff/.password
# Create Key For Client Cert
openssl genrsa -aes256 -out private/client.key.pem -passout file:/home/cliff/.password 2048
# Create CertRequest for ClientCert on Controllers
openssl req -config ../openssl-feralcoder.cnf -new -sha256 -key private/client.key.pem -out csr/client.csr.pem -passin file:/home/cliff/.password
# Sign the CertRequest
openssl ca -batch -config ../openssl-feralcoder.cnf -extensions usr_cert -days 7300 -notext -md sha256 -in csr/client.csr.pem -out certs/client.cert.pem -passin file:/home/cliff/.password
# Create Concatenated Client Cert and Key
openssl rsa -in private/client.key.pem -out private/client.cert-and-key.pem -passin file:/home/cliff/.password
cat certs/client.cert.pem >> private/client.cert-and-key.pem





