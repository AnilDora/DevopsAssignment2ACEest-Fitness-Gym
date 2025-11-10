#!/bin/bash

# Kubernetes Deployment Automation Script for Linux/Mac
# ACEest Fitness - All Deployment Strategies

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
STRATEGY="rolling"
ACTION="deploy"
NAMESPACE="aceest-fitness"
START_MINIKUBE=false
DRY_RUN=false

# Print colored output
print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -s, --strategy <strategy>    Deployment strategy (rolling|blue-green|canary|shadow|ab-testing|all)
    -a, --action <action>        Action to perform (deploy|rollback|switch|test|cleanup)
    -n, --namespace <namespace>  Kubernetes namespace (default: aceest-fitness)
    -m, --start-minikube         Start Minikube if not running
    -d, --dry-run                Perform dry-run
    -h, --help                   Show this help message

EXAMPLES:
    $0 --strategy rolling --action deploy
    $0 -s blue-green -a switch
    $0 -s canary -a test
    $0 -s all -a deploy -m

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--strategy)
            STRATEGY="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -m|--start-minikube)
            START_MINIKUBE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_info "\n=== Checking Prerequisites ===\n"
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        local kubectl_version=$(kubectl version --client --short 2>&1 | head -n1)
        print_success "✓ kubectl is installed: $kubectl_version"
    else
        print_error "✗ kubectl is not installed or not in PATH"
        return 1
    fi
    
    # Check minikube
    if command -v minikube &> /dev/null; then
        local minikube_version=$(minikube version --short 2>&1)
        print_success "✓ minikube is installed: $minikube_version"
    else
        print_error "✗ minikube is not installed or not in PATH"
        return 1
    fi
    
    return 0
}

# Start Minikube if needed
start_minikube() {
    print_info "\n=== Starting Minikube ===\n"
    
    local status=$(minikube status --format='{{.Host}}' 2>&1 || echo "Stopped")
    
    if [[ "$status" == "Running" ]]; then
        print_success "✓ Minikube is already running"
        return 0
    fi
    
    print_warning "Starting Minikube cluster..."
    minikube start --driver=docker --memory=4096 --cpus=2
    
    if [[ $? -eq 0 ]]; then
        print_success "✓ Minikube started successfully"
        return 0
    else
        print_error "✗ Failed to start Minikube"
        return 1
    fi
}

# Create namespace
create_namespace() {
    print_info "\n=== Creating Namespace ===\n"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "✓ Namespace '$NAMESPACE' already exists"
    else
        print_info "Creating namespace '$NAMESPACE'..."
        kubectl apply -f k8s/namespace.yaml
        kubectl apply -f k8s/configmap.yaml
        print_success "✓ Namespace created"
    fi
}

# Deploy strategies
deploy_rolling() {
    print_info "\n=== Deploying Rolling Update Strategy ===\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f k8s/rolling-update-deployment.yaml --dry-run=client
    else
        kubectl apply -f k8s/rolling-update-deployment.yaml
        kubectl rollout status deployment/aceest-fitness-rolling -n "$NAMESPACE" --timeout=5m
        
        if [[ $? -eq 0 ]]; then
            print_success "\n✓ Rolling Update deployment successful"
            local url=$(minikube service aceest-fitness-rolling-service -n "$NAMESPACE" --url)
            print_info "Service URL: $url"
        fi
    fi
}

deploy_blue_green() {
    print_info "\n=== Deploying Blue-Green Strategy ===\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f k8s/blue-green-deployment.yaml --dry-run=client
    else
        kubectl apply -f k8s/blue-green-deployment.yaml
        
        print_info "Waiting for Blue deployment..."
        kubectl rollout status deployment/aceest-fitness-blue -n "$NAMESPACE" --timeout=5m
        
        print_info "Waiting for Green deployment..."
        kubectl rollout status deployment/aceest-fitness-green -n "$NAMESPACE" --timeout=5m
        
        if [[ $? -eq 0 ]]; then
            print_success "\n✓ Blue-Green deployment successful"
            print_info "Production service (currently BLUE):"
            local url=$(minikube service aceest-fitness-bluegreen-service -n "$NAMESPACE" --url)
            print_info "  Main: $url"
            
            print_info "\nDirect access URLs:"
            print_info "  Blue:  $(minikube service aceest-fitness-blue-test -n "$NAMESPACE" --url)"
            print_info "  Green: $(minikube service aceest-fitness-green-test -n "$NAMESPACE" --url)"
        fi
    fi
}

deploy_canary() {
    print_info "\n=== Deploying Canary Strategy ===\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f k8s/canary-deployment.yaml --dry-run=client
    else
        kubectl apply -f k8s/canary-deployment.yaml
        
        print_info "Waiting for Stable deployment..."
        kubectl rollout status deployment/aceest-fitness-stable -n "$NAMESPACE" --timeout=5m
        
        print_info "Waiting for Canary deployment..."
        kubectl rollout status deployment/aceest-fitness-canary -n "$NAMESPACE" --timeout=5m
        
        if [[ $? -eq 0 ]]; then
            print_success "\n✓ Canary deployment successful (90% stable, 10% canary)"
            local url=$(minikube service aceest-fitness-canary-service -n "$NAMESPACE" --url)
            print_info "Service URL: $url"
            
            print_warning "\nTo gradually increase canary traffic:"
            print_info "  kubectl scale deployment aceest-fitness-stable -n $NAMESPACE --replicas=5"
            print_info "  kubectl scale deployment aceest-fitness-canary -n $NAMESPACE --replicas=5"
        fi
    fi
}

deploy_shadow() {
    print_info "\n=== Deploying Shadow Strategy ===\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f k8s/shadow-deployment.yaml --dry-run=client
    else
        kubectl apply -f k8s/shadow-deployment.yaml
        
        print_info "Waiting for Production deployment..."
        kubectl rollout status deployment/aceest-fitness-production -n "$NAMESPACE" --timeout=5m
        
        print_info "Waiting for Shadow deployment..."
        kubectl rollout status deployment/aceest-fitness-shadow -n "$NAMESPACE" --timeout=5m
        
        if [[ $? -eq 0 ]]; then
            print_success "\n✓ Shadow deployment successful"
            print_info "Production: $(minikube service aceest-fitness-production-service -n "$NAMESPACE" --url)"
            print_info "Shadow:     $(minikube service aceest-fitness-shadow-service -n "$NAMESPACE" --url)"
        fi
    fi
}

deploy_ab_testing() {
    print_info "\n=== Deploying A/B Testing Strategy ===\n"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f k8s/ab-testing-deployment.yaml --dry-run=client
    else
        kubectl apply -f k8s/ab-testing-deployment.yaml
        
        print_info "Waiting for Version A deployment..."
        kubectl rollout status deployment/aceest-fitness-version-a -n "$NAMESPACE" --timeout=5m
        
        print_info "Waiting for Version B deployment..."
        kubectl rollout status deployment/aceest-fitness-version-b -n "$NAMESPACE" --timeout=5m
        
        if [[ $? -eq 0 ]]; then
            print_success "\n✓ A/B Testing deployment successful (50/50 split)"
            print_info "Main service (50/50): $(minikube service aceest-fitness-ab-service -n "$NAMESPACE" --url)"
            print_info "Version A (control):  $(minikube service aceest-fitness-version-a -n "$NAMESPACE" --url)"
            print_info "Version B (treatment):$(minikube service aceest-fitness-version-b -n "$NAMESPACE" --url)"
        fi
    fi
}

# Rollback functions
rollback_deployment() {
    local strategy=$1
    print_warning "\n=== Performing Rollback: $strategy ===\n"
    
    case $strategy in
        rolling)
            kubectl rollout undo deployment/aceest-fitness-rolling -n "$NAMESPACE"
            kubectl rollout status deployment/aceest-fitness-rolling -n "$NAMESPACE"
            ;;
        blue-green)
            print_info "Switching service to BLUE..."
            kubectl patch service aceest-fitness-bluegreen-service -n "$NAMESPACE" \
                -p '{"spec":{"selector":{"slot":"blue"}}}'
            ;;
        canary)
            print_info "Scaling down canary to 0..."
            kubectl scale deployment aceest-fitness-canary -n "$NAMESPACE" --replicas=0
            ;;
        shadow)
            print_info "Deleting shadow deployment..."
            kubectl delete deployment aceest-fitness-shadow -n "$NAMESPACE"
            ;;
        ab-testing)
            print_info "Scaling down Version B..."
            kubectl scale deployment aceest-fitness-version-b -n "$NAMESPACE" --replicas=0
            ;;
    esac
    
    print_success "✓ Rollback completed"
}

# Switch function for blue-green
switch_blue_green() {
    print_info "\n=== Blue-Green Switch ===\n"
    
    local current_slot=$(kubectl get service aceest-fitness-bluegreen-service -n "$NAMESPACE" \
        -o jsonpath='{.spec.selector.slot}')
    print_info "Current slot: $current_slot"
    
    local new_slot="green"
    if [[ "$current_slot" == "green" ]]; then
        new_slot="blue"
    fi
    
    print_warning "Switching to: $new_slot"
    kubectl patch service aceest-fitness-bluegreen-service -n "$NAMESPACE" \
        -p "{\"spec\":{\"selector\":{\"slot\":\"$new_slot\"}}}"
    
    print_success "✓ Switched to $new_slot"
}

# Test function
test_deployment() {
    local strategy=$1
    print_info "\n=== Testing Deployment: $strategy ===\n"
    
    local services=()
    
    case $strategy in
        rolling)
            services=("aceest-fitness-rolling-service")
            ;;
        blue-green)
            services=("aceest-fitness-bluegreen-service" "aceest-fitness-blue-test" "aceest-fitness-green-test")
            ;;
        canary)
            services=("aceest-fitness-canary-service" "aceest-fitness-stable-test" "aceest-fitness-canary-test")
            ;;
        shadow)
            services=("aceest-fitness-production-service" "aceest-fitness-shadow-service")
            ;;
        ab-testing)
            services=("aceest-fitness-ab-service" "aceest-fitness-version-a" "aceest-fitness-version-b")
            ;;
    esac
    
    for service in "${services[@]}"; do
        print_info "\nTesting $service..."
        local url=$(minikube service "$service" -n "$NAMESPACE" --url 2>&1)
        
        if [[ $? -eq 0 ]]; then
            if curl -sf "$url/health" > /dev/null 2>&1; then
                print_success "✓ $service is healthy"
                local response=$(curl -s "$url/health")
                print_info "  Response: $response"
            else
                print_error "✗ $service failed health check"
            fi
        else
            print_error "✗ Cannot get URL for $service"
        fi
    done
}

# Cleanup function
cleanup_deployment() {
    local strategy=$1
    print_warning "\n=== Cleaning up: $strategy ===\n"
    
    read -p "Are you sure you want to delete $strategy deployment? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        case $strategy in
            rolling)
                kubectl delete -f k8s/rolling-update-deployment.yaml
                ;;
            blue-green)
                kubectl delete -f k8s/blue-green-deployment.yaml
                ;;
            canary)
                kubectl delete -f k8s/canary-deployment.yaml
                ;;
            shadow)
                kubectl delete -f k8s/shadow-deployment.yaml
                ;;
            ab-testing)
                kubectl delete -f k8s/ab-testing-deployment.yaml
                ;;
            all)
                kubectl delete namespace "$NAMESPACE"
                print_warning "Deleted entire namespace: $NAMESPACE"
                return
                ;;
        esac
        print_success "✓ Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Main execution
print_info "\n╔═══════════════════════════════════════════════════════╗"
print_info "║  ACEest Fitness - Kubernetes Deployment Automation  ║"
print_info "╚═══════════════════════════════════════════════════════╝\n"

# Check prerequisites
if ! check_prerequisites; then
    print_error "Prerequisites check failed. Exiting."
    exit 1
fi

# Start Minikube if requested
if [[ "$START_MINIKUBE" == "true" ]]; then
    if ! start_minikube; then
        print_error "Failed to start Minikube. Exiting."
        exit 1
    fi
fi

# Create namespace
if [[ "$ACTION" == "deploy" ]]; then
    create_namespace
fi

# Execute action
case $ACTION in
    deploy)
        case $STRATEGY in
            rolling) deploy_rolling ;;
            blue-green) deploy_blue_green ;;
            canary) deploy_canary ;;
            shadow) deploy_shadow ;;
            ab-testing) deploy_ab_testing ;;
            all)
                deploy_rolling
                deploy_blue_green
                deploy_canary
                deploy_shadow
                deploy_ab_testing
                ;;
        esac
        ;;
    rollback)
        rollback_deployment "$STRATEGY"
        ;;
    switch)
        if [[ "$STRATEGY" == "blue-green" ]]; then
            switch_blue_green
        else
            print_error "Switch action is only available for blue-green strategy"
        fi
        ;;
    test)
        test_deployment "$STRATEGY"
        ;;
    cleanup)
        cleanup_deployment "$STRATEGY"
        ;;
esac

print_success "\n╔═══════════════════════════════════════════════════════╗"
print_success "║              Deployment Operation Complete           ║"
print_success "╚═══════════════════════════════════════════════════════╝\n"

# Show useful commands
print_info "Useful commands:"
echo -e "  Get all deployments: ${YELLOW}kubectl get deployments -n $NAMESPACE${NC}"
echo -e "  Get all pods:        ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
echo -e "  Get all services:    ${YELLOW}kubectl get services -n $NAMESPACE${NC}"
echo -e "  View logs:           ${YELLOW}kubectl logs -n $NAMESPACE -l app=aceest-fitness --tail=50${NC}"
