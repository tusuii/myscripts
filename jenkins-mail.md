# Jenkins Email Configuration Guide

## 1. Configure SMTP in Jenkins

### Access Email Configuration
1. Go to **Manage Jenkins** > **Configure System**
2. Scroll to **E-mail Notification** section

### SMTP Settings
```
SMTP server: smtp.gmail.com
Default user e-mail suffix: @company.com
Use SMTP Authentication: ✓
User Name: your-email@gmail.com
Password: your-app-password
Use SSL: ✓
SMTP Port: 465
```

### For Other Email Providers
```bash
# Gmail
SMTP: smtp.gmail.com, Port: 587 (TLS) or 465 (SSL)

# Outlook/Hotmail
SMTP: smtp-mail.outlook.com, Port: 587

# Yahoo
SMTP: smtp.mail.yahoo.com, Port: 587

# Custom SMTP
SMTP: mail.yourcompany.com, Port: 25/587
```

## 2. Extended E-mail Notification Plugin

### Install Plugin
1. **Manage Jenkins** > **Manage Plugins**
2. Search for **"Email Extension Plugin"**
3. Install and restart Jenkins

### Configure Extended Email
1. **Manage Jenkins** > **Configure System**
2. Find **Extended E-mail Notification** section

```
SMTP server: smtp.gmail.com
Default user e-mail suffix: @company.com
Use SMTP Authentication: ✓
User Name: your-email@gmail.com
Password: your-app-password
Use SSL: ✓
SMTP port: 465
Default Recipients: team@company.com
Default Subject: $PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS!
Default Content: 
Build URL: $BUILD_URL
Build Log: ${BUILD_LOG, maxLines=100}
```

## 3. Pipeline Email Examples

### Basic Email in Pipeline
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
    }
    post {
        always {
            emailext (
                subject: "Build ${env.BUILD_NUMBER} - ${currentBuild.currentResult}",
                body: """
                Project: ${env.JOB_NAME}
                Build Number: ${env.BUILD_NUMBER}
                Build Status: ${currentBuild.currentResult}
                Build URL: ${env.BUILD_URL}
                """,
                to: 'team@company.com'
            )
        }
    }
}
```

### Conditional Email Notifications
```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh 'echo "Running tests..."'
            }
        }
    }
    post {
        success {
            emailext (
                subject: "✅ SUCCESS: ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}",
                body: """
                Good news! The build was successful.
                
                Project: ${env.JOB_NAME}
                Build: ${env.BUILD_NUMBER}
                Duration: ${currentBuild.durationString}
                
                View details: ${env.BUILD_URL}
                """,
                to: 'team@company.com'
            )
        }
        failure {
            emailext (
                subject: "❌ FAILED: ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}",
                body: """
                Build failed! Please check the logs.
                
                Project: ${env.JOB_NAME}
                Build: ${env.BUILD_NUMBER}
                
                Build Log:
                ${BUILD_LOG, maxLines=50}
                
                Fix it: ${env.BUILD_URL}
                """,
                to: 'team@company.com,manager@company.com'
            )
        }
    }
}
```

### Email with Attachments
```groovy
pipeline {
    agent any
    stages {
        stage('Generate Report') {
            steps {
                sh 'echo "Test Results" > test-report.txt'
                archiveArtifacts artifacts: 'test-report.txt'
            }
        }
    }
    post {
        always {
            emailext (
                subject: "Build Report - ${env.JOB_NAME}",
                body: "Please find the build report attached.",
                to: 'team@company.com',
                attachmentsPattern: 'test-report.txt'
            )
        }
    }
}
```

## 4. Advanced Email Templates

### HTML Email Template
```groovy
pipeline {
    agent any
    post {
        always {
            emailext (
                subject: "Build ${env.BUILD_NUMBER} - ${currentBuild.currentResult}",
                mimeType: 'text/html',
                body: """
                <html>
                <body>
                    <h2 style="color: ${currentBuild.currentResult == 'SUCCESS' ? 'green' : 'red'}">
                        Build ${currentBuild.currentResult}
                    </h2>
                    <table border="1">
                        <tr><td><b>Project</b></td><td>${env.JOB_NAME}</td></tr>
                        <tr><td><b>Build Number</b></td><td>${env.BUILD_NUMBER}</td></tr>
                        <tr><td><b>Duration</b></td><td>${currentBuild.durationString}</td></tr>
                        <tr><td><b>Status</b></td><td>${currentBuild.currentResult}</td></tr>
                    </table>
                    <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                </body>
                </html>
                """,
                to: 'team@company.com'
            )
        }
    }
}
```

### Email with Build Changes
```groovy
pipeline {
    agent any
    post {
        always {
            script {
                def changeString = ""
                def changes = currentBuild.changeSets
                for (int i = 0; i < changes.size(); i++) {
                    def entries = changes[i].items
                    for (int j = 0; j < entries.length; j++) {
                        def entry = entries[j]
                        changeString += "- ${entry.msg} by ${entry.author}\n"
                    }
                }
                
                emailext (
                    subject: "Build ${env.BUILD_NUMBER} - ${currentBuild.currentResult}",
                    body: """
                    Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
                    Status: ${currentBuild.currentResult}
                    
                    Changes in this build:
                    ${changeString ?: 'No changes'}
                    
                    Build URL: ${env.BUILD_URL}
                    """,
                    to: 'team@company.com'
                )
            }
        }
    }
}
```

## 5. Freestyle Job Email Configuration

### Post-build Actions
1. Add **"Editable Email Notification"** post-build action
2. Configure recipients: `team@company.com, $DEFAULT_RECIPIENTS`
3. Set triggers:
   - **Always** - Send regardless of build result
   - **Failure - Any** - Send on any failure
   - **Success** - Send on successful builds
   - **Unstable** - Send on unstable builds

### Email Content Templates
```
Subject: $PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS!

Body:
Project: $PROJECT_NAME
Build Number: $BUILD_NUMBER
Build Status: $BUILD_STATUS
Build URL: $BUILD_URL

Changes:
${CHANGES, showPaths=true, format="[%a] %m\\n"}

Console Output:
${BUILD_LOG, maxLines=100}
```

## 6. Email Triggers and Recipients

### Dynamic Recipients
```groovy
// Email to committers
emailext (
    to: '$DEFAULT_RECIPIENTS',
    recipientProviders: [
        [$class: 'DevelopersRecipientProvider'],
        [$class: 'RequesterRecipientProvider']
    ]
)

// Email to specific people based on branch
script {
    def recipients = env.BRANCH_NAME == 'main' ? 
        'team@company.com,manager@company.com' : 
        'developers@company.com'
    
    emailext (
        to: recipients,
        subject: "Build ${env.BUILD_NUMBER} on ${env.BRANCH_NAME}"
    )
}
```

### Conditional Email Logic
```groovy
post {
    always {
        script {
            if (currentBuild.currentResult == 'FAILURE') {
                emailext (
                    to: 'team@company.com,oncall@company.com',
                    subject: "🚨 URGENT: Build Failed - ${env.JOB_NAME}",
                    body: "Immediate attention required!"
                )
            } else if (currentBuild.currentResult == 'SUCCESS' && 
                       currentBuild.previousBuild?.result == 'FAILURE') {
                emailext (
                    to: 'team@company.com',
                    subject: "✅ Build Fixed - ${env.JOB_NAME}",
                    body: "Build is back to normal!"
                )
            }
        }
    }
}
```

## 7. SonarQube Integration Email

### Pipeline with SonarQube Report Email
```groovy
pipeline {
    agent any
    stages {
        stage('SonarQube Analysis') {
            steps {
                script {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=my-project \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://sonarqube:9000 \
                          -Dsonar.token=${SONAR_TOKEN}
                    '''
                }
            }
        }
        stage('Generate Report') {
            steps {
                sh './sonar-report-generator.sh my-project http://sonarqube:9000 ${SONAR_TOKEN}'
                archiveArtifacts artifacts: 'sonar-reports/*.html, sonar-reports/*.pdf'
            }
        }
    }
    post {
        always {
            emailext (
                subject: "SonarQube Analysis - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                mimeType: 'text/html',
                body: '''
                <h2>SonarQube Analysis Complete</h2>
                <p>Project: ${JOB_NAME}</p>
                <p>Build: ${BUILD_NUMBER}</p>
                <p><a href="${BUILD_URL}artifact/sonar-reports/">Download Reports</a></p>
                <p><a href="http://sonarqube:9000/dashboard?id=my-project">View SonarQube Dashboard</a></p>
                ''',
                to: 'team@company.com',
                attachmentsPattern: 'sonar-reports/*.pdf'
            )
        }
    }
}
```

## 8. Troubleshooting Email Issues

### Common Problems
```bash
# Test SMTP connection
telnet smtp.gmail.com 587

# Check Jenkins logs
tail -f /var/log/jenkins/jenkins.log

# Gmail App Password (not regular password)
# Enable 2FA and generate app-specific password
```

### Debug Email Configuration
```groovy
pipeline {
    agent any
    stages {
        stage('Test Email') {
            steps {
                script {
                    try {
                        emailext (
                            subject: "Test Email from Jenkins",
                            body: "This is a test email to verify configuration.",
                            to: 'your-email@company.com'
                        )
                        echo "Email sent successfully"
                    } catch (Exception e) {
                        echo "Email failed: ${e.getMessage()}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
}
```

### Email Security Settings
```
Gmail:
- Enable 2-Factor Authentication
- Generate App Password
- Use App Password in Jenkins (not regular password)

Corporate Email:
- Check firewall settings
- Verify SMTP server accessibility
- Use correct authentication method
```

## 9. Best Practices

### Email Frequency Management
```groovy
// Only email on status change
post {
    changed {
        emailext (
            subject: "Status Changed: ${env.JOB_NAME}",
            body: "Build status changed from ${currentBuild.previousBuild?.result} to ${currentBuild.currentResult}"
        )
    }
}

// Throttle emails for frequent builds
post {
    failure {
        script {
            if (env.BUILD_NUMBER.toInteger() % 5 == 0) {
                emailext (
                    subject: "Still Failing: ${env.JOB_NAME}",
                    body: "Build has failed ${env.BUILD_NUMBER} times"
                )
            }
        }
    }
}
```

### Template Reuse
```groovy
// Define common email function
def sendBuildNotification(String status, String recipients) {
    emailext (
        subject: "${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: """
        Build ${status.toLowerCase()}
        
        Project: ${env.JOB_NAME}
        Build: ${env.BUILD_NUMBER}
        Duration: ${currentBuild.durationString}
        
        Details: ${env.BUILD_URL}
        """,
        to: recipients
    )
}

// Use in pipeline
post {
    success { sendBuildNotification('SUCCESS', 'team@company.com') }
    failure { sendBuildNotification('FAILURE', 'team@company.com,manager@company.com') }
}
```

This guide covers all aspects of email configuration and usage in Jenkins, from basic setup to advanced templating and integration with build processes.
