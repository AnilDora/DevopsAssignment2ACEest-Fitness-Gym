# Kubernetes Deployment Strategies Guide
## ACEest Fitness - Complete Implementation Guide for Minikube

---

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Deployment Strategies](#deployment-strategies)
   - [Rolling Update](#1-rolling-update)
   - [Blue-Green Deployment](#2-blue-green-deployment)
   - [Canary Release](#3-canary-release)
   - [Shadow Deployment](#4-shadow-deployment)
   - [A/B Testing](#5-ab-testing)
5. [Rollback Procedures](#rollback-procedures)
6. [Monitoring and Testing](#monitoring-and-testing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers five advanced deployment strategies for the ACEest Fitness application on Kubernetes (Minikube):

| Strategy | Use Case | Traffic Management | Rollback Speed | Complexity |
|----------|----------|-------------------|----------------|------------|
| **Rolling Update** | Standard deployments | Gradual pod replacement | Fast (automated) | Low |
| **Blue-Green** | Zero-downtime releases | Instant switch | Instant | Medium |
| **Canary** | Risk mitigation | Gradual traffic shift | Fast | Medium |
| **Shadow** | Performance testing | No production impact | N/A | Low |
| **A/B Testing** | Feature comparison | Split testing | Medium | High |

---

## Prerequisites

### Required Software

1. **Minikube** (v1.22+)
   ```bash
   # Windows (Chocolatey)
   choco install minikube
   
   # Linux
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   
   # macOS
   brew install minikube
   ```

2. **kubectl** (v1.24+)
   ```bash
   # Windows (Chocolatey)
   choco install kubernetes-cli
   
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/kubectl
   
   # macOS
   brew install kubectl
   ```

3. **Docker** (for Minikube driver)
   - Windows: Docker Desktop
   - Linux: Docker CE
   - macOS: Docker Desktop

### Verify Installation

```bash
# Check Minikube
minikube version

# Check kubectl
kubectl version --client

# Check Docker
docker --version
```

---

## Quick Start

### 1. Start Minikube

```bash
# Windows PowerShell
minikube start --driver=docker --memory=4096 --cpus=2

# Linux/Mac
minikube start --driver=docker --memory=4096 --cpus=2
```

### 2. Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
```

### 3. Using Automation Scripts

**Windows:**
```powershell
# Deploy all strategies
.\k8s-deploy.ps1 -Strategy all -Action deploy -StartMinikube

# Deploy specific strategy
.\k8s-deploy.ps1 -Strategy rolling -Action deploy

# Rollback
.\k8s-deploy.ps1 -Strategy rolling -Action rollback

# Test deployment
.\k8s-deploy.ps1 -Strategy rolling -Action test
```

**Linux/Mac:**
```bash
# Make script executable
chmod +x k8s-deploy.sh

# Deploy all strategies
./k8s-deploy.sh --strategy all --action deploy --start-minikube

# Deploy specific strategy
./k8s-deploy.sh -s rolling -a deploy

# Rollback
./k8s-deploy.sh -s rolling -a rollback

# Test deployment
./k8s-deploy.sh -s rolling -a test
```

---

## Deployment Strategies

### 1. Rolling Update

**Description:** Gradually replaces old pods with new ones, ensuring zero downtime.

**Diagram:**
```
Rolling Update Process:
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Old v1.0   │ --> │ Mixed v1/v2 │ --> │  New v2.0   │
│ ███████████ │     │ ███████░░░░ │     │ ░░░░░░░░░░░ │
│ 100% old    │     │ 60% old/40% │     │ 100% new    │
└─────────────┘     └─────────────┘     └─────────────┘
```

#### Manual Deployment

```bash
# 1. Create namespace and configmap
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# 2. Deploy rolling update
kubectl apply -f k8s/rolling-update-deployment.yaml

# 3. Watch rollout
kubectl rollout status deployment/aceest-fitness-rolling -n aceest-fitness

# 4. Get service URL
minikube service aceest-fitness-rolling-service -n aceest-fitness --url
```

#### Configuration Details

**Key Settings:**
- `strategy.type: RollingUpdate`
- `maxSurge: 1` - One extra pod during update
- `maxUnavailable: 1` - One pod can be unavailable
- `minReadySeconds: 10` - Wait 10s before marking ready
- `revisionHistoryLimit: 10` - Keep 10 previous versions

#### Testing

```bash
# Test health endpoint
curl $(minikube service aceest-fitness-rolling-service -n aceest-fitness --url)/health

# Watch pods during update
kubectl get pods -n aceest-fitness -l deployment-strategy=rolling-update -w

# Check rollout history
kubectl rollout history deployment/aceest-fitness-rolling -n aceest-fitness
```

#### Updating the Deployment

```bash
# Update image version
kubectl set image deployment/aceest-fitness-rolling \
  aceest-fitness=anildora/aceest-fitness:2.2 -n aceest-fitness

# Pause rollout (if issues detected)
kubectl rollout pause deployment/aceest-fitness-rolling -n aceest-fitness

# Resume rollout
kubectl rollout resume deployment/aceest-fitness-rolling -n aceest-fitness
```

#### Rollback

```bash
# Automatic rollback to previous version
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness

# Rollback to specific revision
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness --to-revision=2

# Check rollback status
kubectl rollout status deployment/aceest-fitness-rolling -n aceest-fitness
```

---

### 2. Blue-Green Deployment

**Description:** Two identical environments (Blue & Green). Switch traffic instantly between them.

**Diagram:**
```
Blue-Green Architecture:
┌──────────────────┐
│   Production     │
│     Service      │
│  (Points to:     │
│  ┌────────────┐  │
│  │   Blue ✓   │  │  <-- Active (100% traffic)
│  └────────────┘  │
│  ┌────────────┐  │
│  │   Green    │  │  <-- Standby (0% traffic)
│  └────────────┘  │
└──────────────────┘

After Switch:
┌──────────────────┐
│   Production     │
│     Service      │
│  (Points to:     │
│  ┌────────────┐  │
│  │   Blue     │  │  <-- Standby (0% traffic)
│  └────────────┘  │
│  ┌────────────┐  │
│  │   Green ✓  │  │  <-- Active (100% traffic)
│  └────────────┘  │
└──────────────────┘
```

#### Manual Deployment

```bash
# 1. Deploy both blue and green environments
kubectl apply -f k8s/blue-green-deployment.yaml

# 2. Wait for both deployments
kubectl rollout status deployment/aceest-fitness-blue -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-green -n aceest-fitness

# 3. Check service (currently points to blue)
kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness -o yaml | grep slot
```

#### Testing Before Switch

```bash
# Test Blue directly
curl $(minikube service aceest-fitness-blue-test -n aceest-fitness --url)/health

# Test Green directly
curl $(minikube service aceest-fitness-green-test -n aceest-fitness --url)/health

# Test production service (currently blue)
curl $(minikube service aceest-fitness-bluegreen-service -n aceest-fitness --url)/health
```

#### Switching Traffic

**From Blue to Green:**
```bash
# Method 1: Using kubectl patch
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"green"}}}'

# Method 2: Using automation script (Windows)
.\k8s-deploy.ps1 -Strategy blue-green -Action switch

# Method 3: Using automation script (Linux/Mac)
./k8s-deploy.sh -s blue-green -a switch
```

**From Green to Blue (Rollback):**
```bash
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"blue"}}}'
```

#### Verification

```bash
# Check which environment is active
kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness \
  -o jsonpath='{.spec.selector.slot}'

# Test production traffic
for i in {1..10}; do
  curl -s $(minikube service aceest-fitness-bluegreen-service -n aceest-fitness --url)/health | jq -r .version
done
```

---

### 3. Canary Release

**Description:** Gradually shift traffic from stable to canary version to minimize risk.

**Diagram:**
```
Canary Deployment Phases:

Phase 1: Initial (10% canary)
┌────────────────────────┐
│ Stable:  ████████░ 90% │
│ Canary:  █░░░░░░░░ 10% │
└────────────────────────┘

Phase 2: Monitoring (30% canary)
┌────────────────────────┐
│ Stable:  ███████░░ 70% │
│ Canary:  ███░░░░░░ 30% │
└────────────────────────┘

Phase 3: Confident (50% canary)
┌────────────────────────┐
│ Stable:  █████░░░░ 50% │
│ Canary:  █████░░░░ 50% │
└────────────────────────┘

Phase 4: Complete (100% canary)
┌────────────────────────┐
│ Stable:  ░░░░░░░░░  0% │
│ Canary:  ██████████ 100%│
└────────────────────────┘
```

#### Manual Deployment

```bash
# 1. Deploy canary setup (90% stable, 10% canary)
kubectl apply -f k8s/canary-deployment.yaml

# 2. Wait for both deployments
kubectl rollout status deployment/aceest-fitness-stable -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-canary -n aceest-fitness

# 3. Check pod distribution
kubectl get pods -n aceest-fitness -l deployment-strategy=canary
```

#### Traffic Distribution

The canary strategy uses **replica count** to control traffic distribution:

| Phase | Stable Replicas | Canary Replicas | Traffic Split |
|-------|----------------|-----------------|---------------|
| Initial | 9 | 1 | 90% / 10% |
| Phase 1 | 8 | 2 | 80% / 20% |
| Phase 2 | 7 | 3 | 70% / 30% |
| Phase 3 | 5 | 5 | 50% / 50% |
| Complete | 0 | 10 | 0% / 100% |

#### Gradual Rollout

```bash
# Phase 1: Increase to 20%
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=8
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=2

# Monitor for 15-30 minutes, check metrics...

# Phase 2: Increase to 30%
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=7
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=3

# Monitor for 15-30 minutes...

# Phase 3: 50/50 split
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=5
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=5

# Monitor for 30-60 minutes...

# Phase 4: Complete rollout
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=10
```

#### Testing Traffic Distribution

```bash
# Test 20 requests to see distribution
for i in {1..20}; do
  curl -s $(minikube service aceest-fitness-canary-service -n aceest-fitness --url)/health | jq -r '.version // "unknown"'
done | sort | uniq -c

# Expected output (10% canary):
#   18 1.0    (stable)
#    2 2.0    (canary)
```

#### Rollback

```bash
# Option 1: Scale canary to 0
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=10

# Option 2: Delete canary completely
kubectl delete deployment aceest-fitness-canary -n aceest-fitness
```

---

### 4. Shadow Deployment

**Description:** Deploy new version alongside production without sending it real traffic. Used for performance testing.

**Diagram:**
```
Shadow Deployment Architecture:

                  ┌──────────────┐
                  │   User       │
                  │   Traffic    │
                  └──────┬───────┘
                         │
                         │ 100%
                         ▼
           ┌─────────────────────────┐
           │  Production Deployment  │
           │     (Version 1.0)       │
           └─────────────────────────┘
                         
           ┌─────────────────────────┐
           │   Shadow Deployment     │
           │     (Version 2.0)       │
           │   No Real Traffic ✗     │
           │   (Testing Only)        │
           └─────────────────────────┘
```

#### Manual Deployment

```bash
# 1. Deploy shadow setup
kubectl apply -f k8s/shadow-deployment.yaml

# 2. Wait for both deployments
kubectl rollout status deployment/aceest-fitness-production -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-shadow -n aceest-fitness

# 3. Check services
kubectl get service -n aceest-fitness -l deployment-strategy=shadow
```

#### Testing Shadow

```bash
# Production endpoint (receives real traffic)
PROD_URL=$(minikube service aceest-fitness-production-service -n aceest-fitness --url)
echo "Production: $PROD_URL"

# Shadow endpoint (for testing only)
SHADOW_URL=$(minikube service aceest-fitness-shadow-service -n aceest-fitness --url)
echo "Shadow: $SHADOW_URL"

# Test production
curl $PROD_URL/health

# Test shadow
curl $SHADOW_URL/health

# Compare response times
echo "Production response time:"
time curl -s $PROD_URL/health > /dev/null

echo "Shadow response time:"
time curl -s $SHADOW_URL/health > /dev/null
```

#### Load Testing Shadow

```bash
# Use hey or ab for load testing
# Install hey: go install github.com/rakyll/hey@latest

# Load test shadow (100 requests, 10 concurrent)
hey -n 100 -c 10 $SHADOW_URL/health

# Compare with production
hey -n 100 -c 10 $PROD_URL/health
```

#### Promoting Shadow to Production

Once shadow testing is successful:

```bash
# Update production deployment with shadow image
kubectl set image deployment/aceest-fitness-production \
  aceest-fitness=anildora/aceest-fitness:2.1 -n aceest-fitness

# Or use rolling update strategy
kubectl apply -f k8s/rolling-update-deployment.yaml
```

---

### 5. A/B Testing

**Description:** Deploy two versions simultaneously to test features with different user groups.

**Diagram:**
```
A/B Testing Architecture:

                  ┌──────────────┐
                  │   User       │
                  │   Traffic    │
                  └──────┬───────┘
                         │
            ┌────────────┴────────────┐
            │         50%        50%  │
            ▼                         ▼
   ┌─────────────────┐       ┌─────────────────┐
   │   Version A     │       │   Version B     │
   │   (Control)     │       │   (Treatment)   │
   │  Old Features   │       │  New Features   │
   └─────────────────┘       └─────────────────┘
```

#### Manual Deployment

```bash
# 1. Deploy A/B testing setup (50/50 split)
kubectl apply -f k8s/ab-testing-deployment.yaml

# 2. Wait for both versions
kubectl rollout status deployment/aceest-fitness-version-a -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-version-b -n aceest-fitness

# 3. Check traffic distribution
kubectl get pods -n aceest-fitness -l deployment-strategy=ab-testing
```

#### Testing Both Versions

```bash
# Main service (50/50 distribution)
MAIN_URL=$(minikube service aceest-fitness-ab-service -n aceest-fitness --url)

# Version A (control) direct access
VERSION_A=$(minikube service aceest-fitness-version-a -n aceest-fitness --url)

# Version B (treatment) direct access
VERSION_B=$(minikube service aceest-fitness-version-b -n aceest-fitness --url)

# Test main service distribution
for i in {1..20}; do
  curl -s $MAIN_URL/health | jq -r '.version // "unknown"'
done | sort | uniq -c

# Expected: ~10 requests to A, ~10 to B
```

#### Adjusting Traffic Split

```bash
# Change to 70% A / 30% B
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=7
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=3

# Change to 90% A / 10% B
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=9
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=1

# Complete rollout to B (100%)
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=10
```

#### Session Affinity

The A/B service uses `ClientIP` session affinity to keep users on the same version:

```yaml
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 10800  # 3 hours
```

This ensures users get a consistent experience within their session.

---

## Rollback Procedures

See [ROLLBACK_PROCEDURES.md](ROLLBACK_PROCEDURES.md) for detailed rollback instructions.

### Quick Rollback Commands

```bash
# Rolling Update
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness

# Blue-Green (switch back to blue)
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"blue"}}}'

# Canary (remove canary)
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0

# Shadow (delete shadow)
kubectl delete deployment aceest-fitness-shadow -n aceest-fitness

# A/B Testing (remove version B)
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=0
```

---

## Monitoring and Testing

### Check Deployment Status

```bash
# Get all deployments
kubectl get deployments -n aceest-fitness

# Get all pods with labels
kubectl get pods -n aceest-fitness -L app,version,track,slot

# Get all services
kubectl get services -n aceest-fitness

# Get endpoints
kubectl get endpoints -n aceest-fitness
```

### View Logs

```bash
# All pods
kubectl logs -n aceest-fitness -l app=aceest-fitness --tail=50

# Specific deployment
kubectl logs -n aceest-fitness -l deployment-strategy=rolling-update --tail=50

# Follow logs
kubectl logs -n aceest-fitness -l app=aceest-fitness -f
```

### Resource Usage

```bash
# Enable metrics server (if not already enabled)
minikube addons enable metrics-server

# View pod resources
kubectl top pods -n aceest-fitness

# View node resources
kubectl top nodes
```

### Health Checks

```bash
# Create a test script
cat > test-all.sh << 'EOF'
#!/bin/bash

NAMESPACE="aceest-fitness"

echo "=== Testing All Deployments ==="

# Get all services
services=$(kubectl get services -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

for service in $services; do
    echo -e "\n--- Testing $service ---"
    url=$(minikube service $service -n $NAMESPACE --url 2>/dev/null)
    
    if [ -n "$url" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" $url/health)
        if [ "$response" == "200" ]; then
            echo "✓ $service: HEALTHY"
        else
            echo "✗ $service: UNHEALTHY (HTTP $response)"
        fi
    else
        echo "✗ $service: Cannot get URL"
    fi
done
EOF

chmod +x test-all.sh
./test-all.sh
```

---

## Troubleshooting

### Common Issues

#### 1. Minikube Won't Start

```bash
# Delete and recreate cluster
minikube delete
minikube start --driver=docker --memory=4096 --cpus=2

# Check Docker is running
docker ps
```

#### 2. Pods Stuck in Pending

```bash
# Check events
kubectl get events -n aceest-fitness --sort-by='.lastTimestamp'

# Check pod details
kubectl describe pod <pod-name> -n aceest-fitness

# Common causes: insufficient resources, image pull errors
```

#### 3. Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n aceest-fitness

# Check pod status
kubectl get pods -n aceest-fitness

# Verify service selector matches pod labels
kubectl get service <service-name> -n aceest-fitness -o yaml
kubectl get pods -n aceest-fitness --show-labels
```

#### 4. Image Pull Errors

```bash
# Check image name
kubectl describe pod <pod-name> -n aceest-fitness | grep Image

# Manually pull image
docker pull anildora/aceest-fitness:2.1

# Load image into Minikube
minikube image load anildora/aceest-fitness:2.1
```

#### 5. Readiness Probe Failing

```bash
# Check pod logs
kubectl logs <pod-name> -n aceest-fitness

# Describe pod for probe details
kubectl describe pod <pod-name> -n aceest-fitness | grep -A 10 "Readiness"

# Test health endpoint manually
kubectl port-forward <pod-name> -n aceest-fitness 8000:8000
curl http://localhost:8000/health
```

### Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n aceest-fitness

# Describe deployment
kubectl describe deployment <deployment-name> -n aceest-fitness

# Get pod YAML
kubectl get pod <pod-name> -n aceest-fitness -o yaml

# Execute command in pod
kubectl exec -it <pod-name> -n aceest-fitness -- /bin/sh

# Port forward for local testing
kubectl port-forward service/<service-name> -n aceest-fitness 8080:80
```

### Cleanup Everything

```bash
# Delete namespace (removes all resources)
kubectl delete namespace aceest-fitness

# Or use cleanup script
.\k8s-deploy.ps1 -Strategy all -Action cleanup  # Windows
./k8s-deploy.sh -s all -a cleanup               # Linux/Mac

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

---

## Next Steps

1. **Set up Monitoring:** Install Prometheus and Grafana
2. **Implement Istio:** For advanced traffic management
3. **Add CI/CD:** Integrate with Jenkins pipeline
4. **Set up Logging:** Use EFK stack (Elasticsearch, Fluentd, Kibana)
5. **Security:** Implement network policies and RBAC

---

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Deployment Strategies Comparison](https://www.weave.works/blog/kubernetes-deployment-strategies)
- [ROLLBACK_PROCEDURES.md](ROLLBACK_PROCEDURES.md)

---

**Version:** 1.0  
**Last Updated:** November 10, 2025  
**Author:** ACEest Fitness DevOps Team
