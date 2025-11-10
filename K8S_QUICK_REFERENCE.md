# Kubernetes Quick Reference - ACEest Fitness
# All commands for deployment strategies

## Setup Commands

# Start Minikube
minikube start --driver=docker --memory=4096 --cpus=2

# Check status
minikube status
kubectl cluster-info

# Create namespace and configmap
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

## Using Automation Scripts

### Windows PowerShell
# Deploy specific strategy
.\k8s-deploy.ps1 -Strategy rolling -Action deploy -StartMinikube

# All strategies
.\k8s-deploy.ps1 -Strategy all -Action deploy

# Rollback
.\k8s-deploy.ps1 -Strategy rolling -Action rollback

# Test
.\k8s-deploy.ps1 -Strategy rolling -Action test

# Cleanup
.\k8s-deploy.ps1 -Strategy rolling -Action cleanup

### Linux/Mac Bash
# Deploy specific strategy
./k8s-deploy.sh -s rolling -a deploy -m

# All strategies
./k8s-deploy.sh -s all -a deploy

# Rollback
./k8s-deploy.sh -s rolling -a rollback

# Test
./k8s-deploy.sh -s rolling -a test

# Cleanup
./k8s-deploy.sh -s rolling -a cleanup

## Manual Deployment Commands

### 1. Rolling Update
kubectl apply -f k8s/rolling-update-deployment.yaml
kubectl rollout status deployment/aceest-fitness-rolling -n aceest-fitness
minikube service aceest-fitness-rolling-service -n aceest-fitness --url

# Update image
kubectl set image deployment/aceest-fitness-rolling aceest-fitness=anildora/aceest-fitness:2.2 -n aceest-fitness

# Rollback
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness
kubectl rollout history deployment/aceest-fitness-rolling -n aceest-fitness

### 2. Blue-Green
kubectl apply -f k8s/blue-green-deployment.yaml
kubectl rollout status deployment/aceest-fitness-blue -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-green -n aceest-fitness

# Check current active
kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness -o jsonpath='{.spec.selector.slot}'

# Switch to green
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness -p '{"spec":{"selector":{"slot":"green"}}}'

# Switch back to blue (rollback)
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness -p '{"spec":{"selector":{"slot":"blue"}}}'

# Get URLs
minikube service aceest-fitness-bluegreen-service -n aceest-fitness --url
minikube service aceest-fitness-blue-test -n aceest-fitness --url
minikube service aceest-fitness-green-test -n aceest-fitness --url

### 3. Canary
kubectl apply -f k8s/canary-deployment.yaml
kubectl rollout status deployment/aceest-fitness-stable -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-canary -n aceest-fitness

# Increase canary traffic (20%)
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=8
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=2

# 50/50 split
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=5
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=5

# Complete rollout to canary
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=10

# Rollback (remove canary)
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=10

# Get URL
minikube service aceest-fitness-canary-service -n aceest-fitness --url

### 4. Shadow
kubectl apply -f k8s/shadow-deployment.yaml
kubectl rollout status deployment/aceest-fitness-production -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-shadow -n aceest-fitness

# Get URLs
minikube service aceest-fitness-production-service -n aceest-fitness --url
minikube service aceest-fitness-shadow-service -n aceest-fitness --url

# Rollback (delete shadow)
kubectl delete deployment aceest-fitness-shadow -n aceest-fitness

### 5. A/B Testing
kubectl apply -f k8s/ab-testing-deployment.yaml
kubectl rollout status deployment/aceest-fitness-version-a -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-version-b -n aceest-fitness

# Adjust traffic (70/30)
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=7
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=3

# Complete rollout to version B
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=10

# Rollback (remove version B)
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=0
kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=10

# Get URLs
minikube service aceest-fitness-ab-service -n aceest-fitness --url
minikube service aceest-fitness-version-a -n aceest-fitness --url
minikube service aceest-fitness-version-b -n aceest-fitness --url

## Monitoring Commands

# Get all resources
kubectl get all -n aceest-fitness

# Get deployments
kubectl get deployments -n aceest-fitness

# Get pods with labels
kubectl get pods -n aceest-fitness -L app,version,track,slot

# Get services
kubectl get services -n aceest-fitness

# Get endpoints
kubectl get endpoints -n aceest-fitness

# Watch pods
kubectl get pods -n aceest-fitness -w

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n aceest-fitness

# View rollout history
kubectl rollout history deployment/<deployment-name> -n aceest-fitness

## Logging Commands

# View logs (all pods)
kubectl logs -n aceest-fitness -l app=aceest-fitness --tail=50

# Follow logs
kubectl logs -n aceest-fitness -l app=aceest-fitness -f

# Specific deployment logs
kubectl logs -n aceest-fitness -l deployment-strategy=rolling-update --tail=50

# Pod logs
kubectl logs <pod-name> -n aceest-fitness

## Resource Monitoring

# Enable metrics server
minikube addons enable metrics-server

# Pod resource usage
kubectl top pods -n aceest-fitness

# Node resource usage
kubectl top nodes

## Testing Commands

# Test health endpoint (replace with actual URL)
curl <service-url>/health

# Test traffic distribution (canary/AB testing)
for i in {1..20}; do curl -s <service-url>/health | jq -r .version; done | sort | uniq -c

# Port forward for local testing
kubectl port-forward service/<service-name> -n aceest-fitness 8080:80

# Execute command in pod
kubectl exec -it <pod-name> -n aceest-fitness -- /bin/sh

## Debugging Commands

# Describe resource
kubectl describe deployment <deployment-name> -n aceest-fitness
kubectl describe pod <pod-name> -n aceest-fitness
kubectl describe service <service-name> -n aceest-fitness

# Get events
kubectl get events -n aceest-fitness --sort-by='.lastTimestamp'

# Get YAML
kubectl get deployment <deployment-name> -n aceest-fitness -o yaml
kubectl get pod <pod-name> -n aceest-fitness -o yaml

# Check service endpoints
kubectl get endpoints <service-name> -n aceest-fitness

## Cleanup Commands

# Delete specific deployment
kubectl delete -f k8s/rolling-update-deployment.yaml
kubectl delete -f k8s/blue-green-deployment.yaml
kubectl delete -f k8s/canary-deployment.yaml
kubectl delete -f k8s/shadow-deployment.yaml
kubectl delete -f k8s/ab-testing-deployment.yaml

# Delete specific resources
kubectl delete deployment <deployment-name> -n aceest-fitness
kubectl delete service <service-name> -n aceest-fitness

# Delete entire namespace (removes everything)
kubectl delete namespace aceest-fitness

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete

## Useful One-Liners

# Get all pod names
kubectl get pods -n aceest-fitness -o jsonpath='{.items[*].metadata.name}'

# Get all service URLs (requires loop)
for svc in $(kubectl get services -n aceest-fitness -o jsonpath='{.items[*].metadata.name}'); do
  echo "$svc: $(minikube service $svc -n aceest-fitness --url 2>/dev/null)"
done

# Check which pods are ready
kubectl get pods -n aceest-fitness -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Count pods by label
kubectl get pods -n aceest-fitness -l app=aceest-fitness --no-headers | wc -l

# Restart all pods in deployment
kubectl rollout restart deployment/<deployment-name> -n aceest-fitness

# Scale deployment
kubectl scale deployment/<deployment-name> -n aceest-fitness --replicas=5

# Update image
kubectl set image deployment/<deployment-name> <container-name>=<image>:<tag> -n aceest-fitness

## Emergency Commands

# Force delete pod
kubectl delete pod <pod-name> -n aceest-fitness --force --grace-period=0

# Drain node (for maintenance)
kubectl drain <node-name> --ignore-daemonsets

# Uncordon node
kubectl uncordon <node-name>

# Get cluster info
kubectl cluster-info dump

## Minikube Specific

# SSH into Minikube VM
minikube ssh

# Access Kubernetes dashboard
minikube dashboard

# List addons
minikube addons list

# Enable addon
minikube addons enable <addon-name>

# Get Minikube IP
minikube ip

# Load local Docker image into Minikube
minikube image load <image-name>:<tag>

# List images in Minikube
minikube image ls

## Automation Script Examples

# Windows - Deploy all strategies
.\k8s-deploy.ps1 -Strategy all -Action deploy -StartMinikube

# Windows - Test specific strategy
.\k8s-deploy.ps1 -Strategy blue-green -Action test

# Windows - Switch blue-green
.\k8s-deploy.ps1 -Strategy blue-green -Action switch

# Linux/Mac - Deploy all strategies
./k8s-deploy.sh --strategy all --action deploy --start-minikube

# Linux/Mac - Test specific strategy
./k8s-deploy.sh -s canary -a test

# Linux/Mac - Rollback
./k8s-deploy.sh -s rolling -a rollback
