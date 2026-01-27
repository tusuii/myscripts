# Jenkins Pipeline Git Tagging & Rollback Guide

> **A comprehensive guide for implementing Git tagging in Jenkins pipelines to enable easy rollbacks**

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Understanding Git Tags](#2-understanding-git-tags)
3. [Tagging Strategies](#3-tagging-strategies)
4. [Prerequisites](#4-prerequisites)
5. [Basic Tagging Pipeline](#5-basic-tagging-pipeline)
6. [Advanced Tagging Pipeline](#6-advanced-tagging-pipeline)
7. [Rollback Procedures](#7-rollback-procedures)
8. [Complete Pipeline Examples](#8-complete-pipeline-examples)
9. [Alternative Approaches](#9-alternative-approaches)
10. [Best Practices](#10-best-practices)
11. [Troubleshooting](#11-troubleshooting)
12. [FAQ](#12-faq)

---

## 1. Introduction

### 1.1 What is Git Tagging?

Git tags are references that point to specific commits in your Git history. They're like bookmarks for important points in your project's timeline.

**Use Cases:**
- Mark release versions (v1.0.0, v1.0.1)
- Create deployment markers (prod-2024-01-27)
- Enable easy rollbacks
- Track what's deployed in each environment

### 1.2 Why Use Tags in CI/CD?

**Benefits:**
- ✅ Easy identification of deployed versions
- ✅ Simple rollback mechanism
- ✅ Clear deployment history
- ✅ Audit trail for compliance
- ✅ Semantic versioning support

**Without Tags:**
```
Commit: abc123 - What version is this? When was it deployed?
```

**With Tags:**
```
Tag: v1.2.3 (prod-2024-01-27) - Clear version and deployment date!
```

### 1.3 What You'll Learn

By the end of this guide, you'll be able to:
- Create automatic Git tags in Jenkins
- Use semantic versioning
- Deploy specific tagged versions
- Rollback to previous tags
- Implement multiple tagging strategies

---

## 2. Understanding Git Tags

### 2.1 Types of Git Tags

#### Lightweight Tags
Simple pointers to commits.

```bash
# Create lightweight tag
git tag v1.0.0

# List tags
git tag -l
```

#### Annotated Tags (Recommended)
Include metadata: tagger name, email, date, and message.

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# View tag details
git show v1.0.0
```

**💡 Best Practice:** Always use annotated tags in CI/CD for better tracking.

### 2.2 Tag Naming Conventions

#### Semantic Versioning (Recommended)
```
v<MAJOR>.<MINOR>.<PATCH>

Examples:
v1.0.0 - Initial release
v1.0.1 - Bug fix (patch)
v1.1.0 - New feature (minor)
v2.0.0 - Breaking change (major)
```

#### Build-Based Versioning
```
v<BUILD_NUMBER>

Examples:
v123
v124
```

#### Date-Based Versioning
```
v<YYYY.MM.DD>.<BUILD>

Examples:
v2024.01.27.1
v2024.01.27.2
```

#### Environment-Based Tagging
```
<ENV>-v<VERSION>

Examples:
dev-v1.0.0
staging-v1.0.0
prod-v1.0.0
```

### 2.3 Tag Operations

```bash
# Create tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tag to remote
git push origin v1.0.0

# Push all tags
git push origin --tags

# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin :refs/tags/v1.0.0

# List all tags
git tag -l

# List tags matching pattern
git tag -l "v1.*"

# Checkout specific tag
git checkout v1.0.0
```

---

## 3. Tagging Strategies

### 3.1 Strategy 1: Semantic Versioning (Recommended)

**When to Use:**
- Production applications
- Libraries/packages
- API versioning

**Format:** `v<MAJOR>.<MINOR>.<PATCH>`

**Example:**
```groovy
// Auto-increment patch version
def getNextVersion() {
    def lastTag = sh(
        script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
        returnStdout: true
    ).trim()

    def (major, minor, patch) = lastTag.replaceAll('v', '').tokenize('.')
    def newPatch = (patch as Integer) + 1

    return "v${major}.${minor}.${newPatch}"
}
```

### 3.2 Strategy 2: Build Number Tagging

**When to Use:**
- Internal projects
- Continuous deployment
- Simple versioning needs

**Format:** `v<BUILD_NUMBER>` or `build-<BUILD_NUMBER>`

**Example:**
```groovy
def version = "v${env.BUILD_NUMBER}"
// Results in: v123, v124, v125, etc.
```

### 3.3 Strategy 3: Commit SHA Tagging

**When to Use:**
- Development environments
- Feature branches
- Testing deployments

**Format:** `<ENV>-<SHORT_SHA>` or `<BRANCH>-<SHORT_SHA>`

**Example:**
```groovy
def shortSha = sh(
    script: "git rev-parse --short HEAD",
    returnStdout: true
).trim()

def version = "dev-${shortSha}"
// Results in: dev-abc1234
```

### 3.4 Strategy 4: Date-Based Tagging

**When to Use:**
- Daily releases
- Time-based deployments
- Audit requirements

**Format:** `v<YYYY.MM.DD>.<BUILD>` or `release-<YYYY-MM-DD>`

**Example:**
```groovy
def dateVersion = new Date().format('yyyy.MM.dd')
def version = "v${dateVersion}.${env.BUILD_NUMBER}"
// Results in: v2024.01.27.5
```

### 3.5 Strategy 5: Hybrid Tagging

**When to Use:**
- Multiple environments
- Complex deployment workflows
- Need both version and metadata

**Format:** `<ENV>-v<VERSION>-<DATE>-<SHA>`

**Example:**
```groovy
def shortSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
def date = new Date().format('yyyyMMdd')
def version = "${env.DEPLOY_ENV}-v1.2.3-${date}-${shortSha}"
// Results in: prod-v1.2.3-20240127-abc1234
```

### 3.6 Comparison Table

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| **Semantic Versioning** | Industry standard, meaningful versions | Requires discipline, manual version bumps | Production apps, libraries |
| **Build Number** | Simple, automatic | No semantic meaning | Internal tools, CI |
| **Commit SHA** | Unique, traceable | Hard to read | Development, testing |
| **Date-Based** | Time-based tracking | Multiple builds per day need suffixes | Daily releases |
| **Hybrid** | Most information | Long tag names | Complex workflows |

---

## 4. Prerequisites

### 4.1 Jenkins Configuration

**Required Plugins:**
```
✅ Git Plugin
✅ Pipeline Plugin
✅ Credentials Binding Plugin
✅ GitLab Plugin (if using GitLab)
```

**Install Plugins:**
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for plugins above
3. Install and restart Jenkins

### 4.2 Git Credentials Setup

**Create Git Credentials in Jenkins:**

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Select domain: **(global)**
3. Click **Add Credentials**
4. Configure:
   - **Kind**: Username with password (or SSH Key)
   - **Username**: Your Git username
   - **Password**: Personal Access Token or password
   - **ID**: `git-credentials`
   - **Description**: Git Push Credentials
5. Click **Create**

**For GitLab Personal Access Token:**
1. Go to GitLab → **User Settings** → **Access Tokens**
2. Create token with scopes:
   - ✅ `api`
   - ✅ `write_repository`
3. Copy token and use as password in Jenkins credentials

### 4.3 Jenkins Pipeline Job Configuration

**Configure Git in Pipeline:**

1. Create or edit Pipeline job
2. In **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your Git repo URL
   - **Credentials**: Select `git-credentials`
   - **Branches to build**: `*/main` or `*/master`
3. Check **Lightweight checkout** (optional, for faster checkouts)
4. Save

### 4.4 Git Configuration in Jenkins

**Set Git User Info (Required for Tagging):**

Add to your Jenkinsfile:

```groovy
environment {
    GIT_AUTHOR_NAME = 'Jenkins CI'
    GIT_AUTHOR_EMAIL = 'jenkins@example.com'
    GIT_COMMITTER_NAME = 'Jenkins CI'
    GIT_COMMITTER_EMAIL = 'jenkins@example.com'
}
```

---

## 5. Basic Tagging Pipeline

### 5.1 Simple Tag Creation

**Jenkinsfile - Basic Tagging:**

```groovy
pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'git-credentials'  // ID from Jenkins credentials
        GIT_AUTHOR_NAME = 'Jenkins CI'
        GIT_AUTHOR_EMAIL = 'jenkins@example.com'
        GIT_COMMITTER_NAME = 'Jenkins CI'
        GIT_COMMITTER_EMAIL = 'jenkins@example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Building application...'
                // Your build commands here
                sh 'npm install'  // Example
                sh 'npm run build'  // Example
            }
        }

        stage('Create Tag') {
            steps {
                script {
                    // Create tag name using build number
                    def tagName = "v${env.BUILD_NUMBER}"

                    echo "Creating tag: ${tagName}"

                    // Create annotated tag
                    sh """
                        git tag -a ${tagName} -m "Jenkins build ${env.BUILD_NUMBER}"
                    """

                    // Push tag to remote
                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@gitlab.com/YOUR_USERNAME/YOUR_REPO.git ${tagName}
                        """
                    }

                    echo "Tag ${tagName} created and pushed successfully"
                }
            }
        }

        stage('Deploy') {
            steps {
                echo "Deploying version v${env.BUILD_NUMBER}..."
                // Your deployment commands here
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! Tagged as v${env.BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
```

**📝 Important Notes:**

1. **Replace** `YOUR_USERNAME/YOUR_REPO` with your actual GitLab repository path
2. **Update** build and deploy commands for your application
3. **Adjust** credentials ID if you used a different name

### 5.2 Run the Basic Pipeline

**Steps:**

1. **Commit the Jenkinsfile** to your repository
2. **Trigger the pipeline** in Jenkins
3. **View the console output** to see tag creation
4. **Verify in GitLab**:
   - Go to Repository → Tags
   - You should see the new tag (e.g., `v123`)

**Expected Console Output:**
```
Creating tag: v123
[main abc1234] Jenkins build 123
Tag v123 created and pushed successfully
```

### 5.3 Verification Commands

**Check Tags Locally:**
```bash
# List all tags
git tag -l

# Show tag details
git show v123
```

**Check Tags in GitLab:**
```bash
# List remote tags
git ls-remote --tags origin

# Or visit GitLab UI:
# Repository → Tags
```

---

## 6. Advanced Tagging Pipeline

### 6.1 Semantic Versioning with Auto-Increment

**Jenkinsfile - Semantic Versioning:**

```groovy
pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'git-credentials'
        GIT_AUTHOR_NAME = 'Jenkins CI'
        GIT_AUTHOR_EMAIL = 'jenkins@example.com'
        GIT_COMMITTER_NAME = 'Jenkins CI'
        GIT_COMMITTER_EMAIL = 'jenkins@example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Determine Version') {
            steps {
                script {
                    // Get the latest tag
                    def latestTag = sh(
                        script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
                        returnStdout: true
                    ).trim()

                    echo "Latest tag: ${latestTag}"

                    // Parse version
                    def versionMatch = latestTag =~ /v?(\d+)\.(\d+)\.(\d+)/
                    def major = versionMatch[0][1] as Integer
                    def minor = versionMatch[0][2] as Integer
                    def patch = versionMatch[0][3] as Integer

                    // Check commit messages for version bump type
                    def commitMessage = sh(
                        script: "git log -1 --pretty=%B",
                        returnStdout: true
                    ).trim().toLowerCase()

                    // Determine version bump
                    if (commitMessage.contains('[major]') || commitMessage.contains('breaking change')) {
                        major += 1
                        minor = 0
                        patch = 0
                    } else if (commitMessage.contains('[minor]') || commitMessage.contains('feature')) {
                        minor += 1
                        patch = 0
                    } else {
                        // Default: patch bump
                        patch += 1
                    }

                    // Create new version
                    env.NEW_VERSION = "v${major}.${minor}.${patch}"

                    echo "New version: ${env.NEW_VERSION}"
                }
            }
        }

        stage('Build') {
            steps {
                echo "Building version ${env.NEW_VERSION}..."
                // Your build commands
                sh 'npm install'
                sh 'npm run build'
            }
        }

        stage('Test') {
            steps {
                echo "Testing version ${env.NEW_VERSION}..."
                // Your test commands
                sh 'npm test'
            }
        }

        stage('Create and Push Tag') {
            when {
                branch 'main'  // Only tag on main branch
            }
            steps {
                script {
                    echo "Creating tag: ${env.NEW_VERSION}"

                    // Create annotated tag with detailed message
                    def tagMessage = """
Jenkins Build ${env.BUILD_NUMBER}
Version: ${env.NEW_VERSION}
Commit: ${env.GIT_COMMIT}
Date: ${new Date().format('yyyy-MM-dd HH:mm:ss')}
Build URL: ${env.BUILD_URL}
                    """.trim()

                    sh """
                        git tag -a ${env.NEW_VERSION} -m "${tagMessage}"
                    """

                    // Push tag
                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        // Extract repo URL without credentials
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${env.NEW_VERSION}
                        """
                    }

                    echo "✅ Tag ${env.NEW_VERSION} created and pushed successfully"
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo "Deploying version ${env.NEW_VERSION}..."
                // Your deployment commands
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline successful! Version ${env.NEW_VERSION} deployed."
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
```

**How to Use:**

Commit messages control version bumping:

```bash
# Patch bump (v1.0.0 → v1.0.1)
git commit -m "Fix bug in user service"

# Minor bump (v1.0.0 → v1.1.0)
git commit -m "[minor] Add new feature for product listing"

# Major bump (v1.0.0 → v2.0.0)
git commit -m "[major] Breaking change: new API structure"
```

### 6.2 Multi-Environment Tagging

**Jenkinsfile - Environment-Specific Tags:**

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['dev', 'staging', 'prod'],
            description: 'Environment to deploy to'
        )
        string(
            name: 'VERSION',
            defaultValue: '',
            description: 'Version to deploy (leave empty for latest)'
        )
    }

    environment {
        GIT_CREDENTIALS = 'git-credentials'
        GIT_AUTHOR_NAME = 'Jenkins CI'
        GIT_AUTHOR_EMAIL = 'jenkins@example.com'
        GIT_COMMITTER_NAME = 'Jenkins CI'
        GIT_COMMITTER_EMAIL = 'jenkins@example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Determine Version') {
            steps {
                script {
                    if (params.VERSION == '') {
                        // Auto-generate version
                        def shortSha = sh(
                            script: "git rev-parse --short HEAD",
                            returnStdout: true
                        ).trim()

                        def timestamp = new Date().format('yyyyMMdd-HHmmss')
                        env.DEPLOY_VERSION = "${params.DEPLOY_ENV}-${timestamp}-${shortSha}"
                    } else {
                        // Use provided version
                        env.DEPLOY_VERSION = "${params.DEPLOY_ENV}-${params.VERSION}"
                    }

                    echo "Deploy version: ${env.DEPLOY_VERSION}"
                }
            }
        }

        stage('Build') {
            steps {
                echo "Building for ${params.DEPLOY_ENV}..."
                sh """
                    docker build -t myapp:${env.DEPLOY_VERSION} .
                """
            }
        }

        stage('Tag and Push') {
            steps {
                script {
                    // Create environment-specific tag
                    def tagMessage = "Deployment to ${params.DEPLOY_ENV} - Build ${env.BUILD_NUMBER}"

                    sh """
                        git tag -a ${env.DEPLOY_VERSION} -m "${tagMessage}"
                    """

                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${env.DEPLOY_VERSION}
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                echo "Deploying ${env.DEPLOY_VERSION} to ${params.DEPLOY_ENV}..."

                script {
                    // Environment-specific deployment
                    if (params.DEPLOY_ENV == 'prod') {
                        // Production deployment
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${env.DEPLOY_VERSION} -n production
                        """
                    } else if (params.DEPLOY_ENV == 'staging') {
                        // Staging deployment
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${env.DEPLOY_VERSION} -n staging
                        """
                    } else {
                        // Dev deployment
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${env.DEPLOY_VERSION} -n dev
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployed ${env.DEPLOY_VERSION} to ${params.DEPLOY_ENV}"
        }
    }
}
```

**How to Use:**

1. **Build with parameters** in Jenkins
2. **Select environment**: dev, staging, or prod
3. **Optionally specify version** or leave empty for auto-generation
4. Tags will be created like:
   - `dev-20240127-123456-abc1234`
   - `staging-v1.2.3`
   - `prod-v1.2.3`

### 6.3 Tag with Metadata

**Jenkinsfile - Rich Tag Metadata:**

```groovy
pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'git-credentials'
        GIT_AUTHOR_NAME = 'Jenkins CI'
        GIT_AUTHOR_EMAIL = 'jenkins@example.com'
        GIT_COMMITTER_NAME = 'Jenkins CI'
        GIT_COMMITTER_EMAIL = 'jenkins@example.com'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Determine Version') {
            steps {
                script {
                    // Get latest tag
                    def latestTag = sh(
                        script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
                        returnStdout: true
                    ).trim()

                    // Increment patch version
                    def versionMatch = latestTag =~ /v?(\d+)\.(\d+)\.(\d+)/
                    def major = versionMatch[0][1] as Integer
                    def minor = versionMatch[0][2] as Integer
                    def patch = (versionMatch[0][3] as Integer) + 1

                    env.VERSION = "v${major}.${minor}.${patch}"
                }
            }
        }

        stage('Build & Test') {
            steps {
                sh 'npm install && npm test'
            }
        }

        stage('Create Detailed Tag') {
            steps {
                script {
                    // Gather metadata
                    def commitSha = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    def shortSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def commitAuthor = sh(script: "git log -1 --pretty=%an", returnStdout: true).trim()
                    def commitDate = sh(script: "git log -1 --pretty=%ai", returnStdout: true).trim()
                    def branch = env.GIT_BRANCH ?: 'unknown'

                    // Create detailed tag message
                    def tagMessage = """
Release ${env.VERSION}

Build Information:
- Build Number: ${env.BUILD_NUMBER}
- Build URL: ${env.BUILD_URL}
- Jenkins Job: ${env.JOB_NAME}
- Build Date: ${new Date().format('yyyy-MM-dd HH:mm:ss')}

Git Information:
- Commit: ${commitSha}
- Short SHA: ${shortSha}
- Branch: ${branch}
- Author: ${commitAuthor}
- Commit Date: ${commitDate}

Deployment:
- Environment: Production
- Deployed By: Jenkins CI
                    """.trim()

                    // Create annotated tag
                    sh """
                        git tag -a ${env.VERSION} -m "${tagMessage}"
                    """

                    // Push tag
                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${env.VERSION}
                        """
                    }

                    echo "✅ Created and pushed tag ${env.VERSION} with detailed metadata"
                }
            }
        }

        stage('Deploy') {
            steps {
                echo "Deploying ${env.VERSION}..."
            }
        }
    }
}
```

**View Tag Metadata:**

```bash
# View full tag information
git show v1.2.3

# Output:
# tag v1.2.3
# Tagger: Jenkins CI <jenkins@example.com>
# Date:   Sat Jan 27 10:30:00 2024
#
# Release v1.2.3
#
# Build Information:
# - Build Number: 45
# - Build URL: http://jenkins.example.com/job/myapp/45
# ...
```

---

## 7. Rollback Procedures

### 7.1 Manual Rollback Using GitLab UI

**Steps:**

1. **Go to GitLab** → Your Project → **Repository** → **Tags**
2. **Find the tag** you want to rollback to (e.g., `v1.2.2`)
3. **Click** the tag name
4. **Click** "Create release" or note the commit SHA
5. **Create a new branch** from this tag:
   - Repository → Branches → New Branch
   - Branch name: `rollback-to-v1.2.2`
   - Create from: Tag `v1.2.2`
6. **Create merge request** to merge rollback branch to main
7. **Or redeploy** directly from the tag

### 7.2 Jenkins Rollback Pipeline

**Jenkinsfile - Rollback Pipeline:**

```groovy
pipeline {
    agent any

    parameters {
        string(
            name: 'ROLLBACK_TAG',
            description: 'Tag to rollback to (e.g., v1.2.2)',
            defaultValue: ''
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Environment to rollback'
        )
        booleanParam(
            name: 'CONFIRM_ROLLBACK',
            defaultValue: false,
            description: 'Check to confirm rollback (safety measure)'
        )
    }

    environment {
        GIT_CREDENTIALS = 'git-credentials'
    }

    stages {
        stage('Validate') {
            steps {
                script {
                    // Safety checks
                    if (!params.CONFIRM_ROLLBACK) {
                        error("❌ Rollback not confirmed. Check 'CONFIRM_ROLLBACK' to proceed.")
                    }

                    if (params.ROLLBACK_TAG == '') {
                        error("❌ ROLLBACK_TAG parameter is required!")
                    }

                    echo "⚠️  ROLLBACK INITIATED"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Target Tag: ${params.ROLLBACK_TAG}"
                    echo "Build URL: ${env.BUILD_URL}"
                }
            }
        }

        stage('Verify Tag Exists') {
            steps {
                script {
                    // Check if tag exists
                    def tagExists = sh(
                        script: "git tag -l ${params.ROLLBACK_TAG}",
                        returnStdout: true
                    ).trim()

                    if (tagExists == '') {
                        // Try fetching tags from remote
                        sh "git fetch --tags"

                        tagExists = sh(
                            script: "git tag -l ${params.ROLLBACK_TAG}",
                            returnStdout: true
                        ).trim()

                        if (tagExists == '') {
                            error("❌ Tag ${params.ROLLBACK_TAG} does not exist!")
                        }
                    }

                    echo "✅ Tag ${params.ROLLBACK_TAG} verified"

                    // Show tag details
                    sh "git show ${params.ROLLBACK_TAG} --quiet"
                }
            }
        }

        stage('Checkout Tag') {
            steps {
                script {
                    echo "Checking out tag ${params.ROLLBACK_TAG}..."

                    sh """
                        git fetch --tags
                        git checkout tags/${params.ROLLBACK_TAG}
                    """

                    // Verify checkout
                    def currentCommit = sh(
                        script: "git rev-parse HEAD",
                        returnStdout: true
                    ).trim()

                    echo "✅ Checked out commit: ${currentCommit}"
                }
            }
        }

        stage('Build') {
            steps {
                echo "Building from tag ${params.ROLLBACK_TAG}..."
                sh """
                    npm install
                    npm run build
                """
            }
        }

        stage('Deploy Rollback') {
            steps {
                script {
                    echo "🔄 Deploying rollback to ${params.ENVIRONMENT}..."

                    // Create rollback tag
                    def rollbackTagName = "${params.ENVIRONMENT}-rollback-${params.ROLLBACK_TAG}-${new Date().format('yyyyMMdd-HHmmss')}"

                    sh """
                        git tag -a ${rollbackTagName} -m "Rollback to ${params.ROLLBACK_TAG} in ${params.ENVIRONMENT}"
                    """

                    // Deploy based on environment
                    if (params.ENVIRONMENT == 'prod') {
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${params.ROLLBACK_TAG} -n production
                            kubectl rollout status deployment/myapp -n production
                        """
                    } else if (params.ENVIRONMENT == 'staging') {
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${params.ROLLBACK_TAG} -n staging
                            kubectl rollout status deployment/myapp -n staging
                        """
                    } else {
                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${params.ROLLBACK_TAG} -n dev
                            kubectl rollout status deployment/myapp -n dev
                        """
                    }

                    echo "✅ Rollback deployment successful"
                }
            }
        }

        stage('Create Rollback Record') {
            steps {
                script {
                    // Push rollback tag
                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        def rollbackTagName = "${params.ENVIRONMENT}-rollback-${params.ROLLBACK_TAG}-${new Date().format('yyyyMMdd-HHmmss')}"

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${rollbackTagName}
                        """
                    }

                    echo "✅ Rollback record created in Git"
                }
            }
        }
    }

    post {
        success {
            echo """
✅ ROLLBACK SUCCESSFUL
Environment: ${params.ENVIRONMENT}
Rolled back to: ${params.ROLLBACK_TAG}
Build: ${env.BUILD_NUMBER}
            """
        }
        failure {
            echo """
❌ ROLLBACK FAILED
Environment: ${params.ENVIRONMENT}
Target Tag: ${params.ROLLBACK_TAG}
Check logs: ${env.BUILD_URL}console
            """
        }
    }
}
```

**How to Use Rollback Pipeline:**

1. **Create separate Jenkins job** for rollbacks
2. **Build with Parameters**
3. **Enter tag** to rollback to (e.g., `v1.2.2`)
4. **Select environment**
5. **Check "CONFIRM_ROLLBACK"** checkbox
6. **Click Build**

### 7.3 Quick Rollback Commands

**Rollback Using Git CLI:**

```bash
# List available tags
git tag -l | sort -V | tail -10

# Show tag details
git show v1.2.2

# Checkout tag
git checkout tags/v1.2.2

# Create rollback branch
git checkout -b rollback-to-v1.2.2 tags/v1.2.2

# Push rollback branch
git push origin rollback-to-v1.2.2
```

**Rollback Deployment Only (Keep Code):**

```bash
# Rollback Kubernetes deployment to previous version
kubectl rollout undo deployment/myapp -n production

# Rollback to specific revision
kubectl rollout undo deployment/myapp -n production --to-revision=5

# View rollout history
kubectl rollout history deployment/myapp -n production
```

### 7.4 Emergency Rollback Procedure

**For Critical Production Issues:**

1. **Identify last known good tag:**
   ```bash
   git tag -l "prod-*" | sort -V | tail -5
   ```

2. **Verify tag works:**
   ```bash
   git show prod-v1.2.2
   ```

3. **Immediate deployment rollback:**
   ```bash
   # Kubernetes
   kubectl set image deployment/myapp myapp=myapp:prod-v1.2.2 -n production

   # OR use kubectl rollout undo
   kubectl rollout undo deployment/myapp -n production
   ```

4. **Create incident tag:**
   ```bash
   git tag -a incident-rollback-$(date +%Y%m%d-%H%M%S) -m "Emergency rollback from vX.X.X to v1.2.2"
   git push origin --tags
   ```

5. **Notify team:**
   - Post in Slack/Teams
   - Update status page
   - Document in incident log

---

## 8. Complete Pipeline Examples

### 8.1 Full Production Pipeline with Tagging

```groovy
// Complete production-ready pipeline with semantic versioning

pipeline {
    agent any

    parameters {
        choice(
            name: 'VERSION_BUMP',
            choices: ['patch', 'minor', 'major'],
            description: 'Version bump type'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip tests (not recommended for production)'
        )
        booleanParam(
            name: 'DEPLOY_TO_PROD',
            defaultValue: false,
            description: 'Deploy to production after successful build'
        )
    }

    environment {
        GIT_CREDENTIALS = 'git-credentials'
        GIT_AUTHOR_NAME = 'Jenkins CI'
        GIT_AUTHOR_EMAIL = 'jenkins@example.com'
        GIT_COMMITTER_NAME = 'Jenkins CI'
        GIT_COMMITTER_EMAIL = 'jenkins@example.com'

        DOCKER_REGISTRY = 'us-central1-docker.pkg.dev'
        GCP_PROJECT = 'your-project-id'
        DOCKER_REPO = 'microservices-repo'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                script {
                    // Get current commit info
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT_MSG = sh(
                        script: "git log -1 --pretty=%B",
                        returnStdout: true
                    ).trim()

                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('Determine Version') {
            steps {
                script {
                    // Fetch all tags
                    sh "git fetch --tags"

                    // Get latest tag
                    def latestTag = sh(
                        script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
                        returnStdout: true
                    ).trim()

                    echo "Latest tag: ${latestTag}"

                    // Parse version
                    def versionMatch = latestTag =~ /v?(\d+)\.(\d+)\.(\d+)/
                    def major = versionMatch[0][1] as Integer
                    def minor = versionMatch[0][2] as Integer
                    def patch = versionMatch[0][3] as Integer

                    // Increment based on parameter
                    switch(params.VERSION_BUMP) {
                        case 'major':
                            major += 1
                            minor = 0
                            patch = 0
                            break
                        case 'minor':
                            minor += 1
                            patch = 0
                            break
                        case 'patch':
                        default:
                            patch += 1
                            break
                    }

                    // Set new version
                    env.VERSION = "v${major}.${minor}.${patch}"
                    env.VERSION_NUMBER = "${major}.${minor}.${patch}"

                    echo "New version: ${env.VERSION}"
                }
            }
        }

        stage('Build') {
            steps {
                echo "Building version ${env.VERSION}..."

                script {
                    // Build Docker images for all services
                    sh """
                        # Frontend service
                        docker build -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:${env.VERSION} \
                            -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:latest \
                            ./frontend-service

                        # User service
                        docker build -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:${env.VERSION} \
                            -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:latest \
                            ./user-service

                        # Product service
                        docker build -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:${env.VERSION} \
                            -t ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:latest \
                            ./product-service
                    """
                }
            }
        }

        stage('Test') {
            when {
                expression { return !params.SKIP_TESTS }
            }
            steps {
                echo "Running tests for version ${env.VERSION}..."

                sh """
                    # Run tests for each service
                    cd frontend-service && npm install && npm test
                    cd ../user-service && npm install && npm test
                    cd ../product-service && npm install && npm test
                """
            }
        }

        stage('Security Scan') {
            steps {
                echo "Scanning images for vulnerabilities..."

                script {
                    // Example using Trivy
                    sh """
                        trivy image ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:${env.VERSION} || true
                        trivy image ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:${env.VERSION} || true
                        trivy image ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:${env.VERSION} || true
                    """
                }
            }
        }

        stage('Push Images') {
            steps {
                echo "Pushing images to registry..."

                script {
                    // Authenticate to Docker registry
                    sh """
                        gcloud auth configure-docker ${DOCKER_REGISTRY}

                        # Push all images
                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:${env.VERSION}
                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:latest

                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:${env.VERSION}
                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:latest

                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:${env.VERSION}
                        docker push ${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:latest
                    """
                }
            }
        }

        stage('Create Git Tag') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Creating Git tag ${env.VERSION}..."

                    // Create comprehensive tag message
                    def tagMessage = """
Release ${env.VERSION}

Version Bump: ${params.VERSION_BUMP}
Build Number: ${env.BUILD_NUMBER}
Commit: ${env.GIT_COMMIT_SHORT}
Branch: ${env.GIT_BRANCH}
Build URL: ${env.BUILD_URL}
Build Date: ${new Date().format('yyyy-MM-dd HH:mm:ss')}

Images:
- frontend-service:${env.VERSION}
- user-service:${env.VERSION}
- product-service:${env.VERSION}

Changes:
${env.GIT_COMMIT_MSG}
                    """.trim()

                    // Create tag
                    sh """
                        git tag -a ${env.VERSION} -m "${tagMessage}"
                    """

                    // Push tag
                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${env.VERSION}
                        """
                    }

                    echo "✅ Tag ${env.VERSION} created and pushed"
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                echo "Deploying ${env.VERSION} to staging..."

                sh """
                    kubectl set image deployment/frontend-service frontend=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:${env.VERSION} -n staging
                    kubectl set image deployment/user-service user-service=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:${env.VERSION} -n staging
                    kubectl set image deployment/product-service product-service=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:${env.VERSION} -n staging

                    # Wait for rollout
                    kubectl rollout status deployment/frontend-service -n staging
                    kubectl rollout status deployment/user-service -n staging
                    kubectl rollout status deployment/product-service -n staging
                """
            }
        }

        stage('Integration Tests') {
            steps {
                echo "Running integration tests in staging..."

                sh """
                    # Run integration tests
                    ./run-integration-tests.sh staging
                """
            }
        }

        stage('Deploy to Production') {
            when {
                expression { return params.DEPLOY_TO_PROD }
                branch 'main'
            }
            steps {
                input message: "Deploy ${env.VERSION} to production?", ok: 'Deploy'

                echo "Deploying ${env.VERSION} to production..."

                script {
                    sh """
                        kubectl set image deployment/frontend-service frontend=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/frontend-service:${env.VERSION} -n production
                        kubectl set image deployment/user-service user-service=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/user-service:${env.VERSION} -n production
                        kubectl set image deployment/product-service product-service=${DOCKER_REGISTRY}/${GCP_PROJECT}/${DOCKER_REPO}/product-service:${env.VERSION} -n production

                        # Wait for rollout
                        kubectl rollout status deployment/frontend-service -n production
                        kubectl rollout status deployment/user-service -n production
                        kubectl rollout status deployment/product-service -n production
                    """

                    // Create production deployment tag
                    def prodTag = "prod-${env.VERSION}-${new Date().format('yyyyMMdd-HHmmss')}"

                    sh """
                        git tag -a ${prodTag} -m "Production deployment of ${env.VERSION}"
                    """

                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        def repoUrl = sh(
                            script: "git config --get remote.origin.url | sed 's|https://||' | sed 's|.*@||'",
                            returnStdout: true
                        ).trim()

                        sh """
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${repoUrl} ${prodTag}
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo """
✅ PIPELINE SUCCESSFUL
Version: ${env.VERSION}
Build: ${env.BUILD_NUMBER}
Commit: ${env.GIT_COMMIT_SHORT}
            """

            // Send notification (Slack, email, etc.)
        }
        failure {
            echo """
❌ PIPELINE FAILED
Version: ${env.VERSION}
Build: ${env.BUILD_NUMBER}
Logs: ${env.BUILD_URL}console
            """

            // Send failure notification
        }
        always {
            // Cleanup
            sh 'docker system prune -f'
        }
    }
}
```

### 8.2 Simplified Pipeline for Small Projects

```groovy
// Simple tagging pipeline for small projects

pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'git-credentials'
    }

    stages {
        stage('Build and Tag') {
            steps {
                script {
                    // Simple version based on build number
                    def version = "v${env.BUILD_NUMBER}"

                    echo "Building version ${version}..."

                    // Build
                    sh 'npm install && npm run build'

                    // Create and push tag
                    sh """
                        git config user.name "Jenkins"
                        git config user.email "jenkins@example.com"
                        git tag -a ${version} -m "Release ${version}"
                    """

                    withCredentials([usernamePassword(
                        credentialsId: env.GIT_CREDENTIALS,
                        passwordVariable: 'GIT_PASS',
                        usernameVariable: 'GIT_USER'
                    )]) {
                        sh """
                            git push https://${GIT_USER}:${GIT_PASS}@gitlab.com/YOUR_REPO.git ${version}
                        """
                    }

                    echo "✅ Tagged as ${version}"
                }
            }
        }
    }
}
```

---

## 9. Alternative Approaches

### 9.1 Using Jenkins Plugins

#### Git Parameter Plugin

**Install Plugin:**
- Manage Jenkins → Manage Plugins
- Search: "Git Parameter Plugin"
- Install and restart

**Configure:**

```groovy
pipeline {
    agent any

    parameters {
        gitParameter(
            name: 'TAG',
            type: 'PT_TAG',
            description: 'Select tag to deploy',
            defaultValue: 'main',
            sortMode: 'DESCENDING_SMART'
        )
    }

    stages {
        stage('Deploy Tag') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "refs/tags/${params.TAG}"]],
                    userRemoteConfigs: [[url: 'https://gitlab.com/YOUR_REPO.git']]
                ])

                echo "Deploying tag: ${params.TAG}"
                // Your deployment commands
            }
        }
    }
}
```

**Benefits:**
- ✅ UI dropdown for tag selection
- ✅ Easy rollback to any tag
- ✅ No manual tag typing

### 9.2 Using GitLab API for Tagging

**Alternative to Git Push:**

```groovy
stage('Create Tag via GitLab API') {
    steps {
        script {
            withCredentials([string(credentialsId: 'gitlab-token', variable: 'GITLAB_TOKEN')]) {
                sh """
                    curl --request POST \
                         --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
                         --data "tag_name=${env.VERSION}" \
                         --data "ref=main" \
                         --data "message=Release ${env.VERSION}" \
                         "https://gitlab.com/api/v4/projects/YOUR_PROJECT_ID/repository/tags"
                """
            }
        }
    }
}
```

**Benefits:**
- ✅ No Git credentials in Jenkins
- ✅ Use GitLab Personal Access Token
- ✅ Easier to manage

### 9.3 Using GitLab CI Instead of Jenkins

**`.gitlab-ci.yml` with Tagging:**

```yaml
stages:
  - build
  - tag
  - deploy

variables:
  GIT_STRATEGY: clone
  GIT_DEPTH: 0  # Full clone for tag access

build:
  stage: build
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

create_tag:
  stage: tag
  only:
    - main
  script:
    # Get latest tag
    - LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    - echo "Latest tag: $LATEST_TAG"

    # Increment patch version
    - MAJOR=$(echo $LATEST_TAG | cut -d. -f1 | sed 's/v//')
    - MINOR=$(echo $LATEST_TAG | cut -d. -f2)
    - PATCH=$(echo $LATEST_TAG | cut -d. -f3)
    - NEW_PATCH=$((PATCH + 1))
    - NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"

    - echo "New version: $NEW_VERSION"

    # Configure git
    - git config user.name "GitLab CI"
    - git config user.email "gitlab-ci@example.com"

    # Create and push tag
    - git tag -a $NEW_VERSION -m "Release $NEW_VERSION"
    - git push https://oauth2:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git $NEW_VERSION

deploy:
  stage: deploy
  only:
    - main
  script:
    - echo "Deploying..."
    - kubectl set image deployment/myapp myapp=myapp:${CI_COMMIT_TAG} -n production
```

**Benefits:**
- ✅ Native GitLab integration
- ✅ No external Jenkins required
- ✅ Simpler credential management

### 9.4 Using Release Management Tools

#### GitHub Releases / GitLab Releases

**Create Release in Pipeline:**

```groovy
stage('Create GitLab Release') {
    steps {
        script {
            withCredentials([string(credentialsId: 'gitlab-token', variable: 'GITLAB_TOKEN')]) {
                sh """
                    curl --request POST \
                         --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
                         --data "name=Release ${env.VERSION}" \
                         --data "tag_name=${env.VERSION}" \
                         --data "description=Automated release ${env.VERSION}" \
                         "https://gitlab.com/api/v4/projects/YOUR_PROJECT_ID/releases"
                """
            }
        }
    }
}
```

### 9.5 Comparison of Approaches

| Approach | Complexity | Flexibility | Best For |
|----------|------------|-------------|----------|
| **Git Commands in Jenkins** | Medium | High | Full control, custom workflows |
| **GitLab API** | Low | Medium | Simple tagging, less Git overhead |
| **Git Parameter Plugin** | Low | Medium | Easy rollbacks, UI selection |
| **GitLab CI** | Low | High | GitLab-centric workflows |
| **Release Tools** | Medium | High | Public projects, changelog management |

---

## 10. Best Practices

### 10.1 Tagging Best Practices

**DO:**
- ✅ Use semantic versioning for production
- ✅ Create annotated tags (not lightweight)
- ✅ Include metadata in tag messages
- ✅ Tag after successful tests
- ✅ Tag only on main/master branch
- ✅ Use consistent naming conventions
- ✅ Document tagging strategy in README

**DON'T:**
- ❌ Tag before tests pass
- ❌ Create tags manually (use automation)
- ❌ Reuse tag names
- ❌ Delete tags unless absolutely necessary
- ❌ Tag every commit
- ❌ Use special characters in tags

### 10.2 Rollback Best Practices

**DO:**
- ✅ Test rollback procedure regularly
- ✅ Keep deployment history
- ✅ Require confirmation for production rollbacks
- ✅ Create rollback tags for audit trail
- ✅ Notify team before/after rollback
- ✅ Document rollback reasons

**DON'T:**
- ❌ Rollback without investigation
- ❌ Skip rollback testing
- ❌ Rollback without team notification
- ❌ Delete rollback tags
- ❌ Panic - follow procedure

### 10.3 Security Best Practices

**Credentials:**
- ✅ Use Jenkins credentials store
- ✅ Use Personal Access Tokens (not passwords)
- ✅ Rotate tokens regularly
- ✅ Use minimal required scopes
- ✅ Audit credential usage

**Git Security:**
- ✅ Sign tags with GPG (optional but recommended)
- ✅ Protect main branch
- ✅ Require code reviews
- ✅ Use branch protection rules

### 10.4 Pipeline Performance

**Optimization:**
- ✅ Cache dependencies (npm, Maven, etc.)
- ✅ Use parallel stages where possible
- ✅ Minimize Git operations
- ✅ Use lightweight checkout when full history not needed
- ✅ Clean up old builds/artifacts

**Example Caching:**

```groovy
stage('Build with Cache') {
    steps {
        script {
            // Use Docker layer caching
            sh """
                docker build \
                    --cache-from ${IMAGE_NAME}:latest \
                    -t ${IMAGE_NAME}:${VERSION} \
                    .
            """
        }
    }
}
```

### 10.5 Versioning Strategy Recommendations

**For Libraries/Packages:**
- Use semantic versioning (v1.2.3)
- Document breaking changes
- Follow semver strictly

**For Applications:**
- Use semantic versioning OR date-based
- Tag releases, not every commit
- Include environment in tag for multi-env

**For Microservices:**
- Independent versioning per service
- OR monorepo with global versioning
- Tag pattern: `<service>-v1.2.3`

### 10.6 Documentation

**Maintain:**
- `CHANGELOG.md` - What changed in each version
- `VERSION` file - Current version number
- Tag descriptions - Why this tag was created
- Deployment log - What's deployed where

**Example CHANGELOG.md:**

```markdown
# Changelog

## [v1.2.3] - 2024-01-27

### Added
- New user profile feature
- Export functionality

### Fixed
- Bug in product search
- Memory leak in user service

### Changed
- Updated dependencies
- Improved error handling

## [v1.2.2] - 2024-01-20
...
```

---

## 11. Troubleshooting

### 11.1 Common Issues and Solutions

#### Issue: "Permission denied" when pushing tags

**Cause:** Git credentials don't have write access

**Solution:**

```groovy
// Verify credentials have write access
// In GitLab: Personal Access Token needs "write_repository" scope

// Check credential ID matches
withCredentials([usernamePassword(
    credentialsId: 'git-credentials',  // Verify this ID exists
    usernameVariable: 'GIT_USER',
    passwordVariable: 'GIT_PASS'
)]) {
    sh "git push https://${GIT_USER}:${GIT_PASS}@gitlab.com/repo.git ${TAG_NAME}"
}
```

#### Issue: "Tag already exists"

**Cause:** Trying to create a tag that exists

**Solution:**

```groovy
// Check if tag exists before creating
def tagExists = sh(
    script: "git tag -l ${TAG_NAME}",
    returnStdout: true
).trim()

if (tagExists != '') {
    error("Tag ${TAG_NAME} already exists! Choose a different version.")
}

// Or auto-increment if tag exists
while (tagExists != '') {
    patch += 1
    TAG_NAME = "v${major}.${minor}.${patch}"
    tagExists = sh(script: "git tag -l ${TAG_NAME}", returnStdout: true).trim()
}
```

#### Issue: "fatal: no tag found"

**Cause:** Repository has no tags yet

**Solution:**

```groovy
// Handle first tag gracefully
def latestTag = sh(
    script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
    returnStdout: true
).trim()

// This returns 'v0.0.0' if no tags exist
```

#### Issue: Tags not showing in GitLab

**Cause:** Tags pushed to wrong remote or not pushed at all

**Solution:**

```bash
# Verify remote URL
git remote -v

# Push specific tag
git push origin v1.2.3

# Push all tags
git push origin --tags

# Force push tag (if updated)
git push origin v1.2.3 --force
```

#### Issue: "fatal: refusing to merge unrelated histories"

**Cause:** Lightweight checkout or shallow clone

**Solution:**

```groovy
// Use full checkout for tagging
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    extensions: [
        [$class: 'CloneOption', depth: 0, noTags: false, shallow: false]
    ],
    userRemoteConfigs: [[url: 'https://gitlab.com/repo.git']]
])
```

#### Issue: Credentials in URL visible in logs

**Cause:** Git commands print URL with credentials

**Solution:**

```groovy
// Sanitize output
sh '''
    set +x  # Disable command echoing
    git push https://${GIT_USER}:${GIT_PASS}@gitlab.com/repo.git v1.2.3
    set -x  # Re-enable
'''

// Or use credential helper
sh '''
    git config credential.helper store
    echo "https://${GIT_USER}:${GIT_PASS}@gitlab.com" > ~/.git-credentials
    git push origin v1.2.3
    rm ~/.git-credentials
'''
```

### 11.2 Debugging Commands

```groovy
// List all tags
sh 'git tag -l'

// Show tag details
sh 'git show v1.2.3'

// List tags with commit SHAs
sh 'git show-ref --tags'

// Check remote tags
sh 'git ls-remote --tags origin'

// Verify Git user config
sh 'git config user.name'
sh 'git config user.email'

// Check current branch
sh 'git branch'

// Show commit history
sh 'git log --oneline -10'
```

### 11.3 Rollback Issues

#### Issue: Can't checkout tag - "detached HEAD state"

**This is normal!** Tags point to specific commits.

**Solution:**

```groovy
// Create branch from tag for deployment
sh """
    git checkout tags/${ROLLBACK_TAG}
    git checkout -b rollback-branch-${BUILD_NUMBER}
"""

// Or deploy directly from detached HEAD (fine for deployment)
sh "git checkout tags/${ROLLBACK_TAG}"
```

#### Issue: Rollback deployed wrong version

**Solution:**

```groovy
// Always verify tag before deployment
sh """
    echo "Tag details:"
    git show ${ROLLBACK_TAG} --quiet

    echo "Tag commit SHA:"
    git rev-parse ${ROLLBACK_TAG}

    # Confirm with user input in manual pipeline
"""
```

---

## 12. FAQ

### 12.1 General Questions

**Q: Should I tag every commit?**

A: No. Tag only releases/deployments. For development tracking, commit SHAs are sufficient.

**Q: When should I create a tag?**

A: After successful:
- Build and tests
- Deployment to staging
- Approval for production
- Actual production deployment

**Q: Can I change a tag after creating it?**

A: No (best practice). Tags should be immutable. If you need to change, create a new tag (v1.2.4) instead of modifying v1.2.3.

**Q: Should I delete old tags?**

A: Generally no. Keep tags for history and rollback capability. Only delete if absolutely necessary (e.g., accidentally tagged sensitive data).

**Q: How many tags is too many?**

A: No real limit, but keep them meaningful. If tagging every build, consider using build numbers in CI instead of Git tags.

### 12.2 Versioning Questions

**Q: How do I handle breaking changes?**

A: Increment major version:
- v1.9.9 → v2.0.0 (breaking change)
- Document in CHANGELOG.md
- Add `[major]` or `BREAKING CHANGE:` in commit message

**Q: Should microservices share version numbers?**

A: Two approaches:
1. **Independent**: Each service has own version (frontend-v1.2.0, backend-v2.1.5)
2. **Shared**: All services use same version (v1.2.0)

Choose based on:
- Independent: Services evolve separately
- Shared: Coordinated releases

**Q: How to version pre-releases?**

A: Use pre-release identifiers:
- `v1.2.3-alpha.1`
- `v1.2.3-beta.2`
- `v1.2.3-rc.1`

### 12.3 Jenkins-Specific Questions

**Q: How to trigger pipeline only for tagged commits?**

A:
```groovy
when {
    tag "v*"  // Only run on tags matching v*
}
```

**Q: How to get tag name in pipeline?**

A:
```groovy
// If pipeline triggered by tag
env.TAG_NAME

// Or check if current commit has tag
def tag = sh(
    script: "git describe --exact-match --tags HEAD 2>/dev/null || echo ''",
    returnStdout: true
).trim()
```

**Q: How to build specific tag manually?**

A: Use Git Parameter Plugin (Section 9.1) or create parameterized pipeline:

```groovy
parameters {
    string(name: 'TAG_TO_BUILD', defaultValue: 'latest', description: 'Tag to build')
}
```

### 12.4 GitLab-Specific Questions

**Q: How to protect tags in GitLab?**

A: GitLab → Settings → Repository → Protected Tags
- Add pattern: `v*`
- Allowed to create: Maintainers
- Allowed to push: No one

**Q: How to create GitLab Release from Jenkins?**

A: Use GitLab API (Section 9.2):

```groovy
sh """
    curl --request POST \
         --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
         --data "name=Release ${VERSION}" \
         --data "tag_name=${VERSION}" \
         "https://gitlab.com/api/v4/projects/${PROJECT_ID}/releases"
"""
```

**Q: How to trigger Jenkins from GitLab tag creation?**

A: Configure GitLab webhook:
1. GitLab → Settings → Webhooks
2. URL: `http://jenkins-url/generic-webhook-trigger/invoke`
3. Trigger: Tag push events
4. In Jenkinsfile, use Generic Webhook Trigger plugin

---

## Conclusion

You now have a comprehensive understanding of:

✅ Git tagging strategies
✅ Implementing tagging in Jenkins pipelines
✅ Semantic versioning
✅ Rollback procedures
✅ Alternative approaches
✅ Best practices

### Quick Start Checklist

- [ ] Set up Git credentials in Jenkins
- [ ] Configure Git user in pipeline
- [ ] Choose versioning strategy
- [ ] Implement basic tagging pipeline
- [ ] Test tag creation
- [ ] Create rollback pipeline
- [ ] Test rollback procedure
- [ ] Document your strategy

### Next Steps

1. **Start simple**: Begin with build number tagging
2. **Evolve**: Move to semantic versioning as team grows
3. **Automate**: Make tagging fully automatic
4. **Test**: Regularly test rollback procedures
5. **Document**: Keep CHANGELOG.md updated

### Resources

- [Semantic Versioning](https://semver.org/)
- [Git Tagging Documentation](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)

---

**Happy Tagging! 🏷️**

*Last Updated: January 2026*
*Version: 1.0.0*
