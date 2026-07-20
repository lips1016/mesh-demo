#!/bin/bash
# Update all Gateway credentialName to point to istio-system secrets

DOMAIN="devops.local"

for i in 1 2 3 4 5; do
  ns="mesh-demo-${i}"
  app_name="app${i}"
  host="${app_name}.${DOMAIN}"
  
  echo "=== Recreating ${app_name}-gateway in ${ns} ==="
  
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
      credentialName: istio-system/${app_name}
      mode: SIMPLE
EOF
  
  echo "  ✓ Gateway ${app_name}-gateway (credential: istio-system/${app_name})"
done

echo ""
echo "=== Done ==="
