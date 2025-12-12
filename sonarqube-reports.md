# SonarQube Scanner Installation & Report Generation Guide

## Prerequisites

- Java 17+ installed
- SonarQube server running (Docker or standalone)
- SMTP server access for email reports

## 1. SonarQube Scanner Installation

### Download and Install
```bash
# Create directory
mkdir ~/sonar-docker && cd ~/sonar-docker

# Download latest scanner
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip

# Add to PATH
export PATH=$HOME/sonar-docker/sonar-scanner-5.0.1.3006-linux/bin:$PATH
echo 'export PATH=$HOME/sonar-docker/sonar-scanner-5.0.1.3006-linux/bin:$PATH' >> ~/.bashrc

# Set Java 17
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
```

### Verify Installation
```bash
sonar-scanner --version
java -version
```

## 2. Basic Project Scanning

### Create sonar-project.properties
```properties
sonar.projectKey=my-project
sonar.projectName=My Project
sonar.projectVersion=1.0
sonar.sources=.
sonar.exclusions=**/node_modules/**,**/target/**,**/*.test.js
sonar.host.url=http://localhost:9000
sonar.token=your-sonarqube-token
```

### Run Scanner
```bash
# Basic scan
sonar-scanner

# Or with parameters
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=your-token
```

## 3. HTML Report Generation

### Install SonarQube Community Branch Plugin (if needed)
```bash
# Download community plugin for report generation
wget https://github.com/mc1arke/sonarqube-community-branch-plugin/releases/download/1.14.0/sonarqube-community-branch-plugin-1.14.0.jar
# Copy to SonarQube plugins directory
```

### Generate HTML Reports using SonarQube API
```bash
#!/bin/bash
# generate-html-report.sh

PROJECT_KEY="my-project"
SONAR_URL="http://localhost:9000"
SONAR_TOKEN="your-token"
OUTPUT_DIR="reports"

mkdir -p $OUTPUT_DIR

# Get project metrics
curl -u $SONAR_TOKEN: \
  "$SONAR_URL/api/measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density" \
  -o "$OUTPUT_DIR/metrics.json"

# Get issues
curl -u $SONAR_TOKEN: \
  "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&ps=500" \
  -o "$OUTPUT_DIR/issues.json"

echo "Reports generated in $OUTPUT_DIR/"
```

### Create HTML Report Template
```html
<!DOCTYPE html>
<html>
<head>
    <title>SonarQube Report - {{PROJECT_NAME}}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #4CAF50; color: white; padding: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; border: 1px solid #ddd; }
        .issues { margin-top: 20px; }
        .issue { padding: 10px; margin: 5px 0; border-left: 4px solid #f44336; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SonarQube Analysis Report</h1>
        <p>Project: {{PROJECT_NAME}} | Date: {{DATE}}</p>
    </div>
    
    <div class="metrics">
        <div class="metric">
            <h3>Bugs</h3>
            <p>{{BUGS}}</p>
        </div>
        <div class="metric">
            <h3>Vulnerabilities</h3>
            <p>{{VULNERABILITIES}}</p>
        </div>
        <div class="metric">
            <h3>Code Smells</h3>
            <p>{{CODE_SMELLS}}</p>
        </div>
        <div class="metric">
            <h3>Coverage</h3>
            <p>{{COVERAGE}}%</p>
        </div>
    </div>
    
    <div class="issues">
        <h2>Critical Issues</h2>
        {{ISSUES_LIST}}
    </div>
</body>
</html>
```

## 4. PDF Report Generation

### Install wkhtmltopdf
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install wkhtmltopdf

# CentOS/RHEL
sudo yum install wkhtmltopdf
```

### Generate PDF from HTML
```bash
#!/bin/bash
# generate-pdf-report.sh

PROJECT_KEY="my-project"
HTML_FILE="reports/sonar-report.html"
PDF_FILE="reports/sonar-report-$(date +%Y%m%d).pdf"

# Convert HTML to PDF
wkhtmltopdf --page-size A4 --orientation Portrait $HTML_FILE $PDF_FILE

echo "PDF report generated: $PDF_FILE"
```

## 5. Email Report Automation

### Install mail utilities
```bash
# Ubuntu/Debian
sudo apt install mailutils ssmtp

# Configure ssmtp
sudo nano /etc/ssmtp/ssmtp.conf
```

### SSMTP Configuration
```bash
# /etc/ssmtp/ssmtp.conf
root=your-email@company.com
mailhub=smtp.gmail.com:587
rewriteDomain=company.com
AuthUser=your-email@company.com
AuthPass=your-app-password
UseSTARTTLS=YES
UseTLS=YES
```

### Email Script
```bash
#!/bin/bash
# send-sonar-report.sh

PROJECT_KEY="my-project"
REPORT_DATE=$(date +%Y-%m-%d)
PDF_REPORT="reports/sonar-report-$(date +%Y%m%d).pdf"
RECIPIENTS="team@company.com,manager@company.com"

# Email content
cat > email_body.txt << EOF
Subject: SonarQube Analysis Report - $PROJECT_KEY ($REPORT_DATE)

Dear Team,

Please find attached the latest SonarQube analysis report for project: $PROJECT_KEY

Report Date: $REPORT_DATE
Project URL: http://localhost:9000/dashboard?id=$PROJECT_KEY

Best regards,
DevOps Team
EOF

# Send email with attachment
mail -s "SonarQube Report - $PROJECT_KEY" -A $PDF_REPORT $RECIPIENTS < email_body.txt

echo "Report sent to: $RECIPIENTS"
```

## 6. Complete Automation Script

```bash
#!/bin/bash
# sonar-complete-workflow.sh

set -e

PROJECT_KEY="$1"
PROJECT_NAME="$2"
SONAR_URL="http://localhost:9000"
SONAR_TOKEN="$3"
RECIPIENTS="$4"

if [ $# -ne 4 ]; then
    echo "Usage: $0 <project-key> <project-name> <sonar-token> <recipients>"
    exit 1
fi

echo "Starting SonarQube analysis workflow..."

# 1. Run SonarQube scan
echo "Running SonarQube scan..."
sonar-scanner \
  -Dsonar.projectKey=$PROJECT_KEY \
  -Dsonar.projectName="$PROJECT_NAME" \
  -Dsonar.sources=. \
  -Dsonar.host.url=$SONAR_URL \
  -Dsonar.token=$SONAR_TOKEN

# 2. Wait for analysis to complete
echo "Waiting for analysis to complete..."
sleep 30

# 3. Generate reports
echo "Generating reports..."
mkdir -p reports

# Get metrics
curl -u $SONAR_TOKEN: \
  "$SONAR_URL/api/measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage" \
  -o "reports/metrics.json"

# 4. Create HTML report (simplified)
cat > reports/sonar-report.html << EOF
<!DOCTYPE html>
<html>
<head><title>SonarQube Report - $PROJECT_NAME</title></head>
<body>
<h1>SonarQube Analysis Report</h1>
<p>Project: $PROJECT_NAME</p>
<p>Date: $(date)</p>
<p>View full report: <a href="$SONAR_URL/dashboard?id=$PROJECT_KEY">$SONAR_URL/dashboard?id=$PROJECT_KEY</a></p>
</body>
</html>
EOF

# 5. Generate PDF
wkhtmltopdf reports/sonar-report.html reports/sonar-report-$(date +%Y%m%d).pdf

# 6. Send email
mail -s "SonarQube Report - $PROJECT_NAME" -A reports/sonar-report-$(date +%Y%m%d).pdf $RECIPIENTS << EOF
SonarQube analysis completed for: $PROJECT_NAME

View online: $SONAR_URL/dashboard?id=$PROJECT_KEY

Report attached.
EOF

echo "Workflow completed successfully!"
```

## 7. Usage Examples

### Basic Usage
```bash
# Make script executable
chmod +x sonar-complete-workflow.sh

# Run complete workflow
./sonar-complete-workflow.sh "my-project" "My Project" "squ_token123" "team@company.com"
```

### Scheduled Execution (Cron)
```bash
# Add to crontab for daily reports at 9 AM
crontab -e

# Add this line:
0 9 * * * cd /path/to/project && /path/to/sonar-complete-workflow.sh "my-project" "My Project" "squ_token123" "team@company.com"
```

### Jenkins Integration
```groovy
pipeline {
    agent any
    stages {
        stage('SonarQube Analysis & Report') {
            steps {
                script {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=${JOB_NAME} \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://sonarqube:9000 \
                          -Dsonar.token=${SONAR_TOKEN}
                    '''
                    
                    sh '''
                        ./sonar-complete-workflow.sh \
                          "${JOB_NAME}" \
                          "${JOB_NAME}" \
                          "${SONAR_TOKEN}" \
                          "team@company.com"
                    '''
                }
            }
        }
    }
}
```

## 8. Troubleshooting

### Common Issues
- **Java version error**: Ensure Java 17+ is installed and JAVA_HOME is set
- **Connection refused**: Verify SonarQube server is running and accessible
- **Authentication failed**: Check token validity and permissions
- **Email not sending**: Verify SMTP configuration and credentials

### Debug Commands
```bash
# Test SonarQube connection
curl -u token: http://localhost:9000/api/system/status

# Test email configuration
echo "Test email" | mail -s "Test" your-email@company.com

# Verbose scanner output
sonar-scanner -X
```

## 9. Security Best Practices

- Store tokens in environment variables or secure vaults
- Use dedicated service accounts for automation
- Restrict SonarQube project permissions
- Use encrypted SMTP connections
- Regularly rotate authentication tokens
