# Jenkins CI/CD Pipelines for Python/Node.js Microservices on GCP

## Prerequisites

### Required Jenkins Plugins
- Google Kubernetes Engine Plugin
- Google Container Registry Auth Plugin
- Pipeline Plugin
- Docker Pipeline Plugin
- Kubernetes CLI Plugin
- SonarQube Scanner Plugin

### Environment Setup
```groovy
// Global environment variables in Jenkins
environment {
    PROJECT_ID = 'your-gcp-project-id'
    CLUSTER_NAME = 'your-gke-cluster'
    CLUSTER_ZONE = 'us-central1-a'
    REGISTRY_HOSTNAME = 'gcr.io'
    SONAR_HOST = 'http://sonarqube:9000'
}
```

## 1. Basic Python Microservice Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        SERVICE_NAME = 'python-api'
        IMAGE_TAG = "${BUILD_NUMBER}"
        GCR_IMAGE = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/${SERVICE_NAME}:${IMAGE_TAG}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    python3 -m venv venv
                    source venv/bin/activate
                    pip install -r requirements.txt
                    python -m pytest tests/ --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
        
        stage('Build & Push') {
            steps {
                script {
                    def image = docker.build("${GCR_IMAGE}")
                    docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:gcp-service-account') {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to GKE') {
            steps {
                withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh '''
                        gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                        gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID
                        kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$GCR_IMAGE
                        kubectl rollout status deployment/$SERVICE_NAME
                    '''
                }
            }
        }
    }
}
```

## 2. Advanced Node.js Pipeline with Quality Gates

```groovy
pipeline {
    agent any
    
    environment {
        SERVICE_NAME = 'nodejs-api'
        NODE_VERSION = '18'
        IMAGE_TAG = "${BUILD_NUMBER}"
        GCR_IMAGE = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/${SERVICE_NAME}:${IMAGE_TAG}"
    }
    
    tools {
        nodejs "${NODE_VERSION}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }
        
        stage('Lint & Format') {
            parallel {
                stage('ESLint') {
                    steps {
                        sh 'npm run lint'
                    }
                }
                stage('Prettier Check') {
                    steps {
                        sh 'npm run format:check'
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'npm run test:unit -- --coverage --reporter=xunit --outputFile=test-results.xml'
            }
            post {
                always {
                    junit 'test-results.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=$SERVICE_NAME \
                        -Dsonar.sources=src \
                        -Dsonar.tests=tests \
                        -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    '''
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                sh 'npm audit --audit-level=high'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def image = docker.build("${GCR_IMAGE}")
                    docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:gcp-service-account') {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            steps {
                deployToGKE('staging')
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh '''
                    export API_URL=https://staging-${SERVICE_NAME}.example.com
                    npm run test:integration
                '''
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
                deployToGKE('production')
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        failure {
            emailext (
                subject: "Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Build failed. Check console output at ${env.BUILD_URL}",
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}

def deployToGKE(environment) {
    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
        sh """
            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
            gcloud container clusters get-credentials ${CLUSTER_NAME}-${environment} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
            
            helm upgrade --install ${SERVICE_NAME} ./helm-chart \\
                --set image.repository=${REGISTRY_HOSTNAME}/${PROJECT_ID}/${SERVICE_NAME} \\
                --set image.tag=${IMAGE_TAG} \\
                --set environment=${environment} \\
                --namespace ${environment} \\
                --create-namespace
                
            kubectl rollout status deployment/${SERVICE_NAME} -n ${environment}
        """
    }
}
```

## 3. Multi-Service Pipeline with Matrix Strategy

```groovy
pipeline {
    agent none
    
    environment {
        PROJECT_ID = 'your-gcp-project-id'
        REGISTRY_HOSTNAME = 'gcr.io'
    }
    
    stages {
        stage('Build Matrix') {
            matrix {
                axes {
                    axis {
                        name 'SERVICE'
                        values 'user-service', 'order-service', 'payment-service'
                    }
                    axis {
                        name 'ENVIRONMENT'
                        values 'staging', 'production'
                    }
                }
                excludes {
                    exclude {
                        axis {
                            name 'ENVIRONMENT'
                            values 'production'
                        }
                    }
                }
                stages {
                    stage('Build Service') {
                        agent any
                        steps {
                            script {
                                def serviceConfig = getServiceConfig(SERVICE)
                                buildAndDeploy(SERVICE, serviceConfig, ENVIRONMENT)
                            }
                        }
                    }
                }
            }
        }
        
        stage('Production Deployment') {
            when {
                branch 'main'
            }
            agent any
            steps {
                script {
                    def services = ['user-service', 'order-service', 'payment-service']
                    services.each { service ->
                        def serviceConfig = getServiceConfig(service)
                        buildAndDeploy(service, serviceConfig, 'production')
                    }
                }
            }
        }
    }
}

def getServiceConfig(serviceName) {
    def configs = [
        'user-service': [
            'dockerfile': 'services/user/Dockerfile',
            'testCommand': 'python -m pytest services/user/tests/',
            'port': 8001
        ],
        'order-service': [
            'dockerfile': 'services/order/Dockerfile', 
            'testCommand': 'npm test',
            'port': 8002
        ],
        'payment-service': [
            'dockerfile': 'services/payment/Dockerfile',
            'testCommand': 'python -m pytest services/payment/tests/',
            'port': 8003
        ]
    ]
    return configs[serviceName]
}

def buildAndDeploy(serviceName, config, environment) {
    def imageTag = "${BUILD_NUMBER}"
    def gcrImage = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/${serviceName}:${imageTag}"
    
    // Test
    sh config.testCommand
    
    // Build and Push
    def image = docker.build(gcrImage, "-f ${config.dockerfile} .")
    docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:gcp-service-account') {
        image.push()
    }
    
    // Deploy
    deployToGKE(serviceName, gcrImage, environment)
}
```

## 4. GitOps Pipeline with ArgoCD Integration

```groovy
pipeline {
    agent any
    
    environment {
        SERVICE_NAME = 'microservice-app'
        GITOPS_REPO = 'https://github.com/your-org/k8s-manifests.git'
        GITOPS_BRANCH = 'main'
    }
    
    stages {
        stage('Build & Test') {
            parallel {
                stage('Python Services') {
                    steps {
                        dir('python-services') {
                            sh '''
                                for service in */; do
                                    cd $service
                                    python -m pytest tests/
                                    docker build -t gcr.io/${PROJECT_ID}/${service%/}:${BUILD_NUMBER} .
                                    cd ..
                                done
                            '''
                        }
                    }
                }
                stage('Node.js Services') {
                    steps {
                        dir('nodejs-services') {
                            sh '''
                                for service in */; do
                                    cd $service
                                    npm ci && npm test
                                    docker build -t gcr.io/${PROJECT_ID}/${service%/}:${BUILD_NUMBER} .
                                    cd ..
                                done
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Push Images') {
            steps {
                script {
                    docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:gcp-service-account') {
                        sh '''
                            docker images --format "table {{.Repository}}:{{.Tag}}" | grep gcr.io | grep ${BUILD_NUMBER} | while read image; do
                                docker push $image
                            done
                        '''
                    }
                }
            }
        }
        
        stage('Update GitOps Repo') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD')]) {
                    sh '''
                        git clone https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/your-org/k8s-manifests.git gitops
                        cd gitops
                        
                        # Update image tags in Kustomization files
                        find . -name "kustomization.yaml" -exec sed -i "s/newTag: .*/newTag: ${BUILD_NUMBER}/g" {} \\;
                        
                        git config user.email "jenkins@company.com"
                        git config user.name "Jenkins CI"
                        git add .
                        git commit -m "Update image tags to ${BUILD_NUMBER}"
                        git push origin ${GITOPS_BRANCH}
                    '''
                }
            }
        }
    }
}
```

## 5. Canary Deployment Pipeline

```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'DEPLOYMENT_STRATEGY', choices: ['blue-green', 'canary', 'rolling'], description: 'Deployment Strategy')
        string(name: 'CANARY_PERCENTAGE', defaultValue: '10', description: 'Canary Traffic Percentage')
    }
    
    environment {
        SERVICE_NAME = 'api-gateway'
        NAMESPACE = 'production'
    }
    
    stages {
        stage('Deploy Canary') {
            when {
                expression { params.DEPLOYMENT_STRATEGY == 'canary' }
            }
            steps {
                deployCanary()
            }
        }
        
        stage('Run Canary Tests') {
            when {
                expression { params.DEPLOYMENT_STRATEGY == 'canary' }
            }
            steps {
                runCanaryTests()
            }
        }
        
        stage('Promote or Rollback') {
            when {
                expression { params.DEPLOYMENT_STRATEGY == 'canary' }
            }
            steps {
                script {
                    def promote = input(
                        message: 'Promote canary to full deployment?',
                        parameters: [choice(choices: ['Promote', 'Rollback'], name: 'ACTION')]
                    )
                    
                    if (promote == 'Promote') {
                        promoteCanary()
                    } else {
                        rollbackCanary()
                    }
                }
            }
        }
    }
}

def deployCanary() {
    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
        sh """
            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
            gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
            
            # Deploy canary version
            kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}-canary
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${SERVICE_NAME}
      version: canary
  template:
    metadata:
      labels:
        app: ${SERVICE_NAME}
        version: canary
    spec:
      containers:
      - name: ${SERVICE_NAME}
        image: ${GCR_IMAGE}
        ports:
        - containerPort: 8080
EOF

            # Update Istio VirtualService for traffic splitting
            kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ${SERVICE_NAME}
        subset: canary
  - route:
    - destination:
        host: ${SERVICE_NAME}
        subset: stable
      weight: ${100 - params.CANARY_PERCENTAGE.toInteger()}
    - destination:
        host: ${SERVICE_NAME}
        subset: canary
      weight: ${params.CANARY_PERCENTAGE.toInteger()}
EOF
        """
    }
}

def runCanaryTests() {
    sh '''
        # Run smoke tests against canary
        export CANARY_URL=https://api.example.com
        npm run test:canary
        
        # Check metrics
        python scripts/check_canary_metrics.py --duration=300 --error-threshold=1
    '''
}

def promoteCanary() {
    sh '''
        kubectl patch deployment ${SERVICE_NAME} -n ${NAMESPACE} -p '{"spec":{"template":{"spec":{"containers":[{"name":"'${SERVICE_NAME}'","image":"'${GCR_IMAGE}'"}]}}}}'
        kubectl delete deployment ${SERVICE_NAME}-canary -n ${NAMESPACE}
        kubectl apply -f k8s/virtualservice-stable.yaml
    '''
}

def rollbackCanary() {
    sh '''
        kubectl delete deployment ${SERVICE_NAME}-canary -n ${NAMESPACE}
        kubectl apply -f k8s/virtualservice-stable.yaml
    '''
}
```

## 6. Multi-Environment Pipeline with Approval Gates

```groovy
pipeline {
    agent any
    
    environment {
        SERVICE_NAME = 'user-management'
        ENVIRONMENTS = 'dev,staging,production'
    }
    
    stages {
        stage('Build & Test') {
            steps {
                buildAndTest()
            }
        }
        
        stage('Deploy to Environments') {
            steps {
                script {
                    def environments = env.ENVIRONMENTS.split(',')
                    
                    environments.each { environment ->
                        stage("Deploy to ${environment}") {
                            if (environment == 'production') {
                                timeout(time: 24, unit: 'HOURS') {
                                    input message: "Deploy to ${environment}?", 
                                          submitterParameter: 'APPROVER'
                                }
                                echo "Approved by: ${env.APPROVER}"
                            }
                            
                            deployToEnvironment(environment)
                            
                            if (environment != 'production') {
                                runSmokeTests(environment)
                            }
                        }
                    }
                }
            }
        }
        
        stage('Production Health Check') {
            steps {
                runProductionHealthCheck()
            }
        }
    }
    
    post {
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: ":white_check_mark: ${SERVICE_NAME} v${BUILD_NUMBER} deployed successfully to production"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: ":x: ${SERVICE_NAME} v${BUILD_NUMBER} deployment failed"
            )
        }
    }
}

def buildAndTest() {
    sh '''
        # Determine service type and run appropriate tests
        if [ -f "requirements.txt" ]; then
            python -m pytest tests/ --junitxml=test-results.xml --cov=src --cov-report=xml
        elif [ -f "package.json" ]; then
            npm ci
            npm run test -- --coverage --watchAll=false --testResultsProcessor=jest-junit
        fi
    '''
}

def deployToEnvironment(environment) {
    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
        sh """
            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
            gcloud container clusters get-credentials ${CLUSTER_NAME}-${environment} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
            
            helm upgrade --install ${SERVICE_NAME} ./helm-chart \\
                --set image.tag=${BUILD_NUMBER} \\
                --set environment=${environment} \\
                --namespace ${environment} \\
                --values values-${environment}.yaml \\
                --wait --timeout=300s
        """
    }
}

def runSmokeTests(environment) {
    sh """
        export API_URL=https://${environment}-${SERVICE_NAME}.example.com
        python scripts/smoke_tests.py --environment=${environment}
    """
}

def runProductionHealthCheck() {
    sh '''
        # Wait for deployment to stabilize
        sleep 60
        
        # Check health endpoints
        curl -f https://api.example.com/health
        
        # Check metrics
        python scripts/check_production_metrics.py --duration=300
    '''
}
```

## 7. Database Migration Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        DB_MIGRATION_IMAGE = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/db-migrator:${BUILD_NUMBER}"
    }
    
    stages {
        stage('Build Migration Image') {
            steps {
                script {
                    def migrationImage = docker.build("${DB_MIGRATION_IMAGE}", "-f Dockerfile.migrations .")
                    docker.withRegistry("https://${REGISTRY_HOSTNAME}", 'gcr:gcp-service-account') {
                        migrationImage.push()
                    }
                }
            }
        }
        
        stage('Run Migrations') {
            parallel {
                stage('Staging Migration') {
                    steps {
                        runMigration('staging')
                    }
                }
                stage('Production Migration') {
                    when {
                        branch 'main'
                    }
                    steps {
                        input message: 'Run production migration?'
                        runMigration('production')
                    }
                }
            }
        }
        
        stage('Verify Migrations') {
            steps {
                verifyMigrations()
            }
        }
    }
}

def runMigration(environment) {
    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
        sh """
            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
            gcloud container clusters get-credentials ${CLUSTER_NAME}-${environment} --zone ${CLUSTER_ZONE} --project ${PROJECT_ID}
            
            kubectl run db-migration-${BUILD_NUMBER} \\
                --image=${DB_MIGRATION_IMAGE} \\
                --restart=Never \\
                --env="DATABASE_URL=\$(kubectl get secret db-credentials -o jsonpath='{.data.url}' | base64 -d)" \\
                --namespace=${environment}
                
            kubectl wait --for=condition=complete job/db-migration-${BUILD_NUMBER} --timeout=300s -n ${environment}
            kubectl logs job/db-migration-${BUILD_NUMBER} -n ${environment}
            kubectl delete job db-migration-${BUILD_NUMBER} -n ${environment}
        """
    }
}

def verifyMigrations() {
    sh '''
        # Run migration verification tests
        python scripts/verify_migrations.py --environment=staging
    '''
}
```

## 8. Performance Testing Pipeline

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'LOAD_TEST_USERS', defaultValue: '100', description: 'Number of concurrent users')
        string(name: 'LOAD_TEST_DURATION', defaultValue: '300', description: 'Test duration in seconds')
    }
    
    stages {
        stage('Deploy to Performance Environment') {
            steps {
                deployToEnvironment('performance')
            }
        }
        
        stage('Load Testing') {
            parallel {
                stage('API Load Test') {
                    steps {
                        sh """
                            docker run --rm -v \$(pwd)/load-tests:/tests \\
                                loadimpact/k6 run \\
                                --vus ${params.LOAD_TEST_USERS} \\
                                --duration ${params.LOAD_TEST_DURATION}s \\
                                --out json=results.json \\
                                /tests/api-load-test.js
                        """
                    }
                }
                stage('Database Load Test') {
                    steps {
                        sh '''
                            python scripts/db_load_test.py \\
                                --connections=50 \\
                                --duration=300 \\
                                --output=db-results.json
                        '''
                    }
                }
            }
        }
        
        stage('Performance Analysis') {
            steps {
                sh '''
                    python scripts/analyze_performance.py \\
                        --api-results=results.json \\
                        --db-results=db-results.json \\
                        --threshold-p95=500 \\
                        --threshold-error-rate=1
                '''
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'performance-reports',
                        reportFiles: 'index.html',
                        reportName: 'Performance Report'
                    ])
                }
            }
        }
    }
}
```

## 9. Shared Library Functions

Create these in `vars/` directory of your Jenkins shared library:

### buildMicroservice.groovy
```groovy
def call(Map config) {
    pipeline {
        agent any
        
        environment {
            SERVICE_NAME = config.serviceName
            SERVICE_TYPE = config.serviceType // 'python' or 'nodejs'
            IMAGE_TAG = "${BUILD_NUMBER}"
            GCR_IMAGE = "${REGISTRY_HOSTNAME}/${PROJECT_ID}/${SERVICE_NAME}:${IMAGE_TAG}"
        }
        
        stages {
            stage('Test') {
                steps {
                    script {
                        if (env.SERVICE_TYPE == 'python') {
                            sh '''
                                python -m pytest tests/ --junitxml=test-results.xml
                            '''
                        } else if (env.SERVICE_TYPE == 'nodejs') {
                            sh '''
                                npm ci
                                npm test
                            '''
                        }
                    }
                }
            }
            
            stage('Build & Deploy') {
                steps {
                    buildAndPushImage()
                    deployToGKE(config.environments ?: ['staging'])
                }
            }
        }
    }
}
```

### deployToGKE.groovy
```groovy
def call(String environment, Map options = [:]) {
    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
        sh """
            gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
            gcloud container clusters get-credentials ${env.CLUSTER_NAME}-${environment} --zone ${env.CLUSTER_ZONE} --project ${env.PROJECT_ID}
            
            helm upgrade --install ${env.SERVICE_NAME} ./helm-chart \\
                --set image.repository=${env.REGISTRY_HOSTNAME}/${env.PROJECT_ID}/${env.SERVICE_NAME} \\
                --set image.tag=${env.IMAGE_TAG} \\
                --set environment=${environment} \\
                --namespace ${environment} \\
                --create-namespace \\
                ${options.helmArgs ?: ''}
                
            kubectl rollout status deployment/${env.SERVICE_NAME} -n ${environment}
        """
    }
}
```

## Usage Examples

### Using Shared Library
```groovy
@Library('your-jenkins-shared-library') _

buildMicroservice([
    serviceName: 'user-api',
    serviceType: 'python',
    environments: ['staging', 'production']
])
```

### Multi-Branch Pipeline
```groovy
pipeline {
    agent any
    
    stages {
        stage('Branch Strategy') {
            steps {
                script {
                    switch(env.BRANCH_NAME) {
                        case 'main':
                            deployToEnvironments(['staging', 'production'])
                            break
                        case 'develop':
                            deployToEnvironments(['dev'])
                            break
                        case ~/^feature\/.*/:
                            deployToEnvironments(['feature'])
                            break
                        default:
                            echo "No deployment for branch: ${env.BRANCH_NAME}"
                    }
                }
            }
        }
    }
}
```

This comprehensive guide covers intermediate to advanced Jenkins declarative pipeline patterns for your Python/Node.js microservices on GCP with GKE and GCR integration.
