# Kubernetes Secrets Implementation Guide for GKE Microservices

## Overview
This guide covers implementing Kubernetes secrets for a 12-microservices project hosted on Google Kubernetes Engine (GKE).

## Prerequisites
- GKE cluster running
- kubectl configured to connect to your cluster
- Basic understanding of your microservices architecture

## Step 1: Verify Cluster Connection

```bash
# Check cluster connection
kubectl cluster-info

# List current namespaces
kubectl get namespaces

# Create namespace for your microservices (if not exists)
kubectl create namespace microservices
```

## Step 2: Types of Secrets You'll Need

### 2.1 Database Credentials Secret
```yaml
# db-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: microservices
type: Opaque
data:
  # Base64 encoded values
  username: <base64-encoded-username>
  password: <base64-encoded-password>
  host: <base64-encoded-host>
  port: <base64-encoded-port>
```

### 2.2 API Keys Secret
```yaml
# api-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: microservices
type: Opaque
data:
  jwt-secret: <base64-encoded-jwt-secret>
  encryption-key: <base64-encoded-encryption-key>
  third-party-api-key: <base64-encoded-api-key>
```

### 2.3 Service-to-Service Communication Secret
```yaml
# service-auth-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: service-auth
  namespace: microservices
type: Opaque
data:
  service-token: <base64-encoded-service-token>
  internal-api-key: <base64-encoded-internal-key>
```

## Step 3: Create Secrets Using kubectl

### Method 1: From Command Line (Recommended for sensitive data)
```bash
# Create database secret
kubectl create secret generic db-credentials \
  --from-literal=username=myuser \
  --from-literal=password=mypassword \
  --from-literal=host=db.example.com \
  --from-literal=port=5432 \
  --namespace=microservices

# Create API keys secret
kubectl create secret generic api-keys \
  --from-literal=jwt-secret=your-jwt-secret \
  --from-literal=encryption-key=your-encryption-key \
  --from-literal=third-party-api-key=your-api-key \
  --namespace=microservices

# Create service auth secret
kubectl create secret generic service-auth \
  --from-literal=service-token=your-service-token \
  --from-literal=internal-api-key=your-internal-key \
  --namespace=microservices
```

### Method 2: From Files
```bash
# If you have credential files
kubectl create secret generic app-config \
  --from-file=config.json \
  --from-file=credentials.txt \
  --namespace=microservices
```

## Step 4: Microservice Deployment Template

### Sample Deployment for Each Microservice
```yaml
# microservice-deployment.yaml (template for each of your 12 services)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service  # Change for each microservice
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: gcr.io/your-project/user-service:latest
        ports:
        - containerPort: 8080
        env:
        # Database credentials from secret
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: port
        # API keys from secret
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: jwt-secret
        - name: ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: encryption-key
        # Service auth from secret
        - name: SERVICE_TOKEN
          valueFrom:
            secretKeyRef:
              name: service-auth
              key: service-token
        # Mount secrets as files (alternative approach)
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: config-volume
        secret:
          secretName: api-keys
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

## Step 5: Implementation Steps

### 5.1 Create All Secrets
```bash
# Apply all secret files
kubectl apply -f db-secrets.yaml
kubectl apply -f api-secrets.yaml
kubectl apply -f service-auth-secrets.yaml

# Verify secrets are created
kubectl get secrets -n microservices
```

### 5.2 Deploy Your 12 Microservices
Create deployment files for each service:

1. **user-service-deployment.yaml**
2. **auth-service-deployment.yaml**
3. **product-service-deployment.yaml**
4. **order-service-deployment.yaml**
5. **payment-service-deployment.yaml**
6. **inventory-service-deployment.yaml**
7. **notification-service-deployment.yaml**
8. **analytics-service-deployment.yaml**
9. **search-service-deployment.yaml**
10. **recommendation-service-deployment.yaml**
11. **review-service-deployment.yaml**
12. **admin-service-deployment.yaml**

```bash
# Deploy all services
kubectl apply -f user-service-deployment.yaml
kubectl apply -f auth-service-deployment.yaml
# ... repeat for all 12 services

# Check deployments
kubectl get deployments -n microservices
kubectl get pods -n microservices
```

## Step 6: Advanced Secret Management

### 6.1 Using Google Secret Manager (Recommended for GKE)
```yaml
# secret-manager-csi.yaml
apiVersion: v1
kind: SecretProviderClass
metadata:
  name: app-secrets
  namespace: microservices
spec:
  provider: gcp
  parameters:
    secrets: |
      - resourceName: "projects/your-project-id/secrets/db-password/versions/latest"
        path: "db-password"
      - resourceName: "projects/your-project-id/secrets/api-key/versions/latest"
        path: "api-key"
```

### 6.2 Enable Workload Identity (GKE Best Practice)
```bash
# Enable Workload Identity on cluster
gcloud container clusters update your-cluster-name \
    --workload-pool=your-project-id.svc.id.goog

# Create Kubernetes service account
kubectl create serviceaccount workload-identity-sa \
    --namespace=microservices

# Create Google service account
gcloud iam service-accounts create gsa-name

# Bind accounts
gcloud iam service-accounts add-iam-policy-binding \
    gsa-name@your-project-id.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:your-project-id.svc.id.goog[microservices/workload-identity-sa]"

# Annotate Kubernetes service account
kubectl annotate serviceaccount workload-identity-sa \
    --namespace=microservices \
    iam.gke.io/gcp-service-account=gsa-name@your-project-id.iam.gserviceaccount.com
```

## Step 7: Security Best Practices

### 7.1 RBAC Configuration
```yaml
# rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: microservices
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: microservices
subjects:
- kind: ServiceAccount
  name: workload-identity-sa
  namespace: microservices
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 7.2 Network Policies
```yaml
# network-policy.yaml
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
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: microservices
```

## Step 8: Monitoring and Troubleshooting

### 8.1 Verify Secret Usage
```bash
# Check if secrets are mounted correctly
kubectl exec -it <pod-name> -n microservices -- env | grep -E "(DB_|JWT_|API_)"

# Check mounted files
kubectl exec -it <pod-name> -n microservices -- ls -la /etc/config/

# View secret details (without values)
kubectl describe secret db-credentials -n microservices
```

### 8.2 Common Issues and Solutions

**Issue: Secret not found**
```bash
# Check secret exists
kubectl get secrets -n microservices

# Check namespace
kubectl get pods -n microservices
```

**Issue: Permission denied**
```bash
# Check RBAC
kubectl auth can-i get secrets --as=system:serviceaccount:microservices:default -n microservices
```

## Step 9: Deployment Script

### 9.1 Complete Deployment Script
```bash
#!/bin/bash
# deploy-microservices.sh

set -e

NAMESPACE="microservices"
PROJECT_ID="your-project-id"

echo "Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Creating secrets..."
kubectl create secret generic db-credentials \
  --from-literal=username=$DB_USERNAME \
  --from-literal=password=$DB_PASSWORD \
  --from-literal=host=$DB_HOST \
  --from-literal=port=$DB_PORT \
  --namespace=$NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying microservices..."
for service in user auth product order payment inventory notification analytics search recommendation review admin; do
  echo "Deploying $service-service..."
  kubectl apply -f ${service}-service-deployment.yaml
done

echo "Checking deployment status..."
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

echo "Deployment complete!"
```

## Step 10: Maintenance and Updates

### 10.1 Updating Secrets
```bash
# Update existing secret
kubectl create secret generic db-credentials \
  --from-literal=username=newuser \
  --from-literal=password=newpassword \
  --namespace=microservices \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart deployments to pick up new secrets
kubectl rollout restart deployment -n microservices
```

### 10.2 Secret Rotation
```bash
# Create rotation script
#!/bin/bash
# rotate-secrets.sh

SERVICES=("user" "auth" "product" "order" "payment" "inventory" "notification" "analytics" "search" "recommendation" "review" "admin")

for service in "${SERVICES[@]}"; do
  kubectl rollout restart deployment ${service}-service -n microservices
  kubectl rollout status deployment ${service}-service -n microservices
done
```

## Conclusion

This guide provides a complete implementation of Kubernetes secrets for your 12-microservices GKE project. Key points:

1. Use `kubectl create secret` for sensitive data
2. Reference secrets in deployments via `secretKeyRef`
3. Implement RBAC for security
4. Consider Google Secret Manager for production
5. Use Workload Identity for GKE integration
6. Monitor and maintain secrets regularly

Remember to:
- Never commit secrets to version control
- Rotate secrets regularly
- Use least privilege access
- Monitor secret usage
- Backup your secret configurations (not the values)
