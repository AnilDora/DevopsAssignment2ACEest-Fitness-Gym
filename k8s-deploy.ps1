# Kubernetes Deployment Automation Script for Windows
# ACEest Fitness - All Deployment Strategies

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("rolling", "blue-green", "canary", "shadow", "ab-testing", "all")]
    [string]$Strategy = "rolling",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "rollback", "switch", "test", "cleanup")]
    [string]$Action = "deploy",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "aceest-fitness",
    
    [Parameter(Mandatory=$false)]
    [switch]$StartMinikube,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { Write-ColorOutput $args[0] "Green" }
function Write-Error { Write-ColorOutput $args[0] "Red" }
function Write-Warning { Write-ColorOutput $args[0] "Yellow" }
function Write-Info { Write-ColorOutput $args[0] "Cyan" }

# Check prerequisites
function Test-Prerequisites {
    Write-Info "`n=== Checking Prerequisites ===`n"
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short 2>&1
        Write-Success "✓ kubectl is installed: $kubectlVersion"
    } catch {
        Write-Error "✗ kubectl is not installed or not in PATH"
        return $false
    }
    
    # Check minikube
    try {
        $minikubeVersion = minikube version --short 2>&1
        Write-Success "✓ minikube is installed: $minikubeVersion"
    } catch {
        Write-Error "✗ minikube is not installed or not in PATH"
        return $false
    }
    
    return $true
}

# Start Minikube if needed
function Start-MinikubeCluster {
    Write-Info "`n=== Starting Minikube ===`n"
    
    $status = minikube status --format='{{.Host}}' 2>&1
    if ($status -match "Running") {
        Write-Success "✓ Minikube is already running"
        return $true
    }
    
    Write-Warning "Starting Minikube cluster..."
    minikube start --driver=docker --memory=4096 --cpus=2
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Minikube started successfully"
        return $true
    } else {
        Write-Error "✗ Failed to start Minikube"
        return $false
    }
}

# Create namespace
function New-K8sNamespace {
    Write-Info "`n=== Creating Namespace ===`n"
    
    $namespaceExists = kubectl get namespace $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Namespace '$Namespace' already exists"
    } else {
        Write-Info "Creating namespace '$Namespace'..."
        kubectl apply -f k8s/namespace.yaml
        kubectl apply -f k8s/configmap.yaml
        Write-Success "✓ Namespace created"
    }
}

# Deploy strategies
function Deploy-RollingUpdate {
    Write-Info "`n=== Deploying Rolling Update Strategy ===`n"
    
    if ($DryRun) {
        kubectl apply -f k8s/rolling-update-deployment.yaml --dry-run=client
    } else {
        kubectl apply -f k8s/rolling-update-deployment.yaml
        kubectl rollout status deployment/aceest-fitness-rolling -n $Namespace --timeout=5m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ Rolling Update deployment successful"
            $url = minikube service aceest-fitness-rolling-service -n $Namespace --url
            Write-Info "Service URL: $url"
        }
    }
}

function Deploy-BlueGreen {
    Write-Info "`n=== Deploying Blue-Green Strategy ===`n"
    
    if ($DryRun) {
        kubectl apply -f k8s/blue-green-deployment.yaml --dry-run=client
    } else {
        kubectl apply -f k8s/blue-green-deployment.yaml
        
        Write-Info "Waiting for Blue deployment..."
        kubectl rollout status deployment/aceest-fitness-blue -n $Namespace --timeout=5m
        
        Write-Info "Waiting for Green deployment..."
        kubectl rollout status deployment/aceest-fitness-green -n $Namespace --timeout=5m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ Blue-Green deployment successful"
            Write-Info "Production service (currently BLUE):"
            $url = minikube service aceest-fitness-bluegreen-service -n $Namespace --url
            Write-Info "  Main: $url"
            
            Write-Info "`nDirect access URLs:"
            Write-Info "  Blue:  $(minikube service aceest-fitness-blue-test -n $Namespace --url)"
            Write-Info "  Green: $(minikube service aceest-fitness-green-test -n $Namespace --url)"
        }
    }
}

function Deploy-Canary {
    Write-Info "`n=== Deploying Canary Strategy ===`n"
    
    if ($DryRun) {
        kubectl apply -f k8s/canary-deployment.yaml --dry-run=client
    } else {
        kubectl apply -f k8s/canary-deployment.yaml
        
        Write-Info "Waiting for Stable deployment..."
        kubectl rollout status deployment/aceest-fitness-stable -n $Namespace --timeout=5m
        
        Write-Info "Waiting for Canary deployment..."
        kubectl rollout status deployment/aceest-fitness-canary -n $Namespace --timeout=5m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ Canary deployment successful (90% stable, 10% canary)"
            $url = minikube service aceest-fitness-canary-service -n $Namespace --url
            Write-Info "Service URL: $url"
            
            Write-Warning "`nTo gradually increase canary traffic:"
            Write-Info "  kubectl scale deployment aceest-fitness-stable -n $Namespace --replicas=5"
            Write-Info "  kubectl scale deployment aceest-fitness-canary -n $Namespace --replicas=5"
        }
    }
}

function Deploy-Shadow {
    Write-Info "`n=== Deploying Shadow Strategy ===`n"
    
    if ($DryRun) {
        kubectl apply -f k8s/shadow-deployment.yaml --dry-run=client
    } else {
        kubectl apply -f k8s/shadow-deployment.yaml
        
        Write-Info "Waiting for Production deployment..."
        kubectl rollout status deployment/aceest-fitness-production -n $Namespace --timeout=5m
        
        Write-Info "Waiting for Shadow deployment..."
        kubectl rollout status deployment/aceest-fitness-shadow -n $Namespace --timeout=5m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ Shadow deployment successful"
            Write-Info "Production: $(minikube service aceest-fitness-production-service -n $Namespace --url)"
            Write-Info "Shadow:     $(minikube service aceest-fitness-shadow-service -n $Namespace --url)"
        }
    }
}

function Deploy-ABTesting {
    Write-Info "`n=== Deploying A/B Testing Strategy ===`n"
    
    if ($DryRun) {
        kubectl apply -f k8s/ab-testing-deployment.yaml --dry-run=client
    } else {
        kubectl apply -f k8s/ab-testing-deployment.yaml
        
        Write-Info "Waiting for Version A deployment..."
        kubectl rollout status deployment/aceest-fitness-version-a -n $Namespace --timeout=5m
        
        Write-Info "Waiting for Version B deployment..."
        kubectl rollout status deployment/aceest-fitness-version-b -n $Namespace --timeout=5m
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "`n✓ A/B Testing deployment successful (50/50 split)"
            Write-Info "Main service (50/50): $(minikube service aceest-fitness-ab-service -n $Namespace --url)"
            Write-Info "Version A (control):  $(minikube service aceest-fitness-version-a -n $Namespace --url)"
            Write-Info "Version B (treatment):$(minikube service aceest-fitness-version-b -n $Namespace --url)"
        }
    }
}

# Rollback functions
function Invoke-Rollback {
    param([string]$Strategy)
    
    Write-Warning "`n=== Performing Rollback: $Strategy ===`n"
    
    switch ($Strategy) {
        "rolling" {
            kubectl rollout undo deployment/aceest-fitness-rolling -n $Namespace
            kubectl rollout status deployment/aceest-fitness-rolling -n $Namespace
        }
        "blue-green" {
            Write-Info "Switching service to BLUE..."
            kubectl patch service aceest-fitness-bluegreen-service -n $Namespace -p '{\"spec\":{\"selector\":{\"slot\":\"blue\"}}}'
        }
        "canary" {
            Write-Info "Scaling down canary to 0..."
            kubectl scale deployment aceest-fitness-canary -n $Namespace --replicas=0
        }
        "shadow" {
            Write-Info "Deleting shadow deployment..."
            kubectl delete deployment aceest-fitness-shadow -n $Namespace
        }
        "ab-testing" {
            Write-Info "Scaling down Version B..."
            kubectl scale deployment aceest-fitness-version-b -n $Namespace --replicas=0
        }
    }
    
    Write-Success "✓ Rollback completed"
}

# Switch function for blue-green
function Invoke-BlueGreenSwitch {
    Write-Info "`n=== Blue-Green Switch ===`n"
    
    $currentSlot = kubectl get service aceest-fitness-bluegreen-service -n $Namespace -o jsonpath='{.spec.selector.slot}'
    Write-Info "Current slot: $currentSlot"
    
    $newSlot = if ($currentSlot -eq "blue") { "green" } else { "blue" }
    
    Write-Warning "Switching to: $newSlot"
    kubectl patch service aceest-fitness-bluegreen-service -n $Namespace -p "{`"spec`":{`"selector`":{`"slot`":`"$newSlot`"}}}"
    
    Write-Success "✓ Switched to $newSlot"
}

# Test function
function Test-Deployment {
    param([string]$Strategy)
    
    Write-Info "`n=== Testing Deployment: $Strategy ===`n"
    
    $services = @()
    
    switch ($Strategy) {
        "rolling" { $services = @("aceest-fitness-rolling-service") }
        "blue-green" { $services = @("aceest-fitness-bluegreen-service", "aceest-fitness-blue-test", "aceest-fitness-green-test") }
        "canary" { $services = @("aceest-fitness-canary-service", "aceest-fitness-stable-test", "aceest-fitness-canary-test") }
        "shadow" { $services = @("aceest-fitness-production-service", "aceest-fitness-shadow-service") }
        "ab-testing" { $services = @("aceest-fitness-ab-service", "aceest-fitness-version-a", "aceest-fitness-version-b") }
    }
    
    foreach ($service in $services) {
        Write-Info "`nTesting $service..."
        $url = minikube service $service -n $Namespace --url 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            try {
                $response = Invoke-RestMethod -Uri "$url/health" -TimeoutSec 5
                Write-Success "✓ $service is healthy"
                Write-Info "  Response: $($response | ConvertTo-Json -Compress)"
            } catch {
                Write-Error "✗ $service failed health check"
            }
        } else {
            Write-Error "✗ Cannot get URL for $service"
        }
    }
}

# Cleanup function
function Remove-Deployment {
    param([string]$Strategy)
    
    Write-Warning "`n=== Cleaning up: $Strategy ===`n"
    
    $confirmCleanup = Read-Host "Are you sure you want to delete $Strategy deployment? (yes/no)"
    
    if ($confirmCleanup -eq "yes") {
        switch ($Strategy) {
            "rolling" { kubectl delete -f k8s/rolling-update-deployment.yaml }
            "blue-green" { kubectl delete -f k8s/blue-green-deployment.yaml }
            "canary" { kubectl delete -f k8s/canary-deployment.yaml }
            "shadow" { kubectl delete -f k8s/shadow-deployment.yaml }
            "ab-testing" { kubectl delete -f k8s/ab-testing-deployment.yaml }
            "all" {
                kubectl delete namespace $Namespace
                Write-Warning "Deleted entire namespace: $Namespace"
                return
            }
        }
        Write-Success "✓ Cleanup completed"
    } else {
        Write-Info "Cleanup cancelled"
    }
}

# Main execution
Write-ColorOutput "`n╔═══════════════════════════════════════════════════════╗" "Cyan"
Write-ColorOutput "║  ACEest Fitness - Kubernetes Deployment Automation  ║" "Cyan"
Write-ColorOutput "╚═══════════════════════════════════════════════════════╝`n" "Cyan"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Error "Prerequisites check failed. Exiting."
    exit 1
}

# Start Minikube if requested
if ($StartMinikube) {
    if (-not (Start-MinikubeCluster)) {
        Write-Error "Failed to start Minikube. Exiting."
        exit 1
    }
}

# Create namespace
if ($Action -eq "deploy") {
    New-K8sNamespace
}

# Execute action
switch ($Action) {
    "deploy" {
        switch ($Strategy) {
            "rolling" { Deploy-RollingUpdate }
            "blue-green" { Deploy-BlueGreen }
            "canary" { Deploy-Canary }
            "shadow" { Deploy-Shadow }
            "ab-testing" { Deploy-ABTesting }
            "all" {
                Deploy-RollingUpdate
                Deploy-BlueGreen
                Deploy-Canary
                Deploy-Shadow
                Deploy-ABTesting
            }
        }
    }
    "rollback" { Invoke-Rollback -Strategy $Strategy }
    "switch" {
        if ($Strategy -eq "blue-green") {
            Invoke-BlueGreenSwitch
        } else {
            Write-Error "Switch action is only available for blue-green strategy"
        }
    }
    "test" { Test-Deployment -Strategy $Strategy }
    "cleanup" { Remove-Deployment -Strategy $Strategy }
}

Write-ColorOutput "`n╔═══════════════════════════════════════════════════════╗" "Green"
Write-ColorOutput "║              Deployment Operation Complete           ║" "Green"
Write-ColorOutput "╚═══════════════════════════════════════════════════════╝`n" "Green"

# Show useful commands
Write-Info "Useful commands:"
Write-Host "  Get all deployments: " -NoNewline; Write-ColorOutput "kubectl get deployments -n $Namespace" "Yellow"
Write-Host "  Get all pods:        " -NoNewline; Write-ColorOutput "kubectl get pods -n $Namespace" "Yellow"
Write-Host "  Get all services:    " -NoNewline; Write-ColorOutput "kubectl get services -n $Namespace" "Yellow"
Write-Host "  View logs:           " -NoNewline; Write-ColorOutput "kubectl logs -n $Namespace -l app=aceest-fitness --tail=50" "Yellow"
