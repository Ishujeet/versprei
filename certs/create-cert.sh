#! /bin/sh
set -uo errexit

export APP="spread-webhook-service"
export NAMESPACE="default"
export CSR_NAME="${APP}.${NAMESPACE}.svc"

brew install cfssl

# wget -q --show-progress --https-only --timestamping \
#   https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
#   https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
# chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
# sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
# sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson


### Create CA cert

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "server": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

### Create Server Cert

cat > server-csr.json <<EOF
{
  "CN": "admission",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=spread-webhook-service.default.svc\
  -profile=server \
  server-csr.json | cfssljson -bare server

cat ca.pem | base64 | tr -d '\n'

openssl x509 -in server.pem -out server.crt
openssl pkey -in server-key.pem -out server-key.key