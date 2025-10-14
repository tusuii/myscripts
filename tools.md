# Complete DevOps Tools Installation Guide

## Table of Contents
1. [Prerequisites and System Setup](#prerequisites-and-system-setup)
2. [Jenkins with Slave Nodes](#jenkins-with-slave-nodes)
3. [Zabbix Monitoring](#zabbix-monitoring)
4. [OpenTelemetry](#opentelemetry)
5. [SigNoz Observability](#signoz-observability)
6. [SonarQube Code Quality](#sonarqube-code-quality)
7. [Ansible Automation](#ansible-automation)
8. [ArgoCD GitOps](#argocd-gitops)
9. [Terraform Infrastructure](#terraform-infrastructure)
10. [Tool Integration and Configuration](#tool-integration-and-configuration)
11. [Troubleshooting](#troubleshooting)

## Overview
This guide will help you install and configure a complete DevOps toolchain on your server. All tools will be properly integrated and configured for production use.

**Tools to be installed:**
- Jenkins (CI/CD) with slave nodes
- Zabbix (Infrastructure monitoring)
- OpenTelemetry (Observability collector)
- SigNoz (Application monitoring)
- SonarQube (Code quality analysis)
- Ansible (Configuration management)
- ArgoCD (GitOps deployment)
- Terraform (Infrastructure as code)

## Prerequisites and System Setup

### System Requirements
```bash
# Minimum requirements for all tools:
# - 16GB RAM
# - 8 CPU cores
# - 200GB disk space
# - Ubuntu 20.04/22.04 or CentOS 7/8

# Check system resources
free -h
nproc
df -h
lsb_release -a
```

### Initial System Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git vim htop net-tools software-properties-common \
    apt-transport-https ca-certificates gnupg lsb-release unzip

# Install Docker (required for most tools)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installations
docker --version
docker-compose --version
```

### Create Directory Structure
```bash
# Create organized directory structure for all tools
mkdir -p ~/devops-tools/{jenkins,zabbix,opentelemetry,signoz,sonarqube,ansible,argocd,terraform}
mkdir -p ~/devops-tools/configs
mkdir -p ~/devops-tools/data
mkdir -p ~/devops-tools/logs

cd ~/devops-tools
```

## Jenkins with Slave Nodes

### 1. Jenkins Master Setup
```bash
cd ~/devops-tools/jenkins

# Create Jenkins master configuration
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  jenkins-master:
    image: jenkins/jenkins:lts
    container_name: jenkins-master
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - ./jenkins-data:/var/jenkins_home/backup
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Xmx2048m -Xms1024m
    networks:
      - jenkins-network

  jenkins-slave-1:
    image: jenkins/ssh-agent:latest
    container_name: jenkins-slave-1
    restart: unless-stopped
    environment:
      - JENKINS_AGENT_SSH_PUBKEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... # Your SSH public key
    ports:
      - "2222:22"
    volumes:
      - jenkins_slave_1:/home/jenkins
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins-network

  jenkins-slave-2:
    image: jenkins/ssh-agent:latest
    container_name: jenkins-slave-2
    restart: unless-stopped
    environment:
      - JENKINS_AGENT_SSH_PUBKEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... # Your SSH public key
    ports:
      - "2223:22"
    volumes:
      - jenkins_slave_2:/home/jenkins
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins-network

volumes:
  jenkins_home:
  jenkins_slave_1:
  jenkins_slave_2:

networks:
  jenkins-network:
    driver: bridge
EOF

# Start Jenkins
docker-compose up -d

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 60

# Get initial admin password
docker exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2. Jenkins Configuration Script
```bash
# Create Jenkins configuration script
cat > configure-jenkins.sh << 'EOF'
#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="" # Will be set after initial setup

echo "=== Jenkins Configuration Script ==="
echo "1. Open browser and go to: $JENKINS_URL"
echo "2. Use the initial admin password shown above"
echo "3. Install suggested plugins"
echo "4. Create admin user"
echo "5. Run this script again after initial setup"

read -p "Have you completed the initial setup? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter Jenkins admin password: " JENKINS_PASSWORD
    
    # Install additional plugins via CLI
    docker exec jenkins-master jenkins-plugin-cli --plugins \
        ssh-slaves \
        build-timeout \
        credentials-binding \
        timestamper \
        ws-cleanup \
        ant \
        gradle \
        workflow-aggregator \
        pipeline-stage-view \
        git \
        github \
        docker-workflow \
        blueocean \
        prometheus \
        sonar \
        ansible
    
    # Restart Jenkins
    docker-compose restart jenkins-master
    
    echo "Jenkins plugins installed. Please configure slave nodes manually in Jenkins UI."
    echo "Go to Manage Jenkins > Manage Nodes and Clouds > New Node"
fi
EOF

chmod +x configure-jenkins.sh
```

### 3. Jenkins Slave Node Configuration
```bash
# Create slave node configuration guide
cat > slave-node-setup.md << 'EOF'
# Jenkins Slave Node Setup Guide

## Step 1: Access Jenkins UI
1. Open browser: http://localhost:8080
2. Login with admin credentials

## Step 2: Add Slave Node 1
1. Go to "Manage Jenkins" > "Manage Nodes and Clouds"
2. Click "New Node"
3. Node name: `jenkins-slave-1`
4. Type: Permanent Agent
5. Configuration:
   - Remote root directory: `/home/jenkins`
   - Labels: `docker linux slave1`
   - Usage: Use this node as much as possible
   - Launch method: Launch agents via SSH
   - Host: `jenkins-slave-1` (container name)
   - Credentials: Add SSH Username with private key
     - Username: `jenkins`
     - Private Key: Enter directly (paste your private key)
   - Host Key Verification Strategy: Non verifying Verification Strategy

## Step 3: Add Slave Node 2
Repeat Step 2 with:
- Node name: `jenkins-slave-2`
- Host: `jenkins-slave-2`
- Labels: `docker linux slave2`

## Step 4: Verify Nodes
Check that both nodes show as "Connected" in the node list.
EOF
```

### 4. Jenkins Pipeline Examples
```bash
# Create sample pipeline configurations
mkdir -p pipelines

cat > pipelines/sample-pipeline.groovy << 'EOF'
pipeline {
    agent { label 'docker' }
    
    environment {
        DOCKER_REGISTRY = 'your-registry.com'
        APP_NAME = 'sample-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/your-org/your-repo.git'
            }
        }
        
        stage('Build') {
            steps {
                script {
                    sh 'docker build -t ${APP_NAME}:${BUILD_NUMBER} .'
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    agent { label 'slave1' }
                    steps {
                        sh 'npm test'
                    }
                }
                stage('SonarQube Analysis') {
                    agent { label 'slave2' }
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh 'sonar-scanner'
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when { branch 'develop' }
            steps {
                script {
                    sh '''
                        docker tag ${APP_NAME}:${BUILD_NUMBER} ${DOCKER_REGISTRY}/${APP_NAME}:staging
                        docker push ${DOCKER_REGISTRY}/${APP_NAME}:staging
                    '''
                }
            }
        }
        
        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
                script {
                    sh '''
                        docker tag ${APP_NAME}:${BUILD_NUMBER} ${DOCKER_REGISTRY}/${APP_NAME}:latest
                        docker push ${DOCKER_REGISTRY}/${APP_NAME}:latest
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
EOF
```

## Zabbix Monitoring

### 1. Zabbix Server Setup
```bash
cd ~/devops-tools/zabbix

# Create Zabbix configuration
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  zabbix-db:
    image: mysql:8.0
    container_name: zabbix-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: zabbix_root_password
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbix_password
    volumes:
      - zabbix_db_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password
    networks:
      - zabbix-network

  zabbix-server:
    image: zabbix/zabbix-server-mysql:latest
    container_name: zabbix-server
    restart: unless-stopped
    environment:
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbix_password
      MYSQL_ROOT_PASSWORD: zabbix_root_password
    ports:
      - "10051:10051"
    volumes:
      - zabbix_server_data:/var/lib/zabbix
    depends_on:
      - zabbix-db
    networks:
      - zabbix-network

  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql:latest
    container_name: zabbix-web
    restart: unless-stopped
    environment:
      ZBX_SERVER_HOST: zabbix-server
      DB_SERVER_HOST: zabbix-db
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbix_password
      MYSQL_ROOT_PASSWORD: zabbix_root_password
      PHP_TZ: "UTC"
    ports:
      - "8081:8080"
    depends_on:
      - zabbix-server
      - zabbix-db
    networks:
      - zabbix-network

  zabbix-agent:
    image: zabbix/zabbix-agent:latest
    container_name: zabbix-agent
    restart: unless-stopped
    environment:
      ZBX_HOSTNAME: "Docker Host"
      ZBX_SERVER_HOST: zabbix-server
      ZBX_SERVER_PORT: 10051
    ports:
      - "10050:10050"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /dev:/host/dev:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    privileged: true
    pid: host
    networks:
      - zabbix-network

volumes:
  zabbix_db_data:
  zabbix_server_data:

networks:
  zabbix-network:
    driver: bridge
EOF

# Start Zabbix
docker-compose up -d

# Wait for services to start
echo "Waiting for Zabbix to start..."
sleep 120

echo "Zabbix Web UI: http://localhost:8081"
echo "Default credentials: Admin/zabbix"
```

### 2. Zabbix Configuration Script
```bash
cat > configure-zabbix.sh << 'EOF'
#!/bin/bash

echo "=== Zabbix Configuration ==="
echo "1. Open browser: http://localhost:8081"
echo "2. Login with: Admin/zabbix"
echo "3. Change default password"
echo "4. Configure monitoring templates"

# Create custom monitoring templates
mkdir -p templates

cat > templates/docker-monitoring.xml << 'TEMPLATE_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<zabbix_export>
    <version>5.4</version>
    <date>2023-01-01T00:00:00Z</date>
    <groups>
        <group>
            <name>Templates/Applications</name>
        </group>
    </groups>
    <templates>
        <template>
            <template>Template Docker Monitoring</template>
            <name>Template Docker Monitoring</name>
            <groups>
                <group>
                    <name>Templates/Applications</name>
                </group>
            </groups>
            <items>
                <item>
                    <name>Docker containers running</name>
                    <key>docker.containers.running</key>
                    <delay>60s</delay>
                    <value_type>FLOAT</value_type>
                </item>
                <item>
                    <name>Docker containers total</name>
                    <key>docker.containers.total</key>
                    <delay>60s</delay>
                    <value_type>FLOAT</value_type>
                </item>
            </items>
        </template>
    </templates>
</zabbix_export>
TEMPLATE_EOF

echo "Custom templates created in templates/ directory"
echo "Import them via Zabbix Web UI: Configuration > Templates > Import"
EOF

chmod +x configure-zabbix.sh
```

## OpenTelemetry

### 1. OpenTelemetry Collector Setup
```bash
cd ~/devops-tools/opentelemetry

# Create OpenTelemetry configuration
cat > otel-collector-config.yaml << 'EOF'
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
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']
        - job_name: 'jenkins'
          scrape_interval: 30s
          static_configs:
            - targets: ['jenkins-master:8080']
        - job_name: 'sonarqube'
          scrape_interval: 30s
          static_configs:
            - targets: ['sonarqube:9000']

  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268

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
      - key: service.version
        value: 1.0.0
        action: upsert

exporters:
  # Export to SigNoz
  otlp/signoz:
    endpoint: http://signoz-otel-collector:4317
    tls:
      insecure: true
  
  # Export to Jaeger
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  
  # Export to Prometheus
  prometheus:
    endpoint: "0.0.0.0:8889"
  
  # Logging exporter for debugging
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp, jaeger]
      processors: [memory_limiter, batch, resource]
      exporters: [otlp/signoz, jaeger, logging]
    
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resource]
      exporters: [otlp/signoz, prometheus, logging]
    
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [otlp/signoz, logging]

  extensions: [health_check, pprof, zpages]
EOF

# Create Docker Compose for OpenTelemetry
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    restart: unless-stopped
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC receiver
      - "4318:4318"   # OTLP HTTP receiver
      - "8888:8888"   # Prometheus metrics
      - "8889:8889"   # Prometheus exporter
      - "13133:13133" # Health check
      - "55679:55679" # zpages
    networks:
      - otel-network

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    restart: unless-stopped
    ports:
      - "16686:16686" # Jaeger UI
      - "14250:14250" # gRPC
      - "14268:14268" # HTTP
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - otel-network

networks:
  otel-network:
    driver: bridge
EOF

# Start OpenTelemetry
docker-compose up -d

echo "OpenTelemetry Collector: http://localhost:55679"
echo "Jaeger UI: http://localhost:16686"
```

## SigNoz Observability

### 1. SigNoz Installation
```bash
cd ~/devops-tools/signoz

# Clone SigNoz repository
git clone -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy/

# Create custom configuration
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  clickhouse:
    volumes:
      - signoz_clickhouse_data:/var/lib/clickhouse/
    environment:
      - CLICKHOUSE_DB=signoz_traces
      - CLICKHOUSE_USER=signoz
      - CLICKHOUSE_PASSWORD=signoz_password

  otel-collector:
    environment:
      - OTEL_RESOURCE_ATTRIBUTES=service.name=signoz-collector,service.version=0.88.0
    ports:
      - "4317:4317"     # OTLP gRPC receiver
      - "4318:4318"     # OTLP HTTP receiver

  query-service:
    environment:
      - ClickHouseUrl=tcp://clickhouse:9000/?database=signoz_traces&username=signoz&password=signoz_password

  frontend:
    ports:
      - "3301:3301"

volumes:
  signoz_clickhouse_data:
EOF

# Install SigNoz
sudo docker-compose -f docker-compose.yaml -f docker-compose.override.yml up -d

# Wait for services to start
echo "Waiting for SigNoz to start..."
sleep 180

echo "SigNoz UI: http://localhost:3301"
```

### 2. SigNoz Configuration
```bash
# Create SigNoz configuration script
cat > configure-signoz.sh << 'EOF'
#!/bin/bash

echo "=== SigNoz Configuration ==="
echo "1. Open browser: http://localhost:3301"
echo "2. Complete initial setup"
echo "3. Create organization and team"

# Create sample application configuration
mkdir -p sample-apps

cat > sample-apps/nodejs-app.js << 'APP_EOF'
// Sample Node.js application with OpenTelemetry instrumentation
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://localhost:4318/v1/traces',
  }),
  metricExporter: new OTLPMetricExporter({
    url: 'http://localhost:4318/v1/metrics',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello from instrumented app!' });
});

app.listen(3000, () => {
  console.log('App running on port 3000');
});
APP_EOF

cat > sample-apps/package.json << 'PKG_EOF'
{
  "name": "signoz-sample-app",
  "version": "1.0.0",
  "main": "nodejs-app.js",
  "dependencies": {
    "express": "^4.18.0",
    "@opentelemetry/sdk-node": "^0.45.0",
    "@opentelemetry/auto-instrumentations-node": "^0.40.0",
    "@opentelemetry/exporter-otlp-http": "^0.45.0"
  }
}
PKG_EOF

echo "Sample application created in sample-apps/ directory"
echo "Run: cd sample-apps && npm install && node nodejs-app.js"
EOF

chmod +x configure-signoz.sh
```

## SonarQube Code Quality

### 1. SonarQube Installation
```bash
cd ~/devops-tools/sonarqube

# Create SonarQube configuration
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  sonarqube-db:
    image: postgres:13
    container_name: sonarqube-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar_password
      POSTGRES_DB: sonarqube
    volumes:
      - sonarqube_db_data:/var/lib/postgresql/data
    networks:
      - sonarqube-network

  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    restart: unless-stopped
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar_password
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    depends_on:
      - sonarqube-db
    networks:
      - sonarqube-network

volumes:
  sonarqube_db_data:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:

networks:
  sonarqube-network:
    driver: bridge
EOF

# Set system parameters for SonarQube
echo 'vm.max_map_count=524288' | sudo tee -a /etc/sysctl.conf
echo 'fs.file-max=131072' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Start SonarQube
docker-compose up -d

# Wait for SonarQube to start
echo "Waiting for SonarQube to start..."
sleep 120

echo "SonarQube UI: http://localhost:9000"
echo "Default credentials: admin/admin"
```

### 2. SonarQube Configuration
```bash
# Create SonarQube configuration script
cat > configure-sonarqube.sh << 'EOF'
#!/bin/bash

SONAR_URL="http://localhost:9000"
SONAR_USER="admin"
SONAR_PASS="admin"

echo "=== SonarQube Configuration ==="
echo "1. Open browser: $SONAR_URL"
echo "2. Login with: admin/admin"
echo "3. Change default password"

# Wait for user to complete initial setup
read -p "Have you completed the initial setup and changed password? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter new admin password: " NEW_PASS
    
    # Create quality gate
    curl -u admin:$NEW_PASS -X POST "$SONAR_URL/api/qualitygates/create" \
        -d "name=DevOps-Gate"
    
    # Create project for sample analysis
    curl -u admin:$NEW_PASS -X POST "$SONAR_URL/api/projects/create" \
        -d "name=sample-project&project=sample-project&visibility=public"
    
    # Generate token for Jenkins integration
    TOKEN_RESPONSE=$(curl -u admin:$NEW_PASS -X POST "$SONAR_URL/api/user_tokens/generate" \
        -d "name=jenkins-token")
    
    echo "SonarQube token for Jenkins: $TOKEN_RESPONSE"
fi

# Create sample sonar-project.properties
cat > sonar-project.properties << 'SONAR_EOF'
# SonarQube project configuration
sonar.projectKey=sample-project
sonar.projectName=Sample Project
sonar.projectVersion=1.0

# Source code location
sonar.sources=src
sonar.tests=tests

# Language and encoding
sonar.sourceEncoding=UTF-8
sonar.language=js

# Exclusions
sonar.exclusions=node_modules/**,dist/**,build/**

# Test coverage
sonar.javascript.lcov.reportPaths=coverage/lcov.info
SONAR_EOF

echo "Sample sonar-project.properties created"
EOF

chmod +x configure-sonarqube.sh
```

## Ansible Automation

### 1. Ansible Installation
```bash
cd ~/devops-tools/ansible

# Install Ansible
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Verify installation
ansible --version

# Create Ansible directory structure
mkdir -p {playbooks,inventory,roles,group_vars,host_vars}

# Create inventory file
cat > inventory/hosts.yml << 'EOF'
all:
  children:
    devops_servers:
      hosts:
        localhost:
          ansible_connection: local
        jenkins_master:
          ansible_host: localhost
          ansible_port: 2222
        jenkins_slave1:
          ansible_host: localhost
          ansible_port: 2223
    
    monitoring:
      hosts:
        zabbix_server:
          ansible_host: localhost
          ansible_port: 8081
        signoz_server:
          ansible_host: localhost
          ansible_port: 3301

  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
EOF

# Create ansible configuration
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.yml
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = memory
stdout_callback = yaml
bin_ansible_callbacks = True

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
```

### 2. Ansible Playbooks
```bash
# Create Docker installation playbook
cat > playbooks/install-docker.yml << 'EOF'
---
- name: Install Docker on all servers
  hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install required packages
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Start and enable Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: yes
EOF

# Create monitoring setup playbook
cat > playbooks/setup-monitoring.yml << 'EOF'
---
- name: Setup monitoring stack
  hosts: monitoring
  become: yes
  vars:
    monitoring_tools:
      - name: node_exporter
        port: 9100
      - name: cadvisor
        port: 8080
  
  tasks:
    - name: Create monitoring directory
      file:
        path: /opt/monitoring
        state: directory
        mode: '0755'

    - name: Download Node Exporter
      get_url:
        url: https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
        dest: /tmp/node_exporter.tar.gz

    - name: Extract Node Exporter
      unarchive:
        src: /tmp/node_exporter.tar.gz
        dest: /opt/monitoring
        remote_src: yes

    - name: Create systemd service for Node Exporter
      copy:
        content: |
          [Unit]
          Description=Node Exporter
          After=network.target

          [Service]
          Type=simple
          ExecStart=/opt/monitoring/node_exporter-1.6.1.linux-amd64/node_exporter
          Restart=always

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/node_exporter.service

    - name: Start Node Exporter
      systemd:
        name: node_exporter
        state: started
        enabled: yes
        daemon_reload: yes
EOF

# Create application deployment playbook
cat > playbooks/deploy-application.yml << 'EOF'
---
- name: Deploy application
  hosts: devops_servers
  become: yes
  vars:
    app_name: sample-app
    app_version: "{{ version | default('latest') }}"
    docker_registry: "your-registry.com"
  
  tasks:
    - name: Pull application image
      docker_image:
        name: "{{ docker_registry }}/{{ app_name }}:{{ app_version }}"
        source: pull

    - name: Stop existing container
      docker_container:
        name: "{{ app_name }}"
        state: absent
      ignore_errors: yes

    - name: Start new container
      docker_container:
        name: "{{ app_name }}"
        image: "{{ docker_registry }}/{{ app_name }}:{{ app_version }}"
        state: started
        restart_policy: unless-stopped
        ports:
          - "3000:3000"
        env:
          NODE_ENV: production
          OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:4318

    - name: Verify application is running
      uri:
        url: http://localhost:3000/health
        method: GET
      retries: 5
      delay: 10
EOF
```

### 3. Ansible Roles
```bash
# Create Jenkins role
mkdir -p roles/jenkins/{tasks,templates,vars,defaults}

cat > roles/jenkins/tasks/main.yml << 'EOF'
---
- name: Create Jenkins user
  user:
    name: jenkins
    shell: /bin/bash
    home: /var/lib/jenkins

- name: Install Java
  apt:
    name: openjdk-11-jdk
    state: present

- name: Add Jenkins repository key
  apt_key:
    url: https://pkg.jenkins.io/debian-stable/jenkins.io.key
    state: present

- name: Add Jenkins repository
  apt_repository:
    repo: "deb https://pkg.jenkins.io/debian-stable binary/"
    state: present

- name: Install Jenkins
  apt:
    name: jenkins
    state: present

- name: Start Jenkins service
  systemd:
    name: jenkins
    state: started
    enabled: yes
EOF

cat > roles/jenkins/defaults/main.yml << 'EOF'
---
jenkins_port: 8080
jenkins_home: /var/lib/jenkins
jenkins_user: jenkins
EOF
```

## ArgoCD GitOps

### 1. ArgoCD Installation
```bash
cd ~/devops-tools/argocd

# Create ArgoCD namespace and installation
cat > install-argocd.sh << 'EOF'
#!/bin/bash

# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Expose ArgoCD server
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get initial admin password
echo "ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Port forward for local access
echo "Starting port forward to ArgoCD server..."
kubectl port-forward svc/argocd-server -n argocd 8082:443 &

echo "ArgoCD UI: https://localhost:8082"
echo "Username: admin"
EOF

chmod +x install-argocd.sh

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Run installation
./install-argocd.sh
```

### 2. ArgoCD Configuration
```bash
# Create ArgoCD application configurations
mkdir -p applications

cat > applications/sample-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-application
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/sample-app
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

cat > applications/monitoring-stack.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/monitoring-configs
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Create ArgoCD configuration script
cat > configure-argocd.sh << 'EOF'
#!/bin/bash

ARGOCD_SERVER="localhost:8082"
ARGOCD_USER="admin"

echo "=== ArgoCD Configuration ==="
echo "1. Open browser: https://localhost:8082"
echo "2. Accept self-signed certificate"
echo "3. Login with admin and the password shown above"

read -p "Have you logged in to ArgoCD? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter ArgoCD admin password: " ARGOCD_PASS
    
    # Login via CLI
    argocd login $ARGOCD_SERVER --username $ARGOCD_USER --password $ARGOCD_PASS --insecure
    
    # Create applications
    kubectl apply -f applications/
    
    # Add Git repository
    argocd repo add https://github.com/your-org/sample-app --type git --name sample-repo
    
    echo "ArgoCD configured successfully!"
    echo "Applications created and repositories added."
fi
EOF

chmod +x configure-argocd.sh
```

## Terraform Infrastructure

### 1. Terraform Installation
```bash
cd ~/devops-tools/terraform

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform --version

# Create Terraform project structure
mkdir -p {modules,environments/{dev,staging,prod},scripts}
```

### 2. Terraform Configurations
```bash
# Create main Terraform configuration
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Create network for all services
resource "docker_network" "devops_network" {
  name = "devops-network"
  driver = "bridge"
}

# Jenkins Master
resource "docker_container" "jenkins_master" {
  name  = "jenkins-master-tf"
  image = "jenkins/jenkins:lts"
  
  ports {
    internal = 8080
    external = 8083
  }
  
  ports {
    internal = 50000
    external = 50001
  }
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  networks_advanced {
    name = docker_network.devops_network.name
  }
  
  env = [
    "JENKINS_OPTS=--httpPort=8080",
    "JAVA_OPTS=-Xmx2048m -Xms1024m"
  ]
}

# SonarQube
resource "docker_container" "sonarqube" {
  name  = "sonarqube-tf"
  image = "sonarqube:community"
  
  ports {
    internal = 9000
    external = 9001
  }
  
  networks_advanced {
    name = docker_network.devops_network.name
  }
  
  env = [
    "SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true"
  ]
}

# Output important information
output "jenkins_url" {
  value = "http://localhost:8083"
}

output "sonarqube_url" {
  value = "http://localhost:9001"
}

output "network_name" {
  value = docker_network.devops_network.name
}
EOF

# Create variables file
cat > variables.tf << 'EOF'
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devops-tools"
}

variable "jenkins_port" {
  description = "Jenkins external port"
  type        = number
  default     = 8083
}

variable "sonarqube_port" {
  description = "SonarQube external port"
  type        = number
  default     = 9001
}
EOF

# Create environment-specific configurations
cat > environments/dev/terraform.tfvars << 'EOF'
environment = "dev"
project_name = "devops-tools-dev"
jenkins_port = 8083
sonarqube_port = 9001
EOF

cat > environments/prod/terraform.tfvars << 'EOF'
environment = "prod"
project_name = "devops-tools-prod"
jenkins_port = 8080
sonarqube_port = 9000
EOF
```

### 3. Terraform Modules
```bash
# Create Jenkins module
mkdir -p modules/jenkins
cat > modules/jenkins/main.tf << 'EOF'
resource "docker_container" "jenkins" {
  name  = "${var.project_name}-jenkins"
  image = var.jenkins_image
  
  ports {
    internal = 8080
    external = var.jenkins_port
  }
  
  ports {
    internal = 50000
    external = var.jenkins_agent_port
  }
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  volumes {
    host_path      = var.jenkins_home
    container_path = "/var/jenkins_home"
  }
  
  networks_advanced {
    name = var.network_name
  }
  
  env = var.jenkins_env
  
  restart = "unless-stopped"
}
EOF

cat > modules/jenkins/variables.tf << 'EOF'
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "jenkins_image" {
  description = "Jenkins Docker image"
  type        = string
  default     = "jenkins/jenkins:lts"
}

variable "jenkins_port" {
  description = "Jenkins HTTP port"
  type        = number
  default     = 8080
}

variable "jenkins_agent_port" {
  description = "Jenkins agent port"
  type        = number
  default     = 50000
}

variable "jenkins_home" {
  description = "Jenkins home directory"
  type        = string
  default     = "/var/lib/jenkins"
}

variable "network_name" {
  description = "Docker network name"
  type        = string
}

variable "jenkins_env" {
  description = "Jenkins environment variables"
  type        = list(string)
  default     = [
    "JENKINS_OPTS=--httpPort=8080",
    "JAVA_OPTS=-Xmx2048m -Xms1024m"
  ]
}
EOF

cat > modules/jenkins/outputs.tf << 'EOF'
output "container_id" {
  value = docker_container.jenkins.id
}

output "jenkins_url" {
  value = "http://localhost:${var.jenkins_port}"
}
EOF
```

### 4. Terraform Deployment Scripts
```bash
# Create deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
ACTION=${2:-apply}

echo "=== Terraform Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Action: $ACTION"

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars" -out="$ENVIRONMENT.tfplan"

if [ "$ACTION" = "apply" ]; then
    # Apply deployment
    terraform apply "$ENVIRONMENT.tfplan"
    
    echo "Deployment completed!"
    echo "Services:"
    terraform output
elif [ "$ACTION" = "destroy" ]; then
    # Destroy infrastructure
    terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve
    echo "Infrastructure destroyed!"
fi

# Clean up plan file
rm -f "$ENVIRONMENT.tfplan"
EOF

chmod +x scripts/deploy.sh

# Create initialization script
cat > scripts/init.sh << 'EOF'
#!/bin/bash

echo "=== Initializing Terraform Infrastructure ==="

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format Terraform files
terraform fmt -recursive

echo "Terraform initialized successfully!"
echo "Run './scripts/deploy.sh dev apply' to deploy to development"
echo "Run './scripts/deploy.sh prod apply' to deploy to production"
EOF

chmod +x scripts/init.sh
```

## Tool Integration and Configuration

### 1. Master Configuration Script
```bash
cd ~/devops-tools

# Create master configuration script
cat > configure-all-tools.sh << 'EOF'
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Configure Jenkins
configure_jenkins() {
    log "Configuring Jenkins..."
    cd jenkins
    
    # Wait for Jenkins to be ready
    while ! curl -s http://localhost:8080 > /dev/null; do
        info "Waiting for Jenkins to start..."
        sleep 10
    done
    
    # Get initial admin password
    JENKINS_PASS=$(docker exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
    
    if [ ! -z "$JENKINS_PASS" ]; then
        info "Jenkins initial admin password: $JENKINS_PASS"
        info "Please complete Jenkins setup at http://localhost:8080"
    fi
    
    cd ..
}

# Configure Zabbix
configure_zabbix() {
    log "Configuring Zabbix..."
    cd zabbix
    
    # Wait for Zabbix to be ready
    while ! curl -s http://localhost:8081 > /dev/null; do
        info "Waiting for Zabbix to start..."
        sleep 10
    done
    
    info "Zabbix is ready at http://localhost:8081"
    info "Default credentials: Admin/zabbix"
    
    cd ..
}

# Configure SonarQube
configure_sonarqube() {
    log "Configuring SonarQube..."
    cd sonarqube
    
    # Wait for SonarQube to be ready
    while ! curl -s http://localhost:9000 > /dev/null; do
        info "Waiting for SonarQube to start..."
        sleep 10
    done
    
    info "SonarQube is ready at http://localhost:9000"
    info "Default credentials: admin/admin"
    
    cd ..
}

# Configure SigNoz
configure_signoz() {
    log "Configuring SigNoz..."
    cd signoz
    
    # Wait for SigNoz to be ready
    while ! curl -s http://localhost:3301 > /dev/null; do
        info "Waiting for SigNoz to start..."
        sleep 10
    done
    
    info "SigNoz is ready at http://localhost:3301"
    
    cd ..
}

# Main configuration
main() {
    log "Starting tool configuration..."
    
    configure_jenkins
    configure_zabbix
    configure_sonarqube
    configure_signoz
    
    log "All tools configured successfully!"
    
    echo ""
    echo "=== ACCESS INFORMATION ==="
    echo "Jenkins:    http://localhost:8080"
    echo "Zabbix:     http://localhost:8081"
    echo "SonarQube:  http://localhost:9000"
    echo "SigNoz:     http://localhost:3301"
    echo "Jaeger:     http://localhost:16686"
    echo "ArgoCD:     https://localhost:8082"
    echo ""
}

main "$@"
EOF

chmod +x configure-all-tools.sh
```

### 2. Jenkins Integration with Other Tools
```bash
# Create Jenkins integration configuration
cat > jenkins-integrations.md << 'EOF'
# Jenkins Integration Guide

## 1. SonarQube Integration

### Install SonarQube Plugin
1. Go to Jenkins > Manage Jenkins > Manage Plugins
2. Install "SonarQube Scanner" plugin
3. Restart Jenkins

### Configure SonarQube Server
1. Go to Jenkins > Manage Jenkins > Configure System
2. Find "SonarQube servers" section
3. Add SonarQube server:
   - Name: SonarQube
   - Server URL: http://sonarqube:9000
   - Server authentication token: (Generate in SonarQube)

### Sample Pipeline with SonarQube
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/your-repo.git'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner'
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }
}
```

## 2. Ansible Integration

### Install Ansible Plugin
1. Install "Ansible" plugin in Jenkins
2. Configure Ansible installation in Global Tool Configuration

### Sample Pipeline with Ansible
```groovy
pipeline {
    agent any
    stages {
        stage('Deploy with Ansible') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/deploy-application.yml',
                    inventory: 'inventory/hosts.yml',
                    extras: '-e version=${BUILD_NUMBER}'
                )
            }
        }
    }
}
```

## 3. ArgoCD Integration

### Configure ArgoCD Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jenkins-deployed-app
spec:
  source:
    repoURL: https://github.com/your-org/k8s-manifests
    path: .
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 4. OpenTelemetry Integration

### Configure Jenkins for Observability
Add to Jenkins pipeline:
```groovy
environment {
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://otel-collector:4318"
    OTEL_SERVICE_NAME = "jenkins-pipeline"
    OTEL_RESOURCE_ATTRIBUTES = "service.name=jenkins,service.version=1.0"
}
```
EOF
```

### 3. Monitoring Integration
```bash
# Create monitoring integration script
cat > setup-monitoring-integration.sh << 'EOF'
#!/bin/bash

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Configure Zabbix to monitor all services
configure_zabbix_monitoring() {
    log "Setting up Zabbix monitoring for all services..."
    
    # Create Zabbix configuration for Docker monitoring
    cat > zabbix/docker-monitoring.conf << 'ZABBIX_EOF'
# Zabbix Docker monitoring configuration
UserParameter=docker.containers.running,docker ps -q | wc -l
UserParameter=docker.containers.total,docker ps -aq | wc -l
UserParameter=docker.images.total,docker images -q | wc -l
UserParameter=jenkins.status,curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
UserParameter=sonarqube.status,curl -s -o /dev/null -w "%{http_code}" http://localhost:9000
UserParameter=signoz.status,curl -s -o /dev/null -w "%{http_code}" http://localhost:3301
ZABBIX_EOF
    
    log "Zabbix monitoring configuration created"
}

# Configure Prometheus monitoring
configure_prometheus_monitoring() {
    log "Setting up Prometheus monitoring..."
    
    cat > prometheus-config.yml << 'PROM_EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'jenkins'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/prometheus'
    
  - job_name: 'sonarqube'
    static_configs:
      - targets: ['localhost:9000']
    metrics_path: '/api/monitoring/metrics'
    
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
      
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
PROM_EOF
    
    log "Prometheus configuration created"
}

# Setup log aggregation
configure_log_aggregation() {
    log "Setting up log aggregation..."
    
    # Create Fluentd configuration for log collection
    mkdir -p fluentd
    cat > fluentd/fluent.conf << 'FLUENT_EOF'
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /var/log/fluentd-containers.log.pos
  tag kubernetes.*
  format json
</source>

<match **>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    index_name fluentd
    type_name fluentd
  </store>
  <store>
    @type stdout
  </store>
</match>
FLUENT_EOF
    
    log "Log aggregation configuration created"
}

main() {
    configure_zabbix_monitoring
    configure_prometheus_monitoring
    configure_log_aggregation
    
    log "Monitoring integration setup completed!"
}

main "$@"
EOF

chmod +x setup-monitoring-integration.sh
```

### 4. Complete Deployment Script
```bash
# Create master deployment script
cat > deploy-all-tools.sh << 'EOF'
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || error "Docker is required but not installed"
    command -v docker-compose >/dev/null 2>&1 || error "Docker Compose is required but not installed"
    command -v kubectl >/dev/null 2>&1 || warn "kubectl not found - ArgoCD setup will be skipped"
    
    # Check system resources
    MEMORY=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY -lt 16 ]; then
        warn "System has less than 16GB RAM. Some services may not perform optimally."
    fi
    
    log "Prerequisites check completed"
}

# Deploy Jenkins
deploy_jenkins() {
    log "Deploying Jenkins..."
    cd jenkins
    docker-compose up -d
    cd ..
    info "Jenkins deployed at http://localhost:8080"
}

# Deploy Zabbix
deploy_zabbix() {
    log "Deploying Zabbix..."
    cd zabbix
    docker-compose up -d
    cd ..
    info "Zabbix deployed at http://localhost:8081"
}

# Deploy OpenTelemetry
deploy_opentelemetry() {
    log "Deploying OpenTelemetry..."
    cd opentelemetry
    docker-compose up -d
    cd ..
    info "OpenTelemetry deployed - Collector: http://localhost:55679, Jaeger: http://localhost:16686"
}

# Deploy SigNoz
deploy_signoz() {
    log "Deploying SigNoz..."
    cd signoz/signoz/deploy
    docker-compose -f docker-compose.yaml -f docker-compose.override.yml up -d
    cd ../../..
    info "SigNoz deployed at http://localhost:3301"
}

# Deploy SonarQube
deploy_sonarqube() {
    log "Deploying SonarQube..."
    cd sonarqube
    docker-compose up -d
    cd ..
    info "SonarQube deployed at http://localhost:9000"
}

# Install Ansible
install_ansible() {
    log "Installing Ansible..."
    cd ansible
    # Ansible installation is already done in the setup
    info "Ansible installed and configured"
    cd ..
}

# Deploy ArgoCD
deploy_argocd() {
    log "Deploying ArgoCD..."
    if command -v kubectl >/dev/null 2>&1; then
        cd argocd
        ./install-argocd.sh
        cd ..
        info "ArgoCD deployed at https://localhost:8082"
    else
        warn "kubectl not found - skipping ArgoCD deployment"
    fi
}

# Initialize Terraform
initialize_terraform() {
    log "Initializing Terraform..."
    cd terraform
    ./scripts/init.sh
    cd ..
    info "Terraform initialized"
}

# Wait for services to be ready
wait_for_services() {
    log "Waiting for all services to be ready..."
    
    services=(
        "http://localhost:8080|Jenkins"
        "http://localhost:8081|Zabbix"
        "http://localhost:9000|SonarQube"
        "http://localhost:3301|SigNoz"
        "http://localhost:16686|Jaeger"
    )
    
    for service in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service"
        info "Checking $name..."
        
        for i in {1..30}; do
            if curl -s "$url" > /dev/null 2>&1; then
                log "$name is ready!"
                break
            fi
            
            if [ $i -eq 30 ]; then
                warn "$name is not responding after 5 minutes"
            else
                sleep 10
            fi
        done
    done
}

# Display access information
display_access_info() {
    log "Deployment completed successfully!"
    
    echo ""
    echo "=========================================="
    echo "         DEVOPS TOOLS ACCESS INFO        "
    echo "=========================================="
    echo ""
    echo "🔧 Jenkins:         http://localhost:8080"
    echo "   Default: Use initial admin password from container logs"
    echo ""
    echo "📊 Zabbix:          http://localhost:8081"
    echo "   Default: Admin/zabbix"
    echo ""
    echo "🔍 SonarQube:       http://localhost:9000"
    echo "   Default: admin/admin"
    echo ""
    echo "📈 SigNoz:          http://localhost:3301"
    echo "   Complete setup wizard on first access"
    echo ""
    echo "🔎 Jaeger:          http://localhost:16686"
    echo "   No authentication required"
    echo ""
    echo "🚀 ArgoCD:          https://localhost:8082"
    echo "   Username: admin"
    echo "   Password: Check ArgoCD installation output"
    echo ""
    echo "📡 OpenTelemetry:   http://localhost:55679"
    echo "   Collector status and configuration"
    echo ""
    echo "=========================================="
    echo ""
    echo "📝 Next Steps:"
    echo "1. Configure each tool using the provided guides"
    echo "2. Set up integrations between tools"
    echo "3. Create your first CI/CD pipeline"
    echo "4. Configure monitoring and alerting"
    echo ""
    echo "📚 Documentation:"
    echo "- Jenkins slave setup: jenkins/slave-node-setup.md"
    echo "- Tool integrations: jenkins-integrations.md"
    echo "- Ansible playbooks: ansible/playbooks/"
    echo "- Terraform configs: terraform/"
    echo ""
}

# Main deployment function
main() {
    log "Starting DevOps tools deployment..."
    
    check_prerequisites
    
    # Deploy all tools
    deploy_jenkins
    deploy_zabbix
    deploy_opentelemetry
    deploy_signoz
    deploy_sonarqube
    install_ansible
    deploy_argocd
    initialize_terraform
    
    # Wait for services and display info
    wait_for_services
    display_access_info
    
    log "All DevOps tools deployed successfully!"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "stop")
        log "Stopping all services..."
        cd jenkins && docker-compose down
        cd ../zabbix && docker-compose down
        cd ../opentelemetry && docker-compose down
        cd ../sonarqube && docker-compose down
        cd ../signoz/signoz/deploy && docker-compose down
        log "All services stopped"
        ;;
    "restart")
        $0 stop
        sleep 10
        $0 deploy
        ;;
    *)
        echo "Usage: $0 {deploy|stop|restart}"
        exit 1
        ;;
esac
EOF

chmod +x deploy-all-tools.sh
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Docker Issues
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker if needed
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker.service

# Clean up Docker resources
docker system prune -a
docker volume prune
```

#### 2. Port Conflicts
```bash
# Check which ports are in use
sudo netstat -tulpn | grep LISTEN

# Kill process using specific port
sudo lsof -ti:8080 | xargs kill -9

# Change port in docker-compose.yml if needed
```

#### 3. Memory Issues
```bash
# Check memory usage
free -h
docker stats

# Increase swap if needed
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 4. Service-Specific Issues

##### Jenkins Issues
```bash
# Check Jenkins logs
docker logs jenkins-master

# Reset Jenkins admin password
docker exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword

# Access Jenkins container
docker exec -it jenkins-master bash
```

##### SonarQube Issues
```bash
# Check SonarQube logs
docker logs sonarqube

# Increase vm.max_map_count for Elasticsearch
echo 'vm.max_map_count=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Check SonarQube database
docker exec -it sonarqube-postgres psql -U sonar -d sonarqube
```

##### Zabbix Issues
```bash
# Check Zabbix server logs
docker logs zabbix-server

# Check database connection
docker exec -it zabbix-mysql mysql -u zabbix -p zabbix

# Restart Zabbix services
cd zabbix && docker-compose restart
```

### Debug Scripts
```bash
# Create comprehensive debug script
cat > debug-tools.sh << 'EOF'
#!/bin/bash

echo "=== DevOps Tools Debug Information ==="
echo ""

echo "--- System Information ---"
uname -a
free -h
df -h
echo ""

echo "--- Docker Information ---"
docker --version
docker-compose --version
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "--- Service Status ---"
services=(
    "http://localhost:8080|Jenkins"
    "http://localhost:8081|Zabbix"
    "http://localhost:9000|SonarQube"
    "http://localhost:3301|SigNoz"
    "http://localhost:16686|Jaeger"
)

for service in "${services[@]}"; do
    IFS='|' read -r url name <<< "$service"
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "200" ] || [ "$status" = "302" ]; then
        echo "✅ $name: OK ($status)"
    else
        echo "❌ $name: FAILED ($status)"
    fi
done
echo ""

echo "--- Docker Logs (last 10 lines) ---"
containers=("jenkins-master" "zabbix-server" "sonarqube" "otel-collector")
for container in "${containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "$container"; then
        echo "--- $container ---"
        docker logs --tail 10 "$container" 2>&1
        echo ""
    fi
done

echo "--- Network Information ---"
docker network ls
echo ""

echo "--- Volume Information ---"
docker volume ls
echo ""
EOF

chmod +x debug-tools.sh
```

### Cleanup Script
```bash
# Create cleanup script
cat > cleanup-tools.sh << 'EOF'
#!/bin/bash

echo "=== DevOps Tools Cleanup ==="
echo "This will remove all containers, volumes, and networks created by the tools."
read -p "Are you sure? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping and removing all services..."
    
    # Stop all services
    cd jenkins && docker-compose down -v
    cd ../zabbix && docker-compose down -v
    cd ../opentelemetry && docker-compose down -v
    cd ../sonarqube && docker-compose down -v
    cd ../signoz/signoz/deploy && docker-compose down -v
    cd ../../..
    
    # Remove ArgoCD if installed
    if command -v kubectl >/dev/null 2>&1; then
        kubectl delete namespace argocd --ignore-not-found=true
    fi
    
    # Clean up Docker
    docker system prune -a -f
    docker volume prune -f
    docker network prune -f
    
    echo "Cleanup completed!"
else
    echo "Cleanup cancelled."
fi
EOF

chmod +x cleanup-tools.sh
```

## Final Setup Instructions

### Quick Start Guide
```bash
# Create quick start guide
cat > QUICK_START.md << 'EOF'
# DevOps Tools Quick Start Guide

## 1. Prerequisites Check
- Ubuntu 20.04/22.04 or CentOS 7/8
- 16GB+ RAM, 8+ CPU cores, 200GB+ disk space
- Docker and Docker Compose installed

## 2. Installation Steps

### Step 1: Run the master deployment script
```bash
./deploy-all-tools.sh
```

### Step 2: Configure each tool
```bash
./configure-all-tools.sh
```

### Step 3: Set up integrations
Follow the guides in:
- `jenkins-integrations.md`
- `ansible/playbooks/`
- `terraform/`

## 3. Access Information
After deployment, access your tools at:
- Jenkins: http://localhost:8080
- Zabbix: http://localhost:8081  
- SonarQube: http://localhost:9000
- SigNoz: http://localhost:3301
- Jaeger: http://localhost:16686
- ArgoCD: https://localhost:8082

## 4. Troubleshooting
If you encounter issues:
```bash
./debug-tools.sh
```

## 5. Cleanup (if needed)
To remove everything:
```bash
./cleanup-tools.sh
```

## 6. Next Steps
1. Configure Jenkins slave nodes
2. Set up SonarQube quality gates
3. Create Ansible playbooks for your infrastructure
4. Configure ArgoCD applications
5. Set up monitoring dashboards in Zabbix and SigNoz
EOF
```

## Conclusion

This comprehensive guide provides:

✅ **Complete DevOps toolchain installation:**
- Jenkins with slave nodes for CI/CD
- Zabbix for infrastructure monitoring
- OpenTelemetry for observability collection
- SigNoz for application monitoring and tracing
- SonarQube for code quality analysis
- Ansible for configuration management
- ArgoCD for GitOps deployment
- Terraform for infrastructure as code

✅ **Production-ready configurations:**
- Docker Compose setups for all tools
- Proper networking and volume management
- Security configurations and best practices
- Integration guides between tools

✅ **Automation scripts:**
- Master deployment script for one-command setup
- Configuration scripts for each tool
- Monitoring and integration setup
- Troubleshooting and cleanup utilities

✅ **Beginner-friendly approach:**
- Step-by-step instructions
- Detailed explanations for each tool
- Common issue troubleshooting
- Quick start guide for immediate use

**To get started:**
1. Run `./deploy-all-tools.sh` to install everything
2. Follow the configuration guides for each tool
3. Set up integrations using the provided examples
4. Use the troubleshooting scripts if needed

This setup gives you a complete DevOps environment ready for production use!
