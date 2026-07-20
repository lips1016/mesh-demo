#!/bin/bash
# Fix Gateway and VirtualService to match existing project-01 pattern

DOMAIN="devops.local"

for i in 1 2 3 4 5; do
  ns="mesh-demo-${i}"
  app_name="app${i}"
  host="${app_name}.${DOMAIN}"
  
  echo "=== Recreating ${app_name} resources in ${ns} ==="
  
  # --- Gateway: credentialName = secret in SAME namespace (istio-system/app${i} secret must be copied) ---
  # Istio Gateway credentialName MUST be in the same namespace as the Gateway.
  # Since certs are in istio-system, we need to copy secrets OR create certs in each namespace.
  # Following the existing pattern: each namespace has its own cert/secret.
  
  # Create Certificate in each namespace (copy from istio-system pattern)
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
    mesh-demo: "${i}"
spec:
  commonName: "${host}"
  dnsNames:
  - "${host}"
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: selfsigned-cluster-issuer
  privateKey:
    algorithm: RSA
    encoding: PKCS8
    size: 2048
    rotationPolicy: Always
  secretName: ${app_name}
  usages:
  - server auth
  - client auth
EOF
  echo "  ✓ Certificate ${app_name} in ${ns}"
  
  # --- Gateway: single server, credentialName = app${i} (same ns) ---
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
      credentialName: ${app_name}
      mode: SIMPLE
EOF
  echo "  ✓ Gateway ${app_name}-gateway (credentialName: ${app_name})"
  
  # --- VirtualService: match uri prefix, no port number in destination ---
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
spec:
  gateways:
  - "${app_name}-gateway"
  hosts:
  - "${host}"
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: ${app_name}
EOF
  echo "  ✓ VirtualService ${app_name}"
  
  echo ""
done

echo "=== Done ==="
