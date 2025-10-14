# SigNoz Manual Setup Guide for GKE

## Step 1: Prerequisites Setup

### Install Required Tools

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Configure GCP

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## Step 2: Create GKE Cluster

```bash
# Create GKE cluster
gcloud container clusters create signoz-cluster \
  --zone=us-central1-a \
  --num-nodes=3 \
  --machine-type=e2-standard-4 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-network-policy \
  --enable-ip-alias \
  --disk-size=50GB \
  --enable-monitoring \
  --enable-logging

# Get cluster credentials
gcloud container clusters get-credentials signoz-cluster --zone=us-central1-a
```

**Verify cluster is ready:**
```bash
kubectl get nodes
```

## Step 3: Create Namespace

```bash
kubectl create namespace platform
```

## Step 4: Install SigNoz

### Add Helm Repository

```bash
helm repo add signoz https://charts.signoz.io
helm repo update
```

### Create SigNoz Values File

```bash
cat > signoz-values.yaml << EOF
clickhouse:
  persistence:
    size: 100Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

queryService:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

frontend:
  service:
    type: LoadBalancer

otelCollector:
  resources:
    requests:
      memory: "500Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "500m"

otelCollectorMetrics:
  resources:
    requests:
      memory: "500Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "500m"
EOF
```

### Install SigNoz

```bash
helm install signoz signoz/signoz \
  -n platform \
  -f signoz-values.yaml \
  --wait --timeout=10m
```

**Verify SigNoz installation:**
```bash
kubectl get pods -n platform
```

## Step 5: Install Infrastructure Monitoring

### Install Node Exporter

```bash
cat > node-exporter.yaml << EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: platform
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.6.1
        args:
          - '--path.procfs=/host/proc'
          - '--path.sysfs=/host/sys'
          - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$\$|/)'
        ports:
        - containerPort: 9100
          hostPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /rootfs
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: platform
spec:
  selector:
    app: node-exporter
  ports:
  - port: 9100
    targetPort: 9100
EOF

kubectl apply -f node-exporter.yaml
```

### Install kube-state-metrics

```bash
cat > kube-state-metrics.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0
        ports:
        - containerPort: 8080
        - containerPort: 8081
        resources:
          requests:
            memory: "100Mi"
            cpu: "100m"
          limits:
            memory: "200Mi"
            cpu: "200m"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: platform
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["list", "watch"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["list", "watch"]
- apiGroups: ["batch"]
  resources: ["*"]
  verbs: ["list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: platform
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: platform
spec:
  selector:
    app: kube-state-metrics
  ports:
  - name: http-metrics
    port: 8080
    targetPort: 8080
  - name: telemetry
    port: 8081
    targetPort: 8081
EOF

kubectl apply -f kube-state-metrics.yaml
```

## Step 6: Install OpenTelemetry Operator

```bash
# Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s deployment/opentelemetry-operator -n opentelemetry-operator-system
```

## Step 7: Configure Auto-Instrumentation

```bash
cat > instrumentation.yaml << EOF
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: signoz-instrumentation
  namespace: default
spec:
  exporter:
    endpoint: http://signoz-otel-collector.platform.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.32.0
    env:
      - name: OTEL_JAVAAGENT_DEBUG
        value: "false"
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"
  
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.44.0
    env:
      - name: OTEL_LOG_LEVEL
        value: "info"
  
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.41b0
    env:
      - name: OTEL_LOG_LEVEL
        value: "info"
EOF

kubectl apply -f instrumentation.yaml
```

## Step 8: Access SigNoz

### Get SigNoz URL

```bash
# Check if LoadBalancer IP is ready
kubectl get svc signoz-frontend -n platform

# If external IP is pending, use port-forward
kubectl port-forward svc/signoz-frontend 3301:3301 -n platform
```

**Access SigNoz at:** `http://localhost:3301` (if using port-forward) or `http://EXTERNAL_IP:3301`

## Step 9: Deploy Sample Application with Monitoring

```bash
cat > sample-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
      annotations:
        instrumentation.opentelemetry.io/inject-java: "signoz-instrumentation"
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
        env:
        - name: OTEL_SERVICE_NAME
          value: "sample-app"
        - name: OTEL_SERVICE_VERSION
          value: "1.0.0"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: default
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

kubectl apply -f sample-app.yaml
```

## Step 10: Verify Everything is Working

### Check All Pods

```bash
# Check SigNoz pods
kubectl get pods -n platform

# Check monitoring pods
kubectl get pods -n opentelemetry-operator-system

# Check sample app
kubectl get pods -n default
```

### Check Services

```bash
kubectl get svc -n platform
kubectl get svc -n default
```

### Test Metrics Collection

```bash
# Check if metrics are being collected
kubectl exec -it deployment/signoz-otel-collector -n platform -- wget -qO- http://localhost:8888/metrics | head -20
```

## Step 11: Configure Per-User Monitoring

### Add User Context to Your Applications

For applications that need user tracking, add these annotations and environment variables:

```yaml
# Add to your deployment metadata.annotations
annotations:
  instrumentation.opentelemetry.io/inject-java: "signoz-instrumentation"
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"

# Add to container env
env:
- name: OTEL_SERVICE_NAME
  value: "your-app-name"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.name=your-app-name,service.version=1.0.0"
```

### Example: Add Monitoring to Existing App

```bash
# Add instrumentation to existing deployment
kubectl patch deployment YOUR_APP_NAME -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"signoz-instrumentation"}}}}}'

# Add Prometheus scraping
kubectl patch deployment YOUR_APP_NAME -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8080"}}}}}'
```

## Step 12: Access and Configure SigNoz

1. **Open SigNoz UI** at your URL
2. **Complete initial setup** (create admin user)
3. **Navigate to different sections:**
   - **Services**: View application performance
   - **Traces**: See distributed traces
   - **Metrics**: Infrastructure and custom metrics
   - **Logs**: Application and system logs
   - **Alerts**: Set up monitoring alerts

## Verification Checklist

- [ ] GKE cluster is running
- [ ] SigNoz pods are running in `platform` namespace
- [ ] Node exporter is collecting node metrics
- [ ] OpenTelemetry operator is installed
- [ ] Sample app is deployed and instrumented
- [ ] SigNoz UI is accessible
- [ ] Metrics are visible in SigNoz dashboard
- [ ] Traces are being collected

## Troubleshooting

### Common Issues

**SigNoz pods not starting:**
```bash
kubectl describe pod -n platform
kubectl logs -f deployment/signoz-frontend -n platform
```

**No metrics showing:**
```bash
kubectl logs -f deployment/signoz-otel-collector -n platform
```

**LoadBalancer IP pending:**
```bash
# Use port-forward instead
kubectl port-forward svc/signoz-frontend 3301:3301 -n platform
```

**Application not instrumented:**
```bash
# Check if annotation is applied
kubectl get deployment YOUR_APP -o yaml | grep instrumentation

# Check OpenTelemetry operator logs
kubectl logs -f deployment/opentelemetry-operator -n opentelemetry-operator-system
```

## Next Steps

1. **Add more applications** by applying instrumentation annotations
2. **Create custom dashboards** in SigNoz for your specific metrics
3. **Set up alerts** for critical infrastructure and application metrics
4. **Configure log collection** from your applications
5. **Implement user-specific tracking** in your application code

Your SigNoz monitoring setup is now complete and ready to monitor your GKE infrastructure and applications!
