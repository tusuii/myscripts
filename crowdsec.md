# Setting up CrowdSec with Istio
## Overview

CrowdSec works with Istio by deploying:
1. **CrowdSec LAPI** (Local API) - analyzes logs and makes blocking decisions
2. **Custom Bouncers** - enforce blocking decisions at various points in Istio

## Step 1: Install CrowdSec LAPI

First, deploy CrowdSec's Local API in your Kubernetes cluster:

```yaml
# crowdsec-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: crowdsec
```

```yaml
# crowdsec-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: crowdsec-config
  namespace: crowdsec
data:
  acquis.yaml: |
    source: kubernetes
    labels:
      type: kubernetes
---
apiVersion: v1
kind: Secret
metadata:
  name: crowdsec-lapi-secrets
  namespace: crowdsec
type: Opaque
stringData:
  # Generate a secure random string for your bouncer key
  bouncer-key: "YOUR_SECURE_BOUNCER_KEY_HERE"
```

```yaml
# crowdsec-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crowdsec
  namespace: crowdsec
spec:
  replicas: 2
  selector:
    matchLabels:
      app: crowdsec
  template:
    metadata:
      labels:
        app: crowdsec
    spec:
      containers:
      - name: crowdsec
        image: crowdsecurity/crowdsec:latest
        env:
        - name: COLLECTIONS
          value: "crowdsecurity/linux crowdsecurity/nginx crowdsecurity/http-cve crowdsecurity/whitelist-good-actors"
        - name: GID
          value: "1000"
        - name: BOUNCER_KEY_custom
          valueFrom:
            secretKeyRef:
              name: crowdsec-lapi-secrets
              key: bouncer-key
        ports:
        - containerPort: 8080
          name: lapi
        - containerPort: 6060
          name: metrics
        volumeMounts:
        - name: crowdsec-db
          mountPath: /var/lib/crowdsec/data
        - name: crowdsec-config
          mountPath: /etc/crowdsec/acquis.yaml
          subPath: acquis.yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: crowdsec-db
        persistentVolumeClaim:
          claimName: crowdsec-pvc
      - name: crowdsec-config
        configMap:
          name: crowdsec-config
---
apiVersion: v1
kind: Service
metadata:
  name: crowdsec-service
  namespace: crowdsec
spec:
  selector:
    app: crowdsec
  ports:
  - port: 8080
    targetPort: 8080
    name: lapi
  - port: 6060
    targetPort: 6060
    name: metrics
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: crowdsec-pvc
  namespace: crowdsec
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

Apply these configurations:
```bash
kubectl apply -f crowdsec-namespace.yaml
kubectl apply -f crowdsec-config.yaml
kubectl apply -f crowdsec-deployment.yaml
```

## Step 2: Create Custom Envoy Filter Bouncer

For Istio integration, you'll need to create a custom bouncer that works with Envoy (Istio's proxy). Here's an approach using an external authorization server:

```yaml
# crowdsec-bouncer-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crowdsec-envoy-bouncer
  namespace: crowdsec
spec:
  replicas: 2
  selector:
    matchLabels:
      app: crowdsec-bouncer
  template:
    metadata:
      labels:
        app: crowdsec-bouncer
    spec:
      containers:
      - name: bouncer
        image: fbonalair/traefik-crowdsec-bouncer:latest  # Can be adapted for Envoy
        env:
        - name: CROWDSEC_BOUNCER_API_KEY
          valueFrom:
            secretKeyRef:
              name: crowdsec-lapi-secrets
              key: bouncer-key
        - name: CROWDSEC_AGENT_HOST
          value: "crowdsec-service.crowdsec.svc.cluster.local:8080"
        - name: BOUNCER_LOG_LEVEL
          value: "INFO"
        ports:
        - containerPort: 8080
          name: http
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
  name: crowdsec-bouncer-service
  namespace: crowdsec
spec:
  selector:
    app: crowdsec-bouncer
  ports:
  - port: 8080
    targetPort: 8080
    name: http
```

## Step 3: Configure Istio EnvoyFilter for External Authorization

```yaml
# istio-envoy-filter.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: crowdsec-ext-authz
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
            subFilter:
              name: "envoy.filters.http.router"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.ext_authz
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
          transport_api_version: V3
          grpc_service:
            envoy_grpc:
              cluster_name: outbound|8080||crowdsec-bouncer-service.crowdsec.svc.cluster.local
            timeout: 0.5s
          failure_mode_allow: false
          with_request_body:
            max_request_bytes: 8192
            allow_partial_message: true
  - applyTo: CLUSTER
    match:
      context: GATEWAY
    patch:
      operation: ADD
      value:
        name: outbound|8080||crowdsec-bouncer-service.crowdsec.svc.cluster.local
        type: STRICT_DNS
        connect_timeout: 1s
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: crowdsec-bouncer-service.crowdsec.svc.cluster.local
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: crowdsec-bouncer-service.crowdsec.svc.cluster.local
                    port_value: 8080
```

## Step 4: Alternative - Lua Script Bouncer in Envoy

For a more direct integration, you can use a Lua script in Envoy:

```yaml
# crowdsec-lua-filter.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: crowdsec-lua-filter
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inline_code: |
            function envoy_on_request(request_handle)
              local headers = request_handle:headers()
              local ip = headers:get("x-forwarded-for") or headers:get("x-real-ip")
              
              -- Query CrowdSec LAPI
              local lapi_headers, lapi_body = request_handle:httpCall(
                "crowdsec_lapi",
                {
                  [":method"] = "GET",
                  [":path"] = "/v1/decisions?ip=" .. ip,
                  [":authority"] = "crowdsec-service.crowdsec.svc.cluster.local",
                  ["X-Api-Key"] = "YOUR_BOUNCER_KEY"
                },
                "",
                5000
              )
              
              if lapi_body and lapi_body ~= "null" and lapi_body ~= "[]" then
                request_handle:respond(
                  {[":status"] = "403"},
                  "Access Denied by CrowdSec"
                )
              end
            end
  - applyTo: CLUSTER
    match:
      context: GATEWAY
    patch:
      operation: ADD
      value:
        name: crowdsec_lapi
        type: STRICT_DNS
        connect_timeout: 5s
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: crowdsec_lapi
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: crowdsec-service.crowdsec.svc.cluster.local
                    port_value: 8080
```

## Step 5: Configure CrowdSec Scenarios for DDoS Protection

```yaml
# crowdsec-scenarios-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: crowdsec-custom-scenarios
  namespace: crowdsec
data:
  ddos-scenarios.yaml: |
    type: leaky
    name: custom/http-ddos
    description: "Detect HTTP DDoS attacks"
    filter: "evt.Meta.log_type == 'http_access-log'"
    leakspeed: 10s
    capacity: 50
    groupby: evt.Meta.source_ip
    blackhole: 5m
    labels:
      service: http
      type: ddos
      remediation: ban
    ---
    type: trigger
    name: custom/http-scan
    description: "Detect HTTP scanning"
    filter: "evt.Meta.http_status in ['404', '403', '401']"
    groupby: evt.Meta.source_ip
    distinct: evt.Meta.http_path
    capacity: 10
    leakspeed: 30s
    blackhole: 10m
    labels:
      service: http
      type: scan
      remediation: ban
```

Mount this ConfigMap in your CrowdSec deployment:

```yaml
# Add to crowdsec-deployment.yaml volumes section
- name: custom-scenarios
  configMap:
    name: crowdsec-custom-scenarios

# Add to volumeMounts
- name: custom-scenarios
  mountPath: /etc/crowdsec/scenarios/ddos-scenarios.yaml
  subPath: ddos-scenarios.yaml
```

## Step 6: Feed Istio Access Logs to CrowdSec

Enable Istio access logs and configure log forwarding:

```yaml
# istio-telemetry.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: envoy
    filter:
      expression: response.code >= 200
```

Create a log forwarder (Fluent Bit or similar):

```yaml
# fluent-bit-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: istio-system
data:
  fluent-bit.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*istio-proxy*.log
        Parser            docker
        Tag               istio.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB

    [FILTER]
        Name    parser
        Match   istio.*
        Key_Name log
        Parser  istio-access

    [OUTPUT]
        Name   http
        Match  istio.*
        Host   crowdsec-service.crowdsec.svc.cluster.local
        Port   8080
        URI    /v1/logs
        Format json
        Header X-Api-Key YOUR_BOUNCER_KEY

  parsers.conf: |
    [PARSER]
        Name        istio-access
        Format      regex
        Regex       ^\[(?<timestamp>[^\]]+)\] "(?<method>\S+) (?<path>\S+) (?<protocol>\S+)" (?<response_code>\d+) (?<response_flags>\S+) (?<bytes_received>\d+) (?<bytes_sent>\d+) (?<duration>\d+) (?<upstream_service_time>\S+) "(?<x_forwarded_for>[^"]*)" "(?<user_agent>[^"]*)"
        Time_Key    timestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
```

## Step 7: Test and Monitor

Test the setup:

```bash
# Check CrowdSec is running
kubectl get pods -n crowdsec

# View CrowdSec decisions
kubectl exec -n crowdsec deployment/crowdsec -- cscli decisions list

# Manually add a test ban
kubectl exec -n crowdsec deployment/crowdsec -- cscli decisions add --ip 1.2.3.4 --duration 1h --reason "test"

# Test from that IP - should get 403
curl -H "X-Forwarded-For: 1.2.3.4" http://your-istio-gateway/

# View metrics
kubectl exec -n crowdsec deployment/crowdsec -- cscli metrics

# Check bouncer connectivity
kubectl logs -n crowdsec deployment/crowdsec-envoy-bouncer
```

Monitor CrowdSec alerts:

```bash
# Watch for new decisions
kubectl exec -n crowdsec deployment/crowdsec -- cscli alerts list

# View hub updates
kubectl exec -n crowdsec deployment/crowdsec -- cscli hub list
```

## Additional DDoS Protection Configurations

Configure rate limiting scenarios:

```bash
# Install additional collections
kubectl exec -n crowdsec deployment/crowdsec -- cscli collections install crowdsecurity/http-cve
kubectl exec -n crowdsec deployment/crowdsec -- cscli collections install crowdsecurity/iptables
kubectl exec -n crowdsec deployment/crowdsec -- cscli collections install crowdsecurity/appsec-virtual-patching
```


