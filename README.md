# Gitops + ArgoCD + Kargo

## Local Development Setup

This repository contains the GitOps configuration for a local Kubernetes environment using **k3d**, **Argo CD**, and **Kargo**.

---

### Prerequisites

You must have the following tools installed on your local machine:

| Tool | Purpose |
| --- | --- |
| **k3d** | Runs a local Kubernetes (k3s) cluster in Docker. |
| **kubectl** | The standard CLI for interacting with the cluster. |
| **yq** | Used for manifest processing and command-line YAML edits. |
| **helm** | Required for initial bootstrapping of the Argo CD controller. |
| **docker** | The underlying engine for the k3d cluster nodes. |

---

### Manual Configuration

Before the cluster services can be accessed via a browser, you must manually update your local DNS to map the virtual hostnames to your local machine.

#### 1. Update `/etc/hosts`

Add the following entries to your `/etc/hosts` file (requires `sudo`):

```text
127.0.0.1 argocd.local
127.0.0.1 kargo.local

```

#### 2. Port Mapping Note

The Ingress is configured to use the **Traefik** entrypoint provided by k3d. By default, k3d maps the internal HTTPS port (443) to **8443** on your localhost.

---

### Deployment Summary

#### Argo CD

* **URL:** `https://argocd.local:8443`
* **Bootstrap Sync:** Managed by the `root-app` manifest.
* **Credentials:** * **User:** `admin`
* **Password:** Use `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`



#### Kargo

* **URL:** `https://kargo.local:8443`
* **Credentials:**
* **User:** `admin`
* **Password:** `admin123` (as defined in `clusters/local/kargo/values.yaml`)



---

### Troubleshooting & Key Configurations

* **Server-Side Apply:** Because Argo CD and Kargo use large CRDs, all Application manifests must have `ServerSideApply=true` enabled in their `syncOptions`.
* **Insecure Mode:** To allow Traefik to terminate SSL at the edge, both services are configured in "insecure" mode internally:
* **Argo CD:** `server.insecure: "true"` (set via `argocd-cmd-params-cm`).
* **Kargo:** `api.tls.enabled: false` and `api.tls.terminatedUpstream: true`.



---

**Would you like me to add a section on how to specifically initialize the k3d cluster with the correct port mappings?**
