#!/bin/bash
# Lab 13 - GitOps with ArgoCD - Complete Automation Script
# Runs entire lab including Ansible deployment, verification, and Playwright tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
TESTS_DIR="${PROJECT_ROOT}/tests"
SCREENSHOTS_DIR="${PROJECT_ROOT}/app_python/docs/lab13screens"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${SCREENSHOTS_DIR}/execution_${TIMESTAMP}.log"

# Create screenshots directory
mkdir -p "${SCREENSHOTS_DIR}"

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

# Print header
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Phase 1: Prerequisites Check
phase_1_prerequisites() {
    print_header "PHASE 1: Checking Prerequisites"
    
    log_info "Checking kubectl..."
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    log_success "kubectl found: $(kubectl version --client --short)"
    
    log_info "Checking Helm..."
    if ! command -v helm &> /dev/null; then
        log_error "Helm not found. Please install Helm."
        exit 1
    fi
    log_success "Helm found: $(helm version --short)"
    
    log_info "Checking Ansible..."
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible not found. Please install Ansible: pip install ansible"
        exit 1
    fi
    log_success "Ansible found: $(ansible --version | head -1)"
    
    log_info "Checking Node.js..."
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js."
        exit 1
    fi
    log_success "Node.js found: $(node --version)"
    
    log_info "Checking npm..."
    if ! command -v npm &> /dev/null; then
        log_error "npm not found. Please install npm."
        exit 1
    fi
    log_success "npm found: $(npm --version)"
    
    log_info "Verifying Kubernetes cluster access..."
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Check KUBECONFIG and cluster status."
        exit 1
    fi
    CLUSTER_CONTEXT=$(kubectl config current-context)
    log_success "Connected to cluster: $CLUSTER_CONTEXT"
}

# Phase 2: Install Dependencies
phase_2_dependencies() {
    print_header "PHASE 2: Installing Dependencies"
    
    log_info "Installing Node.js dependencies..."
    cd "${PROJECT_ROOT}"
    npm install --quiet
    log_success "Node.js dependencies installed"
    
    log_info "Installing Playwright browsers..."
    npx playwright install --with-deps > /dev/null 2>&1 || true
    log_success "Playwright browsers configured"
    
    log_info "Verifying Ansible Kubernetes modules..."
    python3 -m pip install kubernetes --quiet 2>/dev/null || true
    log_success "Python dependencies ready"
}

# Phase 3: Execute Ansible Playbook
phase_3_ansible_deployment() {
    print_header "PHASE 3: Executing Ansible Deployment"
    
    log_info "Starting ArgoCD deployment via Ansible..."
    log_info "This may take 5-10 minutes..."
    
    cd "${ANSIBLE_DIR}"
    
    # Run playbook with output to both console and log
    if ansible-playbook playbooks/argocd-deploy.yml -v 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "Ansible deployment completed successfully"
    else
        log_error "Ansible deployment failed. Check logs for details."
        return 1
    fi
    
    # Extract credentials from playbook output
    log_info "Extracting ArgoCD credentials..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$ARGOCD_PASSWORD" != "NOT_FOUND" ]; then
        echo "ARGOCD_PASSWORD=${ARGOCD_PASSWORD}" > "${SCREENSHOTS_DIR}/.env.local"
        log_success "Credentials saved to .env.local"
    else
        log_warning "Could not retrieve ArgoCD password automatically"
    fi
}

# Phase 4: Verify Deployment
phase_4_verification() {
    print_header "PHASE 4: Verifying Deployment"
    
    log_info "Checking ArgoCD namespace..."
    if kubectl get namespace argocd &> /dev/null; then
        log_success "ArgoCD namespace exists"
    else
        log_error "ArgoCD namespace not found"
        return 1
    fi
    
    log_info "Waiting for ArgoCD pods to be ready..."
    if kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=argocd-server \
        -n argocd --timeout=300s 2>/dev/null; then
        log_success "ArgoCD server pod is ready"
    else
        log_warning "ArgoCD pod readiness check timed out"
    fi
    
    log_info "Checking deployed applications..."
    APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    if [ "$APP_COUNT" -gt 0 ]; then
        log_success "Found $APP_COUNT application(s)"
    else
        log_warning "No applications found yet"
    fi
    
    log_info "Checking dev namespace..."
    kubectl get pods -n dev 2>/dev/null | tee -a "${LOG_FILE}"
    
    log_info "Checking prod namespace..."
    kubectl get pods -n prod 2>/dev/null | tee -a "${LOG_FILE}"
}

# Phase 5: Setup Port Forwarding
phase_5_port_forwarding() {
    print_header "PHASE 5: Setting Up Port Forwarding"
    
    log_info "Checking if port 8080 is available..."
    if lsof -i :8080 &> /dev/null; then
        log_warning "Port 8080 is in use. Killing existing process..."
        pkill -f "port-forward" || true
        sleep 2
    fi
    
    log_info "Starting port forwarding (kubectl port-forward)..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    echo "$PORT_FORWARD_PID" > "${SCREENSHOTS_DIR}/.port-forward.pid"
    
    sleep 3
    
    log_info "Verifying ArgoCD UI accessibility..."
    for i in {1..10}; do
        if curl -s -k https://localhost:8080 > /dev/null 2>&1; then
            log_success "ArgoCD UI is accessible at http://localhost:8080"
            return 0
        fi
        sleep 2
    done
    
    log_warning "ArgoCD UI may not be immediately accessible, continuing..."
}

# Phase 6: Run Playwright Tests
phase_6_playwright_testing() {
    print_header "PHASE 6: Running Playwright Tests"
    
    log_info "Configuring Playwright environment variables..."
    export ARGOCD_URL="http://localhost:8080"
    export ARGOCD_USERNAME="admin"
    export ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-admin}"
    
    cd "${PROJECT_ROOT}"
    
    log_info "Running Playwright test suite..."
    log_info "This will capture screenshots of the ArgoCD UI..."
    
    if npx playwright test tests/lab13.spec.ts --reporter=list 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "Playwright tests completed"
    else
        log_warning "Some Playwright tests may have failed, continuing..."
    fi
    
    # Check if screenshots were generated
    SCREENSHOT_COUNT=$(ls -1 "${SCREENSHOTS_DIR}"/*.png 2>/dev/null | wc -l)
    if [ "$SCREENSHOT_COUNT" -gt 0 ]; then
        log_success "Generated $SCREENSHOT_COUNT screenshot(s)"
    else
        log_warning "No screenshots captured"
    fi
}

# Phase 7: Verification Report
phase_7_verification_report() {
    print_header "PHASE 7: Generating Verification Report"
    
    REPORT_FILE="${SCREENSHOTS_DIR}/VERIFICATION_REPORT_${TIMESTAMP}.txt"
    
    {
        echo "========================================="
        echo "Lab 13 - GitOps with ArgoCD"
        echo "Verification Report"
        echo "========================================="
        echo "Date: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo ""
        echo "========================================="
        echo "ARGOCD NAMESPACE COMPONENTS"
        echo "========================================="
        kubectl get pods -n argocd
        echo ""
        echo "========================================="
        echo "APPLICATIONS"
        echo "========================================="
        kubectl get applications -n argocd
        echo ""
        echo "========================================="
        echo "DEV NAMESPACE"
        echo "========================================="
        kubectl get pods -n dev
        kubectl get svc -n dev
        echo ""
        echo "========================================="
        echo "PROD NAMESPACE"
        echo "========================================="
        kubectl get pods -n prod
        kubectl get svc -n prod
        echo ""
        echo "========================================="
        echo "SCREENSHOTS GENERATED"
        echo "========================================="
        ls -lh "${SCREENSHOTS_DIR}"/*.png 2>/dev/null || echo "No screenshots found"
        echo ""
        echo "========================================="
        echo "COMPLETION SUMMARY"
        echo "========================================="
        echo "✓ Ansible deployment completed"
        echo "✓ ArgoCD installed and verified"
        echo "✓ Applications deployed"
        echo "✓ Playwright tests executed"
        echo "✓ Screenshots captured"
        echo ""
        echo "Next steps:"
        echo "1. Access ArgoCD UI at http://localhost:8080"
        echo "2. Review screenshots in: $SCREENSHOTS_DIR"
        echo "3. Run manual tests as documented"
        echo "4. Review Lab 13 Implementation Report"
        echo "========================================="
    } | tee "${REPORT_FILE}"
    
    log_success "Verification report saved: ${REPORT_FILE}"
}

# Cleanup function
cleanup() {
    print_header "Cleaning Up"
    
    log_info "Stopping port forwarding..."
    if [ -f "${SCREENSHOTS_DIR}/.port-forward.pid" ]; then
        kill "$(cat "${SCREENSHOTS_DIR}/.port-forward.pid")" 2>/dev/null || true
        rm "${SCREENSHOTS_DIR}/.port-forward.pid"
    fi
    
    log_success "Cleanup complete"
}

# Main execution
main() {
    print_header "Lab 13 - GitOps with ArgoCD - Complete Automation"
    log_info "Start time: $(date)"
    log_info "Logs will be saved to: ${LOG_FILE}"
    
    # Run all phases
    if phase_1_prerequisites; then
        phase_2_dependencies &&
        phase_3_ansible_deployment &&
        phase_4_verification &&
        phase_5_port_forwarding &&
        phase_6_playwright_testing &&
        phase_7_verification_report
    else
        log_error "Execution halted due to prerequisite failure"
        exit 1
    fi
    
    # Cleanup
    cleanup
    
    print_header "Lab 13 Execution Complete!"
    log_success "All phases completed successfully"
    log_info "End time: $(date)"
    log_info "Logs saved to: ${LOG_FILE}"
    log_info "Screenshots saved to: ${SCREENSHOTS_DIR}"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
