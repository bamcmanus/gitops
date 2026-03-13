#!/usr/bin/env bash

set -euo pipefail

NAME=${1:-}

usage() {
  echo "Usage:"
  echo "  argocd.sh <cluster-name> <repo-url> [path]"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1"
    exit 1
  }
}

check_dependencies() {
  require_command kubectl
  require_command k3d
}

use_context() {
  kubectl config use-context "k3d-$NAME" >/dev/null
}

install_argocd() {
  if kubectl get ns argocd >/dev/null 2>&1; then
    echo "argocd already installed"
  else
    kubectl create namespace argocd
    kubectl apply --server-side -n argocd \
      -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  fi
}

wait_for_argocd() {

  kubectl wait \
    --for=condition=available \
    deployment/argocd-server \
    -n argocd \
    --timeout=180s
}

apply_bootstrap_app() {
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  kubectl apply -f "$SCRIPT_DIR/../clusters/$NAME/argocd/bootstrap-app.yaml"
}

if [[ -z "$NAME" ]]; then
  usage
fi

check_dependencies
use_context
install_argocd
wait_for_argocd
apply_bootstrap_app

echo "Argo CD bootstrapped"

# Get the auto-generated password
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "---------------------------------------------------"
echo "  Argo CD Setup Complete!"
echo "  URL:      https://localhost:8443"
echo "  Username: admin"
echo "  Password: $ARGOCD_PWD"
echo "---------------------------------------------------"

# Automatically open the browser (macOS/Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  open "https://localhost:8443"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  xdg-open "https://localhost:8443"
fi
