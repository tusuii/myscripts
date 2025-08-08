#!/bin/bash

# ====== FUNCTIONS ======

install_jdk() {
    echo "[INFO] Installing Temurin 17 JDK..."
    sudo apt update -y
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update -y
    sudo apt install temurin-17-jdk -y
    java --version
}

install_jenkins() {
    echo "[INFO] Installing Jenkins..."
    install_jdk
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install jenkins -y
    sudo systemctl enable jenkins
    sudo systemctl start jenkins
    echo "[INFO] Jenkins installed and started."
}

install_docker() {
    echo "[INFO] Installing Docker..."
    sudo apt-get update -y
    sudo apt-get install docker.io -y
    sudo usermod -aG docker $USER
    newgrp docker <<EONG
sudo chmod 777 /var/run/docker.sock
EONG
    echo "[INFO] Docker installed."
}

install_sonarqube() {
    echo "[INFO] Installing SonarQube..."
    install_docker
    docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
    echo "[INFO] SonarQube running on port 9000."
}

install_trivy() {
    echo "[INFO] Installing Trivy..."
    sudo apt-get install wget apt-transport-https gnupg lsb-release -y
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt-get update -y
    sudo apt-get install trivy -y
}

install_grafana() {
    echo "[INFO] Installing Grafana..."
    sudo apt-get install -y apt-transport-https software-properties-common
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt-get update -y
    sudo apt-get install grafana -y
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
}

install_prometheus() {
    echo "[INFO] Installing Prometheus..."
    install_docker
    docker run -d --name prometheus -p 9090:9090 prom/prometheus
}

install_ansible() {
    echo "[INFO] Installing Ansible..."
    sudo apt-get update -y
    sudo apt-get install ansible -y
}

install_terraform() {
    echo "[INFO] Installing Terraform..."
    sudo apt-get update -y
    sudo apt-get install wget unzip -y
    TERRAFORM_VERSION="1.8.5"
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    terraform -version
}

# ====== MAIN SCRIPT ======

if [ "$1" != "-t" ]; then
    echo "Usage: $0 -t <tool1> <tool2> ..."
    echo "Available tools: jenkins docker sonarqube trivy grafana prometheus ansible terraform"
    exit 1
fi

shift # Remove -t from arguments

for tool in "$@"; do
    case $tool in
        jenkins) install_jenkins ;;
        docker) install_docker ;;
        sonarqube) install_sonarqube ;;
        trivy) install_trivy ;;
        grafana) install_grafana ;;
        prometheus) install_prometheus ;;
        ansible) install_ansible ;;
        terraform) install_terraform ;;
        *)
            echo "[WARN] Unknown tool: $tool"
            ;;
    esac
done

echo "[DONE] Installation complete."
