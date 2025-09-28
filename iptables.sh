#!/bin/bash

# LBR host IP (replace with actual IP)
LBR_HOST=""  ## Enter portnumber to skip

echo "[INFO] Installing iptables and dependencies..."
yum install -y iptables iptables-services policycoreutils telnet >/dev/null 2>&1

echo "[INFO] Flushing old iptables rules..."
iptables -F

echo "[INFO] Setting default policies..."
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "[INFO] Allowing loopback..."
iptables -A INPUT -i lo -j ACCEPT

echo "[INFO] Allowing established/related connections..."
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "[INFO] Allowing port 8083 only from LBR host ${LBR_HOST}..."
iptables -A INPUT -p tcp -s ${LBR_HOST} --dport 8083 -j ACCEPT

echo "[INFO] Dropping all other traffic to port 8083..."
iptables -A INPUT -p tcp --dport 8083 -j DROP

echo "[INFO] Saving iptables rules..."
service iptables save

echo "[INFO] Enabling iptables service on boot..."
systemctl enable iptables
systemctl restart iptables

echo "[SUCCESS] Firewall configured. Port 8083 is restricted to ${LBR_HOST}."
