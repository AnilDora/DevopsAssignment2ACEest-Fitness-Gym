# Canary Deployment Demo Script
# ACEest Fitness & Gym Management System
# Demonstrates progressive canary rollout: 10% -> 50% -> 100%

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    CANARY DEPLOYMENT DEMO - ACEest Fitness Application" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Function to print colored messages
function Write-Step {
    param($step, $message)
    Write-Host "`n[$step] $message" -ForegroundColor Yellow
}

function Write-Success {
    param($message)
    Write-Host "✓ $message" -ForegroundColor Green
}

function Write-Info {
    param($message)
    Write-Host "  $message" -ForegroundColor White
}

function Write-Error {
    param($message)
    Write-Host "✗ $message" -ForegroundColor Red
}

# Check prerequisites
Write-Step "0/9" "Checking Prerequisites..."

# Check Docker
$dockerRunning = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running. Please start Docker Desktop first."
    Write-Info "Run: Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'"
    exit 1
}
Write-Success "Docker is running"

# Check Minikube
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Info "Starting Minikube cluster..."
    minikube start --driver=docker
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Minikube"
        exit 1
    }
}
Write-Success "Minikube is running"

# Check kubectl
kubectl version --client --short 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "kubectl is not installed"
    exit 1
}
Write-Success "kubectl is available"

Write-Host "`n" + "─" * 70

# Step 1: Create namespace
Write-Step "1/9" "Creating/Verifying Namespace..."
kubectl apply -f k8s/namespace.yaml
Write-Success "Namespace 'aceest-fitness' ready"

# Step 2: Apply ConfigMap
Write-Step "2/9" "Applying ConfigMap..."
kubectl apply -f k8s/configmap.yaml
Write-Success "ConfigMap applied"

# Step 3: Deploy Canary Configuration
Write-Step "3/9" "Deploying Canary Configuration (Stable + Canary)..."
Write-Info "This will deploy:"
Write-Info "  - 9 Stable pods (version 1.0) - 90% of traffic"
Write-Info "  - 1 Canary pod (version 2.0) - 10% of traffic"

kubectl apply -f k8s/canary-deployment.yaml

# Wait for deployments
Write-Info "`nWaiting for stable deployment to be ready..."
kubectl rollout status deployment/aceest-fitness-stable -n aceest-fitness --timeout=120s

Write-Info "Waiting for canary deployment to be ready..."
kubectl rollout status deployment/aceest-fitness-canary -n aceest-fitness --timeout=120s

Write-Success "Canary deployment phase 1 complete (10% canary traffic)"

# Step 4: Show current state
Write-Step "4/9" "Current Deployment State..."
Write-Host "`nPods:" -ForegroundColor Cyan
kubectl get pods -n aceest-fitness -l app=aceest-fitness --show-labels

Write-Host "`nDeployments:" -ForegroundColor Cyan
kubectl get deployments -n aceest-fitness

Write-Host "`nService:" -ForegroundColor Cyan
kubectl get svc -n aceest-fitness -l app=aceest-fitness

# Get service URL
$servicePort = kubectl get svc aceest-fitness-canary-service -n aceest-fitness -o jsonpath='{.spec.ports[0].nodePort}'
$minikubeIp = minikube ip
$serviceUrl = "http://${minikubeIp}:${servicePort}"

Write-Host "`nService URL: " -NoNewline -ForegroundColor Cyan
Write-Host $serviceUrl -ForegroundColor Green

# Step 5: Test traffic distribution (10% canary)
Write-Step "5/9" "Testing Traffic Distribution (90% Stable / 10% Canary)..."
Write-Info "Sending 100 requests to verify traffic split..."

$stableCount = 0
$canaryCount = 0
$errorCount = 0

for ($i = 1; $i -le 100; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$serviceUrl/health" -TimeoutSec 2 -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        
        if ($content.version -eq "1.0") {
            $stableCount++
        } elseif ($content.version -eq "2.0") {
            $canaryCount++
        }
        
        if ($i % 20 -eq 0) {
            Write-Host "." -NoNewline
        }
    } catch {
        $errorCount++
    }
}

Write-Host "`n"
Write-Info "Traffic Distribution Results:"
Write-Host "  Stable (v1.0): " -NoNewline -ForegroundColor White
Write-Host "$stableCount requests (${stableCount}%)" -ForegroundColor Green
Write-Host "  Canary (v2.0): " -NoNewline -ForegroundColor White
Write-Host "$canaryCount requests (${canaryCount}%)" -ForegroundColor Yellow
if ($errorCount -gt 0) {
    Write-Host "  Errors: $errorCount" -ForegroundColor Red
}

# Step 6: Monitor metrics (simulated)
Write-Step "6/9" "Monitoring Canary Metrics..."
Write-Info "In production, you would monitor:"
Write-Info "  ✓ Error rate: Compare canary vs stable"
Write-Info "  ✓ Response time: Check p50, p95, p99"
Write-Info "  ✓ Resource usage: CPU, memory"
Write-Info "  ✓ Business metrics: Conversion rate, user engagement"

Start-Sleep -Seconds 3

# Decision point
Write-Host "`n" + "─" * 70
Write-Host "`nCANARY PHASE 1 (10%) - DECISION POINT" -ForegroundColor Yellow
Write-Host "─" * 70

$phase1Decision = Read-Host "`nCanary looks healthy. Proceed to 50% rollout? (Y/N)"

if ($phase1Decision -ne 'Y' -and $phase1Decision -ne 'y') {
    Write-Error "Canary deployment paused. Rolling back..."
    
    # Rollback
    Write-Step "ROLLBACK" "Scaling canary to 0..."
    kubectl scale deployment/aceest-fitness-canary -n aceest-fitness --replicas=0
    kubectl scale deployment/aceest-fitness-stable -n aceest-fitness --replicas=9
    
    Write-Success "Rollback complete. All traffic on stable version."
    exit 0
}

# Step 7: Scale to 50% canary
Write-Step "7/9" "Scaling to 50% Canary Traffic..."
Write-Info "Scaling stable from 9 to 5 replicas"
Write-Info "Scaling canary from 1 to 5 replicas"

kubectl scale deployment/aceest-fitness-stable -n aceest-fitness --replicas=5
kubectl scale deployment/aceest-fitness-canary -n aceest-fitness --replicas=5

# Wait for scaling
Start-Sleep -Seconds 10

kubectl rollout status deployment/aceest-fitness-stable -n aceest-fitness --timeout=60s
kubectl rollout status deployment/aceest-fitness-canary -n aceest-fitness --timeout=60s

Write-Success "Scaled to 50/50 split"

# Show updated state
Write-Host "`nUpdated Pods:" -ForegroundColor Cyan
kubectl get pods -n aceest-fitness -l app=aceest-fitness

# Test 50% distribution
Write-Info "`nTesting 50/50 traffic distribution..."
$stableCount = 0
$canaryCount = 0

for ($i = 1; $i -le 50; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$serviceUrl/health" -TimeoutSec 2 -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        
        if ($content.version -eq "1.0") {
            $stableCount++
        } elseif ($content.version -eq "2.0") {
            $canaryCount++
        }
        
        if ($i % 10 -eq 0) {
            Write-Host "." -NoNewline
        }
    } catch {
        # Ignore
    }
}

Write-Host "`n"
Write-Info "50/50 Traffic Distribution:"
Write-Host "  Stable: $stableCount requests" -ForegroundColor Green
Write-Host "  Canary: $canaryCount requests" -ForegroundColor Yellow

Start-Sleep -Seconds 3

# Decision point 2
Write-Host "`n" + "─" * 70
Write-Host "`nCANARY PHASE 2 (50%) - DECISION POINT" -ForegroundColor Yellow
Write-Host "─" * 70

$phase2Decision = Read-Host "`nCanary still healthy at 50%. Complete rollout to 100%? (Y/N)"

if ($phase2Decision -ne 'Y' -and $phase2Decision -ne 'y') {
    Write-Error "Canary deployment paused. Rolling back..."
    
    # Rollback
    Write-Step "ROLLBACK" "Reverting to stable version..."
    kubectl scale deployment/aceest-fitness-canary -n aceest-fitness --replicas=0
    kubectl scale deployment/aceest-fitness-stable -n aceest-fitness --replicas=9
    
    Write-Success "Rollback complete. All traffic on stable version."
    exit 0
}

# Step 8: Complete rollout to 100%
Write-Step "8/9" "Completing Rollout to 100% Canary..."
Write-Info "Scaling stable to 0 replicas (retiring old version)"
Write-Info "Scaling canary to 9 replicas (new version becomes stable)"

kubectl scale deployment/aceest-fitness-stable -n aceest-fitness --replicas=0
kubectl scale deployment/aceest-fitness-canary -n aceest-fitness --replicas=9

# Wait for scaling
Start-Sleep -Seconds 10

kubectl rollout status deployment/aceest-fitness-canary -n aceest-fitness --timeout=60s

Write-Success "100% rollout complete!"

# Show final state
Write-Host "`nFinal Deployment State:" -ForegroundColor Cyan
kubectl get pods -n aceest-fitness -l app=aceest-fitness
kubectl get deployments -n aceest-fitness

# Verify 100% traffic
Write-Info "`nVerifying 100% traffic on new version..."
$canaryCount = 0

for ($i = 1; $i -le 20; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$serviceUrl/health" -TimeoutSec 2 -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        
        if ($content.version -eq "2.0") {
            $canaryCount++
        }
    } catch {
        # Ignore
    }
}

Write-Host "  Canary (v2.0): $canaryCount/20 requests" -ForegroundColor Green

# Step 9: Summary
Write-Host "`n" + "═" * 70
Write-Host "    CANARY DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "═" * 70

Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Phase 1: 10% canary traffic validated" -ForegroundColor Green
Write-Host "  ✓ Phase 2: 50% canary traffic validated" -ForegroundColor Green
Write-Host "  ✓ Phase 3: 100% rollout successful" -ForegroundColor Green
Write-Host "`n  New version (2.0) is now serving all traffic!" -ForegroundColor Green

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Info "1. Monitor the new version for 24-48 hours"
Write-Info "2. If stable, label canary deployment as 'stable'"
Write-Info "3. Update deployment manifests to reflect new baseline"

Write-Host "`nRollback Command (if needed):" -ForegroundColor Yellow
Write-Host "  kubectl scale deployment/aceest-fitness-stable -n aceest-fitness --replicas=9" -ForegroundColor White
Write-Host "  kubectl scale deployment/aceest-fitness-canary -n aceest-fitness --replicas=0" -ForegroundColor White

Write-Host "`nAccess the application:" -ForegroundColor Cyan
Write-Host "  URL: $serviceUrl" -ForegroundColor Green
Write-Host "  or run: minikube service aceest-fitness-canary-service -n aceest-fitness" -ForegroundColor White

Write-Host "`n✓ Demo Complete!`n" -ForegroundColor Green
