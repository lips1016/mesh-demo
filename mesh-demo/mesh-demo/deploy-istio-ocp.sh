#!/bin/bash
# Deploy Gateway, VirtualService, and Certificate for mesh-demo apps on OCP
# Pattern: per-app Gateway + VS + Certificate (same as existing project-01 pattern)

DOMAIN="devops.local"
ISSUER="acme-cluster-issuer"

for i in 1 2 3 4 5; do
  ns="mesh-demo-${i}"
  app_name="app${i}"
  host="${app_name}.${DOMAIN}"
  secret_name="${app_name}"
  
  echo "=== Creating ${app_name} in ${ns} ==="
  
  # --- Gateway ---
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: "${app_name}-gateway"
  labels:
    app: ${app_name}
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - "${host}"
    port:
      name: HTTPS
      number: 443
      protocol: HTTPS
    tls:
      credentialName: ${secret_name}
      mode: SIMPLE
EOF
  echo "  ✓ Gateway ${app_name}-gateway"
  
  # --- VirtualService ---
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
spec:
  hosts:
  - "${host}"
  gateways:
  - "${app_name}-gateway"
  http:
  - route:
    - destination:
        host: ${app_name}
        port:
          number: 80
EOF
  echo "  ✓ VirtualService ${app_name}"
  
  # --- Certificate ---
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
  
  echo ""
done

echo "=== All resources created ==="
