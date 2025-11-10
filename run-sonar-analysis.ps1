# ACEest Fitness - SonarQube Analysis Script
# Automated code quality analysis with SonarQube

param(
    [string]$SonarToken = $env:SONAR_TOKEN,
    [string]$SonarUrl = "http://localhost:9000"
)

# Color output functions
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }

Clear-Host
Write-Info "=========================================="
Write-Info "  ACEest Fitness - SonarQube Analysis"
Write-Info "=========================================="
Write-Host ""

# Step 1: Check if SonarQube is running
Write-Info "[1/7] Checking SonarQube server..."
try {
    $response = Invoke-WebRequest -Uri "$SonarUrl/api/system/status" -TimeoutSec 5 -ErrorAction Stop
    $status = ($response.Content | ConvertFrom-Json).status
    if ($status -eq "UP") {
        Write-Success "    ✓ SonarQube server is running"
    } else {
        Write-Warning "    ! SonarQube status: $status"
    }
} catch {
    Write-Error "    ✗ SonarQube server is not accessible at $SonarUrl"
    Write-Warning ""
    Write-Warning "Quick Start:"
    Write-Warning "  docker run -d --name sonarqube -p 9000:9000 sonarqube:latest"
    Write-Warning "  Wait 60 seconds for startup, then try again"
    Write-Warning ""
    exit 1
}

# Step 2: Check for SonarQube token
Write-Info "[2/7] Validating authentication..."
if ([string]::IsNullOrEmpty($SonarToken)) {
    Write-Error "    ✗ SONAR_TOKEN environment variable not set"
    Write-Warning ""
    Write-Warning "To set token:"
    Write-Warning "  1. Login to $SonarUrl (admin/admin)"
    Write-Warning "  2. My Account → Security → Generate Token"
    Write-Warning "  3. Run: `$env:SONAR_TOKEN = 'your-token-here'"
    Write-Warning ""
    exit 1
}
Write-Success "    ✓ Authentication token found"

# Step 3: Check if sonar-scanner is installed
Write-Info "[3/7] Checking sonar-scanner installation..."
$scannerInstalled = $false
try {
    $null = Get-Command sonar-scanner -ErrorAction Stop
    Write-Success "    ✓ sonar-scanner CLI is installed"
    $scannerInstalled = $true
} catch {
    Write-Warning "    ! sonar-scanner CLI not found"
    Write-Warning "    Attempting Docker-based scanning..."
    
    # Check if Docker is available
    try {
        $null = Get-Command docker -ErrorAction Stop
        Write-Success "    ✓ Docker is available, will use Docker-based scanner"
        $scannerInstalled = "docker"
    } catch {
        Write-Error "    ✗ Neither sonar-scanner nor Docker found"
        Write-Warning ""
        Write-Warning "Install options:"
        Write-Warning "  Option 1: choco install sonarscanner"
        Write-Warning "  Option 2: Install Docker Desktop"
        Write-Warning ""
        exit 1
    }
}

# Step 4: Clean old reports
Write-Info "[4/7] Cleaning old reports..."
$filesToClean = @("coverage.xml", "test-results.xml", ".coverage", "htmlcov")
foreach ($file in $filesToClean) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path ".scannerwork") {
    Remove-Item -Path ".scannerwork" -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Success "    ✓ Old reports cleaned"

# Step 5: Install/Update test dependencies
Write-Info "[5/7] Installing test dependencies..."
try {
    pip install -q pytest pytest-cov coverage 2>$null
    Write-Success "    ✓ Dependencies installed"
} catch {
    Write-Warning "    ! Failed to install dependencies"
}

# Step 6: Run tests with coverage
Write-Info "[6/7] Running tests with coverage..."
Write-Host ""
pytest --cov=. --cov-report=xml:coverage.xml --cov-report=html --junitxml=test-results.xml -v --tb=short

if ($LASTEXITCODE -ne 0) {
    Write-Warning ""
    Write-Warning "Tests failed, but continuing with analysis..."
    Write-Warning ""
} else {
    Write-Success ""
    Write-Success "    ✓ Tests passed"
    Write-Success ""
}

# Verify coverage file exists
if (-not (Test-Path "coverage.xml")) {
    Write-Warning "    ! Coverage file not generated, analysis will continue without coverage data"
} else {
    $coverageSize = (Get-Item "coverage.xml").Length
    Write-Success "    ✓ Coverage report generated ($coverageSize bytes)"
}

# Step 7: Run SonarQube analysis
Write-Info "[7/7] Running SonarQube analysis..."
Write-Host ""

if ($scannerInstalled -eq "docker") {
    Write-Info "Using Docker-based scanner..."
    docker run --rm `
        --network="host" `
        -v "${PWD}:/usr/src" `
        -e SONAR_HOST_URL=$SonarUrl `
        -e SONAR_LOGIN=$SonarToken `
        sonarsource/sonar-scanner-cli `
        -Dsonar.projectKey=aceest-fitness `
        -Dsonar.projectName="ACEest Fitness & Gym Management System" `
        -Dsonar.projectVersion=2.0 `
        -Dsonar.sources=. `
        -Dsonar.sourceEncoding=UTF-8 `
        -Dsonar.exclusions="venv/**,__pycache__/**,*.pyc,test_*.py,**/tests/**,htmlcov/**,.pytest_cache/**,*.md,Dockerfile,.dockerignore,Jenkinsfile,k8s/**" `
        -Dsonar.python.coverage.reportPaths=coverage.xml `
        -Dsonar.python.xunit.reportPath=test-results.xml `
        -Dsonar.python.version=3.11 `
        -Dsonar.qualitygate.wait=false
} else {
    sonar-scanner `
        -Dsonar.projectKey=aceest-fitness `
        -Dsonar.projectName="ACEest Fitness & Gym Management System" `
        -Dsonar.projectVersion=2.0 `
        -Dsonar.sources=. `
        -Dsonar.sourceEncoding=UTF-8 `
        -Dsonar.exclusions="venv/**,__pycache__/**,*.pyc,test_*.py,**/tests/**,htmlcov/**,.pytest_cache/**,*.md,Dockerfile,.dockerignore,Jenkinsfile,k8s/**" `
        -Dsonar.python.coverage.reportPaths=coverage.xml `
        -Dsonar.python.xunit.reportPath=test-results.xml `
        -Dsonar.python.version=3.11 `
        -Dsonar.qualitygate.wait=false `
        -Dsonar.host.url=$SonarUrl `
        -Dsonar.login=$SonarToken
}

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Success "=========================================="
    Write-Success "       ANALYSIS COMPLETED SUCCESSFULLY"
    Write-Success "=========================================="
    Write-Host ""
    Write-Info "View detailed results at:"
    Write-Host "  → $SonarUrl/dashboard?id=aceest-fitness" -ForegroundColor Yellow
    Write-Host ""
    
    # Try to fetch quick summary
    try {
        $projectUrl = "$SonarUrl/api/measures/component?component=aceest-fitness&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density"
        $measures = Invoke-RestMethod -Uri $projectUrl -Headers @{Authorization = "Bearer $SonarToken"} -ErrorAction SilentlyContinue
        
        if ($measures) {
            Write-Info "Quick Summary:"
            foreach ($measure in $measures.component.measures) {
                $metric = $measure.metric
                $value = $measure.value
                
                switch ($metric) {
                    "bugs" { Write-Host "  Bugs: $value" }
                    "vulnerabilities" { Write-Host "  Vulnerabilities: $value" }
                    "code_smells" { Write-Host "  Code Smells: $value" }
                    "coverage" { Write-Host "  Coverage: $value%" }
                    "duplicated_lines_density" { Write-Host "  Duplications: $value%" }
                }
            }
            Write-Host ""
        }
    } catch {
        # Silently ignore if API call fails
    }
    
    # Offer to open browser
    Write-Host "Press any key to open SonarQube dashboard, or Ctrl+C to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Start-Process "$SonarUrl/dashboard?id=aceest-fitness"
} else {
    Write-Error "=========================================="
    Write-Error "       ANALYSIS FAILED"
    Write-Error "=========================================="
    Write-Host ""
    Write-Warning "Check the error messages above for details"
    exit 1
}
