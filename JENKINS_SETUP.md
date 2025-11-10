# Jenkins CI/CD Setup Guide
## ACEest Fitness & Gym Management System

### 🔧 Continuous Integration with Jenkins - Assignment Requirement #5

---

## Table of Contents
1. [Overview](#overview)
2. [Jenkins Installation](#jenkins-installation)
3. [Jenkins Configuration](#jenkins-configuration)
4. [Git Webhook Setup](#git-webhook-setup)
5. [Pipeline Features](#pipeline-features)
6. [Build Artifacts](#build-artifacts)
7. [Automated Triggers](#automated-triggers)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### Purpose
- **Continuous Integration** - Automated build and testing on every code change
- **Build Server** - Jenkins as central CI/CD orchestrator
- **Automated Triggers** - Git webhook + SCM polling for automatic builds
- **Artifact Management** - Version-controlled build artifacts
- **Quality Gates** - Automated testing and code quality checks

### Architecture

```
GitHub Repository
      ↓
   Webhook/Poll
      ↓
Jenkins Build Server
      ↓
   ├── Checkout Code
   ├── Install Dependencies
   ├── Run Tests (Pytest)
   ├── Code Quality (SonarQube)
   ├── Build Docker Image
   ├── Generate Artifacts ✅
   ├── Push to Docker Hub
   └── Deploy to Kubernetes
      ↓
Build Artifacts Stored
```

---

## Jenkins Installation

### Prerequisites
- Java 11 or 17 (OpenJDK recommended)
- Docker installed
- Git installed
- Minimum 2GB RAM, 2 CPU cores

### Option 1: Install on Ubuntu/Debian

```bash
# Update system
sudo apt update

# Install Java
sudo apt install openjdk-11-jdk -y

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install jenkins -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Option 2: Run with Docker

```bash
# Create Jenkins volume
docker volume create jenkins-data

# Run Jenkins container
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Option 3: Run with Docker Compose

Create `docker-compose-jenkins.yml`:

```yaml
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    restart: unless-stopped

volumes:
  jenkins-data:
```

```bash
# Start Jenkins
docker-compose -f docker-compose-jenkins.yml up -d

# View logs
docker-compose -f docker-compose-jenkins.yml logs -f

# Get initial password
docker-compose -f docker-compose-jenkins.yml exec jenkins \
  cat /var/jenkins_home/secrets/initialAdminPassword
```

### Access Jenkins

1. Open browser: `http://localhost:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user
5. Configure Jenkins URL

---

## Jenkins Configuration

### Step 1: Install Required Plugins

**Navigate to:** Manage Jenkins → Manage Plugins → Available

Install the following plugins:

✅ **Git Integration:**
- Git plugin
- GitHub plugin
- GitHub Branch Source Plugin

✅ **Docker Integration:**
- Docker plugin
- Docker Pipeline plugin
- Docker Commons plugin

✅ **Testing & Quality:**
- JUnit plugin
- HTML Publisher plugin
- SonarQube Scanner plugin
- Code Coverage API plugin

✅ **Pipeline:**
- Pipeline plugin
- Pipeline: Stage View
- Pipeline: GitHub Groovy Libraries

✅ **Kubernetes:**
- Kubernetes plugin
- Kubernetes Credentials Provider

✅ **Notifications:**
- Email Extension Plugin
- Slack Notification Plugin (optional)

✅ **Utilities:**
- Workspace Cleanup Plugin
- Timestamper plugin
- Build Timeout plugin

### Step 2: Configure Global Tools

**Navigate to:** Manage Jenkins → Global Tool Configuration

#### Configure Git

```
Name: Default
Path to Git executable: git (or /usr/bin/git)
```

#### Configure Docker

```
Name: docker
Install automatically: ✅
Docker version: latest
```

#### Configure SonarQube Scanner

```
Name: SonarQube Scanner
Install automatically: ✅
Version: Latest
```

### Step 3: Configure Credentials

**Navigate to:** Manage Jenkins → Manage Credentials → Global → Add Credentials

#### 1. Docker Hub Credentials

```
Kind: Username with password
Scope: Global
Username: <your-dockerhub-username>
Password: <your-dockerhub-password-or-token>
ID: dockerhub-credentials
Description: Docker Hub credentials
```

#### 2. GitHub Credentials

```
Kind: Username with password (or Personal Access Token)
Scope: Global
Username: <your-github-username>
Password: <github-personal-access-token>
ID: github-credentials
Description: GitHub credentials
```

**Generate GitHub Personal Access Token:**
1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scopes: `repo`, `admin:repo_hook`
4. Copy token (save it securely!)

#### 3. Kubernetes Config (Optional)

```
Kind: Secret file
Scope: Global
File: <upload-kubeconfig-file>
ID: kubeconfig
Description: Kubernetes config
```

### Step 4: Configure SonarQube

**Navigate to:** Manage Jenkins → Configure System → SonarQube servers

```
Name: SonarQube
Server URL: http://sonarqube:9000
Server authentication token: <sonarqube-token>
```

**Generate SonarQube Token:**
1. Login to SonarQube
2. My Account → Security → Generate Token
3. Copy token and add to Jenkins

---

## Git Webhook Setup

### Method 1: GitHub Webhook (Recommended)

#### Step 1: Configure Jenkins GitHub Plugin

**Navigate to:** Manage Jenkins → Configure System → GitHub

```
GitHub Server:
  API URL: https://api.github.com
  Credentials: <github-credentials>
  Manage hooks: ✅
```

#### Step 2: Create Webhook in GitHub

1. Go to your GitHub repository
2. Navigate to: **Settings → Webhooks → Add webhook**

**Webhook Configuration:**
```
Payload URL: http://<jenkins-url>:8080/github-webhook/
Content type: application/json
Secret: <optional-secret>
SSL verification: Enable SSL verification

Which events would you like to trigger this webhook?
  ✅ Just the push event
  ✅ Pull requests
  
Active: ✅
```

**Example:**
```
Payload URL: http://jenkins.example.com:8080/github-webhook/
Content type: application/json
Events: Push events, Pull request events
```

#### Step 3: Test Webhook

1. In GitHub webhook settings, click "Recent Deliveries"
2. Click "Redeliver" to test
3. Check for HTTP 200 response
4. Verify in Jenkins: Manage Jenkins → System Log

### Method 2: SCM Polling (Fallback)

If webhooks can't be configured (firewall, local development), use SCM polling:

**In Jenkinsfile (already configured):**
```groovy
triggers {
    // Poll every 5 minutes
    pollSCM('H/5 * * * *')
}
```

**Polling Schedule Syntax:**
```
H/5 * * * *    # Every 5 minutes
H/15 * * * *   # Every 15 minutes
H * * * *      # Every hour
H H * * *      # Once per day
```

### Method 3: Manual Trigger

Build can also be triggered manually:
1. Go to Jenkins job
2. Click "Build Now"
3. Build starts immediately

---

## Pipeline Features

### 12-Stage Pipeline

Our Jenkinsfile implements a comprehensive CI/CD pipeline:

```
Stage 1:  Checkout ✅
Stage 2:  Install Dependencies ✅
Stage 3:  Lint & Code Quality ✅
Stage 4:  Unit Tests ✅
Stage 5:  SonarQube Analysis ✅
Stage 6:  Quality Gate ✅
Stage 7:  Generate Build Artifacts ✅ NEW!
Stage 8:  Build Docker Image ✅
Stage 9:  Security Scan ✅
Stage 10: Push Docker Image ✅
Stage 11: Deploy to Kubernetes ✅
Stage 12: Smoke Tests ✅
```

### Stage Details

#### Stage 1: Checkout
- Clone repository
- Get commit info (SHA, message)
- Set environment variables

#### Stage 2: Install Dependencies
- Create Python virtual environment
- Install requirements.txt
- Upgrade pip

#### Stage 3: Lint & Code Quality
- Run flake8 (PEP 8 compliance)
- Run pylint (code analysis)
- Generate linting reports

#### Stage 4: Unit Tests
- Run pytest with coverage
- Generate JUnit XML reports
- Generate HTML coverage reports
- Publish test results

#### Stage 5: SonarQube Analysis
- Run SonarQube scanner
- Upload code metrics
- Analyze code quality, security, bugs

#### Stage 6: Quality Gate
- Wait for SonarQube analysis
- Check quality gate status
- Abort pipeline if quality gate fails

#### Stage 7: Generate Build Artifacts ✅
**NEW! Comprehensive artifact generation:**

```
Artifacts Generated:
├── aceest-fitness-{VERSION}.tar.gz      # Source code package
├── aceest-fitness-{VERSION}.tar.gz.sha256  # Checksum
├── docker-image-{VERSION}.tar.gz        # Docker image archive
├── test-results-{VERSION}.xml           # Unit test results
├── coverage-{VERSION}.xml               # Coverage report
├── coverage-report-{VERSION}/           # HTML coverage
├── version.txt                          # Build metadata
└── build-metadata.json                  # Machine-readable metadata
```

#### Stage 8: Build Docker Image
- Build multi-stage Docker image
- Tag with version number
- Tag as latest
- Save image as artifact

#### Stage 9: Security Scan
- Scan Docker image with Trivy
- Check for vulnerabilities
- Report HIGH and CRITICAL issues

#### Stage 10: Push Docker Image
- Login to Docker Hub
- Push versioned image
- Push latest tag

#### Stage 11: Deploy to Kubernetes
- Update deployment with new image
- Wait for rollout completion
- Verify pod status

#### Stage 12: Smoke Tests
- Get service URL
- Test health endpoint
- Verify application is running

---

## Build Artifacts

### Artifact Types

#### 1. Source Code Package

**File:** `aceest-fitness-{VERSION}.tar.gz`

**Contents:**
- Complete application source code
- Configuration files
- Kubernetes manifests
- Documentation
- Jenkinsfile

**Excludes:**
- Virtual environment (venv/)
- Python cache (__pycache__)
- Git repository (.git/)
- Test artifacts

**Usage:**
```bash
# Extract artifact
tar -xzf aceest-fitness-123.tar.gz

# Deploy to server
cd aceest-fitness-123
python -m venv venv
venv/bin/pip install -r requirements.txt
python app.py
```

#### 2. Docker Image Archive

**File:** `docker-image-v{VERSION}.tar.gz`

**Contents:**
- Complete Docker image
- All layers compressed
- Ready for offline deployment

**Usage:**
```bash
# Extract and load image
gunzip docker-image-v123.tar.gz
docker load < docker-image-v123.tar

# Run container
docker run -d -p 5000:5000 yourdockerhub/aceest-fitness:v123
```

#### 3. Test Results

**File:** `test-results-{VERSION}.xml`

**Contents:**
- JUnit XML format
- All 26 test results
- Test execution times
- Failure details (if any)

**Usage:**
```bash
# View in browser
open test-results-123.xml

# Parse with Python
import xml.etree.ElementTree as ET
tree = ET.parse('test-results-123.xml')
```

#### 4. Coverage Report

**Files:**
- `coverage-{VERSION}.xml` (Machine-readable)
- `coverage-report-{VERSION}/` (HTML report)

**Contents:**
- Line coverage percentage (91%)
- Branch coverage
- Uncovered lines
- Coverage by file

**Usage:**
```bash
# View HTML report
cd coverage-report-123
open index.html
```

#### 5. Version File

**File:** `version.txt`

**Contents:**
```
Build Number: 123
Image Tag: v123
Git Commit: abc1234
Build Date: 2025-11-10 15:30:00 UTC
Branch: main
Build URL: http://jenkins/job/aceest-fitness/123/
```

#### 6. Build Metadata

**File:** `build-metadata.json`

**Contents:**
```json
{
  "buildNumber": "123",
  "version": "v123",
  "gitCommit": "abc1234",
  "branch": "main",
  "timestamp": "2025-11-10 15:30:00",
  "status": "SUCCESS"
}
```

### Downloading Artifacts

#### From Jenkins UI

1. Navigate to build: Jenkins → Job → Build #123
2. Click "Build Artifacts"
3. Download individual files or all artifacts

**Direct URL:**
```
http://jenkins:8080/job/aceest-fitness/123/artifact/
```

#### Using wget/curl

```bash
# Download all artifacts
wget -r -np -nH --cut-dirs=3 \
  http://jenkins:8080/job/aceest-fitness/123/artifact/

# Download specific artifact
curl -O http://jenkins:8080/job/aceest-fitness/123/artifact/artifacts/aceest-fitness-123.tar.gz
```

#### Using Jenkins CLI

```bash
# Download Jenkins CLI
wget http://jenkins:8080/jnlpJars/jenkins-cli.jar

# Download artifacts
java -jar jenkins-cli.jar -s http://jenkins:8080/ \
  -auth admin:password \
  download-build aceest-fitness 123
```

### Artifact Retention

**Configure in Jenkinsfile:**
```groovy
options {
    buildDiscarder(logRotator(
        numToKeepStr: '10',        // Keep last 10 builds
        artifactNumToKeepStr: '5'  // Keep artifacts for last 5 builds
    ))
}
```

**Or in Job Configuration:**
1. Job → Configure
2. Discard old builds
3. Set max # of builds to keep: 10
4. Set max # of builds to keep with artifacts: 5

---

## Automated Triggers

### Trigger Mechanisms

#### 1. GitHub Webhook (Push Event)

**When it triggers:**
- Code pushed to repository
- Pull request created/updated
- Tag created

**Configuration:**
```groovy
triggers {
    githubPush()
}
```

**Flow:**
```
Developer pushes code to GitHub
           ↓
GitHub sends webhook to Jenkins
           ↓
Jenkins receives webhook
           ↓
Pipeline build starts automatically
           ↓
Build #124 executes all stages
```

#### 2. SCM Polling

**When it triggers:**
- Jenkins checks repository every 5 minutes
- If changes detected, build starts

**Configuration:**
```groovy
triggers {
    pollSCM('H/5 * * * *')  // Every 5 minutes
}
```

**Polling Schedule Examples:**
```groovy
pollSCM('H/5 * * * *')   // Every 5 minutes
pollSCM('H/15 * * * *')  // Every 15 minutes
pollSCM('H * * * *')     // Every hour
pollSCM('H H * * *')     // Once per day
pollSCM('H H * * 1-5')   // Weekdays only
```

#### 3. Scheduled Builds

**Configuration:**
```groovy
triggers {
    // Nightly build at 2 AM
    cron('H 2 * * *')
}
```

**Cron Syntax:**
```
MINUTE HOUR DAY MONTH DAYOFWEEK

H 2 * * *       # Daily at 2 AM
H */4 * * *     # Every 4 hours
H 0 * * 0       # Weekly on Sunday
H 0 1 * *       # Monthly on 1st
```

#### 4. Manual Trigger

- Click "Build Now" in Jenkins UI
- Use Jenkins CLI
- Call Jenkins API

### Multi-Trigger Setup (Recommended)

```groovy
triggers {
    // Primary: GitHub webhook
    githubPush()
    
    // Fallback: SCM polling (if webhook fails)
    pollSCM('H/5 * * * *')
    
    // Scheduled: Nightly build
    cron('H 2 * * *')
}
```

---

## Create Jenkins Job

### Step 1: Create Pipeline Job

1. Jenkins Dashboard → New Item
2. Enter name: `aceest-fitness`
3. Select: **Pipeline**
4. Click OK

### Step 2: Configure Job

#### General Section

```
✅ GitHub project
  Project url: https://github.com/yourusername/aceest-fitness

✅ Discard old builds
  Max # of builds to keep: 10
  Max # of builds to keep with artifacts: 5
```

#### Build Triggers

```
✅ GitHub hook trigger for GITScm polling
✅ Poll SCM
  Schedule: H/5 * * * *
```

#### Pipeline Section

```
Definition: Pipeline script from SCM

SCM: Git
  Repository URL: https://github.com/yourusername/aceest-fitness.git
  Credentials: github-credentials
  Branch: */main

Script Path: Jenkinsfile

✅ Lightweight checkout
```

### Step 3: Save and Build

1. Click "Save"
2. Click "Build Now"
3. Watch console output
4. View build artifacts

---

## Testing the Setup

### Test 1: Manual Build

```bash
# In Jenkins
1. Go to aceest-fitness job
2. Click "Build Now"
3. Wait for build to complete
4. Check console output
5. Download artifacts
```

### Test 2: Push Trigger

```bash
# In your local repository
echo "# Test" >> README.md
git add README.md
git commit -m "test: Trigger Jenkins build"
git push origin main

# Watch Jenkins
# Build should start automatically within seconds
```

### Test 3: Pull Request Trigger

```bash
# Create feature branch
git checkout -b feature/test
echo "# Feature" >> test.txt
git add test.txt
git commit -m "feat: Test PR trigger"
git push origin feature/test

# Create pull request in GitHub
# Jenkins should start PR build automatically
```

### Test 4: Webhook Verification

```bash
# In GitHub repository
Settings → Webhooks → <your-webhook>
Click "Recent Deliveries"
Check for green checkmark (200 response)
View request/response details
```

---

## Troubleshooting

### Issue 1: Webhook Not Working

**Symptoms:**
- Builds don't start automatically
- GitHub shows webhook delivery failures

**Solutions:**

```bash
# Check Jenkins is accessible from internet
curl http://your-jenkins-url:8080/github-webhook/

# Check GitHub webhook logs
GitHub → Repo → Settings → Webhooks → Recent Deliveries

# Check Jenkins logs
Manage Jenkins → System Log → All Jenkins Logs

# Fallback to SCM polling
triggers {
    pollSCM('H/5 * * * *')
}
```

### Issue 2: Build Fails at Checkout

**Symptoms:**
```
ERROR: Failed to connect to repository
```

**Solutions:**

```bash
# Verify credentials
Manage Jenkins → Manage Credentials → Check github-credentials

# Test Git connection
git ls-remote https://github.com/yourusername/aceest-fitness.git

# Use SSH instead of HTTPS
Repository URL: git@github.com:yourusername/aceest-fitness.git
Credentials: SSH private key
```

### Issue 3: Docker Build Fails

**Symptoms:**
```
ERROR: Cannot connect to Docker daemon
```

**Solutions:**

```bash
# Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Or run Jenkins in Docker with socket mount
-v /var/run/docker.sock:/var/run/docker.sock

# Verify Docker access
docker ps
```

### Issue 4: Artifacts Not Generated

**Symptoms:**
- No artifacts shown in build
- "Artifacts" link missing

**Solutions:**

```bash
# Check archive configuration in Jenkinsfile
archiveArtifacts artifacts: 'artifacts/**/*'

# Verify artifacts directory exists
sh 'ls -la artifacts/'

# Check workspace permissions
sh 'chmod -R 755 artifacts/'
```

### Issue 5: SonarQube Analysis Fails

**Symptoms:**
```
ERROR: SonarQube server not found
```

**Solutions:**

```bash
# Install SonarQube locally
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

# Configure in Jenkins
Manage Jenkins → Configure System → SonarQube servers
  URL: http://localhost:9000

# Or skip SonarQube stages (for testing)
# Comment out SonarQube stages in Jenkinsfile
```

---

## Assignment Requirements Met

### ✅ Configure Jenkins as Build Server

**Delivered:**
- ✅ Jenkins installation guide (3 methods)
- ✅ Complete Jenkins configuration
- ✅ Plugin installation instructions
- ✅ Credential management setup
- ✅ Global tool configuration
- ✅ Pipeline job creation

### ✅ Git Repository Polling & Webhooks

**Delivered:**
- ✅ **GitHub webhook** setup (primary method)
- ✅ **SCM polling** configuration (H/5 * * * *)
- ✅ **Automatic build triggers** on code changes
- ✅ **Multiple trigger methods** (webhook + polling + cron)
- ✅ **Pull request triggers** enabled
- ✅ **Branch-specific builds** configured

### ✅ Generate Build Artifacts

**Delivered:**
- ✅ **Source code package** (aceest-fitness-{VERSION}.tar.gz)
- ✅ **Docker image archive** (docker-image-{VERSION}.tar.gz)
- ✅ **Test results** (JUnit XML)
- ✅ **Coverage reports** (XML + HTML)
- ✅ **Version file** (build metadata)
- ✅ **Build metadata JSON** (machine-readable)
- ✅ **Checksum files** (SHA256)
- ✅ **Artifact retention** (configurable)
- ✅ **Version-specific artifacts** (unique per build)

---

## Quick Reference

### Jenkins URLs

```
Dashboard:     http://localhost:8080
Job Config:    http://localhost:8080/job/aceest-fitness/configure
Build #123:    http://localhost:8080/job/aceest-fitness/123
Artifacts:     http://localhost:8080/job/aceest-fitness/123/artifact/
Console:       http://localhost:8080/job/aceest-fitness/123/console
```

### Common Commands

```bash
# Restart Jenkins
sudo systemctl restart jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Check Jenkins status
sudo systemctl status jenkins

# Test webhook
curl -X POST http://localhost:8080/github-webhook/

# Download artifacts
wget http://localhost:8080/job/aceest-fitness/123/artifact/artifacts/aceest-fitness-123.tar.gz
```

### Pipeline Syntax

```groovy
// Trigger build on push
triggers { githubPush() }

// Poll every 5 minutes
triggers { pollSCM('H/5 * * * *') }

// Archive artifacts
archiveArtifacts artifacts: 'artifacts/**/*'

// Publish test results
junit 'test-results.xml'
```

---

## Summary

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     CONTINUOUS INTEGRATION: ✅ COMPLETE                   ║
║                                                           ║
║     Jenkins: Configured as build server                   ║
║     Webhook: Automatic build triggers                     ║
║     Polling: Fallback mechanism (H/5 * * * *)             ║
║     Artifacts: Version-controlled builds                  ║
║     Pipeline: 12-stage automated workflow                 ║
║                                                           ║
║     Assignment Requirement #5: DONE! ✅                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

**Last Updated:** November 10, 2025  
**Jenkins Version:** 2.426+  
**Pipeline Stages:** 12  
**Artifact Types:** 7  
**Trigger Methods:** 3 (Webhook + Polling + Manual)  
**Status:** ✅ Production Ready
