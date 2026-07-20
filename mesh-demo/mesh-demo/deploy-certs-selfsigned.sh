#!/bin/bash
# Redeploy Certificates using self-signed ClusterIssuer

DOMAIN="devops.local"
ISSUER="selfsigned-cluster-issuer"

for i in 1 2 3 4 5; do
  ns="mesh-demo-${i}"
  app_name="app${i}"
  host="${app_name}.${DOMAIN}"
  secret_name="${app_name}"
  
  echo "=== Creating Certificate ${secret_name} in ${ns} ==="
  
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${secret_name}
  labels:
    app: ${app_name}
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
  
  echo "  ✓ Certificate ${secret_name}"
done

echo ""
echo "=== Done ==="
