# Server Setup Guide - Jumpbox to Main Server with Application Installation

## Architecture Overview
```
Your Computer → Jumpbox/Bastion → Main Server (SonarQube)
     |              |                    |
  Browser      SSH Tunnel           Port 9000
```

## Step 1: SSH Connection Setup

### Connect to Jumpbox First
```bash
# Connect to jumpbox
ssh -i /path/to/jumpbox-key.pem user@jumpbox-ip

# From jumpbox, connect to main server
ssh -i /path/to/main-server-key.pem user@main-server-ip
```

### SSH Config for Easy Access
Create `~/.ssh/config` on your local machine:
```
Host jumpbox
    HostName jumpbox-ip-address
    User ubuntu
    IdentityFile ~/.ssh/jumpbox-key.pem
    ForwardAgent yes

Host mainserver
    HostName main-server-private-ip
    User ubuntu
    IdentityFile ~/.ssh/main-server-key.pem
    ProxyJump jumpbox
```

Now you can connect directly:
```bash
ssh mainserver
```

## Step 2: Install SonarQube on Main Server

### Prerequisites Installation
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 11 (required for SonarQube)
sudo apt install openjdk-11-jdk -y
java -version

# Install PostgreSQL (recommended database)
sudo apt install postgresql postgresql-contrib -y

# Install unzip and wget
sudo apt install unzip wget -y
```

### Database Setup
```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt, create database and user
CREATE DATABASE sonarqube;
CREATE USER sonarqube WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
\q
```

### SonarQube Installation
```bash
# Create sonarqube user
sudo adduser --system --no-create-home --group --disabled-login sonarqube

# Download SonarQube
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip
sudo unzip sonarqube-9.9.2.77730.zip
sudo mv sonarqube-9.9.2.77730 sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube
sudo nano /opt/sonarqube/conf/sonar.properties
```

Add these lines to `sonar.properties`:
```properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=your_password
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
```

### System Configuration
```bash
# Increase system limits
sudo nano /etc/sysctl.conf
```
Add:
```
vm.max_map_count=524288
fs.file-max=131072
```

```bash
# Apply changes
sudo sysctl -p

# Set ulimits
sudo nano /etc/security/limits.conf
```
Add:
```
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
```

### Create Systemd Service
```bash
sudo nano /etc/systemd/system/sonarqube.service
```

Content:
```ini
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
```

### Start SonarQube
```bash
# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

# Check status
sudo systemctl status sonarqube
```

## Step 3: Firewall Configuration

### On Main Server
```bash
# Allow SonarQube port
sudo ufw allow 9000/tcp
sudo ufw enable
sudo ufw status
```

### On Jumpbox (if needed)
```bash
# Allow SSH and port forwarding
sudo ufw allow ssh
sudo ufw allow 9000/tcp
sudo ufw enable
```

## Step 4: Access SonarQube from Your Browser

### Method 1: SSH Tunnel (Recommended)
From your local machine:
```bash
# Create SSH tunnel through jumpbox
ssh -L 9000:main-server-private-ip:9000 -J jumpbox mainserver

# Or using config names
ssh -L 9000:localhost:9000 mainserver
```

Then access: `http://localhost:9000` in your browser

### Method 2: Port Forwarding Chain
```bash
# On jumpbox, forward port to main server
ssh -L 9000:main-server-private-ip:9000 user@main-server-private-ip

# On your local machine, forward to jumpbox
ssh -L 9000:localhost:9000 user@jumpbox-ip
```

### Method 3: Reverse Proxy (Advanced)
Install nginx on jumpbox:
```bash
# On jumpbox
sudo apt install nginx -y
sudo nano /etc/nginx/sites-available/sonarqube
```

Nginx config:
```nginx
server {
    listen 80;
    server_name jumpbox-public-ip;
    
    location / {
        proxy_pass http://main-server-private-ip:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 5: SonarQube Initial Setup

1. Access SonarQube at `http://localhost:9000`
2. Default credentials: `admin/admin`
3. Change password when prompted
4. Create your first project

## Debugging Commands

### System Monitoring
```bash
# System resources
htop                    # Interactive process viewer
free -h                 # Memory usage
df -h                   # Disk usage
lsof -i :9000          # Check what's using port 9000
netstat -tulpn         # All listening ports

# Process monitoring
ps aux | grep sonar     # SonarQube processes
ps aux | grep java     # Java processes
pgrep -f sonarqube     # Find SonarQube PID
```

### Service Debugging
```bash
# Service status and logs
sudo systemctl status sonarqube
sudo journalctl -u sonarqube -f        # Follow logs
sudo journalctl -u sonarqube --since "1 hour ago"

# SonarQube specific logs
tail -f /opt/sonarqube/logs/sonar.log
tail -f /opt/sonarqube/logs/web.log
tail -f /opt/sonarqube/logs/ce.log
tail -f /opt/sonarqube/logs/es.log
```

### Network Debugging
```bash
# Port connectivity
telnet localhost 9000               # Test local connection
nc -zv main-server-ip 9000         # Test from jumpbox
ss -tulpn | grep :9000             # Check port binding

# SSH tunnel debugging
ssh -v -L 9000:localhost:9000 mainserver    # Verbose SSH
lsof -i :9000                       # Check local port forwarding
```

### Database Debugging
```bash
# PostgreSQL status
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"      # List databases
sudo -u postgres psql -d sonarqube -c "\dt"  # List tables

# Connection test
sudo -u postgres psql -d sonarqube -c "SELECT version();"
```

### File System Debugging
```bash
# Permissions check
ls -la /opt/sonarqube/
ls -la /opt/sonarqube/logs/
sudo -u sonarqube ls -la /opt/sonarqube/

# Disk space
du -sh /opt/sonarqube/
df -h /opt/
```

### Performance Monitoring
```bash
# Real-time monitoring
watch -n 2 'ps aux | grep sonar'
watch -n 2 'free -h'
iostat -x 2                        # I/O statistics
sar -u 2 5                         # CPU usage

# Java process monitoring
jps                                 # List Java processes
jstat -gc PID                      # Garbage collection stats
```

### Troubleshooting Common Issues

#### SonarQube Won't Start
```bash
# Check Java version
java -version

# Check system limits
ulimit -n
ulimit -u

# Check configuration
sudo -u sonarqube /opt/sonarqube/bin/linux-x86-64/sonar.sh console
```

#### Can't Access from Browser
```bash
# Check if service is running
curl -I http://localhost:9000

# Check SSH tunnel
ps aux | grep ssh
netstat -an | grep 9000

# Test connectivity step by step
# From main server:
curl -I http://localhost:9000
# From jumpbox:
curl -I http://main-server-ip:9000
```

#### Database Connection Issues
```bash
# Test database connection
sudo -u sonarqube psql -h localhost -d sonarqube -U sonarqube

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

## Security Best Practices

1. **Change default passwords** immediately
2. **Use SSH keys** instead of passwords
3. **Configure firewall** properly
4. **Regular updates**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
5. **Monitor logs** regularly
6. **Backup database**:
   ```bash
   sudo -u postgres pg_dump sonarqube > sonarqube_backup.sql
   ```

## Quick Reference Commands

```bash
# Start/stop SonarQube
sudo systemctl start sonarqube
sudo systemctl stop sonarqube
sudo systemctl restart sonarqube

# SSH tunnel
ssh -L 9000:localhost:9000 mainserver

# Check logs
sudo journalctl -u sonarqube -f

# Check port
netstat -tulpn | grep 9000
```
