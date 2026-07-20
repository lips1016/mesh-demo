#!/bin/bash
# Deploy remaining apps (app2-5) to OCP

BASE_DOMAIN="luban.paulhome.local"
GATEWAY_NS="gateway"
GATEWAY_NAME="luban-gateway"

for i in 2 3 4 5; do
  ns="mesh-demo-${i}"
  app_name="app${i}"
  image="quay.io/paulwong6668/app${i}:ocp"
  app_display="App ${i}"
  
  # Build OTHER_APPS env var
  others=""
  for j in 1 2 3 4 5; do
    if [ "$j" -ne "$i" ]; then
      other_ns="mesh-demo-${j}"
      other_host="app${j}.${other_ns}.svc.cluster.local"
      if [ -n "$others" ]; then
        others="${others}, "
      fi
      others="${others}{\"name\": \"app${j}\", \"namespace\": \"${other_ns}\", \"host\": \"${other_host}\"}"
    fi
  done
  
  echo "=== Creating ${app_name} in ${ns} ==="
  
  # Deployment
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
    mesh-demo: "${i}"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${app_name}
  template:
    metadata:
      labels:
        app: ${app_name}
    spec:
      containers:
      - name: ${app_name}
        image: ${image}
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: APP_NAME
          value: "${app_display}"
        - name: APP_NAMESPACE
          value: "${ns}"
        - name: APP_PORT
          value: "8080"
        - name: OTHER_APPS
          value: |
            [${others}]
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
EOF

  # Service
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
spec:
  selector:
    app: ${app_name}
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
EOF

  # Route (OpenShift Route)
  cat <<EOF | oc apply -f - -n ${ns}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${app_name}
  labels:
    app: ${app_name}
spec:
  host: ${app_name}.${BASE_DOMAIN}
  to:
    kind: Service
    name: ${app_name}
    weight: 100
  port:
    targetPort: 8080
  tls:
    termination: passthrough
EOF

  echo "Created ${app_name} in ${ns}"
  echo ""
done

echo "=== Done ==="
