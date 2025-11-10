#!/bin/bash

# ACEest Fitness Quick Start Script
# This script automates the initial setup and deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="aceest-fitness"
NAMESPACE="aceest-fitness"
DOCKER_IMAGE="yourdockerhub/aceest-fitness"
VERSION="v1.0"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ACEest Fitness & Gym - Quick Start Script      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists python3; then
    print_error "Python 3 is not installed"
    exit 1
fi
print_status "Python 3 found"

if ! command_exists docker; then
    print_error "Docker is not installed"
    exit 1
fi
print_status "Docker found"

if ! command_exists kubectl; then
    print_error "kubectl is not installed"
    exit 1
fi
print_status "kubectl found"

if ! command_exists git; then
    print_error "Git is not installed"
    exit 1
fi
print_status "Git found"

echo ""

# Menu
show_menu() {
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1. Setup Local Development Environment"
    echo "2. Run Tests"
    echo "3. Build and Run with Docker"
    echo "4. Deploy to Kubernetes"
    echo "5. Complete Setup (All of the above)"
    echo "6. Exit"
    echo ""
}

# Setup virtual environment
setup_venv() {
    echo -e "${YELLOW}Setting up Python virtual environment...${NC}"
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_status "Virtual environment created"
    else
        print_info "Virtual environment already exists"
    fi
    
    # Activate based on OS
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        source venv/Scripts/activate
    else
        source venv/bin/activate
    fi
    
    pip install --upgrade pip > /dev/null 2>&1
    pip install -r requirements.txt > /dev/null 2>&1
    print_status "Dependencies installed"
}

# Run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    
    if [ ! -d "venv" ]; then
        setup_venv
    fi
    
    # Activate venv
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        source venv/Scripts/activate
    else
        source venv/bin/activate
    fi
    
    pytest test_app.py -v --cov=app --cov-report=term
    print_status "Tests completed"
}

# Build Docker image
build_docker() {
    echo -e "${YELLOW}Building Docker image...${NC}"
    
    docker build -t ${APP_NAME}:${VERSION} .
    docker tag ${APP_NAME}:${VERSION} ${APP_NAME}:latest
    
    print_status "Docker image built: ${APP_NAME}:${VERSION}"
}

# Run Docker container
run_docker() {
    echo -e "${YELLOW}Starting Docker container...${NC}"
    
    # Stop existing container if running
    docker stop ${APP_NAME} 2>/dev/null || true
    docker rm ${APP_NAME} 2>/dev/null || true
    
    docker run -d \
        --name ${APP_NAME} \
        -p 5000:5000 \
        -e FLASK_ENV=development \
        ${APP_NAME}:latest
    
    print_status "Container started on http://localhost:5000"
    
    # Wait for application to start
    echo -e "${BLUE}Waiting for application to start...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:5000/health > /dev/null 2>&1; then
            print_status "Application is ready!"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
}

# Deploy to Kubernetes
deploy_k8s() {
    echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
    
    # Check if cluster is accessible
    if ! kubectl cluster-info > /dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Make sure your cluster is running (e.g., minikube start)"
        return 1
    fi
    
    print_status "Connected to Kubernetes cluster"
    
    # Create namespace
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    print_status "Namespace created: ${NAMESPACE}"
    
    # Apply deployment
    kubectl apply -f k8s/deployment.yaml
    print_status "Deployment applied"
    
    # Wait for deployment
    echo -e "${BLUE}Waiting for deployment to be ready...${NC}"
    kubectl rollout status deployment/${APP_NAME}-deployment -n ${NAMESPACE} --timeout=5m
    
    # Get service URL
    echo ""
    echo -e "${GREEN}Deployment successful!${NC}"
    echo ""
    echo -e "${BLUE}To access the application:${NC}"
    
    # Check if using Minikube
    if command_exists minikube; then
        SERVICE_URL=$(minikube service ${APP_NAME}-service -n ${NAMESPACE} --url)
        echo "Service URL: ${SERVICE_URL}"
        echo ""
        echo "Or run: minikube service ${APP_NAME}-service -n ${NAMESPACE}"
    else
        echo "Get service IP: kubectl get svc -n ${NAMESPACE}"
        echo "Port forward: kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME}-service 8080:80"
    fi
}

# Complete setup
complete_setup() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   Running Complete Setup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    
    setup_venv
    echo ""
    
    run_tests
    echo ""
    
    build_docker
    echo ""
    
    run_docker
    echo ""
    
    read -p "Deploy to Kubernetes? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_k8s
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}

# Show status
show_status() {
    echo -e "${BLUE}Current Status:${NC}"
    echo ""
    
    # Docker status
    if docker ps | grep -q ${APP_NAME}; then
        print_status "Docker container is running"
        echo "   URL: http://localhost:5000"
    else
        print_info "Docker container is not running"
    fi
    
    echo ""
    
    # Kubernetes status
    if kubectl get namespace ${NAMESPACE} > /dev/null 2>&1; then
        print_status "Kubernetes namespace exists"
        
        if kubectl get deployment ${APP_NAME}-deployment -n ${NAMESPACE} > /dev/null 2>&1; then
            REPLICAS=$(kubectl get deployment ${APP_NAME}-deployment -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
            print_status "Deployment ready: ${REPLICAS} replicas"
        fi
    else
        print_info "Kubernetes deployment not found"
    fi
    
    echo ""
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-6): " choice
    echo ""
    
    case $choice in
        1)
            setup_venv
            echo ""
            print_info "To activate virtual environment:"
            echo "  Linux/Mac: source venv/bin/activate"
            echo "  Windows: venv\\Scripts\\activate"
            echo ""
            print_info "To run the application:"
            echo "  python app.py"
            ;;
        2)
            run_tests
            ;;
        3)
            build_docker
            echo ""
            run_docker
            ;;
        4)
            deploy_k8s
            ;;
        5)
            complete_setup
            ;;
        6)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please try again."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
