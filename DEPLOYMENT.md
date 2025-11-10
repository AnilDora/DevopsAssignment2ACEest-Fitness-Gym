# Deployment Guide for ACEest Fitness

## Prerequisites Checklist

Before deploying, ensure you have:

- [ ] Docker installed and running
- [ ] Kubernetes cluster (Minikube/EKS/GKE/AKS)
- [ ] kubectl configured
- [ ] Docker Hub account
- [ ] Jenkins server (for CI/CD)
- [ ] SonarQube server (for code quality)

## Step-by-Step Deployment

### Step 1: Local Development Setup

```bash
# Clone repository
git clone https://github.com/yourusername/aceest-fitness.git
cd aceest-fitness

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run locally
python app.py

# Test the application
# Open: http://localhost:5000
```

### Step 2: Run Tests

```bash
# Activate virtual environment
source venv/bin/activate

# Run unit tests
pytest test_app.py -v

# Check coverage
pytest test_app.py --cov=app --cov-report=html

# View coverage report
# Open: htmlcov/index.html
```

### Step 3: Docker Deployment

#### Build Docker Image

```bash
# Build the image
docker build -t aceest-fitness:v1.0 .

# Tag for Docker Hub
docker tag aceest-fitness:v1.0 yourdockerhub/aceest-fitness:v1.0
docker tag aceest-fitness:v1.0 yourdockerhub/aceest-fitness:latest

# Test locally
docker run -d -p 5000:5000 --name aceest-fitness aceest-fitness:v1.0

# Check logs
docker logs -f aceest-fitness

# Test health endpoint
curl http://localhost:5000/health

# Stop and remove
docker stop aceest-fitness
docker rm aceest-fitness
```

#### Push to Docker Hub

```bash
# Login to Docker Hub
docker login

# Push images
docker push yourdockerhub/aceest-fitness:v1.0
docker push yourdockerhub/aceest-fitness:latest

# Verify
# Visit: https://hub.docker.com/r/yourdockerhub/aceest-fitness
```

#### Docker Compose Deployment

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f aceest-fitness

# Scale application
docker-compose up -d --scale aceest-fitness=3

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Step 4: Kubernetes Deployment

#### Setup Kubernetes Cluster

**Option 1: Minikube (Local)**

```bash
# Install Minikube
# Windows: choco install minikube
# Mac: brew install minikube
# Linux: See official docs

# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server

# Check status
kubectl cluster-info
kubectl get nodes
```

**Option 2: AWS EKS**

```bash
# Install eksctl
# Windows: choco install eksctl
# Mac: brew install eksctl

# Create cluster
eksctl create cluster \
  --name aceest-fitness-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed

# Configure kubectl
aws eks update-kubeconfig --name aceest-fitness-cluster --region us-east-1
```

**Option 3: GKE (Google Cloud)**

```bash
# Install gcloud CLI
# See: https://cloud.google.com/sdk/docs/install

# Create cluster
gcloud container clusters create aceest-fitness-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Get credentials
gcloud container clusters get-credentials aceest-fitness-cluster --zone us-central1-a
```

#### Deploy to Kubernetes

```bash
# Create namespace
kubectl create namespace aceest-fitness

# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Check deployment
kubectl get all -n aceest-fitness

# Watch deployment
kubectl rollout status deployment/aceest-fitness-deployment -n aceest-fitness

# Get service external IP
kubectl get svc -n aceest-fitness

# Wait for LoadBalancer IP
kubectl get svc aceest-fitness-service -n aceest-fitness --watch
```

#### Access Application

```bash
# Get service URL
SERVICE_IP=$(kubectl get svc aceest-fitness-service -n aceest-fitness -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://${SERVICE_IP}"

# Or use port-forward for testing
kubectl port-forward -n aceest-fitness svc/aceest-fitness-service 8080:80

# Access: http://localhost:8080
```

### Step 5: Jenkins CI/CD Setup

#### Install Jenkins

**Using Docker:**

```bash
# Create volume for Jenkins data
docker volume create jenkins_home

# Run Jenkins
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Access Jenkins: http://localhost:8080
```

#### Configure Jenkins

1. **Install Required Plugins:**
   - Git Plugin
   - Docker Pipeline Plugin
   - Kubernetes Plugin
   - SonarQube Scanner
   - Email Extension Plugin
   - Blue Ocean (optional)

2. **Add Credentials:**

   ```
   Dashboard → Manage Jenkins → Credentials → System → Global credentials
   
   Add:
   - dockerhub-credentials (Username with password)
   - github-credentials (Username with password/token)
   - kubeconfig (Secret file)
   ```

3. **Configure Tools:**

   ```
   Dashboard → Manage Jenkins → Global Tool Configuration
   
   Add:
   - JDK (if needed)
   - Git
   - Docker
   - SonarQube Scanner
   ```

4. **Configure SonarQube:**

   ```
   Dashboard → Manage Jenkins → Configure System
   
   SonarQube servers:
   - Name: SonarQube
   - Server URL: http://sonarqube:9000
   - Server authentication token: (add from credentials)
   ```

#### Create Pipeline Job

```bash
# 1. New Item → Pipeline
# 2. Pipeline:
#    - Definition: Pipeline script from SCM
#    - SCM: Git
#    - Repository URL: https://github.com/yourusername/aceest-fitness.git
#    - Credentials: github-credentials
#    - Branch: */main
#    - Script Path: Jenkinsfile

# 3. Build Triggers:
#    - ✓ GitHub hook trigger for GITScm polling

# 4. Save and Build
```

#### Setup GitHub Webhook

```bash
# 1. Go to GitHub repository
# 2. Settings → Webhooks → Add webhook
# 3. Payload URL: http://jenkins-url:8080/github-webhook/
# 4. Content type: application/json
# 5. Events: Just the push event
# 6. Active: ✓
# 7. Add webhook
```

### Step 6: SonarQube Setup

```bash
# Run SonarQube
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:latest

# Access SonarQube: http://localhost:9000
# Default credentials: admin/admin

# 1. Create new project
#    - Project key: aceest-fitness
#    - Display name: ACEest Fitness

# 2. Generate token
#    - My Account → Security → Generate Token
#    - Copy token

# 3. Add token to Jenkins credentials
#    - Jenkins → Credentials → Add → Secret text
#    - ID: sonarqube-token
```

### Step 7: Deployment Strategies

#### Rolling Update

```bash
# Update deployment with new image
kubectl set image deployment/aceest-fitness-deployment \
  aceest-fitness=yourdockerhub/aceest-fitness:v2.0 \
  -n aceest-fitness

# Watch rollout
kubectl rollout status deployment/aceest-fitness-deployment -n aceest-fitness

# Check history
kubectl rollout history deployment/aceest-fitness-deployment -n aceest-fitness

# Rollback if needed
kubectl rollout undo deployment/aceest-fitness-deployment -n aceest-fitness
```

#### Blue-Green Deployment

```bash
# Deploy blue-green configuration
kubectl apply -f k8s/blue-green-deployment.yaml

# Deploy new version to green
kubectl set image deployment/aceest-fitness-green \
  aceest-fitness=yourdockerhub/aceest-fitness:v2.0 \
  -n aceest-fitness

# Wait for green to be ready
kubectl rollout status deployment/aceest-fitness-green -n aceest-fitness

# Test green environment
kubectl port-forward -n aceest-fitness svc/aceest-fitness-green-test 8081:80
# Test: http://localhost:8081

# Switch traffic to green
kubectl patch service aceest-fitness-bluegreen -n aceest-fitness \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback to blue if needed
kubectl patch service aceest-fitness-bluegreen -n aceest-fitness \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

#### Canary Deployment

```bash
# Deploy canary configuration
kubectl apply -f k8s/canary-deployment.yaml

# Start with 10% canary traffic
kubectl scale deployment/aceest-fitness-stable --replicas=9 -n aceest-fitness
kubectl scale deployment/aceest-fitness-canary --replicas=1 -n aceest-fitness

# Monitor metrics, then increase to 50%
kubectl scale deployment/aceest-fitness-stable --replicas=5 -n aceest-fitness
kubectl scale deployment/aceest-fitness-canary --replicas=5 -n aceest-fitness

# Promote canary to stable
CANARY_IMAGE=$(kubectl get deployment aceest-fitness-canary -n aceest-fitness \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

kubectl set image deployment/aceest-fitness-stable \
  aceest-fitness=$CANARY_IMAGE \
  -n aceest-fitness

# Reset replica counts
kubectl scale deployment/aceest-fitness-stable --replicas=9 -n aceest-fitness
kubectl scale deployment/aceest-fitness-canary --replicas=1 -n aceest-fitness
```

### Step 8: Monitoring and Verification

```bash
# Check deployment status
kubectl get deployments -n aceest-fitness
kubectl get pods -n aceest-fitness
kubectl get services -n aceest-fitness
kubectl get hpa -n aceest-fitness

# View pod logs
kubectl logs -f deployment/aceest-fitness-deployment -n aceest-fitness

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name> -n aceest-fitness

# Check resource usage
kubectl top nodes
kubectl top pods -n aceest-fitness

# Test health endpoint
curl http://<SERVICE_IP>/health

# Test metrics endpoint
curl http://<SERVICE_IP>/metrics

# Port forward for local testing
kubectl port-forward -n aceest-fitness svc/aceest-fitness-service 8080:80
```

### Step 9: Horizontal Pod Autoscaling

```bash
# HPA is already configured in deployment.yaml
# It will scale based on:
# - CPU: 70% utilization
# - Memory: 80% utilization
# - Min replicas: 2
# - Max replicas: 10

# Check HPA status
kubectl get hpa -n aceest-fitness

# Describe HPA
kubectl describe hpa aceest-fitness-hpa -n aceest-fitness

# Test autoscaling with load
# Install hey (HTTP load generator)
# Windows: choco install hey
# Mac: brew install hey

# Generate load
hey -z 60s -c 50 http://<SERVICE_IP>/

# Watch HPA scale up
kubectl get hpa -n aceest-fitness --watch
```

### Step 10: Backup and Disaster Recovery

```bash
# Export Kubernetes resources
kubectl get all -n aceest-fitness -o yaml > backup.yaml

# Backup using Velero (recommended)
# Install Velero
velero install --provider aws --plugins velero/velero-plugin-for-aws:v1.2.0 \
  --bucket aceest-fitness-backup \
  --backup-location-config region=us-east-1

# Create backup
velero backup create aceest-fitness-backup --include-namespaces aceest-fitness

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup aceest-fitness-backup
```

## Troubleshooting

### Common Issues

#### 1. Pods not starting

```bash
# Check pod status
kubectl get pods -n aceest-fitness

# Describe pod to see events
kubectl describe pod <pod-name> -n aceest-fitness

# Check logs
kubectl logs <pod-name> -n aceest-fitness

# Common fixes:
# - Image pull errors: Check Docker Hub credentials
# - Resource limits: Adjust in deployment.yaml
# - Config errors: Check ConfigMap and Secrets
```

#### 2. Service not accessible

```bash
# Check service
kubectl get svc -n aceest-fitness

# Check endpoints
kubectl get endpoints -n aceest-fitness

# Test from within cluster
kubectl run test-pod --rm -it --image=curlimages/curl -- sh
curl http://aceest-fitness-service.aceest-fitness.svc.cluster.local/health
```

#### 3. Jenkins build failures

```bash
# Check Jenkins logs
docker logs -f jenkins

# Check workspace
# Jenkins → Job → Workspace

# Common fixes:
# - Credentials: Verify all credentials are set
# - Docker socket: Ensure Docker socket is mounted
# - Kubernetes config: Verify kubeconfig file
```

## Production Checklist

Before going to production:

- [ ] All tests passing
- [ ] Code quality gate passed
- [ ] Security scan completed
- [ ] Secrets properly configured
- [ ] Resource limits set
- [ ] Health checks configured
- [ ] Monitoring set up
- [ ] Backup strategy in place
- [ ] SSL/TLS configured
- [ ] Domain name configured
- [ ] Autoscaling tested
- [ ] Disaster recovery plan documented
- [ ] Team trained on operations

## Maintenance

### Regular Tasks

```bash
# Update dependencies
pip list --outdated
pip install -r requirements.txt --upgrade

# Update Docker image
docker pull python:3.11-slim

# Update Kubernetes
kubectl version

# Check for security updates
docker scan yourdockerhub/aceest-fitness:latest
```

### Monitoring

```bash
# Setup Prometheus and Grafana (optional)
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Username: admin
# Password: prom-operator
```

---

**Deployment Complete! 🎉**

Your ACEest Fitness application is now running in production with:
- ✅ Automated CI/CD pipeline
- ✅ Container orchestration
- ✅ Multiple deployment strategies
- ✅ Autoscaling capabilities
- ✅ Monitoring and health checks
