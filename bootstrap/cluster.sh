#!/usr/bin/env bash

set -euo pipefail

CMD=${1:-}
NAME=${2:-}

########################################
# usage
########################################

usage() {
  echo "Usage:"
  echo "  cluster.sh create <name>"
  echo "  cluster.sh start <name>"
  echo "  cluster.sh stop <name>"
  echo "  cluster.sh delete <name>"
  echo "  cluster.sh list"
  exit 1
}

########################################
# helpers
########################################

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found"
    exit 1
  fi
}

require_name() {
  if [[ -z "${NAME}" ]]; then
    echo "Error: cluster name required"
    exit 1
  fi
}

check_dependencies() {
  require_command k3d
  require_command kubectl
  require_command docker
}

check_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    echo "Error: docker is not running"
    exit 1
  fi
}

cluster_exists() {
  k3d cluster list | awk '{print $1}' | grep -q "^${NAME}$"
}

use_context() {
  kubectl config use-context "k3d-${NAME}" >/dev/null
}

########################################
# commands
########################################

create_cluster() {
  require_name

  if cluster_exists; then
    echo "Cluster ${NAME} already exists"
    use_context
    return
  fi

  echo "Creating cluster ${NAME}..."

  k3d cluster create "${NAME}" \
    --servers 1 \
    --agents 1 \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer"

  use_context

  echo "Cluster ${NAME} created"
}

start_cluster() {
  require_name

  echo "Starting cluster ${NAME}..."

  k3d cluster start "${NAME}"

  use_context

  echo "Cluster ${NAME} started"
}

stop_cluster() {
  require_name

  echo "Stopping cluster ${NAME}..."

  k3d cluster stop "${NAME}"

  echo "Cluster ${NAME} stopped"
}

delete_cluster() {
  require_name

  echo "Deleting cluster ${NAME}..."

  k3d cluster delete "${NAME}"

  echo "Cluster ${NAME} deleted"
}

list_clusters() {
  k3d cluster list
}

########################################
# runtime
########################################

if [[ -z "${CMD}" ]]; then
  usage
fi

check_dependencies
check_docker_running

case "${CMD}" in
  create)
    create_cluster
    ;;
  start)
    start_cluster
    ;;
  stop)
    stop_cluster
    ;;
  delete)
    delete_cluster
    ;;
  list)
    list_clusters
    ;;
  *)
    usage
    ;;
esac
