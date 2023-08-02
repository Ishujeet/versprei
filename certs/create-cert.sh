#! /bin/sh
set -uo errexit

APP=${1:=spread-webhook-service}
NAMESPACE=${2:=default}
CSR_NAME="${APP}.${NAMESPACE}.svc"

HAS_WGET="$(type "wget" &> /dev/null && echo true || echo false)"
HAS_CFSSL="$(type "CFSSL" &> /dev/null && echo true || echo false)"
HAS_BREW="$(type "brew" &> /dev/null && echo true || echo false)"

# initOS discovers the operating system for this system.
initOS() {
  OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

  case "$OS" in
    # Minimalist GNU for Windows
    mingw*|cygwin*) OS='windows';;
  esac
}


if [ "${HAS_CURL}" != "true" ]; then
  echo "Curl is required"
  exit 1
fi

if [ "${OS}" == "darwin" ]; then
  if [ "${HAS_BREW}" == "true" ]; then
    if [ "${HAS_CFSSL}" != "true" ]; then
      echo "Installing cfssl...."
      brew install cfssl
    fi
  else
    echo "HomeBrew is required"
  fi
else
  if [ "${HAS_CFSSL}" != "true" ]; then
    echo "Installing cfssl...."
    wget -q --show-progress --https-only --timestamping \
      https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
      https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
    sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
    sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
  fi
fi

echo "Creating CA config json.........."

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
echo "Creating CA CSR json.........."
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
echo "Generating CA cert.........."
cfssl gencert -initca ca-csr.json | cfssljson -bare ca


echo "Creating SERVER CSR json.........."
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
echo "Generating SERVER cert and key.........."
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${CSR_NAME} -profile=server server-csr.json | cfssljson -bare server


echo "Converting .pem key & cert to .key and .crt.........."
openssl x509 -in server.pem -out server.crt
openssl pkey -in server-key.pem -out server-key.key

echo "Replace CA bundle in MutatingWebhookConfiguration with below one...."
cat ca.pem | base64 | tr -d '\n'