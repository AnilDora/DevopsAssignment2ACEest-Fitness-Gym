# Kubernetes Deployment - ACEest Fitness

Complete implementation of advanced deployment strategies on Kubernetes (Minikube).

## 📋 Assignment Requirements Completed

✅ **Deploy containerized application using Kubernetes (Minikube)**  
✅ **Implement advanced deployment methodologies:**
- ✅ Rolling Update
- ✅ Blue-Green Deployment  
- ✅ Canary Release
- ✅ Shadow Deployment
- ✅ A/B Testing

✅ **Rollback mechanisms in place for all strategies**

---

## 🚀 Quick Start

### Prerequisites
- Minikube v1.22+
- kubectl v1.24+
- Docker

### 1. Start Minikube
```bash
minikube start --driver=docker --memory=4096 --cpus=2
```

### 2. Deploy a Strategy

**Windows:**
```powershell
.\k8s-deploy.ps1 -Strategy rolling -Action deploy -StartMinikube
```

**Linux/Mac:**
```bash
chmod +x k8s-deploy.sh
./k8s-deploy.sh -s rolling -a deploy -m
```

### 3. Test Deployment
```bash
# Get service URL
minikube service aceest-fitness-rolling-service -n aceest-fitness --url

# Test health endpoint
curl <service-url>/health
```

---

## 📁 Project Structure

```
k8s/
├── namespace.yaml                    # Namespace definition
├── configmap.yaml                    # Application configuration
├── base-deployment.yaml              # Basic deployment template
├── rolling-update-deployment.yaml    # Rolling update strategy
├── blue-green-deployment.yaml        # Blue-green deployment
├── canary-deployment.yaml            # Canary release
├── shadow-deployment.yaml            # Shadow deployment
└── ab-testing-deployment.yaml        # A/B testing

Scripts:
├── k8s-deploy.ps1                    # Windows automation script
└── k8s-deploy.sh                     # Linux/Mac automation script

Documentation:
├── KUBERNETES_DEPLOYMENT_GUIDE.md    # Complete deployment guide
├── ROLLBACK_PROCEDURES.md            # Rollback documentation
└── K8S_QUICK_REFERENCE.md            # Quick command reference
```

---

## 🎯 Deployment Strategies

### 1. Rolling Update
**Use Case:** Standard zero-downtime deployments

```bash
kubectl apply -f k8s/rolling-update-deployment.yaml
```

**Features:**
- Gradual pod replacement
- Configurable `maxSurge` and `maxUnavailable`
- Automatic rollback on failure
- 10 revision history for rollbacks

**Rollback:**
```bash
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness
```

---

### 2. Blue-Green Deployment
**Use Case:** Instant zero-downtime releases with easy rollback

```bash
kubectl apply -f k8s/blue-green-deployment.yaml
```

**Features:**
- Two identical environments (Blue & Green)
- Instant traffic switch
- Zero downtime
- Quick rollback

**Switch Traffic:**
```bash
# Switch to Green
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"green"}}}'

# Rollback to Blue
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"blue"}}}'
```

---

### 3. Canary Release
**Use Case:** Risk mitigation through gradual rollout

```bash
kubectl apply -f k8s/canary-deployment.yaml
```

**Features:**
- Initial 90% stable / 10% canary split
- Gradual traffic increase
- Monitor metrics before full rollout
- Easy rollback

**Adjust Traffic:**
```bash
# Increase canary to 50%
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=5
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=5

# Rollback (remove canary)
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0
```

---

### 4. Shadow Deployment
**Use Case:** Performance testing without user impact

```bash
kubectl apply -f k8s/shadow-deployment.yaml
```

**Features:**
- Production receives all user traffic
- Shadow deployment for testing
- No impact on users
- Compare performance metrics

**Test:**
```bash
PROD_URL=$(minikube service aceest-fitness-production-service -n aceest-fitness --url)
SHADOW_URL=$(minikube service aceest-fitness-shadow-service -n aceest-fitness --url)

curl $PROD_URL/health
curl $SHADOW_URL/health
```

---

### 5. A/B Testing
**Use Case:** Feature comparison and experimentation

```bash
kubectl apply -f k8s/ab-testing-deployment.yaml
```

**Features:**
- 50/50 traffic split (configurable)
- Session affinity (3 hours)
- Direct access to each version
- Compare metrics between versions

**Adjust Split:**
```bash
# Change to 70/30 (A/B)
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=7
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=3
```

---

## 🔄 Automation Scripts

### Features
- ✅ Automatic Minikube startup
- ✅ Namespace creation
- ✅ Deployment with rollout monitoring
- ✅ Testing and verification
- ✅ Easy rollback
- ✅ Cleanup operations
- ✅ Colored output
- ✅ Dry-run support

### Script Options

**Windows PowerShell:**
```powershell
.\k8s-deploy.ps1 [-Strategy <strategy>] [-Action <action>] [-Namespace <name>] [-StartMinikube] [-DryRun]

# Examples:
.\k8s-deploy.ps1 -Strategy rolling -Action deploy
.\k8s-deploy.ps1 -Strategy blue-green -Action switch
.\k8s-deploy.ps1 -Strategy canary -Action test
.\k8s-deploy.ps1 -Strategy rolling -Action rollback
.\k8s-deploy.ps1 -Strategy all -Action deploy -StartMinikube
```

**Linux/Mac Bash:**
```bash
./k8s-deploy.sh [OPTIONS]

Options:
  -s, --strategy <strategy>    rolling|blue-green|canary|shadow|ab-testing|all
  -a, --action <action>        deploy|rollback|switch|test|cleanup
  -n, --namespace <namespace>  Kubernetes namespace (default: aceest-fitness)
  -m, --start-minikube         Start Minikube if not running
  -d, --dry-run                Perform dry-run

# Examples:
./k8s-deploy.sh -s rolling -a deploy
./k8s-deploy.sh -s blue-green -a switch
./k8s-deploy.sh -s canary -a test
./k8s-deploy.sh -s rolling -a rollback
./k8s-deploy.sh -s all -a deploy -m
```

---

## 📊 Comparison Matrix

| Strategy | Downtime | Rollback Speed | Resource Usage | Complexity | Best For |
|----------|----------|----------------|----------------|------------|----------|
| **Rolling Update** | None | Fast | Low (1x) | Low | Standard releases |
| **Blue-Green** | None | Instant | High (2x) | Medium | Critical releases |
| **Canary** | None | Fast | Medium (1.1x) | Medium | Risk mitigation |
| **Shadow** | None | N/A | Medium (1.3x) | Low | Performance testing |
| **A/B Testing** | None | Medium | High (2x) | High | Feature testing |

---

## 🔍 Monitoring

### Check Status
```bash
# Get all resources
kubectl get all -n aceest-fitness

# Get pods with labels
kubectl get pods -n aceest-fitness -L app,version,track,slot

# View logs
kubectl logs -n aceest-fitness -l app=aceest-fitness --tail=50

# Resource usage (requires metrics-server)
kubectl top pods -n aceest-fitness
```

### Health Checks
```bash
# Test service endpoint
SERVICE_URL=$(minikube service <service-name> -n aceest-fitness --url)
curl $SERVICE_URL/health

# Test traffic distribution
for i in {1..20}; do 
  curl -s $SERVICE_URL/health | jq -r .version
done | sort | uniq -c
```

---

## 🛠️ Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n aceest-fitness
kubectl logs <pod-name> -n aceest-fitness
```

**Service not accessible:**
```bash
kubectl get endpoints -n aceest-fitness
kubectl describe service <service-name> -n aceest-fitness
```

**Image pull errors:**
```bash
# Check image
kubectl describe pod <pod-name> -n aceest-fitness | grep Image

# Load image into Minikube
minikube image load anildora/aceest-fitness:2.1
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **KUBERNETES_DEPLOYMENT_GUIDE.md** | Complete deployment guide with examples |
| **ROLLBACK_PROCEDURES.md** | Detailed rollback procedures for all strategies |
| **K8S_QUICK_REFERENCE.md** | Quick command reference |

---

## 🧹 Cleanup

### Delete Specific Deployment
```bash
kubectl delete -f k8s/<deployment-file>.yaml
```

### Delete All Resources
```bash
kubectl delete namespace aceest-fitness
```

### Stop Minikube
```bash
minikube stop
minikube delete  # Complete removal
```

### Using Scripts
```powershell
# Windows
.\k8s-deploy.ps1 -Strategy all -Action cleanup
```
```bash
# Linux/Mac
./k8s-deploy.sh -s all -a cleanup
```

---

## 📈 Next Steps

1. **Monitoring**: Set up Prometheus & Grafana
2. **Service Mesh**: Implement Istio for advanced traffic management
3. **CI/CD Integration**: Connect with Jenkins pipeline
4. **Logging**: Deploy EFK stack
5. **Security**: Implement NetworkPolicies and RBAC

---

## 🎓 Learning Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Deployment Strategies Guide](https://www.weave.works/blog/kubernetes-deployment-strategies)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## ✅ Assignment Verification Checklist

- [x] Minikube cluster setup and running
- [x] Namespace and ConfigMap created
- [x] Rolling Update deployment implemented
- [x] Blue-Green deployment implemented
- [x] Canary Release implemented
- [x] Shadow Deployment implemented
- [x] A/B Testing implemented
- [x] Rollback mechanisms documented and tested
- [x] Automation scripts created (Windows & Linux)
- [x] Comprehensive documentation completed
- [x] All deployments tested and verified

---

**Version:** 1.0  
**Last Updated:** November 10, 2025  
**Status:** ✅ Complete
