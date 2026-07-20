#!/usr/bin/env python3
"""Generate Kubernetes manifests for mesh-demo apps."""

import json
import sys

NUM_APPS = 5
BASE_DOMAIN = "luban.paulhome.local"
GATEWAY_NS = "gateway"
GATEWAY_NAME = "luban-gateway"
HARBOR = "harbor.luban.paulhome.local"
PROJECT = "mesh-demo"
IMAGE_TAG = "latest"

lines = []

# ---- Namespaces ----
for i in range(1, NUM_APPS + 1):
    ns = f"mesh-demo-{i}"
    lines.append(f"""---
apiVersion: v1
kind: Namespace
metadata:
  name: {ns}
  labels:
    app: mesh-demo
    app.kubernetes.io/part-of: mesh-demo
""")

# ---- Deployments & Services ----
for i in range(1, NUM_APPS + 1):
    ns = f"mesh-demo-{i}"
    app_name = f"app{i}"
    host = f"{app_name}.{BASE_DOMAIN}"
    
    # Build OTHER_APPS env var (all apps EXCEPT current)
    others = []
    for j in range(1, NUM_APPS + 1):
        if j != i:
            others.append({
                "name": f"app{j}",
                "namespace": f"mesh-demo-{j}",
                "host": f"app{j}.mesh-demo-{j}.svc.cluster.local"
            })
    others_json = json.dumps(others)
    
    lines.append(f"""---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app_name}
  namespace: {ns}
  labels:
    app: {app_name}
    mesh-demo: "{i}"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {app_name}
  template:
    metadata:
      labels:
        app: {app_name}
    spec:
      containers:
      - name: {app_name}
        image: {HARBOR}/{PROJECT}/{app_name}:{IMAGE_TAG}
        ports:
        - containerPort: 8080
        env:
        - name: APP_NAME
          value: "App {i}"
        - name: APP_NAMESPACE
          value: "{ns}"
        - name: APP_PORT
          value: "8080"
        - name: OTHER_APPS
          value: |
            {others_json}
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: {app_name}
  namespace: {ns}
  labels:
    app: {app_name}
spec:
  selector:
    app: {app_name}
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {app_name}-route
  namespace: {ns}
spec:
  hostnames:
  - "{host}"
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: {GATEWAY_NAME}
    namespace: {GATEWAY_NS}
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: {app_name}
      port: 80
""")

# ---- CoreDNS NodeHosts ----
for i in range(1, NUM_APPS + 1):
    host = f"app{i}.{BASE_DOMAIN}"
    lines.append(f"""---
# CoreDNS NodeHosts entry for {host}
# Run: kubectl patch cm coredns -n kube-system --type json -p '[{{\"op\":\"add\",\"path\":\"/data/{host}\",\"value\":\"192.168.48.111\"}}]'
""")

print("\n".join(lines))
