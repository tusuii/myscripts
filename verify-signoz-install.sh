#!/bin/bash

################################################################################
# SigNoz Installation Verification Script
# Run this after installation to check all components
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  SigNoz Installation Verification"
echo "=========================================="
echo ""

# Function to check service status
check_service() {
    local service=$1
    if systemctl is-active --quiet ${service}.service; then
        echo -e "${GREEN}✓${NC} ${service} is running"
        return 0
    else
        echo -e "${RED}✗${NC} ${service} is NOT running"
        echo "  Fix: sudo systemctl start ${service}.service"
        return 1
    fi
}

# Function to check port
check_port() {
    local port=$1
    local name=$2
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        echo -e "${GREEN}✓${NC} Port ${port} (${name}) is listening"
        return 0
    else
        echo -e "${RED}✗${NC} Port ${port} (${name}) is NOT listening"
        return 1
    fi
}

# Check services
echo "=== Service Status ==="
all_services_ok=true
for service in zookeeper clickhouse-server signoz signoz-otel-collector; do
    check_service $service || all_services_ok=false
done

echo ""
echo "=== Port Bindings ==="
all_ports_ok=true
check_port 2181 "ZooKeeper" || all_ports_ok=false
check_port 9000 "ClickHouse TCP" || all_ports_ok=false
check_port 8123 "ClickHouse HTTP" || all_ports_ok=false
check_port 8080 "SigNoz UI/API" || all_ports_ok=false
check_port 4317 "OTLP gRPC" || all_ports_ok=false
check_port 4318 "OTLP HTTP" || all_ports_ok=false
check_port 13133 "Health Check" || all_ports_ok=false

echo ""
echo "=== API Health Check ==="
if curl -s -f http://localhost:8080/api/v1/health > /dev/null 2>&1; then
    response=$(curl -s http://localhost:8080/api/v1/health)
    echo -e "${GREEN}✓${NC} SigNoz API is responding: ${response}"
else
    echo -e "${RED}✗${NC} SigNoz API is not responding"
    echo "  Fix: sudo journalctl -u signoz.service -f"
fi

echo ""
echo "=== ClickHouse Connection ==="
if clickhouse-client --password="signoz_password_123" --query="SELECT 1" > /dev/null 2>&1; then
    version=$(clickhouse-client --password="signoz_password_123" --query="SELECT version()")
    echo -e "${GREEN}✓${NC} ClickHouse is accessible (version: ${version})"
    
    # Check if it's the correct version
    if echo "$version" | grep -q "25.5.6"; then
        echo -e "${GREEN}✓${NC} ClickHouse version is correct (25.5.6)"
    else
        echo -e "${YELLOW}⚠${NC} ClickHouse version is ${version} (expected 25.5.6)"
    fi
else
    echo -e "${RED}✗${NC} Cannot connect to ClickHouse"
    echo "  Fix: sudo systemctl restart clickhouse-server.service"
fi

echo ""
echo "=== Database Tables ==="
if clickhouse-client --password="signoz_password_123" --query="SHOW DATABASES" 2>/dev/null | grep -q "signoz"; then
    databases=$(clickhouse-client --password="signoz_password_123" --query="SHOW DATABASES" | grep signoz)
    echo -e "${GREEN}✓${NC} SigNoz databases found:"
    echo "$databases" | sed 's/^/  - /'
else
    echo -e "${RED}✗${NC} SigNoz databases not found"
    echo "  Fix: Re-run schema migrations"
fi

echo ""
echo "=== Resource Usage ==="
echo "Memory:"
free -h | grep -E "^Mem" | awk '{print "  Total: " $2 ", Used: " $3 ", Free: " $4}'

echo "Disk:"
df -h / | tail -1 | awk '{print "  Total: " $2 ", Used: " $3 ", Available: " $4 " (" $5 " used)"}'

echo ""
echo "=== Recent Logs (Last 10 lines) ==="
echo "SigNoz OTel Collector:"
journalctl -u signoz-otel-collector.service -n 5 --no-pager 2>/dev/null | tail -5 | sed 's/^/  /'

echo ""
echo "=========================================="
if [ "$all_services_ok" = true ] && [ "$all_ports_ok" = true ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Access SigNoz at: http://$(hostname -I | awk '{print $1}'):8080"
    echo "OTLP gRPC endpoint: $(hostname -I | awk '{print $1}'):4317"
    echo "OTLP HTTP endpoint: $(hostname -I | awk '{print $1}'):4318"
else
    echo -e "${YELLOW}Some checks failed. Review above output.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Restart services: sudo systemctl restart signoz-otel-collector"
    echo "  2. Check logs: sudo journalctl -u signoz-otel-collector.service -f"
    echo "  3. Verify firewall: sudo ufw status"
fi
echo "=========================================="
echo ""

# Test OTLP endpoint with a simple connection test
echo "=== OTLP Endpoint Test ==="
if timeout 2 bash -c "echo > /dev/tcp/localhost/4317" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Port 4317 accepts connections"
else
    echo -e "${RED}✗${NC} Port 4317 does not accept connections"
    echo "  Fix: sudo systemctl restart signoz-otel-collector.service"
fi

if timeout 2 bash -c "echo > /dev/tcp/localhost/4318" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Port 4318 accepts connections"
else
    echo -e "${RED}✗${NC} Port 4318 does not accept connections"
    echo "  Fix: sudo systemctl restart signoz-otel-collector.service"
fi

echo ""
