# 🚀 Canary Deployment Demo Guide
## ACEest Fitness - Progressive Rollout Strategy

### What is Canary Deployment?
Canary deployment is a progressive rollout strategy where a new version is gradually introduced to a small subset of users (10%) before rolling out to everyone. This allows you to test in production with minimal risk.

---

## 📋 Pre-requisites

1. **Start Minikube:**
```powershell
minikube start --driver=docker
```

2. **Verify cluster is running:**
```powershell
kubectl cluster-info
minikube status
```

---

## 🎯 Canary Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Unified Service (Load Balancer)             │
│           aceest-fitness-canary-service                  │
│                                                           │
│  Distributes traffic based on pod count:                 │
│  • 90% traffic → Stable (9 pods)                         │
│  • 10% traffic → Canary (1 pod)                          │
└─────────────────────────────────────────────────────────┘
                    ↓                    ↓
    ┌───────────────────┐    ┌──────────────────┐
    │  STABLE VERSION   │    │  CANARY VERSION  │
    │   (Version 1.0)   │    │   (Version 2.0)  │
    │                   │    │                  │
    │   9 Replicas      │    │   1 Replica      │
    │   90% Traffic     │    │   10% Traffic    │
    │                   │    │                  │
    │   Image: 2.0      │    │   Image: 2.1     │
    └───────────────────┘    └──────────────────┘
```

---

## 📝 Step-by-Step Demo

### Step 1: Deploy Canary Configuration

```powershell
# Apply the canary deployment manifests
kubectl apply -f k8s\canary-deployment.yaml

# Expected output:
# deployment.apps/aceest-fitness-stable created
# deployment.apps/aceest-fitness-canary created
# service/aceest-fitness-canary-service created
# service/aceest-fitness-stable-test created
# service/aceest-fitness-canary-test created
```

### Step 2: Verify Deployments

```powershell
# Check all canary-related pods
kubectl get pods -n aceest-fitness -l deployment-strategy=canary

# You should see:
# - 9 pods with label track=stable (running version 1.0)
# - 1 pod with label track=canary (running version 2.0)
```

### Step 3: Check Services

```powershell
# List all services
kubectl get svc -n aceest-fitness

# You should see:
# - aceest-fitness-canary-service (main service - distributes traffic)
# - aceest-fitness-stable-test (direct access to stable)
# - aceest-fitness-canary-test (direct access to canary)
```

### Step 4: Test Stable Version (90% traffic)

```powershell
# Get the stable service URL
minikube service aceest-fitness-stable-test -n aceest-fitness --url

# Test the stable version
$STABLE_URL = $(minikube service aceest-fitness-stable-test -n aceest-fitness --url)
curl $STABLE_URL/health

# Expected response:
# {
#   "status": "healthy",
#   "version": "1.0",
#   "track": "stable"
# }
```

### Step 5: Test Canary Version (10% traffic)

```powershell
# Get the canary service URL
minikube service aceest-fitness-canary-test -n aceest-fitness --url

# Test the canary version directly
$CANARY_URL = $(minikube service aceest-fitness-canary-test -n aceest-fitness --url)
curl $CANARY_URL/health

# Expected response:
# {
#   "status": "healthy",
#   "version": "2.0",
#   "track": "canary"
# }
```

### Step 6: Test Unified Service (Load Balanced)

```powershell
# Get the unified service URL
minikube service aceest-fitness-canary-service -n aceest-fitness --url

# Test multiple times to see traffic distribution
$SERVICE_URL = $(minikube service aceest-fitness-canary-service -n aceest-fitness --url)

# Run 20 requests and count versions
1..20 | ForEach-Object {
    $response = Invoke-RestMethod -Uri "$SERVICE_URL/health"
    Write-Host "Request $_: Version $($response.version) - Track: $($response.track)"
}

# Expected output (approximately):
# ~18 requests (90%) will hit stable version 1.0
# ~2 requests (10%) will hit canary version 2.0
```

### Step 7: Monitor Pod Status

```powershell
# Watch pods in real-time
kubectl get pods -n aceest-fitness -l deployment-strategy=canary -w

# Check resource usage
kubectl top pods -n aceest-fitness -l deployment-strategy=canary
```

### Step 8: Progressive Rollout Simulation

Now let's simulate progressive rollout phases:

#### Phase 1: 10% Canary (Initial - Already done)
```powershell
# Current state: 9 stable + 1 canary
kubectl get pods -n aceest-fitness -l deployment-strategy=canary --no-headers | wc -l
```

#### Phase 2: Increase to 50% Canary
```powershell
# Scale stable down to 3, canary up to 3 (50/50 split)
kubectl scale deployment aceest-fitness-stable --replicas=3 -n aceest-fitness
kubectl scale deployment aceest-fitness-canary --replicas=3 -n aceest-fitness

# Wait for scaling
Start-Sleep -Seconds 15

# Verify
kubectl get pods -n aceest-fitness -l deployment-strategy=canary

# Test traffic distribution
1..20 | ForEach-Object {
    $response = Invoke-RestMethod -Uri "$SERVICE_URL/health"
    Write-Host "Request $_: Version $($response.version)"
}
# Expected: ~10 stable (50%), ~10 canary (50%)
```

#### Phase 3: Full Rollout (100% Canary)
```powershell
# Scale stable to 0, canary to 9 (full cutover)
kubectl scale deployment aceest-fitness-stable --replicas=0 -n aceest-fitness
kubectl scale deployment aceest-fitness-canary --replicas=9 -n aceest-fitness

# Wait for scaling
Start-Sleep -Seconds 15

# Verify
kubectl get pods -n aceest-fitness -l deployment-strategy=canary

# All traffic now goes to canary (version 2.0)
1..10 | ForEach-Object {
    $response = Invoke-RestMethod -Uri "$SERVICE_URL/health"
    Write-Host "Request $_: Version $($response.version)"
}
# Expected: 100% version 2.0 (canary)
```

---

## 🔄 Rollback Demo

### Emergency Rollback (If canary has issues)

```powershell
# Scenario: Canary version has critical bug, rollback immediately

# Scale canary to 0, stable back to 9
kubectl scale deployment aceest-fitness-canary --replicas=0 -n aceest-fitness
kubectl scale deployment aceest-fitness-stable --replicas=9 -n aceest-fitness

# Verify rollback
kubectl get pods -n aceest-fitness -l deployment-strategy=canary

# Test - all traffic back to stable
1..10 | ForEach-Object {
    $response = Invoke-RestMethod -Uri "$SERVICE_URL/health"
    Write-Host "Request $_: Version $($response.version)"
}
# Expected: 100% version 1.0 (stable)
```

**Rollback time: ~30 seconds** ⚡

---

## 📊 Monitoring Commands

### Real-time Traffic Monitoring

```powershell
# Continuous monitoring script
while ($true) {
    Clear-Host
    Write-Host "=== Canary Deployment Status ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Pod count
    $stablePods = (kubectl get pods -n aceest-fitness -l track=stable --no-headers 2>$null | Measure-Object).Count
    $canaryPods = (kubectl get pods -n aceest-fitness -l track=canary --no-headers 2>$null | Measure-Object).Count
    
    Write-Host "Stable Pods: $stablePods" -ForegroundColor Green
    Write-Host "Canary Pods: $canaryPods" -ForegroundColor Yellow
    Write-Host ""
    
    # Calculate percentages
    $total = $stablePods + $canaryPods
    if ($total -gt 0) {
        $stablePercent = [math]::Round(($stablePods / $total) * 100, 1)
        $canaryPercent = [math]::Round(($canaryPods / $total) * 100, 1)
        
        Write-Host "Traffic Distribution:" -ForegroundColor Cyan
        Write-Host "  Stable: $stablePercent%" -ForegroundColor Green
        Write-Host "  Canary: $canaryPercent%" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 5
}
```

### Check Deployment Logs

```powershell
# Stable deployment logs
kubectl logs -n aceest-fitness -l track=stable --tail=50

# Canary deployment logs
kubectl logs -n aceest-fitness -l track=canary --tail=50

# Follow logs in real-time
kubectl logs -n aceest-fitness -l track=canary -f
```

---

## 🎓 Key Observations

### Traffic Distribution
```powershell
# Automated test script
$stableCount = 0
$canaryCount = 0
$totalRequests = 100

Write-Host "Testing traffic distribution with $totalRequests requests..." -ForegroundColor Cyan

1..$totalRequests | ForEach-Object {
    try {
        $response = Invoke-RestMethod -Uri "$SERVICE_URL/health" -TimeoutSec 2
        if ($response.track -eq "stable") {
            $stableCount++
        } elseif ($response.track -eq "canary") {
            $canaryCount++
        }
    } catch {
        Write-Host "Request $_ failed" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Green
Write-Host "Stable (v1.0): $stableCount requests ($([math]::Round($stableCount/$totalRequests*100, 1))%)"
Write-Host "Canary (v2.0): $canaryCount requests ($([math]::Round($canaryCount/$totalRequests*100, 1))%)"
```

---

## 🧹 Cleanup

```powershell
# Delete canary deployments
kubectl delete -f k8s\canary-deployment.yaml

# Verify deletion
kubectl get pods -n aceest-fitness -l deployment-strategy=canary
```

---

## 💡 Best Practices

1. **Start Small:** Begin with 10% traffic to minimize risk
2. **Monitor Metrics:** Watch error rates, latency, CPU/memory usage
3. **Gradual Increase:** 10% → 25% → 50% → 100%
4. **Define Success Criteria:** 
   - Error rate < 1%
   - P95 latency < 200ms
   - No increase in 5xx errors
5. **Automated Rollback:** Set up alerts to auto-rollback on failures
6. **Test Duration:** Run each phase for 15-30 minutes minimum

---

## 🎯 When to Use Canary Deployment

✅ **Use for:**
- Major feature releases
- Backend API changes
- Performance optimizations
- Database schema changes
- Critical bug fixes

❌ **Avoid for:**
- Breaking changes (use blue-green instead)
- Database migrations with schema incompatibility
- Emergency hotfixes (too slow)

---

## 📈 Success Metrics

| Metric | Target | Command |
|--------|--------|---------|
| Pod Health | 100% Ready | `kubectl get pods -n aceest-fitness` |
| Error Rate | < 1% | Check application logs |
| Response Time | < 200ms | `curl -w "@curl-format.txt" $URL` |
| CPU Usage | < 70% | `kubectl top pods -n aceest-fitness` |
| Memory Usage | < 512Mi | `kubectl top pods -n aceest-fitness` |

---

**Demo Created:** November 10, 2025  
**Strategy:** Canary Deployment (Progressive Rollout)  
**Risk Level:** Low (10% initial exposure)  
**Rollback Time:** ~30 seconds

🚀 **Ready to test in production with confidence!**
