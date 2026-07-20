#!/bin/bash
# Deploy certificates to istio-system namespace

DOMAIN="devops.local"
ISSUER="selfsigned-cluster-issuer"

for i in 1 2 3 4 5; do
  host="app${i}.${DOMAIN}"
  secret_name="app${i}"
  
  echo "=== Creating Certificate ${secret_name} in istio-system ==="
  
  cat <<EOF | oc apply -f - -n istio-system
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${secret_name}
  labels:
    app: app${i}
    mesh-demo: "${i}"
spec:
  commonName: "${host}"
  dnsNames:
  - "${host}"
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: ${ISSUER}
  privateKey:
    algorithm: RSA
    encoding: PKCS8
    size: 2048
    rotationPolicy: Always
  secretName: ${secret_name}
  usages:
  - server auth
  - client auth
EOF
  
  echo "  ✓ Certificate ${secret_name} in istio-system"
done

echo ""
echo "=== Done ==="
