#!/bin/bash

# Exit on any error
set -e

echo "===== Step 1: Creating jenkins user (if not exists) ====="
if id "jenkins" &>/dev/null; then
    echo "User 'jenkins' already exists."
else
    sudo useradd -m -s /bin/bash jenkins
    echo "User 'jenkins' created successfully."
fi

echo "===== Step 2: Creating SSH directory ====="
sudo mkdir -p /home/jenkins/.ssh
sudo chown jenkins:jenkins /home/jenkins/.ssh
sudo chmod 700 /home/jenkins/.ssh

echo "===== Step 3: Generating SSH keys ====="
sudo -u jenkins ssh-keygen -t rsa -b 4096 -f /home/jenkins/.ssh/id_rsa -N ""
echo "SSH key generated."

echo "===== Step 4: Setting permissions ====="
sudo chown jenkins:jenkins /home/jenkins/.ssh/id_rsa*
sudo chmod 600 /home/jenkins/.ssh/id_rsa
sudo chmod 644 /home/jenkins/.ssh/id_rsa.pub

echo "===== Public Key (copy this to slave node ~/.ssh/authorized_keys) ====="
sudo cat /home/jenkins/.ssh/id_rsa.pub

echo "===== Done ====="
echo "Now paste this key into the slave node's file:"
echo "~/.ssh/authorized_keys"



: '
cat id_rsa.pub >> ~/.ssh/authorized_keys
sudo -u jenkins ssh jenkins@<SLAVE_IP>
'
