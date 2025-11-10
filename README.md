# ACEest Fitness & Gym Management System
## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                          │
│              (Flask Web Application)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                   CI/CD Pipeline                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  GitHub  │─▶│ Jenkins  │─▶│  Docker  │─▶│   K8s    │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────┐       ┌────────▼──────┐
│   SonarQube   │       │    Docker     │
│ Code Quality  │       │     Hub       │
└───────────────┘       └───────────────┘
                               │
                     ┌─────────▼──────────┐
                     │  Kubernetes Cluster │
                     │  ┌──────────────┐  │
                     │  │  Deployments │  │
                     │  │   Services   │  │
                     │  │     Pods     │  │
                     │  │     HPA      │  │
                     │  └──────────────┘  │
                     └────────────────────┘
```
## SONAR SCAN REPORT(Running locally):

![alt text](image-21.png)

![alt text](image-22.png)

![alt text](image-23.png)

![alt text](image-24.png)

## UNIT TEST CASE REPORT:

![alt text](image-20.png)

![alt text](image-19.png)

## DOCKER IMAGES:
![alt text](image-1.png)


## MINIKUBE RUNNING SERVICE:

![alt text](image-12.png)


## Application Running Screen shot:

![alt text](image-13.png)


## MINIKUBE SCREEN SHOT FOR RUNNING PODS:

![alt text](image.png)

## SHOWING KUBERNETES DASHBOARD:

![alt text](image-2.png)


## POD:

![alt text](image-3.png)

## SERVICES:

![alt text](image-4.png)

## CONFIG MAPS:

![alt text](image-5.png)

## Rolling out Deployment:

![alt text](image-6.png)

## SCALING PODS:

![alt text](image-7.png)


## BLUE GREEN DEPLOYMENT:


![alt text](image-16.png)

## CANARY DEPLOYMENT:

kubectl apply -f "C:\BITS-Mine\Assignment\Devops\Assignment 2\Project\k8s\canary-deployment.yaml"
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

## Shadow Deployment:

kubectl apply -f "C:\BITS-Mine\Assignment\Devops\Assignment 2\Project\k8s\shadow-deployment.yaml"
kubectl rollout status deployment/aceest-fitness-production -n aceest-fitness
kubectl rollout status deployment/aceest-fitness-shadow -n aceest-fitness




