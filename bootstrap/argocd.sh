#!/usr/bin/env bash

set -euo pipefail

NAME=${1:-}
# Adjust this to match your actual local repo pathing
REPO_ROOT=$(git rev-parse --show-toplevel)
CLUSTER_DIR="$REPO_ROOT/clusters/$NAME"

usage() {
  echo "Usage: argocd.sh <cluster-name>"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1. Please install it first."
    exit 1
  }
}

check_dependencies() {
  require_command kubectl
  require_command k3d
  require_command helm
  require_command yq
}

use_context() {
  kubectl config use-context "k3d-$NAME" >/dev/null
}

install_argocd() {
  echo "Extracting desired Argo CD version from manifests..."
  
  # Extracts the targetRevision from your core app manifest
  CHART_VERSION=$(yq eval '.spec.sources[] | select(.chart == "argo-cd") | .targetRevision' "$CLUSTER_DIR/argocd/argocd-core.yaml")
  
  echo "Bootstrapping Argo CD v$CHART_VERSION via Helm..."

  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
  helm repo update >/dev/null

  # Seed install using your local values.yaml
  # This replaces the raw kubectl apply and the manual configmap patching
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --version "$CHART_VERSION" \
    --set server.extraArgs={--insecure} \
    -f "$CLUSTER_DIR/argocd/values.yaml" \
    --wait
}

apply_bootstrap_app() {
  echo "Applying Root Application..."
  # This kicks off the self-management takeover
  kubectl apply -f "$CLUSTER_DIR/argocd/bootstrap-app.yaml"
}

# --- Main Execution ---

if [[ -z "$NAME" ]]; then
  usage
fi

check_dependencies
use_context
install_argocd
# wait_for_argocd is handled by helm --wait now
apply_bootstrap_app

echo "Argo CD bootstrapped and self-managing."

# Get the initial admin password (Argo CD creates this on first install)
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "---------------------------------------------------"
echo "  Argo CD Setup Complete!"
echo "  URL:      https://argocd.local:8443"
echo "  Username: admin"
echo "  Password: $ARGOCD_PWD"
echo "---------------------------------------------------"
