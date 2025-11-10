# Kubernetes Rollback Procedures for ACEest Fitness

## Quick Rollback Commands

### 1. Rolling Update Rollback

```bash
# View rollout history
kubectl rollout history deployment/aceest-fitness-rolling -n aceest-fitness

# Rollback to previous version
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness

# Rollback to specific revision
kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness --to-revision=2

# Check rollback status
kubectl rollout status deployment/aceest-fitness-rolling -n aceest-fitness
```

### 2. Blue-Green Rollback

```bash
# Switch service back to BLUE (stable)
kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
  -p '{"spec":{"selector":{"slot":"blue"}}}'

# Verify the switch
kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness -o yaml | grep slot

# Test the rollback
minikube service aceest-fitness-bluegreen-service -n aceest-fitness --url
```

### 3. Canary Rollback

```bash
# Scale down canary to 0 (100% to stable)
kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0

# Verify canary is scaled down
kubectl get deployment aceest-fitness-canary -n aceest-fitness

# Or delete canary deployment entirely
kubectl delete deployment aceest-fitness-canary -n aceest-fitness
```

### 4. Shadow Deployment Rollback

```bash
# Shadow deployment doesn't affect production, just delete it
kubectl delete deployment aceest-fitness-shadow -n aceest-fitness
kubectl delete service aceest-fitness-shadow-service -n aceest-fitness

# Or keep it running but fix issues
kubectl set image deployment/aceest-fitness-shadow \
  aceest-fitness=anildora/aceest-fitness:2.0 -n aceest-fitness
```

### 5. A/B Testing Rollback

```bash
# Option 1: Scale down version B (treatment)
kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=0

# Option 2: Delete version B deployment
kubectl delete deployment aceest-fitness-version-b -n aceest-fitness

# Option 3: Update service to only route to version A
kubectl patch service aceest-fitness-ab-service -n aceest-fitness \
  -p '{"spec":{"selector":{"variant":"control"}}}'
```

---

## Detailed Rollback Procedures

### Rolling Update Rollback Process

1. **Check current status:**
   ```bash
   kubectl get deployment aceest-fitness-rolling -n aceest-fitness
   kubectl describe deployment aceest-fitness-rolling -n aceest-fitness
   ```

2. **View revision history:**
   ```bash
   kubectl rollout history deployment/aceest-fitness-rolling -n aceest-fitness
   kubectl rollout history deployment/aceest-fitness-rolling -n aceest-fitness --revision=3
   ```

3. **Pause rollout (if in progress):**
   ```bash
   kubectl rollout pause deployment/aceest-fitness-rolling -n aceest-fitness
   ```

4. **Execute rollback:**
   ```bash
   kubectl rollout undo deployment/aceest-fitness-rolling -n aceest-fitness
   ```

5. **Monitor rollback:**
   ```bash
   kubectl rollout status deployment/aceest-fitness-rolling -n aceest-fitness
   kubectl get pods -n aceest-fitness -l app=aceest-fitness -w
   ```

6. **Verify rollback:**
   ```bash
   kubectl get pods -n aceest-fitness -l deployment-strategy=rolling-update
   curl $(minikube service aceest-fitness-rolling-service -n aceest-fitness --url)/health
   ```

### Blue-Green Rollback Process

1. **Identify current active environment:**
   ```bash
   kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness -o jsonpath='{.spec.selector.slot}'
   ```

2. **Test the target environment (before switch):**
   ```bash
   # Test blue deployment
   curl $(minikube service aceest-fitness-blue-test -n aceest-fitness --url)/health
   
   # Test green deployment
   curl $(minikube service aceest-fitness-green-test -n aceest-fitness --url)/health
   ```

3. **Switch service selector:**
   ```bash
   # If currently on green, switch to blue
   kubectl patch service aceest-fitness-bluegreen-service -n aceest-fitness \
     -p '{"spec":{"selector":{"slot":"blue"}}}'
   ```

4. **Verify the switch:**
   ```bash
   kubectl get service aceest-fitness-bluegreen-service -n aceest-fitness -o yaml
   kubectl get endpoints aceest-fitness-bluegreen-service -n aceest-fitness
   ```

5. **Test production traffic:**
   ```bash
   curl $(minikube service aceest-fitness-bluegreen-service -n aceest-fitness --url)/health
   ```

6. **Keep green deployment for quick re-deployment (optional):**
   ```bash
   # Or scale it down to save resources
   kubectl scale deployment aceest-fitness-green -n aceest-fitness --replicas=1
   ```

### Canary Rollback Process

1. **Check canary metrics:**
   ```bash
   kubectl get deployment -n aceest-fitness -l deployment-strategy=canary
   kubectl top pods -n aceest-fitness -l track=canary
   ```

2. **Gradually reduce canary traffic:**
   ```bash
   # Reduce from 10% to 5% (1 pod out of 20)
   kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=19
   kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=1
   
   # Wait and monitor...
   
   # Complete rollback (0%)
   kubectl scale deployment aceest-fitness-canary -n aceest-fitness --replicas=0
   kubectl scale deployment aceest-fitness-stable -n aceest-fitness --replicas=10
   ```

3. **Verify traffic distribution:**
   ```bash
   for i in {1..20}; do 
     curl -s $(minikube service aceest-fitness-canary-service -n aceest-fitness --url)/health | jq -r .version
   done | sort | uniq -c
   ```

4. **Complete cleanup (optional):**
   ```bash
   kubectl delete deployment aceest-fitness-canary -n aceest-fitness
   kubectl delete service aceest-fitness-canary-test -n aceest-fitness
   ```

### Shadow Deployment Rollback

Shadow deployments don't receive production traffic, so "rollback" means:

1. **Fix the shadow deployment:**
   ```bash
   # Update to previous working version
   kubectl set image deployment/aceest-fitness-shadow \
     aceest-fitness=anildora/aceest-fitness:2.0 -n aceest-fitness
   ```

2. **Or remove it completely:**
   ```bash
   kubectl delete deployment aceest-fitness-shadow -n aceest-fitness
   kubectl delete service aceest-fitness-shadow-service -n aceest-fitness
   ```

3. **Production remains unaffected:**
   ```bash
   kubectl get deployment aceest-fitness-production -n aceest-fitness
   curl $(minikube service aceest-fitness-production-service -n aceest-fitness --url)/health
   ```

### A/B Testing Rollback

1. **Check current traffic distribution:**
   ```bash
   kubectl get deployment -n aceest-fitness -l deployment-strategy=ab-testing
   ```

2. **Option 1 - Gradual rollback (reduce B traffic):**
   ```bash
   # Move from 50/50 to 70/30 (A/B)
   kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=7
   kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=3
   
   # Move to 90/10
   kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=9
   kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=1
   
   # Complete rollback to A
   kubectl scale deployment aceest-fitness-version-a -n aceest-fitness --replicas=10
   kubectl scale deployment aceest-fitness-version-b -n aceest-fitness --replicas=0
   ```

3. **Option 2 - Immediate rollback (switch service):**
   ```bash
   kubectl patch service aceest-fitness-ab-service -n aceest-fitness \
     -p '{"spec":{"selector":{"variant":"control"}}}'
   ```

4. **Verify rollback:**
   ```bash
   for i in {1..10}; do 
     curl -s $(minikube service aceest-fitness-ab-service -n aceest-fitness --url)/health | jq -r .version
   done | sort | uniq -c
   ```

---

## Emergency Rollback (All Strategies)

### Nuclear Option - Revert Everything

```bash
# Delete all new deployments
kubectl delete deployment aceest-fitness-rolling -n aceest-fitness
kubectl delete deployment aceest-fitness-green -n aceest-fitness
kubectl delete deployment aceest-fitness-canary -n aceest-fitness
kubectl delete deployment aceest-fitness-shadow -n aceest-fitness
kubectl delete deployment aceest-fitness-version-b -n aceest-fitness

# Keep only stable/baseline deployments
kubectl get deployment -n aceest-fitness

# Deploy base stable version
kubectl apply -f k8s/base-deployment.yaml
```

### Quick Health Check Script

```bash
#!/bin/bash
# Check health of all deployments

echo "=== Deployment Health Check ==="

echo -e "\n1. Rolling Update:"
kubectl get deployment aceest-fitness-rolling -n aceest-fitness 2>/dev/null || echo "Not deployed"

echo -e "\n2. Blue-Green:"
kubectl get deployment aceest-fitness-blue aceest-fitness-green -n aceest-fitness 2>/dev/null || echo "Not deployed"

echo -e "\n3. Canary:"
kubectl get deployment aceest-fitness-stable aceest-fitness-canary -n aceest-fitness 2>/dev/null || echo "Not deployed"

echo -e "\n4. Shadow:"
kubectl get deployment aceest-fitness-production aceest-fitness-shadow -n aceest-fitness 2>/dev/null || echo "Not deployed"

echo -e "\n5. A/B Testing:"
kubectl get deployment aceest-fitness-version-a aceest-fitness-version-b -n aceest-fitness 2>/dev/null || echo "Not deployed"

echo -e "\n=== Pod Status ==="
kubectl get pods -n aceest-fitness
```

---

## Rollback Decision Matrix

| Scenario | Strategy | Rollback Method | Downtime |
|----------|----------|-----------------|----------|
| Bad code in rolling update | Rolling | `kubectl rollout undo` | None |
| Green version failing | Blue-Green | Switch service to blue | None |
| Canary showing errors | Canary | Scale canary to 0 | None |
| Shadow test failures | Shadow | Delete or fix shadow | None (prod unaffected) |
| Version B performing poorly | A/B Test | Scale B to 0 or switch service | None |
| Complete cluster failure | All | Redeploy from base | Minimal |

---

## Post-Rollback Checklist

1. ✅ **Verify pod status:**
   ```bash
   kubectl get pods -n aceest-fitness
   ```

2. ✅ **Check service endpoints:**
   ```bash
   kubectl get endpoints -n aceest-fitness
   ```

3. ✅ **Test application:**
   ```bash
   curl $(minikube service <service-name> -n aceest-fitness --url)/health
   ```

4. ✅ **Check logs:**
   ```bash
   kubectl logs -n aceest-fitness -l app=aceest-fitness --tail=50
   ```

5. ✅ **Monitor metrics:**
   ```bash
   kubectl top pods -n aceest-fitness
   ```

6. ✅ **Document incident:**
   - What went wrong
   - When it was detected
   - Rollback method used
   - Time to recovery
   - Lessons learned

---

## Prevention Best Practices

1. **Always test in lower environments first**
2. **Use gradual rollouts (canary/A-B)**
3. **Monitor metrics during deployment**
4. **Set up automated health checks**
5. **Have rollback scripts ready**
6. **Document rollback procedures**
7. **Practice rollbacks regularly**
8. **Keep previous versions available**
9. **Use immutable infrastructure**
10. **Implement circuit breakers**
