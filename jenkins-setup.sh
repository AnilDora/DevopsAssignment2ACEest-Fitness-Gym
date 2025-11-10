#!/bin/bash

# Jenkins Quick Setup Script
# Run this to quickly set up Jenkins with required plugins and configuration

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Jenkins Quick Setup for ACEest Fitness            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASSWORD="${JENKINS_PASSWORD}"

# Check if Jenkins is accessible
echo -e "${CYAN}Checking Jenkins accessibility...${NC}"
if ! curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" | grep -q "200\|403"; then
    echo -e "${YELLOW}⚠️  Jenkins not accessible at $JENKINS_URL${NC}"
    echo "Please start Jenkins and try again"
    exit 1
fi
echo -e "${GREEN}✅ Jenkins is accessible${NC}"
echo ""

# Install Jenkins CLI
echo -e "${CYAN}Downloading Jenkins CLI...${NC}"
curl -O "$JENKINS_URL/jnlpJars/jenkins-cli.jar"
echo -e "${GREEN}✅ Jenkins CLI downloaded${NC}"
echo ""

# Function to install plugin
install_plugin() {
    local plugin=$1
    echo -e "${CYAN}Installing plugin: $plugin${NC}"
    java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" \
        install-plugin "$plugin" || echo "Plugin already installed or failed"
}

# Install required plugins
echo -e "${CYAN}Installing required plugins...${NC}"
echo ""

# Core plugins
install_plugin "git"
install_plugin "github"
install_plugin "github-branch-source"

# Docker plugins
install_plugin "docker-plugin"
install_plugin "docker-workflow"
install_plugin "docker-commons"

# Testing plugins
install_plugin "junit"
install_plugin "htmlpublisher"
install_plugin "code-coverage-api"

# Quality plugins
install_plugin "sonar"

# Pipeline plugins
install_plugin "workflow-aggregator"
install_plugin "pipeline-stage-view"

# Kubernetes plugin
install_plugin "kubernetes"
install_plugin "kubernetes-credentials-provider"

# Notification plugins
install_plugin "email-ext"

# Utility plugins
install_plugin "ws-cleanup"
install_plugin "timestamper"
install_plugin "build-timeout"

echo ""
echo -e "${GREEN}✅ Plugins installed${NC}"
echo ""

# Restart Jenkins
echo -e "${YELLOW}⚠️  Jenkins needs to restart for plugins to take effect${NC}"
echo -e "${CYAN}Restarting Jenkins...${NC}"
java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" \
    safe-restart

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete!                              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. Wait for Jenkins to restart (~2 minutes)"
echo "2. Configure credentials in Jenkins UI"
echo "3. Set up GitHub webhook"
echo "4. Create pipeline job"
echo "5. Run first build"
echo ""
echo -e "${CYAN}Documentation:${NC}"
echo "See JENKINS_SETUP.md for detailed instructions"
echo ""
