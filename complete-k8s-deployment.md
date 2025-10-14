# Complete Kubernetes Microservices Deployment Guide for GKE

## Table of Contents
1. [Prerequisites and Setup](#prerequisites-and-setup)
2. [GKE Cluster Configuration](#gke-cluster-configuration)
3. [Namespace and RBAC Setup](#namespace-and-rbac-setup)
4. [Secrets Management](#secrets-management)
5. [ConfigMaps Configuration](#configmaps-configuration)
6. [SSL/TLS Configuration](#ssltls-configuration)
7. [Microservices Deployment](#microservices-deployment)
8. [OpenTelemetry Setup](#opentelemetry-setup)
9. [Observability Stack](#observability-stack)
10. [Per-User Metrics and Tracing](#per-user-metrics-and-tracing)
11. [CI/CD Pipeline](#cicd-pipeline)
12. [Advanced Kubernetes Concepts](#advanced-kubernetes-concepts)
13. [Monitoring and Alerting](#monitoring-and-alerting)
14. [Troubleshooting](#troubleshooting)

## Overview
This guide implements a production-ready Kubernetes deployment for 12 microservices on GKE with:
- Complete SSL/TLS encryption
- Comprehensive secrets and config management
- OpenTelemetry observability with per-user tracking
- Full CI/CD pipeline
- Advanced Kubernetes features

## Prerequisites and Setup

### Required Tools
```bash
# Install required tools
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install gcloud CLI (if not installed)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Environment Setup
```bash
# Set environment variables
export PROJECT_ID="your-gcp-project-id"
export CLUSTER_NAME="microservices-cluster"
export REGION="us-central1"
export NAMESPACE="microservices"

# Authenticate with GCP
gcloud auth login
gcloud config set project $PROJECT_ID
```

## GKE Cluster Configuration

### Create Production-Ready GKE Cluster
```bash
# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Create GKE cluster with advanced features
gcloud container clusters create $CLUSTER_NAME \
    --region=$REGION \
    --machine-type=e2-standard-4 \
    --num-nodes=3 \
    --min-nodes=2 \
    --max-nodes=10 \
    --enable-autoscaling \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-ip-alias \
    --enable-network-policy \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --workload-pool=$PROJECT_ID.svc.id.goog \
    --addons=HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS

# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
```

### Cluster Verification
```bash
# Verify cluster
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

## Namespace and RBAC Setup

### Create Namespaces
```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    name: microservices
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: cicd
  labels:
    name: cicd
```

### RBAC Configuration
```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservices-sa
  namespace: microservices
  annotations:
    iam.gke.io/gcp-service-account: microservices-sa@$PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: microservices-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: microservices-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: microservices-role
subjects:
- kind: ServiceAccount
  name: microservices-sa
  namespace: microservices
```

### Workload Identity Setup
```bash
# Create Google Service Account
gcloud iam service-accounts create microservices-sa \
    --display-name="Microservices Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:microservices-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:microservices-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:microservices-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudtrace.agent"

# Bind Kubernetes SA to Google SA
gcloud iam service-accounts add-iam-policy-binding \
    microservices-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[microservices/microservices-sa]"
```

## Secrets Management

### Database Secrets
```yaml
# database-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: microservices
type: Opaque
data:
  # Base64 encoded values - replace with actual encoded values
  postgres-username: <base64-encoded-username>
  postgres-password: <base64-encoded-password>
  postgres-host: <base64-encoded-host>
  postgres-port: <base64-encoded-port>
  postgres-database: <base64-encoded-database>
  redis-host: <base64-encoded-redis-host>
  redis-password: <base64-encoded-redis-password>
```

### API Keys and JWT Secrets
```yaml
# api-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
  namespace: microservices
type: Opaque
data:
  jwt-secret: <base64-encoded-jwt-secret>
  jwt-refresh-secret: <base64-encoded-jwt-refresh-secret>
  encryption-key: <base64-encoded-encryption-key>
  stripe-api-key: <base64-encoded-stripe-key>
  sendgrid-api-key: <base64-encoded-sendgrid-key>
  google-oauth-client-id: <base64-encoded-oauth-client-id>
  google-oauth-client-secret: <base64-encoded-oauth-client-secret>
```

### SSL/TLS Certificates
```yaml
# tls-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: microservices-tls
  namespace: microservices
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>
---
apiVersion: v1
kind: Secret
metadata:
  name: ca-certificates
  namespace: microservices
type: Opaque
data:
  ca.crt: <base64-encoded-ca-certificate>
```

### Create Secrets Script
```bash
#!/bin/bash
# create-secrets.sh

# Database credentials
kubectl create secret generic database-credentials \
  --from-literal=postgres-username="$DB_USERNAME" \
  --from-literal=postgres-password="$DB_PASSWORD" \
  --from-literal=postgres-host="$DB_HOST" \
  --from-literal=postgres-port="$DB_PORT" \
  --from-literal=postgres-database="$DB_NAME" \
  --from-literal=redis-host="$REDIS_HOST" \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --namespace=microservices

# API credentials
kubectl create secret generic api-credentials \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=jwt-refresh-secret="$JWT_REFRESH_SECRET" \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --from-literal=stripe-api-key="$STRIPE_API_KEY" \
  --from-literal=sendgrid-api-key="$SENDGRID_API_KEY" \
  --namespace=microservices

# TLS certificates
kubectl create secret tls microservices-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=microservices
```

## ConfigMaps Configuration

### Application Configuration
```yaml
# app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: microservices
data:
  # Application settings
  LOG_LEVEL: "info"
  ENVIRONMENT: "production"
  DEBUG: "false"
  
  # Service discovery
  SERVICE_DISCOVERY_ENABLED: "true"
  SERVICE_MESH_ENABLED: "true"
  
  # Observability
  OTEL_ENABLED: "true"
  METRICS_ENABLED: "true"
  TRACING_ENABLED: "true"
  LOGGING_ENABLED: "true"
  
  # Performance settings
  MAX_CONNECTIONS: "100"
  CONNECTION_TIMEOUT: "30s"
  READ_TIMEOUT: "30s"
  WRITE_TIMEOUT: "30s"
  
  # Feature flags
  FEATURE_USER_ANALYTICS: "true"
  FEATURE_RECOMMENDATION_ENGINE: "true"
  FEATURE_REAL_TIME_NOTIFICATIONS: "true"
```

### Service-Specific Configurations
```yaml
# service-configs.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-service-config
  namespace: microservices
data:
  PORT: "8080"
  SERVICE_NAME: "user-service"
  DATABASE_POOL_SIZE: "10"
  CACHE_TTL: "300"
  USER_SESSION_TIMEOUT: "3600"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-service-config
  namespace: microservices
data:
  PORT: "8080"
  SERVICE_NAME: "auth-service"
  JWT_EXPIRY: "3600"
  REFRESH_TOKEN_EXPIRY: "604800"
  MAX_LOGIN_ATTEMPTS: "5"
  LOCKOUT_DURATION: "900"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-service-config
  namespace: microservices
data:
  PORT: "8080"
  SERVICE_NAME: "payment-service"
  PAYMENT_TIMEOUT: "30s"
  RETRY_ATTEMPTS: "3"
  WEBHOOK_TIMEOUT: "10s"
```

### OpenTelemetry Configuration
```yaml
# otel-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: microservices
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
            - job_name: 'microservices'
              kubernetes_sd_configs:
                - role: pod
                  namespaces:
                    names:
                      - microservices
    
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      memory_limiter:
        limit_mib: 512
      resource:
        attributes:
          - key: environment
            value: production
            action: upsert
          - key: cluster
            value: microservices-cluster
            action: upsert
    
    exporters:
      googlecloud:
        project: ${PROJECT_ID}
      jaeger:
        endpoint: jaeger-collector:14250
        tls:
          insecure: true
      prometheus:
        endpoint: "0.0.0.0:8889"
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [googlecloud, jaeger]
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch, resource]
          exporters: [googlecloud, prometheus]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [googlecloud]
```

## SSL/TLS Configuration

### Ingress with SSL Termination
```yaml
# ingress-ssl.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  namespace: microservices
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "microservices-ip"
    networking.gke.io/managed-certificates: "microservices-ssl-cert"
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - hosts:
    - api.yourdomain.com
    - app.yourdomain.com
    secretName: microservices-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /api/users/*
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 80
      - path: /api/auth/*
        pathType: Prefix
        backend:
          service:
            name: auth-service
            port:
              number: 80
      - path: /api/products/*
        pathType: Prefix
        backend:
          service:
            name: product-service
            port:
              number: 80
      - path: /api/orders/*
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80
      - path: /api/payments/*
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80
```

### Managed SSL Certificate
```yaml
# managed-ssl-cert.yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: microservices-ssl-cert
  namespace: microservices
spec:
  domains:
    - api.yourdomain.com
    - app.yourdomain.com
```

### Network Policies for SSL
```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservices-netpol
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: microservices
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8443
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 6379
```

## Microservices Deployment

### Base Deployment Template
```yaml
# microservice-base-template.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
  labels:
    app: user-service
    version: v1
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: user-service
      version: v1
  template:
    metadata:
      labels:
        app: user-service
        version: v1
        tier: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: microservices-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: user-service
        image: gcr.io/${PROJECT_ID}/user-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8443
          name: https
          protocol: TCP
        env:
        # Service configuration
        - name: SERVICE_NAME
          value: "user-service"
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: user-service-config
              key: PORT
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: ENVIRONMENT
        
        # Database configuration
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-port
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-database
        
        # Redis configuration
        - name: REDIS_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: redis-host
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: redis-password
        
        # JWT configuration
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: api-credentials
              key: jwt-secret
        - name: JWT_REFRESH_SECRET
          valueFrom:
            secretKeyRef:
              name: api-credentials
              key: jwt-refresh-secret
        
        # OpenTelemetry configuration
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector:4318"
        - name: OTEL_SERVICE_NAME
          value: "user-service"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.name=user-service,service.version=v1,environment=production"
        
        # Health check endpoints
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        # Resource limits
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        
        # Volume mounts
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
          readOnly: true
        - name: tls-certs
          mountPath: /app/certs
          readOnly: true
      
      volumes:
      - name: config-volume
        configMap:
          name: user-service-config
      - name: tls-certs
        secret:
          secretName: microservices-tls
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
  labels:
    app: user-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  - port: 443
    targetPort: 8443
    protocol: TCP
    name: https
  selector:
    app: user-service
```

### All 12 Microservices Deployment Script
```bash
#!/bin/bash
# deploy-all-microservices.sh

set -e

SERVICES=("user" "auth" "product" "order" "payment" "inventory" "notification" "analytics" "search" "recommendation" "review" "admin")
NAMESPACE="microservices"

echo "Deploying all microservices..."

for service in "${SERVICES[@]}"; do
  echo "Creating deployment for ${service}-service..."
  
  # Create service-specific deployment
  cat > ${service}-service-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${service}-service
  namespace: ${NAMESPACE}
  labels:
    app: ${service}-service
    version: v1
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: ${service}-service
      version: v1
  template:
    metadata:
      labels:
        app: ${service}-service
        version: v1
        tier: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: microservices-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: ${service}-service
        image: gcr.io/\${PROJECT_ID}/${service}-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        env:
        - name: SERVICE_NAME
          value: "${service}-service"
        - name: PORT
          value: "8080"
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: ENVIRONMENT
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-host
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: postgres-password
        - name: REDIS_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: redis-host
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: api-credentials
              key: jwt-secret
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector:4318"
        - name: OTEL_SERVICE_NAME
          value: "${service}-service"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.name=${service}-service,service.version=v1,environment=production"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: tls-certs
          mountPath: /app/certs
          readOnly: true
      volumes:
      - name: tls-certs
        secret:
          secretName: microservices-tls
---
apiVersion: v1
kind: Service
metadata:
  name: ${service}-service
  namespace: ${NAMESPACE}
  labels:
    app: ${service}-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
  selector:
    app: ${service}-service
EOF

  # Apply the deployment
  kubectl apply -f ${service}-service-deployment.yaml
  
  echo "Deployed ${service}-service"
done

echo "All microservices deployed successfully!"
```

### HPA Configuration for All Services
```yaml
# hpa-all-services.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: microservices
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
---
# Repeat for all other services...
```

## OpenTelemetry Setup

### OpenTelemetry Collector Deployment
```yaml
# otel-collector.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: microservices
  labels:
    app: otel-collector
spec:
  replicas: 2
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      serviceAccountName: microservices-sa
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:latest
        ports:
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        - containerPort: 8889
          name: prometheus
        env:
        - name: PROJECT_ID
          value: "${PROJECT_ID}"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/otel
          readOnly: true
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config-volume
        configMap:
          name: otel-collector-config
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: microservices
  labels:
    app: otel-collector
spec:
  type: ClusterIP
  ports:
  - port: 4317
    targetPort: 4317
    name: otlp-grpc
  - port: 4318
    targetPort: 4318
    name: otlp-http
  - port: 8889
    targetPort: 8889
    name: prometheus
  selector:
    app: otel-collector
```

### OpenTelemetry Instrumentation
```yaml
# otel-instrumentation.yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: microservices-instrumentation
  namespace: microservices
spec:
  exporter:
    endpoint: http://otel-collector:4318
  propagators:
    - tracecontext
    - baggage
    - b3
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"
  resource:
    addK8sUIDAttributes: true
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
```

## Observability Stack

### Prometheus Setup
```yaml
# prometheus.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config-volume
          mountPath: /etc/prometheus
        - name: storage-volume
          mountPath: /prometheus
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: config-volume
        configMap:
          name: prometheus-config
      - name: storage-volume
        persistentVolumeClaim:
          claimName: prometheus-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus
```

### Grafana Setup
```yaml
# grafana.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: admin-password
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-config
          mountPath: /etc/grafana/provisioning
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
      - name: grafana-config
        configMap:
          name: grafana-config
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
```

### Jaeger Tracing
```yaml
# jaeger.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686
        - containerPort: 14250
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 16686
    targetPort: 16686
    name: ui
  - port: 14250
    targetPort: 14250
    name: grpc
  selector:
    app: jaeger
```

## Per-User Metrics and Tracing

### User Context Propagation
```yaml
# user-context-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-context-config
  namespace: microservices
data:
  context.yaml: |
    user_tracking:
      enabled: true
      headers:
        - "X-User-ID"
        - "X-Session-ID"
        - "X-Tenant-ID"
      attributes:
        - user.id
        - user.session
        - user.tenant
        - user.role
    
    sampling:
      per_user: true
      user_sample_rate: 0.1
      high_value_users: 1.0
      
    metrics:
      user_dimensions:
        - user_id
        - session_id
        - tenant_id
        - user_role
        - user_tier
```

### Custom Metrics for User Tracking
```yaml
# user-metrics-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-metrics-config
  namespace: microservices
data:
  metrics.yaml: |
    custom_metrics:
      - name: user_request_duration
        type: histogram
        description: "Request duration per user"
        labels: ["user_id", "service", "endpoint", "method"]
        
      - name: user_request_count
        type: counter
        description: "Request count per user"
        labels: ["user_id", "service", "status_code"]
        
      - name: user_active_sessions
        type: gauge
        description: "Active sessions per user"
        labels: ["user_id", "session_type"]
        
      - name: user_feature_usage
        type: counter
        description: "Feature usage per user"
        labels: ["user_id", "feature", "action"]
        
      - name: user_error_rate
        type: counter
        description: "Error rate per user"
        labels: ["user_id", "service", "error_type"]
```

### User Analytics Service
```yaml
# user-analytics-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-analytics-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-analytics-service
  template:
    metadata:
      labels:
        app: user-analytics-service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: user-analytics
        image: gcr.io/${PROJECT_ID}/user-analytics-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: CLICKHOUSE_HOST
          value: "clickhouse-service"
        - name: REDIS_HOST
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: redis-host
        - name: OTEL_SERVICE_NAME
          value: "user-analytics-service"
        - name: USER_TRACKING_ENABLED
          value: "true"
        volumeMounts:
        - name: user-context-config
          mountPath: /app/config/context
        - name: user-metrics-config
          mountPath: /app/config/metrics
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: user-context-config
        configMap:
          name: user-context-config
      - name: user-metrics-config
        configMap:
          name: user-metrics-config
---
apiVersion: v1
kind: Service
metadata:
  name: user-analytics-service
  namespace: microservices
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: user-analytics-service
```

### ClickHouse for User Analytics
```yaml
# clickhouse.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: clickhouse
  namespace: microservices
spec:
  serviceName: clickhouse-service
  replicas: 1
  selector:
    matchLabels:
      app: clickhouse
  template:
    metadata:
      labels:
        app: clickhouse
    spec:
      containers:
      - name: clickhouse
        image: clickhouse/clickhouse-server:latest
        ports:
        - containerPort: 8123
        - containerPort: 9000
        volumeMounts:
        - name: clickhouse-data
          mountPath: /var/lib/clickhouse
        - name: clickhouse-config
          mountPath: /etc/clickhouse-server/config.d
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: clickhouse-config
        configMap:
          name: clickhouse-config
  volumeClaimTemplates:
  - metadata:
      name: clickhouse-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: clickhouse-service
  namespace: microservices
spec:
  ports:
  - port: 8123
    name: http
  - port: 9000
    name: native
  selector:
    app: clickhouse
```

## CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy Microservices to GKE

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GKE_CLUSTER: microservices-cluster
  GKE_ZONE: us-central1-a
  REGISTRY: gcr.io

jobs:
  setup-build-publish-deploy:
    name: Setup, Build, Publish, and Deploy
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        service: [user, auth, product, order, payment, inventory, notification, analytics, search, recommendation, review, admin]
    
    steps:
    - name: Checkout
      uses: actions/checkout@v3

    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v1
      with:
        service_account_key: ${{ secrets.GCP_SA_KEY }}
        project_id: ${{ secrets.GCP_PROJECT_ID }}

    - name: Configure Docker to use gcloud as a credential helper
      run: |-
        gcloud --quiet auth configure-docker

    - name: Get GKE credentials
      run: |-
        gcloud container clusters get-credentials "$GKE_CLUSTER" --zone "$GKE_ZONE"

    - name: Build Docker image
      run: |-
        docker build \
          --tag "$REGISTRY/$PROJECT_ID/${{ matrix.service }}-service:$GITHUB_SHA" \
          --build-arg GITHUB_SHA="$GITHUB_SHA" \
          --build-arg GITHUB_REF="$GITHUB_REF" \
          ./services/${{ matrix.service }}-service/

    - name: Push Docker image
      run: |-
        docker push "$REGISTRY/$PROJECT_ID/${{ matrix.service }}-service:$GITHUB_SHA"

    - name: Deploy to GKE
      run: |-
        kubectl set image deployment/${{ matrix.service }}-service \
          ${{ matrix.service }}-service=$REGISTRY/$PROJECT_ID/${{ matrix.service }}-service:$GITHUB_SHA \
          --namespace=microservices
        
        kubectl rollout status deployment/${{ matrix.service }}-service --namespace=microservices

    - name: Verify deployment
      run: |-
        kubectl get services -o wide --namespace=microservices
```

### ArgoCD GitOps Setup
```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microservices-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/microservices-k8s
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: microservices
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: microservices-project
  namespace: argocd
spec:
  description: Microservices Project
  sourceRepos:
  - 'https://github.com/your-org/microservices-k8s'
  destinations:
  - namespace: microservices
    server: https://kubernetes.default.svc
  - namespace: monitoring
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
  - group: rbac.authorization.k8s.io
    kind: ClusterRoleBinding
  namespaceResourceWhitelist:
  - group: ''
    kind: '*'
  - group: apps
    kind: '*'
  - group: networking.k8s.io
    kind: '*'
```

### Kustomization for Environment Management
```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespaces.yaml
- rbac.yaml
- secrets.yaml
- configmaps.yaml
- deployments/
- services/
- ingress.yaml

commonLabels:
  app.kubernetes.io/name: microservices
  app.kubernetes.io/part-of: microservices-platform

images:
- name: gcr.io/PROJECT_ID/user-service
  newTag: latest
- name: gcr.io/PROJECT_ID/auth-service
  newTag: latest
# ... repeat for all services
```

```yaml
# k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: microservices

resources:
- ../../base

patchesStrategicMerge:
- production-patches.yaml

replicas:
- name: user-service
  count: 5
- name: auth-service
  count: 3
- name: product-service
  count: 4
- name: order-service
  count: 3
- name: payment-service
  count: 2

images:
- name: gcr.io/PROJECT_ID/user-service
  newTag: v1.2.3
```

### Helm Charts Structure
```yaml
# helm/microservices/Chart.yaml
apiVersion: v2
name: microservices
description: A Helm chart for microservices deployment
type: application
version: 0.1.0
appVersion: "1.0"

dependencies:
- name: postgresql
  version: 12.1.2
  repository: https://charts.bitnami.com/bitnami
- name: redis
  version: 17.3.7
  repository: https://charts.bitnami.com/bitnami
- name: prometheus
  version: 15.18.0
  repository: https://prometheus-community.github.io/helm-charts
```

```yaml
# helm/microservices/values.yaml
global:
  imageRegistry: gcr.io
  imageTag: latest
  namespace: microservices

microservices:
  user:
    enabled: true
    replicas: 3
    image: user-service
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  auth:
    enabled: true
    replicas: 2
    image: auth-service
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"

ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "microservices-ip"
    networking.gke.io/managed-certificates: "microservices-ssl-cert"
  hosts:
    - host: api.yourdomain.com
      paths:
        - path: /
          pathType: Prefix

postgresql:
  enabled: true
  auth:
    postgresPassword: "your-postgres-password"
    database: "microservices"

redis:
  enabled: true
  auth:
    enabled: true
    password: "your-redis-password"

monitoring:
  prometheus:
    enabled: true
  grafana:
    enabled: true
  jaeger:
    enabled: true
```

## Advanced Kubernetes Concepts

### Pod Disruption Budgets
```yaml
# pod-disruption-budgets.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service-pdb
  namespace: microservices
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: user-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-services-pdb
  namespace: microservices
spec:
  minAvailable: 1
  selector:
    matchLabels:
      tier: critical
```

### Resource Quotas and Limits
```yaml
# resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: microservices-quota
  namespace: microservices
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    pods: "50"
    services: "20"
    secrets: "20"
    configmaps: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: microservices-limits
  namespace: microservices
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
    type: Container
  - max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### Service Mesh with Istio
```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: microservices-gateway
  namespace: microservices
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: microservices-tls
    hosts:
    - api.yourdomain.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: microservices-vs
  namespace: microservices
spec:
  hosts:
  - api.yourdomain.com
  gateways:
  - microservices-gateway
  http:
  - match:
    - uri:
        prefix: /api/users
    route:
    - destination:
        host: user-service
        port:
          number: 80
  - match:
    - uri:
        prefix: /api/auth
    route:
    - destination:
        host: auth-service
        port:
          number: 80
```

### Cluster Autoscaler
```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=gce
        - --skip-nodes-with-local-storage=false
        - --expander=most-pods
        - --node-group-auto-discovery=mig:name=gke-microservices-cluster-default-pool
```

### Vertical Pod Autoscaler
```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: user-service-vpa
  namespace: microservices
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: user-service
      maxAllowed:
        cpu: 1
        memory: 1Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
```

## Monitoring and Alerting

### Prometheus Configuration
```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
    
    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
          namespaces:
            names:
            - microservices
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
      
      - job_name: 'otel-collector'
        static_configs:
        - targets: ['otel-collector:8889']
        scrape_interval: 10s
        metrics_path: /metrics
```

### Alert Rules
```yaml
# alert-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: monitoring
data:
  microservices.yml: |
    groups:
    - name: microservices.rules
      rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} for service {{ $labels.service }}"
      
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "95th percentile latency is {{ $value }}s for service {{ $labels.service }}"
      
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
      
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }} for container {{ $labels.container }}"
      
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ $value | humanizePercentage }} for container {{ $labels.container }}"
      
      - alert: UserServiceDown
        expr: up{job="kubernetes-pods", app="user-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "User service is down"
          description: "User service has been down for more than 1 minute"
```

### AlertManager Configuration
```yaml
# alertmanager.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:latest
        ports:
        - containerPort: 9093
        volumeMounts:
        - name: config-volume
          mountPath: /etc/alertmanager
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: config-volume
        configMap:
          name: alertmanager-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alerts@yourdomain.com'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
      routes:
      - match:
          severity: critical
        receiver: 'critical-alerts'
      - match:
          severity: warning
        receiver: 'warning-alerts'
    
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://webhook-service:8080/alerts'
    
    - name: 'critical-alerts'
      email_configs:
      - to: 'oncall@yourdomain.com'
        subject: 'CRITICAL: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
        title: 'Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    
    - name: 'warning-alerts'
      email_configs:
      - to: 'team@yourdomain.com'
        subject: 'WARNING: {{ .GroupLabels.alertname }}'
```

### Grafana Dashboards
```yaml
# grafana-dashboards.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
data:
  microservices-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Microservices Overview",
        "tags": ["microservices"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total[5m])) by (service)",
                "legendFormat": "{{ service }}"
              }
            ]
          },
          {
            "id": 2,
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service)",
                "legendFormat": "{{ service }}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (service, le))",
                "legendFormat": "{{ service }} 95th percentile"
              }
            ]
          }
        ]
      }
    }
  
  user-analytics.json: |
    {
      "dashboard": {
        "title": "User Analytics",
        "panels": [
          {
            "title": "Active Users",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(user_active_sessions)",
                "legendFormat": "Active Users"
              }
            ]
          },
          {
            "title": "User Requests by Service",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(user_request_count[5m])) by (service, user_id)",
                "legendFormat": "{{ service }}"
              }
            ]
          },
          {
            "title": "Feature Usage",
            "type": "piechart",
            "targets": [
              {
                "expr": "sum(user_feature_usage) by (feature)",
                "legendFormat": "{{ feature }}"
              }
            ]
          }
        ]
      }
    }
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Pod Startup Issues
```bash
# Check pod status
kubectl get pods -n microservices

# Describe pod for events
kubectl describe pod <pod-name> -n microservices

# Check logs
kubectl logs <pod-name> -n microservices

# Check previous container logs if pod restarted
kubectl logs <pod-name> -n microservices --previous

# Execute into running pod
kubectl exec -it <pod-name> -n microservices -- /bin/bash
```

#### 2. Service Discovery Issues
```bash
# Check service endpoints
kubectl get endpoints -n microservices

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- nslookup user-service.microservices.svc.cluster.local

# Check DNS resolution
kubectl exec -it <pod-name> -n microservices -- nslookup kubernetes.default.svc.cluster.local
```

#### 3. SSL/TLS Issues
```bash
# Check certificate status
kubectl describe managedcertificate microservices-ssl-cert -n microservices

# Verify ingress configuration
kubectl describe ingress microservices-ingress -n microservices

# Check certificate expiry
kubectl get secret microservices-tls -n microservices -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

#### 4. Performance Issues
```bash
# Check resource usage
kubectl top pods -n microservices
kubectl top nodes

# Check HPA status
kubectl get hpa -n microservices

# Check VPA recommendations
kubectl describe vpa user-service-vpa -n microservices
```

### Debug Scripts
```bash
#!/bin/bash
# debug-microservices.sh

NAMESPACE="microservices"

echo "=== Checking Pod Status ==="
kubectl get pods -n $NAMESPACE -o wide

echo -e "\n=== Checking Services ==="
kubectl get svc -n $NAMESPACE

echo -e "\n=== Checking Ingress ==="
kubectl get ingress -n $NAMESPACE

echo -e "\n=== Checking ConfigMaps ==="
kubectl get configmaps -n $NAMESPACE

echo -e "\n=== Checking Secrets ==="
kubectl get secrets -n $NAMESPACE

echo -e "\n=== Checking Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'

echo -e "\n=== Checking Resource Usage ==="
kubectl top pods -n $NAMESPACE

echo -e "\n=== Checking HPA Status ==="
kubectl get hpa -n $NAMESPACE

echo -e "\n=== Failed Pods Details ==="
for pod in $(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Pod: $pod ---"
  kubectl describe pod $pod -n $NAMESPACE
  echo "--- Logs: $pod ---"
  kubectl logs $pod -n $NAMESPACE --tail=50
done
```

## Complete Deployment Script

### Master Deployment Script
```bash
#!/bin/bash
# deploy-complete-microservices.sh

set -e

# Configuration
PROJECT_ID="your-gcp-project-id"
CLUSTER_NAME="microservices-cluster"
REGION="us-central1"
NAMESPACE="microservices"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v gcloud >/dev/null 2>&1 || error "gcloud is required but not installed"
    command -v helm >/dev/null 2>&1 || error "helm is required but not installed"
    
    log "Prerequisites check passed"
}

# Setup GCP and GKE
setup_gke() {
    log "Setting up GKE cluster..."
    
    # Enable APIs
    gcloud services enable container.googleapis.com
    gcloud services enable compute.googleapis.com
    gcloud services enable monitoring.googleapis.com
    gcloud services enable logging.googleapis.com
    
    # Create cluster if it doesn't exist
    if ! gcloud container clusters describe $CLUSTER_NAME --region=$REGION >/dev/null 2>&1; then
        log "Creating GKE cluster..."
        gcloud container clusters create $CLUSTER_NAME \
            --region=$REGION \
            --machine-type=e2-standard-4 \
            --num-nodes=3 \
            --min-nodes=2 \
            --max-nodes=10 \
            --enable-autoscaling \
            --enable-autorepair \
            --enable-autoupgrade \
            --enable-ip-alias \
            --enable-network-policy \
            --enable-cloud-logging \
            --enable-cloud-monitoring \
            --workload-pool=$PROJECT_ID.svc.id.goog
    else
        log "GKE cluster already exists"
    fi
    
    # Get credentials
    gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
    
    log "GKE setup completed"
}

# Create namespaces
create_namespaces() {
    log "Creating namespaces..."
    
    kubectl apply -f namespaces.yaml
    kubectl apply -f rbac.yaml
    
    log "Namespaces created"
}

# Setup secrets
setup_secrets() {
    log "Setting up secrets..."
    
    # Check if secrets exist, if not create them
    if ! kubectl get secret database-credentials -n $NAMESPACE >/dev/null 2>&1; then
        warn "Database credentials secret not found. Please create it manually or set environment variables."
        # ./create-secrets.sh
    fi
    
    log "Secrets setup completed"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "Deploying infrastructure components..."
    
    # Deploy ConfigMaps
    kubectl apply -f app-config.yaml
    kubectl apply -f service-configs.yaml
    kubectl apply -f otel-config.yaml
    
    # Deploy OpenTelemetry Collector
    kubectl apply -f otel-collector.yaml
    
    # Deploy monitoring stack
    kubectl apply -f prometheus.yaml
    kubectl apply -f grafana.yaml
    kubectl apply -f jaeger.yaml
    kubectl apply -f alertmanager.yaml
    
    log "Infrastructure deployment completed"
}

# Deploy microservices
deploy_microservices() {
    log "Deploying microservices..."
    
    SERVICES=("user" "auth" "product" "order" "payment" "inventory" "notification" "analytics" "search" "recommendation" "review" "admin")
    
    for service in "${SERVICES[@]}"; do
        log "Deploying $service-service..."
        kubectl apply -f ${service}-service-deployment.yaml
        
        # Wait for deployment to be ready
        kubectl rollout status deployment/${service}-service -n $NAMESPACE --timeout=300s
        
        log "$service-service deployed successfully"
    done
    
    log "All microservices deployed"
}

# Setup networking
setup_networking() {
    log "Setting up networking..."
    
    # Apply network policies
    kubectl apply -f network-policies.yaml
    
    # Setup ingress
    kubectl apply -f managed-ssl-cert.yaml
    kubectl apply -f ingress-ssl.yaml
    
    # Setup HPA
    kubectl apply -f hpa-all-services.yaml
    
    log "Networking setup completed"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check all pods are running
    kubectl get pods -n $NAMESPACE
    
    # Check services
    kubectl get svc -n $NAMESPACE
    
    # Check ingress
    kubectl get ingress -n $NAMESPACE
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get ingress microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ ! -z "$EXTERNAL_IP" ]; then
        log "External IP: $EXTERNAL_IP"
        log "You can access your application at: https://$EXTERNAL_IP"
    else
        warn "External IP not yet assigned. Check ingress status later."
    fi
    
    log "Deployment verification completed"
}

# Main execution
main() {
    log "Starting complete microservices deployment..."
    
    check_prerequisites
    setup_gke
    create_namespaces
    setup_secrets
    deploy_infrastructure
    deploy_microservices
    setup_networking
    verify_deployment
    
    log "Deployment completed successfully!"
    log "Next steps:"
    log "1. Configure DNS to point to the external IP"
    log "2. Access Grafana dashboard for monitoring"
    log "3. Check Jaeger for distributed tracing"
    log "4. Set up alerting rules in AlertManager"
}

# Run main function
main "$@"
```

### Cleanup Script
```bash
#!/bin/bash
# cleanup-microservices.sh

set -e

NAMESPACE="microservices"
MONITORING_NAMESPACE="monitoring"

echo "Cleaning up microservices deployment..."

# Delete microservices
kubectl delete namespace $NAMESPACE --ignore-not-found=true

# Delete monitoring
kubectl delete namespace $MONITORING_NAMESPACE --ignore-not-found=true

# Delete cluster (optional - uncomment if needed)
# gcloud container clusters delete microservices-cluster --region=us-central1 --quiet

echo "Cleanup completed!"
```

## Conclusion

This comprehensive guide provides a complete production-ready Kubernetes deployment for your 12-microservices project on GKE with:

### ✅ **Features Implemented:**
- **SSL/TLS encryption** with managed certificates
- **Comprehensive secrets management** for databases, APIs, and certificates
- **ConfigMaps** for application configuration
- **OpenTelemetry observability** with metrics, logs, and traces
- **Per-user tracking and analytics** with ClickHouse
- **Complete CI/CD pipeline** with GitHub Actions and ArgoCD
- **Advanced Kubernetes concepts** (HPA, VPA, PDB, Network Policies)
- **Production monitoring** with Prometheus, Grafana, and AlertManager
- **Distributed tracing** with Jaeger
- **Automated deployment scripts** for easy setup

### 🚀 **Next Steps:**
1. Customize the configurations for your specific services
2. Set up your container registry and CI/CD pipelines
3. Configure DNS and SSL certificates for your domain
4. Implement application-specific health checks
5. Set up backup and disaster recovery procedures
6. Configure log aggregation and analysis
7. Implement security scanning and compliance checks

### 📊 **Monitoring Capabilities:**
- Real-time metrics and dashboards
- Per-user request tracking and analytics
- Distributed tracing across all services
- Automated alerting for critical issues
- Resource usage optimization recommendations

This setup provides enterprise-grade reliability, security, and observability for your microservices architecture on GKE.
