#!/bin/bash

# Deployment Strategy Scripts for ACEest Fitness
# This script provides functions for all deployment strategies

set -e

NAMESPACE="aceest-fitness"
APP_NAME="aceest-fitness"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ===== ROLLING UPDATE DEPLOYMENT =====
rolling_update() {
    local new_image=$1
    
    log_info "Starting Rolling Update deployment..."
    log_info "New image: $new_image"
    
    # Update deployment with new image
    kubectl set image deployment/${APP_NAME}-deployment \
        ${APP_NAME}=${new_image} \
        -n ${NAMESPACE}
    
    # Watch rollout status
    kubectl rollout status deployment/${APP_NAME}-deployment -n ${NAMESPACE}
    
    log_info "Rolling update completed successfully!"
}

# ===== BLUE-GREEN DEPLOYMENT =====
blue_green_deploy() {
    local new_image=$1
    local current_version=$(kubectl get service ${APP_NAME}-bluegreen -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}')
    
    log_info "Current active version: $current_version"
    
    if [ "$current_version" == "blue" ]; then
        new_version="green"
    else
        new_version="blue"
    fi
    
    log_info "Deploying to $new_version environment..."
    
    # Update the inactive environment
    kubectl set image deployment/${APP_NAME}-${new_version} \
        ${APP_NAME}=${new_image} \
        -n ${NAMESPACE}
    
    # Wait for deployment to be ready
    kubectl rollout status deployment/${APP_NAME}-${new_version} -n ${NAMESPACE}
    
    # Test the new version
    log_info "Testing $new_version environment..."
    kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-${new_version}-test 8080:80 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Health check
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        log_info "Health check passed for $new_version"
        kill $PORT_FORWARD_PID
        
        # Switch traffic
        read -p "Switch traffic to $new_version? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            kubectl patch service ${APP_NAME}-bluegreen -n ${NAMESPACE} \
                -p "{\"spec\":{\"selector\":{\"version\":\"${new_version}\"}}}"
            log_info "Traffic switched to $new_version successfully!"
        else
            log_warn "Deployment cancelled by user"
        fi
    else
        log_error "Health check failed for $new_version"
        kill $PORT_FORWARD_PID
        exit 1
    fi
}

# ===== ROLLBACK BLUE-GREEN =====
blue_green_rollback() {
    local current_version=$(kubectl get service ${APP_NAME}-bluegreen -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}')
    
    if [ "$current_version" == "blue" ]; then
        previous_version="green"
    else
        previous_version="blue"
    fi
    
    log_warn "Rolling back from $current_version to $previous_version..."
    
    kubectl patch service ${APP_NAME}-bluegreen -n ${NAMESPACE} \
        -p "{\"spec\":{\"selector\":{\"version\":\"${previous_version}\"}}}"
    
    log_info "Rollback completed! Traffic switched to $previous_version"
}

# ===== CANARY DEPLOYMENT =====
canary_deploy() {
    local new_image=$1
    local canary_percentage=${2:-10}
    
    log_info "Starting Canary deployment with ${canary_percentage}% traffic..."
    
    # Update canary deployment
    kubectl set image deployment/${APP_NAME}-canary \
        ${APP_NAME}=${new_image} \
        -n ${NAMESPACE}
    
    kubectl rollout status deployment/${APP_NAME}-canary -n ${NAMESPACE}
    
    # Calculate replicas based on percentage
    local total_replicas=10
    local canary_replicas=$((total_replicas * canary_percentage / 100))
    local stable_replicas=$((total_replicas - canary_replicas))
    
    log_info "Scaling: Stable=$stable_replicas, Canary=$canary_replicas"
    
    kubectl scale deployment/${APP_NAME}-stable --replicas=$stable_replicas -n ${NAMESPACE}
    kubectl scale deployment/${APP_NAME}-canary --replicas=$canary_replicas -n ${NAMESPACE}
    
    log_info "Canary deployment at ${canary_percentage}% traffic"
    log_info "Monitor metrics and gradually increase canary percentage"
}

# ===== PROMOTE CANARY =====
promote_canary() {
    log_info "Promoting canary to stable..."
    
    local canary_image=$(kubectl get deployment ${APP_NAME}-canary -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}')
    
    # Update stable deployment with canary image
    kubectl set image deployment/${APP_NAME}-stable \
        ${APP_NAME}=${canary_image} \
        -n ${NAMESPACE}
    
    kubectl rollout status deployment/${APP_NAME}-stable -n ${NAMESPACE}
    
    # Scale back to normal
    kubectl scale deployment/${APP_NAME}-stable --replicas=9 -n ${NAMESPACE}
    kubectl scale deployment/${APP_NAME}-canary --replicas=1 -n ${NAMESPACE}
    
    log_info "Canary promoted to stable successfully!"
}

# ===== ROLLBACK DEPLOYMENT =====
rollback_deployment() {
    log_warn "Rolling back deployment..."
    
    kubectl rollout undo deployment/${APP_NAME}-deployment -n ${NAMESPACE}
    kubectl rollout status deployment/${APP_NAME}-deployment -n ${NAMESPACE}
    
    log_info "Rollback completed successfully!"
}

# ===== CHECK DEPLOYMENT STATUS =====
check_status() {
    log_info "Checking deployment status..."
    
    kubectl get deployments -n ${NAMESPACE}
    kubectl get services -n ${NAMESPACE}
    kubectl get pods -n ${NAMESPACE}
}

# ===== MAIN MENU =====
show_menu() {
    echo ""
    echo "======================================"
    echo "  ACEest Fitness Deployment Manager"
    echo "======================================"
    echo "1. Rolling Update"
    echo "2. Blue-Green Deployment"
    echo "3. Blue-Green Rollback"
    echo "4. Canary Deployment (10%)"
    echo "5. Canary Deployment (50%)"
    echo "6. Promote Canary to Stable"
    echo "7. Rollback Deployment"
    echo "8. Check Status"
    echo "9. Exit"
    echo "======================================"
}

# Main execution
if [ "$#" -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Select option: " option
        
        case $option in
            1)
                read -p "Enter new image (e.g., yourdockerhub/aceest-fitness:v2.0): " image
                rolling_update $image
                ;;
            2)
                read -p "Enter new image: " image
                blue_green_deploy $image
                ;;
            3)
                blue_green_rollback
                ;;
            4)
                read -p "Enter new image: " image
                canary_deploy $image 10
                ;;
            5)
                read -p "Enter new image: " image
                canary_deploy $image 50
                ;;
            6)
                promote_canary
                ;;
            7)
                rollback_deployment
                ;;
            8)
                check_status
                ;;
            9)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
    done
else
    # Command-line mode
    case $1 in
        rolling-update)
            rolling_update $2
            ;;
        blue-green)
            blue_green_deploy $2
            ;;
        blue-green-rollback)
            blue_green_rollback
            ;;
        canary)
            canary_deploy $2 ${3:-10}
            ;;
        promote-canary)
            promote_canary
            ;;
        rollback)
            rollback_deployment
            ;;
        status)
            check_status
            ;;
        *)
            echo "Usage: $0 {rolling-update|blue-green|blue-green-rollback|canary|promote-canary|rollback|status} [image] [percentage]"
            exit 1
            ;;
    esac
fi
