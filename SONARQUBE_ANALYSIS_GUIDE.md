# SonarQube Analysis Setup and Execution Guide
## ACEest Fitness Project - Code Quality Analysis

---

## 📋 Prerequisites

### Option 1: Local SonarQube Server (Recommended for Development)

#### Step 1: Install SonarQube using Docker

```powershell
# Pull SonarQube Docker image
docker pull sonarqube:latest

# Run SonarQube container
docker run -d --name sonarqube `
  -p 9000:9000 `
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true `
  sonarqube:latest

# Wait for SonarQube to start (takes 1-2 minutes)
Write-Host "Waiting for SonarQube to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Open SonarQube in browser
Start-Process "http://localhost:9000"
```

**Default credentials:**
- Username: `admin`
- Password: `admin` (you'll be prompted to change it)

#### Step 2: Install SonarScanner

**Option A: Using Chocolatey (Easiest)**
```powershell
choco install sonarscanner
```

**Option B: Manual Installation**
1. Download from: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
2. Extract to `C:\sonarqube\sonar-scanner`
3. Add to PATH:
```powershell
$env:Path += ";C:\sonarqube\sonar-scanner\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, "User")
```

**Option C: Using npm**
```powershell
npm install -g sonarqube-scanner
```

#### Step 3: Generate SonarQube Token

1. Login to SonarQube at http://localhost:9000
2. Go to: **My Account → Security → Generate Token**
3. Token Name: `aceest-fitness-token`
4. Click **Generate**
5. Copy the token (you'll need it for analysis)

Example token: `squ_1234567890abcdef1234567890abcdef12345678`

---

## 🚀 Running SonarQube Analysis

### Method 1: Using SonarScanner CLI

```powershell
# Set environment variables
$env:SONAR_HOST_URL = "http://localhost:9000"
$env:SONAR_TOKEN = "YOUR_TOKEN_HERE"  # Replace with your actual token

# Run analysis
sonar-scanner `
  -Dsonar.projectKey=aceest-fitness `
  -Dsonar.sources=. `
  -Dsonar.host.url=http://localhost:9000 `
  -Dsonar.login=$env:SONAR_TOKEN

# Or using the sonar-project.properties file
sonar-scanner -Dsonar.login=$env:SONAR_TOKEN
```

### Method 2: Using Python sonar-scanner

```powershell
# Install sonar-python-scanner
pip install sonar-python-scanner

# Run analysis
python -m sonar `
  --sonar-url http://localhost:9000 `
  --sonar-token YOUR_TOKEN_HERE `
  --project-key aceest-fitness
```

### Method 3: Using Docker (No Installation Required)

```powershell
# Run SonarScanner in Docker container
docker run --rm `
  --network="host" `
  -v "${PWD}:/usr/src" `
  -e SONAR_HOST_URL="http://localhost:9000" `
  -e SONAR_LOGIN="YOUR_TOKEN_HERE" `
  sonarsource/sonar-scanner-cli
```

---

## 📊 Complete Analysis Workflow

### Step-by-Step Execution

```powershell
# 1. Ensure SonarQube is running
docker ps | Select-String "sonarqube"

# 2. Run tests with coverage
Write-Host "Running tests with coverage..." -ForegroundColor Cyan
pytest --cov=. --cov-report=xml:coverage.xml --cov-report=html --junitxml=test-results.xml

# 3. Check if coverage files exist
if (Test-Path "coverage.xml") {
    Write-Host "✓ Coverage report generated" -ForegroundColor Green
} else {
    Write-Host "✗ Coverage report missing" -ForegroundColor Red
}

# 4. Run SonarQube analysis
Write-Host "Running SonarQube analysis..." -ForegroundColor Cyan
sonar-scanner `
  -Dsonar.projectKey=aceest-fitness `
  -Dsonar.projectName="ACEest Fitness & Gym Management System" `
  -Dsonar.projectVersion=2.0 `
  -Dsonar.sources=. `
  -Dsonar.exclusions="venv/**,__pycache__/**,*.pyc,test_*.py,**/tests/**,htmlcov/**,.pytest_cache/**" `
  -Dsonar.python.coverage.reportPaths=coverage.xml `
  -Dsonar.python.xunit.reportPath=test-results.xml `
  -Dsonar.python.version=3.11 `
  -Dsonar.host.url=http://localhost:9000 `
  -Dsonar.login=YOUR_TOKEN_HERE

# 5. Wait for analysis to complete
Write-Host "Analysis complete! Check results at: http://localhost:9000" -ForegroundColor Green
Start-Process "http://localhost:9000/dashboard?id=aceest-fitness"
```

---

## 🔧 Automated Analysis Script

Save this as `run-sonar-analysis.ps1`:

```powershell
<#
.SYNOPSIS
    Automated SonarQube analysis script for ACEest Fitness project
.DESCRIPTION
    Runs tests, generates coverage, and performs SonarQube analysis
#>

param(
    [string]$SonarToken = $env:SONAR_TOKEN,
    [string]$SonarUrl = "http://localhost:9000"
)

# Color output functions
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

Write-Info "=== ACEest Fitness - SonarQube Analysis ==="
Write-Host ""

# Step 1: Check if SonarQube is running
Write-Info "Step 1: Checking SonarQube server..."
try {
    $response = Invoke-WebRequest -Uri "$SonarUrl/api/system/status" -TimeoutSec 5 -ErrorAction Stop
    Write-Success "✓ SonarQube server is running"
} catch {
    Write-Error "✗ SonarQube server is not running"
    Write-Host "Start SonarQube: docker run -d --name sonarqube -p 9000:9000 sonarqube:latest"
    exit 1
}

# Step 2: Check for SonarQube token
if ([string]::IsNullOrEmpty($SonarToken)) {
    Write-Error "✗ SONAR_TOKEN not set"
    Write-Host "Set token: `$env:SONAR_TOKEN = 'your-token-here'"
    exit 1
}
Write-Success "✓ SonarQube token found"

# Step 3: Check if sonar-scanner is installed
Write-Info "Step 2: Checking sonar-scanner installation..."
try {
    $null = Get-Command sonar-scanner -ErrorAction Stop
    Write-Success "✓ sonar-scanner is installed"
} catch {
    Write-Error "✗ sonar-scanner not found"
    Write-Host "Install: choco install sonarscanner"
    Write-Host "Or use Docker method (see guide)"
    exit 1
}

# Step 4: Clean old reports
Write-Info "Step 3: Cleaning old reports..."
Remove-Item -Path "coverage.xml" -ErrorAction SilentlyContinue
Remove-Item -Path "test-results.xml" -ErrorAction SilentlyContinue
Remove-Item -Path ".scannerwork" -Recurse -ErrorAction SilentlyContinue
Write-Success "✓ Cleaned old reports"

# Step 5: Install/Update dependencies
Write-Info "Step 4: Installing dependencies..."
pip install -q pytest pytest-cov coverage 2>$null
Write-Success "✓ Dependencies ready"

# Step 6: Run tests with coverage
Write-Info "Step 5: Running tests with coverage..."
pytest --cov=. --cov-report=xml:coverage.xml --cov-report=html --junitxml=test-results.xml -v

if ($LASTEXITCODE -ne 0) {
    Write-Error "✗ Tests failed"
    exit 1
}
Write-Success "✓ Tests passed"

# Step 7: Verify coverage file
if (-not (Test-Path "coverage.xml")) {
    Write-Error "✗ Coverage file not generated"
    exit 1
}
Write-Success "✓ Coverage report generated"

# Step 8: Run SonarQube analysis
Write-Info "Step 6: Running SonarQube analysis..."
Write-Host ""

sonar-scanner `
  -Dsonar.projectKey=aceest-fitness `
  -Dsonar.projectName="ACEest Fitness & Gym Management System" `
  -Dsonar.projectVersion=2.0 `
  -Dsonar.sources=. `
  -Dsonar.sourceEncoding=UTF-8 `
  -Dsonar.exclusions="venv/**,__pycache__/**,*.pyc,test_*.py,**/tests/**,htmlcov/**,.pytest_cache/**,*.md,Dockerfile,.dockerignore,Jenkinsfile" `
  -Dsonar.python.coverage.reportPaths=coverage.xml `
  -Dsonar.python.xunit.reportPath=test-results.xml `
  -Dsonar.python.version=3.11 `
  -Dsonar.qualitygate.wait=true `
  -Dsonar.qualitygate.timeout=300 `
  -Dsonar.host.url=$SonarUrl `
  -Dsonar.login=$SonarToken

if ($LASTEXITCODE -ne 0) {
    Write-Error "✗ SonarQube analysis failed"
    exit 1
}

Write-Host ""
Write-Success "=== Analysis Complete ==="
Write-Host ""
Write-Host "View results at: $SonarUrl/dashboard?id=aceest-fitness" -ForegroundColor Yellow
Write-Host ""

# Open dashboard in browser
$openBrowser = Read-Host "Open SonarQube dashboard? (Y/N)"
if ($openBrowser -eq 'Y' -or $openBrowser -eq 'y') {
    Start-Process "$SonarUrl/dashboard?id=aceest-fitness"
}
```

**Usage:**
```powershell
# Set your token first
$env:SONAR_TOKEN = "your-token-here"

# Run the script
.\run-sonar-analysis.ps1
```

---

## 📈 Understanding SonarQube Reports

### Key Metrics

1. **Bugs** - Code that will likely cause application failure
2. **Vulnerabilities** - Security weaknesses
3. **Code Smells** - Maintainability issues
4. **Coverage** - Percentage of code covered by tests
5. **Duplications** - Duplicated code blocks
6. **Technical Debt** - Estimated time to fix all issues

### Quality Gate

Default quality gate conditions:
- Coverage on New Code ≥ 80%
- Duplicated Lines on New Code ≤ 3%
- Maintainability Rating on New Code = A
- Reliability Rating on New Code = A
- Security Rating on New Code = A

---

## 🐛 Troubleshooting

### Issue 1: SonarQube not accessible
```powershell
# Check if container is running
docker ps -a | Select-String "sonarqube"

# Check logs
docker logs sonarqube

# Restart container
docker restart sonarqube
```

### Issue 2: sonar-scanner not found
```powershell
# Check PATH
$env:Path -split ';' | Select-String "sonar"

# Reinstall
choco uninstall sonarscanner
choco install sonarscanner
```

### Issue 3: Coverage file not found
```powershell
# Generate coverage manually
pytest --cov=. --cov-report=xml:coverage.xml

# Check if file exists
Test-Path coverage.xml
```

### Issue 4: Authentication failed
```powershell
# Regenerate token in SonarQube UI
# My Account → Security → Generate Token

# Update environment variable
$env:SONAR_TOKEN = "new-token-here"
```

---

## 🔄 CI/CD Integration

### Jenkins Integration

Add to your Jenkinsfile:

```groovy
stage('SonarQube Analysis') {
    steps {
        script {
            def scannerHome = tool 'SonarScanner'
            withSonarQubeEnv('SonarQube') {
                sh "${scannerHome}/bin/sonar-scanner \
                    -Dsonar.projectKey=aceest-fitness \
                    -Dsonar.sources=. \
                    -Dsonar.python.coverage.reportPaths=coverage.xml"
            }
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
```

---

## 📊 Sample Output

```
INFO: Scanner configuration file: C:\sonarqube\sonar-scanner\conf\sonar-scanner.properties
INFO: Project root configuration file: sonar-project.properties
INFO: SonarScanner 4.8.0.2856
INFO: Java 11.0.17 Oracle Corporation (64-bit)
INFO: Windows 10 10.0 amd64
INFO: User cache: C:\Users\User\.sonar\cache
INFO: Analyzing on SonarQube server 9.9
INFO: Default locale: "en_US", source code encoding: "UTF-8"

INFO: Load global settings
INFO: Load global settings (done) | time=156ms
INFO: Server id: 1234ABCD
INFO: User cache: C:\Users\User\.sonar\cache
INFO: Load/download plugins
INFO: Load/download plugins (done) | time=89ms

INFO: Process project properties
INFO: Project key: aceest-fitness
INFO: Base dir: C:\BITS-Mine\Assignment\Devops\Assignment 2\Project
INFO: Working dir: C:\BITS-Mine\Assignment\Devops\Assignment 2\Project\.scannerwork

INFO: Load project settings for component key: 'aceest-fitness'
INFO: Load project settings for component key: 'aceest-fitness' (done) | time=45ms

INFO: Execute project builders
INFO: Execute project builders (done) | time=3ms

INFO: Project configuration:
INFO:   Excluded sources: venv/**, __pycache__/**, *.pyc, test_*.py

INFO: Indexing files...
INFO: 15 files indexed

INFO: Quality profile for py: Sonar way
INFO: Sensor Python Sensor [python]
INFO: Starting global symbols computation
INFO: 8 source files to be analyzed

INFO: Sensor Python Sensor [python] (done) | time=2345ms
INFO: Sensor Python Coverage [python]
INFO: Parsing report 'coverage.xml'
INFO: Sensor Python Coverage [python] (done) | time=89ms

INFO: Analysis report generated in 234ms
INFO: Analysis report uploaded in 156ms

INFO: ANALYSIS SUCCESSFUL, you can browse http://localhost:9000/dashboard?id=aceest-fitness
INFO: Note that you will be able to access the updated dashboard once the server has processed the submitted analysis report

INFO: More about the report processing at http://localhost:9000/api/ce/task?id=AY...

INFO: Task total time: 5.678 s
INFO: SUCCESS
```

---

## 🎯 Quick Start Commands

```powershell
# 1. Start SonarQube
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

# 2. Install scanner (choose one)
choco install sonarscanner
# OR
npm install -g sonarqube-scanner

# 3. Generate token at http://localhost:9000
# My Account → Security → Generate Token

# 4. Set token
$env:SONAR_TOKEN = "your-token-here"

# 5. Run analysis
sonar-scanner -Dsonar.login=$env:SONAR_TOKEN

# 6. View results
Start-Process "http://localhost:9000/dashboard?id=aceest-fitness"
```

---

**Created:** November 10, 2025  
**Project:** ACEest Fitness - Code Quality Analysis  
**Tool:** SonarQube 9.9+  
**Scanner:** SonarScanner CLI 4.8+
