# ACEest Fitness - Quick Start Script for Windows PowerShell
# This script automates the setup and deployment of the ACEest Fitness application

param(
    [Parameter(Position=0)]
    [ValidateSet('setup', 'test', 'docker', 'k8s', 'all', 'clean')]
    [string]$Action = 'menu'
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "ℹ $Message" "Cyan"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

# Banner
function Show-Banner {
    Write-Host ""
    Write-ColorOutput "╔════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║          ACEest Fitness - DevOps Quick Start               ║" "Cyan"
    Write-ColorOutput "║              Windows PowerShell Edition                     ║" "Cyan"
    Write-ColorOutput "╚════════════════════════════════════════════════════════════╝" "Cyan"
    Write-Host ""
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $allGood = $true
    
    # Check Python
    try {
        $pythonVersion = python --version 2>&1
        Write-Success "Python: $pythonVersion"
    } catch {
        Write-Error "Python not found. Please install Python 3.11+"
        $allGood = $false
    }
    
    # Check pip
    try {
        $pipVersion = pip --version 2>&1
        Write-Success "pip: Found"
    } catch {
        Write-Error "pip not found. Please install pip"
        $allGood = $false
    }
    
    # Check Docker (optional)
    try {
        $dockerVersion = docker --version 2>&1
        Write-Success "Docker: $dockerVersion"
    } catch {
        Write-Warning "Docker not found (optional for Docker deployment)"
    }
    
    # Check kubectl (optional)
    try {
        $kubectlVersion = kubectl version --client --short 2>&1
        Write-Success "kubectl: Found"
    } catch {
        Write-Warning "kubectl not found (optional for Kubernetes deployment)"
    }
    
    Write-Host ""
    return $allGood
}

# Setup virtual environment
function Setup-VirtualEnvironment {
    Write-Info "Setting up Python virtual environment..."
    
    # Remove existing venv if present
    if (Test-Path "venv") {
        Write-Info "Removing existing virtual environment..."
        Remove-Item -Recurse -Force "venv"
    }
    
    # Create new virtual environment
    Write-Info "Creating virtual environment..."
    python -m venv venv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create virtual environment"
        Write-Info "If you get an error, try installing/repairing Python from python.org"
        return $false
    }
    
    Write-Success "Virtual environment created"
    
    # Activate virtual environment
    Write-Info "Activating virtual environment..."
    & ".\venv\Scripts\Activate.ps1"
    
    # Upgrade pip
    Write-Info "Upgrading pip..."
    python -m pip install --upgrade pip | Out-Null
    
    # Install dependencies
    Write-Info "Installing dependencies..."
    pip install -r requirements.txt
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies"
        return $false
    }
    
    Write-Success "Dependencies installed successfully"
    Write-Host ""
    return $true
}

# Run tests
function Invoke-Tests {
    Write-Info "Running unit tests..."
    
    # Activate virtual environment if not already active
    if (-not $env:VIRTUAL_ENV) {
        & ".\venv\Scripts\Activate.ps1"
    }
    
    # Run pytest with coverage
    pytest test_app.py -v --cov=app --cov-report=html --cov-report=term
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "All tests passed!"
        Write-Info "Coverage report generated in htmlcov/index.html"
        
        # Ask if user wants to open coverage report
        $open = Read-Host "Open coverage report in browser? (y/N)"
        if ($open -eq 'y' -or $open -eq 'Y') {
            Start-Process "htmlcov\index.html"
        }
    } else {
        Write-Error "Tests failed"
        return $false
    }
    
    Write-Host ""
    return $true
}

# Build Docker image
function Build-DockerImage {
    Write-Info "Building Docker image..."
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed or not in PATH"
        return $false
    }
    
    docker build -t aceest-fitness:latest .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker image built successfully"
        docker images aceest-fitness
    } else {
        Write-Error "Failed to build Docker image"
        return $false
    }
    
    Write-Host ""
    return $true
}

# Run Docker container
function Start-DockerContainer {
    Write-Info "Starting Docker container..."
    
    # Stop existing container if running
    $existing = docker ps -q -f name=aceest-fitness
    if ($existing) {
        Write-Info "Stopping existing container..."
        docker stop aceest-fitness | Out-Null
        docker rm aceest-fitness | Out-Null
    }
    
    # Run new container
    docker run -d -p 5000:5000 --name aceest-fitness aceest-fitness:latest
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Container started successfully"
        Write-Info "Application running at: http://localhost:5000"
        
        # Wait for health check
        Write-Info "Waiting for application to be ready..."
        Start-Sleep -Seconds 5
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Success "Health check passed"
                Write-Info "Application is ready!"
            }
        } catch {
            Write-Warning "Health check failed, but container is running"
        }
        
        Write-Host ""
        Write-Info "To view logs: docker logs aceest-fitness"
        Write-Info "To stop: docker stop aceest-fitness"
    } else {
        Write-Error "Failed to start container"
        return $false
    }
    
    Write-Host ""
    return $true
}

# Deploy to Kubernetes
function Deploy-Kubernetes {
    Write-Info "Deploying to Kubernetes..."
    
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Error "kubectl is not installed or not in PATH"
        return $false
    }
    
    # Create namespace
    Write-Info "Creating namespace..."
    kubectl create namespace aceest-fitness --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply deployment
    Write-Info "Applying deployment..."
    kubectl apply -f k8s/deployment.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Deployment applied successfully"
        
        Write-Info "Waiting for pods to be ready..."
        kubectl wait --for=condition=ready pod -l app=aceest-fitness -n aceest-fitness --timeout=120s
        
        Write-Host ""
        Write-Success "Deployment successful!"
        Write-Info "Checking deployment status..."
        kubectl get all -n aceest-fitness
        
        Write-Host ""
        Write-Info "To access the application:"
        Write-Info "  kubectl port-forward -n aceest-fitness svc/aceest-fitness 5000:80"
    } else {
        Write-Error "Failed to deploy to Kubernetes"
        return $false
    }
    
    Write-Host ""
    return $true
}

# Run application locally
function Start-LocalApp {
    Write-Info "Starting application locally..."
    
    # Activate virtual environment if not already active
    if (-not $env:VIRTUAL_ENV) {
        & ".\venv\Scripts\Activate.ps1"
    }
    
    Write-Success "Starting Flask application..."
    Write-Info "Application will be available at: http://localhost:5000"
    Write-Info "Press Ctrl+C to stop"
    Write-Host ""
    
    python app.py
}

# Clean up
function Invoke-Cleanup {
    Write-Warning "This will remove:"
    Write-Warning "  - Virtual environment"
    Write-Warning "  - Python cache files"
    Write-Warning "  - Test coverage reports"
    Write-Warning "  - Docker containers and images"
    Write-Host ""
    
    $confirm = Read-Host "Are you sure? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Cleanup cancelled"
        return
    }
    
    Write-Info "Cleaning up..."
    
    # Remove venv
    if (Test-Path "venv") {
        Write-Info "Removing virtual environment..."
        Remove-Item -Recurse -Force "venv"
    }
    
    # Remove Python cache
    if (Test-Path "__pycache__") {
        Write-Info "Removing Python cache..."
        Remove-Item -Recurse -Force "__pycache__"
    }
    
    # Remove pytest cache
    if (Test-Path ".pytest_cache") {
        Remove-Item -Recurse -Force ".pytest_cache"
    }
    
    # Remove coverage files
    if (Test-Path "htmlcov") {
        Remove-Item -Recurse -Force "htmlcov"
    }
    if (Test-Path ".coverage") {
        Remove-Item -Force ".coverage"
    }
    
    # Stop and remove Docker containers
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $existing = docker ps -a -q -f name=aceest-fitness
        if ($existing) {
            Write-Info "Removing Docker containers..."
            docker stop aceest-fitness 2>&1 | Out-Null
            docker rm aceest-fitness 2>&1 | Out-Null
        }
        
        $image = docker images -q aceest-fitness
        if ($image) {
            Write-Info "Removing Docker images..."
            docker rmi aceest-fitness:latest 2>&1 | Out-Null
        }
    }
    
    Write-Success "Cleanup complete!"
    Write-Host ""
}

# Show menu
function Show-Menu {
    Write-Host ""
    Write-ColorOutput "Select an option:" "Yellow"
    Write-Host "  1) Setup development environment"
    Write-Host "  2) Run tests"
    Write-Host "  3) Build and run Docker container"
    Write-Host "  4) Deploy to Kubernetes"
    Write-Host "  5) Run application locally"
    Write-Host "  6) Complete setup (setup + test)"
    Write-Host "  7) Clean up"
    Write-Host "  8) Exit"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-8)"
    return $choice
}

# Main execution
function Main {
    Show-Banner
    
    # Handle command line arguments
    if ($Action -ne 'menu') {
        switch ($Action) {
            'setup' {
                Test-Prerequisites
                Setup-VirtualEnvironment
                return
            }
            'test' {
                Invoke-Tests
                return
            }
            'docker' {
                Build-DockerImage
                Start-DockerContainer
                return
            }
            'k8s' {
                Deploy-Kubernetes
                return
            }
            'all' {
                Test-Prerequisites
                Setup-VirtualEnvironment
                Invoke-Tests
                return
            }
            'clean' {
                Invoke-Cleanup
                return
            }
        }
    }
    
    # Interactive menu
    while ($true) {
        $choice = Show-Menu
        
        switch ($choice) {
            '1' {
                Test-Prerequisites
                Setup-VirtualEnvironment
            }
            '2' {
                Invoke-Tests
            }
            '3' {
                Build-DockerImage
                if ($LASTEXITCODE -eq 0) {
                    Start-DockerContainer
                }
            }
            '4' {
                Deploy-Kubernetes
            }
            '5' {
                Start-LocalApp
            }
            '6' {
                Test-Prerequisites
                if (Setup-VirtualEnvironment) {
                    Invoke-Tests
                }
            }
            '7' {
                Invoke-Cleanup
            }
            '8' {
                Write-Info "Goodbye!"
                return
            }
            default {
                Write-Error "Invalid choice. Please select 1-8"
            }
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
}

# Run main function
Main
