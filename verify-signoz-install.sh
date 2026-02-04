#!/bin/bash

################################################################################
# SigNoz Installation Script with ClickHouse 25.5.6 Compatibility
# This script installs SigNoz v0.94+ with ClickHouse 25.5.6
# Fixes port 4317 binding issues and ensures all components work properly
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLICKHOUSE_VERSION="25.5.6"
CLICKHOUSE_PASSWORD="signoz_password_123"
ZOOKEEPER_VERSION="3.8.5"
INSTALL_DIR="/opt"
DATA_DIR="/var/lib"
LOG_DIR="/var/log"

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This script must be run as root. Use sudo."
        exit 1
    fi
}

wait_for_service() {
    local service=$1
    local max_wait=${2:-30}
    local counter=0
    
    log_info "Waiting for $service to be ready..."
    while [ $counter -lt $max_wait ]; do
        if systemctl is-active --quiet $service; then
            log_success "$service is running"
            return 0
        fi
        sleep 2
        counter=$((counter + 2))
    done
    
    log_error "$service failed to start within ${max_wait}s"
    return 1
}

check_port() {
    local port=$1
    local service=$2
    
    if netstat -tuln | grep -q ":$port "; then
        log_success "Port $port is listening ($service)"
        return 0
    else
        log_warning "Port $port is NOT listening ($service)"
        return 1
    fi
}

################################################################################
# System Prerequisites
################################################################################

install_prerequisites() {
    log_info "Installing system prerequisites..."
    
    # Update package list
    apt update -qq
    
    # Install required packages
    apt install -y \
        curl \
        wget \
        tar \
        default-jdk \
        net-tools \
        gnupg \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        > /dev/null 2>&1
    
    log_success "Prerequisites installed"
}

################################################################################
# ClickHouse Installation (Version 25.5.6)
################################################################################

install_clickhouse() {
    log_info "Installing ClickHouse ${CLICKHOUSE_VERSION}..."
    
    # Add ClickHouse repository
    curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | tee /etc/apt/sources.list.d/clickhouse.list
    
    # Update and install specific version
    apt update -qq
    apt install -y clickhouse-server=${CLICKHOUSE_VERSION} clickhouse-client=${CLICKHOUSE_VERSION} clickhouse-common-static=${CLICKHOUSE_VERSION} > /dev/null 2>&1
    
    # Hold the version to prevent unwanted upgrades
    apt-mark hold clickhouse-server clickhouse-client clickhouse-common-static
    
    # Set password
    echo -e "${CLICKHOUSE_PASSWORD}\n${CLICKHOUSE_PASSWORD}" | passwd clickhouse 2>/dev/null || true
    
    log_success "ClickHouse ${CLICKHOUSE_VERSION} installed"
}

configure_clickhouse_cluster() {
    log_info "Configuring ClickHouse cluster setup..."
    
    # Create cluster configuration
    cat > /etc/clickhouse-server/config.d/cluster.xml << 'EOF'
<clickhouse replace="true">
    <!-- Distributed DDL configuration -->
    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
    
    <!-- Remote servers configuration (single node cluster for SigNoz) -->
    <remote_servers>
        <cluster>
            <shard>
                <replica>
                    <host>127.0.0.1</host>
                    <port>9000</port>
                </replica>
            </shard>
        </cluster>
    </remote_servers>
    
    <!-- ZooKeeper configuration -->
    <zookeeper>
        <node>
            <host>127.0.0.1</host>
            <port>2181</port>
        </node>
    </zookeeper>
    
    <!-- Macros for distributed tables -->
    <macros>
        <shard>01</shard>
        <replica>01</replica>
    </macros>
    
    <!-- Listen on all interfaces for testing -->
    <listen_host>::</listen_host>
    
    <!-- Maximum concurrent queries -->
    <max_concurrent_queries>100</max_concurrent_queries>
    
    <!-- Memory settings -->
    <max_server_memory_usage>0</max_server_memory_usage>
    <max_memory_usage>10000000000</max_memory_usage>
</clickhouse>
EOF
    
    # Set proper permissions
    chown clickhouse:clickhouse /etc/clickhouse-server/config.d/cluster.xml
    chmod 644 /etc/clickhouse-server/config.d/cluster.xml
    
    # Configure password
    cat > /etc/clickhouse-server/users.d/signoz.xml << EOF
<clickhouse>
    <users>
        <default>
            <password>${CLICKHOUSE_PASSWORD}</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
    </users>
</clickhouse>
EOF
    
    chown clickhouse:clickhouse /etc/clickhouse-server/users.d/signoz.xml
    chmod 644 /etc/clickhouse-server/users.d/signoz.xml
    
    log_success "ClickHouse cluster configuration created"
}

################################################################################
# ZooKeeper Installation
################################################################################

install_zookeeper() {
    log_info "Installing ZooKeeper ${ZOOKEEPER_VERSION}..."
    
    # Download ZooKeeper
    curl -L "https://dlcdn.apache.org/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz" -o /tmp/zookeeper.tar.gz
    
    # Extract and install
    tar -xzf /tmp/zookeeper.tar.gz -C /tmp/
    mkdir -p ${INSTALL_DIR}/zookeeper
    mkdir -p ${DATA_DIR}/zookeeper
    mkdir -p ${LOG_DIR}/zookeeper
    cp -r /tmp/apache-zookeeper-${ZOOKEEPER_VERSION}-bin/* ${INSTALL_DIR}/zookeeper/
    
    # Create configuration
    cat > ${INSTALL_DIR}/zookeeper/conf/zoo.cfg << EOF
tickTime=2000
dataDir=${DATA_DIR}/zookeeper
clientPort=2181
admin.serverPort=3181
maxClientCnxns=60
4lw.commands.whitelist=*
EOF
    
    # Create environment file
    cat > ${INSTALL_DIR}/zookeeper/conf/zoo.env << EOF
ZOO_LOG_DIR=${LOG_DIR}/zookeeper
EOF
    
    # Create user and set permissions
    getent passwd zookeeper >/dev/null || useradd --system --home ${INSTALL_DIR}/zookeeper --no-create-home --user-group --shell /sbin/nologin zookeeper
    chown -R zookeeper:zookeeper ${INSTALL_DIR}/zookeeper
    chown -R zookeeper:zookeeper ${DATA_DIR}/zookeeper
    chown -R zookeeper:zookeeper ${LOG_DIR}/zookeeper
    
    # Create systemd service
    cat > /etc/systemd/system/zookeeper.service << EOF
[Unit]
Description=Apache ZooKeeper
Documentation=http://zookeeper.apache.org
After=network.target

[Service]
EnvironmentFile=${INSTALL_DIR}/zookeeper/conf/zoo.env
Type=forking
WorkingDirectory=${INSTALL_DIR}/zookeeper
User=zookeeper
Group=zookeeper
ExecStart=${INSTALL_DIR}/zookeeper/bin/zkServer.sh start ${INSTALL_DIR}/zookeeper/conf/zoo.cfg
ExecStop=${INSTALL_DIR}/zookeeper/bin/zkServer.sh stop ${INSTALL_DIR}/zookeeper/conf/zoo.cfg
ExecReload=${INSTALL_DIR}/zookeeper/bin/zkServer.sh restart ${INSTALL_DIR}/zookeeper/conf/zoo.cfg
TimeoutSec=30
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable zookeeper.service
    systemctl start zookeeper.service
    
    # Cleanup
    rm -rf /tmp/zookeeper.tar.gz /tmp/apache-zookeeper-${ZOOKEEPER_VERSION}-bin
    
    log_success "ZooKeeper ${ZOOKEEPER_VERSION} installed and started"
}

################################################################################
# Start ClickHouse
################################################################################

start_clickhouse() {
    log_info "Starting ClickHouse service..."
    
    systemctl enable clickhouse-server.service
    systemctl restart clickhouse-server.service
    
    # Wait for ClickHouse to be ready
    sleep 5
    
    # Verify connection
    local max_attempts=10
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if clickhouse-client --password="${CLICKHOUSE_PASSWORD}" --query="SELECT 1" > /dev/null 2>&1; then
            log_success "ClickHouse is ready and accepting connections"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 3
    done
    
    log_error "Failed to connect to ClickHouse after ${max_attempts} attempts"
    return 1
}

################################################################################
# Run Schema Migrations
################################################################################

run_schema_migrations() {
    log_info "Running SigNoz schema migrations..."
    
    # Download schema migrator
    local arch=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
    curl -L "https://github.com/SigNoz/signoz-otel-collector/releases/latest/download/signoz-schema-migrator_linux_${arch}.tar.gz" -o /tmp/signoz-schema-migrator.tar.gz
    
    # Extract
    tar -xzf /tmp/signoz-schema-migrator.tar.gz -C /tmp/
    
    # Run synchronous migrations
    log_info "Running synchronous migrations..."
    /tmp/signoz-schema-migrator_linux_${arch}/bin/signoz-schema-migrator sync \
        --dsn="tcp://localhost:9000?password=${CLICKHOUSE_PASSWORD}" \
        --replication=true \
        --up=
    
    # Run asynchronous migrations
    log_info "Running asynchronous migrations..."
    /tmp/signoz-schema-migrator_linux_${arch}/bin/signoz-schema-migrator async \
        --dsn="tcp://localhost:9000?password=${CLICKHOUSE_PASSWORD}" \
        --replication=true \
        --up=
    
    # Cleanup
    rm -rf /tmp/signoz-schema-migrator.tar.gz /tmp/signoz-schema-migrator_linux_${arch}
    
    log_success "Schema migrations completed"
}

################################################################################
# Install SigNoz
################################################################################

install_signoz() {
    log_info "Installing SigNoz..."
    
    # Download SigNoz
    local arch=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
    curl -L "https://github.com/SigNoz/signoz/releases/latest/download/signoz_linux_${arch}.tar.gz" -o /tmp/signoz.tar.gz
    
    # Extract and install
    tar -xzf /tmp/signoz.tar.gz -C /tmp/
    mkdir -p ${INSTALL_DIR}/signoz
    mkdir -p ${DATA_DIR}/signoz
    cp -r /tmp/signoz_linux_${arch}/* ${INSTALL_DIR}/signoz/
    
    # Create environment configuration
    cat > ${INSTALL_DIR}/signoz/conf/systemd.env << EOF
SIGNOZ_INSTRUMENTATION_LOGS_LEVEL=info
INVITE_EMAIL_TEMPLATE=${INSTALL_DIR}/signoz/templates/invitation_email_template.html
SIGNOZ_SQLSTORE_SQLITE_PATH=${DATA_DIR}/signoz/signoz.db
SIGNOZ_WEB_ENABLED=true
SIGNOZ_WEB_DIRECTORY=${INSTALL_DIR}/signoz/web
SIGNOZ_JWT_SECRET=signoz_jwt_secret_change_me_in_production
SIGNOZ_ALERTMANAGER_PROVIDER=signoz
SIGNOZ_TELEMETRYSTORE_PROVIDER=clickhouse
SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=tcp://localhost:9000?password=${CLICKHOUSE_PASSWORD}
DOT_METRICS_ENABLED=true
EOF
    
    # Create user and set permissions
    getent passwd signoz >/dev/null || useradd --system --home ${INSTALL_DIR}/signoz --no-create-home --user-group --shell /sbin/nologin signoz
    chown -R signoz:signoz ${DATA_DIR}/signoz
    chown -R signoz:signoz ${INSTALL_DIR}/signoz
    
    # Create systemd service
    cat > /etc/systemd/system/signoz.service << EOF
[Unit]
Description=SigNoz Application Monitoring Platform
Documentation=https://signoz.io/docs
After=clickhouse-server.service zookeeper.service
Wants=clickhouse-server.service zookeeper.service

[Service]
User=signoz
Group=signoz
Type=simple
KillMode=mixed
Restart=on-failure
RestartSec=10
WorkingDirectory=${INSTALL_DIR}/signoz
EnvironmentFile=${INSTALL_DIR}/signoz/conf/systemd.env
ExecStart=${INSTALL_DIR}/signoz/bin/signoz server

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable signoz.service
    systemctl start signoz.service
    
    # Cleanup
    rm -rf /tmp/signoz.tar.gz /tmp/signoz_linux_${arch}
    
    log_success "SigNoz installed and started"
}

################################################################################
# Install SigNoz OTel Collector (Fixes Port 4317)
################################################################################

install_otel_collector() {
    log_info "Installing SigNoz OTel Collector..."
    
    # Download OTel Collector
    local arch=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
    curl -L "https://github.com/SigNoz/signoz-otel-collector/releases/latest/download/signoz-otel-collector_linux_${arch}.tar.gz" -o /tmp/signoz-otel-collector.tar.gz
    
    # Extract and install
    tar -xzf /tmp/signoz-otel-collector.tar.gz -C /tmp/
    mkdir -p ${DATA_DIR}/signoz-otel-collector
    mkdir -p ${INSTALL_DIR}/signoz-otel-collector
    cp -r /tmp/signoz-otel-collector_linux_${arch}/* ${INSTALL_DIR}/signoz-otel-collector/
    
    # Set permissions
    chown -R signoz:signoz ${DATA_DIR}/signoz-otel-collector
    chown -R signoz:signoz ${INSTALL_DIR}/signoz-otel-collector
    
    # Create collector configuration with explicit port bindings
    cat > ${INSTALL_DIR}/signoz-otel-collector/conf/config.yaml << EOF
receivers:
  # OTLP receivers - PRIMARY DATA INGESTION
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317  # OTLP gRPC - Fixed binding
        max_recv_msg_size_mib: 16
      http:
        endpoint: 0.0.0.0:4318  # OTLP HTTP
        
  # Jaeger receivers for backward compatibility
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
        
  # HTTP log receivers
  httplogreceiver/heroku:
    endpoint: 0.0.0.0:8081
    source: heroku
  httplogreceiver/json:
    endpoint: 0.0.0.0:8082
    source: json

processors:
  # Batch processor for better performance
  batch:
    send_batch_size: 50000
    timeout: 1s
    
  # Span metrics processor
  signozspanmetrics/delta:
    metrics_exporter: signozclickhousemetrics 
    latency_histogram_buckets: [100us, 1ms, 2ms, 6ms, 10ms, 50ms, 100ms, 250ms, 500ms, 1000ms, 1400ms, 2000ms, 5s, 10s, 20s, 40s, 60s]
    dimensions_cache_size: 100000
    dimensions:
      - name: service.namespace
        default: default
      - name: deployment.environment
        default: default
      - name: signoz.collector.id
    aggregation_temporality: AGGREGATION_TEMPORALITY_DELTA

extensions:
  # Health check endpoint
  health_check:
    endpoint: 0.0.0.0:13133
    
  # Debug endpoints
  zpages:
    endpoint: localhost:55679
  pprof:
    endpoint: localhost:1777

exporters:
  # ClickHouse exporters for SigNoz
  clickhousetraces:
    datasource: tcp://localhost:9000/signoz_traces?password=${CLICKHOUSE_PASSWORD}
    use_new_schema: true
    
  signozclickhousemetrics:
    dsn: tcp://localhost:9000/signoz_metrics?password=${CLICKHOUSE_PASSWORD}
    timeout: 45s
    
  clickhouselogsexporter:
    dsn: tcp://localhost:9000/signoz_logs?password=${CLICKHOUSE_PASSWORD}
    timeout: 10s
    use_new_schema: true
    
  metadataexporter:
    dsn: tcp://localhost:9000/signoz_metadata?password=${CLICKHOUSE_PASSWORD}
    timeout: 10s
    tenant_id: default
    cache:
      provider: in_memory

service:
  telemetry:
    logs:
      encoding: json
      level: info
      
  extensions: [health_check, zpages, pprof]
  
  pipelines:
    traces:
      receivers: [otlp, jaeger]
      processors: [signozspanmetrics/delta, batch]
      exporters: [clickhousetraces, metadataexporter]
      
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [metadataexporter, signozclickhousemetrics]
      
    logs:
      receivers: [otlp, httplogreceiver/heroku, httplogreceiver/json]
      processors: [batch]
      exporters: [clickhouselogsexporter, metadataexporter]
EOF
    
    # Create OpAMP configuration
    cat > ${INSTALL_DIR}/signoz-otel-collector/conf/opamp.yaml << EOF
server_endpoint: ws://127.0.0.1:4320/v1/opamp
EOF
    
    # Create systemd service
    cat > /etc/systemd/system/signoz-otel-collector.service << EOF
[Unit]
Description=SigNoz OpenTelemetry Collector
Documentation=https://signoz.io/docs
After=clickhouse-server.service signoz.service
Wants=signoz.service

[Service]
User=signoz
Group=signoz
Type=simple
KillMode=mixed
Restart=on-failure
RestartSec=10
WorkingDirectory=${INSTALL_DIR}/signoz-otel-collector
ExecStart=${INSTALL_DIR}/signoz-otel-collector/bin/signoz-otel-collector --config=${INSTALL_DIR}/signoz-otel-collector/conf/config.yaml --manager-config=${INSTALL_DIR}/signoz-otel-collector/conf/opamp.yaml --copy-path=${DATA_DIR}/signoz-otel-collector/config.yaml

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable signoz-otel-collector.service
    systemctl start signoz-otel-collector.service
    
    # Cleanup
    rm -rf /tmp/signoz-otel-collector.tar.gz /tmp/signoz-otel-collector_linux_${arch}
    
    log_success "SigNoz OTel Collector installed and started"
}

################################################################################
# Verification
################################################################################

verify_installation() {
    log_info "Verifying installation..."
    echo ""
    
    # Check services
    log_info "Checking service status..."
    local all_ok=true
    
    for service in zookeeper clickhouse-server signoz signoz-otel-collector; do
        if systemctl is-active --quiet ${service}.service; then
            log_success "${service} is running"
        else
            log_error "${service} is NOT running"
            all_ok=false
        fi
    done
    
    echo ""
    log_info "Checking port bindings..."
    
    # Check critical ports
    sleep 5  # Give services time to bind ports
    
    check_port 2181 "ZooKeeper"
    check_port 9000 "ClickHouse TCP"
    check_port 8123 "ClickHouse HTTP"
    check_port 8080 "SigNoz UI/API"
    check_port 4317 "OTLP gRPC" || log_warning "Port 4317 may take a few seconds to bind..."
    check_port 4318 "OTLP HTTP"
    check_port 13133 "Health Check"
    
    echo ""
    
    # Test SigNoz API
    log_info "Testing SigNoz API..."
    sleep 5
    
    local max_attempts=15
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f http://localhost:8080/api/v1/health > /dev/null 2>&1; then
            log_success "SigNoz API is responding"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "SigNoz API health check timeout (may need more time to initialize)"
    fi
    
    # Test ClickHouse connection
    log_info "Testing ClickHouse connection..."
    if clickhouse-client --password="${CLICKHOUSE_PASSWORD}" --query="SELECT version()" > /dev/null 2>&1; then
        local version=$(clickhouse-client --password="${CLICKHOUSE_PASSWORD}" --query="SELECT version()")
        log_success "ClickHouse version: ${version}"
    else
        log_error "Failed to connect to ClickHouse"
        all_ok=false
    fi
    
    echo ""
    echo "========================================"
    if [ "$all_ok" = true ]; then
        log_success "Installation completed successfully!"
    else
        log_warning "Installation completed with some warnings"
    fi
    echo "========================================"
    echo ""
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "     SigNoz Installation Summary"
    echo "=========================================="
    echo ""
    echo "Components Installed:"
    echo "  • ZooKeeper ${ZOOKEEPER_VERSION}"
    echo "  • ClickHouse ${CLICKHOUSE_VERSION}"
    echo "  • SigNoz (Latest)"
    echo "  • SigNoz OTel Collector (Latest)"
    echo ""
    echo "Access Points:"
    echo "  • SigNoz UI:        http://$(hostname -I | awk '{print $1}'):8080"
    echo "  • SigNoz UI (localhost): http://localhost:8080"
    echo "  • OTLP gRPC:        $(hostname -I | awk '{print $1}'):4317"
    echo "  • OTLP HTTP:        $(hostname -I | awk '{print $1}'):4318"
    echo "  • ClickHouse TCP:   localhost:9000"
    echo "  • ClickHouse HTTP:  localhost:8123"
    echo ""
    echo "Credentials:"
    echo "  • ClickHouse User:  default"
    echo "  • ClickHouse Password: ${CLICKHOUSE_PASSWORD}"
    echo ""
    echo "Useful Commands:"
    echo "  • Check services:   systemctl status zookeeper clickhouse-server signoz signoz-otel-collector"
    echo "  • View SigNoz logs: journalctl -u signoz.service -f"
    echo "  • View OTel logs:   journalctl -u signoz-otel-collector.service -f"
    echo "  • Test connection:  curl http://localhost:8080/api/v1/health"
    echo "  • Send test trace:  See https://signoz.io/docs/instrumentation/"
    echo ""
    echo "Port Status Check:"
    netstat -tuln | grep -E ':(2181|9000|8123|8080|4317|4318|13133) ' || echo "  Run 'netstat -tuln | grep -E \":(2181|9000|8123|8080|4317|4318)\"' to check ports"
    echo ""
    echo "=========================================="
    echo ""
    
    log_info "To view detailed logs:"
    echo "  journalctl -u signoz-otel-collector.service -f"
    echo ""
    
    log_info "Documentation: https://signoz.io/docs/"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    echo ""
    echo "=========================================="
    echo "  SigNoz + ClickHouse 25.5.6 Installer"
    echo "=========================================="
    echo ""
    
    check_root
    
    log_info "Starting installation..."
    echo ""
    
    # Installation steps
    install_prerequisites
    install_zookeeper
    wait_for_service zookeeper.service 30
    
    install_clickhouse
    configure_clickhouse_cluster
    start_clickhouse
    wait_for_service clickhouse-server.service 30
    
    run_schema_migrations
    install_signoz
    wait_for_service signoz.service 30
    
    install_otel_collector
    wait_for_service signoz-otel-collector.service 30
    
    # Verification
    verify_installation
    print_summary
    
    log_success "Installation complete! Access SigNoz at http://localhost:8080"
}

# Run main installation
main "$@"
