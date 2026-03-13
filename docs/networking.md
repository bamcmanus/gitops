### Local Kubernetes Networking Architecture

In a production cloud environment, a **LoadBalancer** service type provisions an external cloud resource with its own public IP. In a local **k3d** development environment, networking is constrained by the host machine’s single IP address and the Docker bridge network.

#### Architectural Logic

To expose multiple services via a single host port (e.g., **8443**), a **Layer 7 Ingress Controller** acts as the cluster's gateway. This architecture centralizes traffic management, allowing one entry point to route traffic to various internal services based on paths or hostnames.

The network path is defined by three distinct stages:

1. **The Host-to-Container Bridge:** Port **8443** on the physical machine is mapped directly to the cluster's edge proxy (Traefik) via Docker.
2. **The Ingress Layer:** The Ingress Controller terminates the SSL connection from the browser. It inspects the request and determines the internal destination.
3. **The Service-to-Pod Path:** Traffic travels over the internal cluster network to the specific application pod.

#### Protocol Synchronization

For traffic to flow successfully, the Ingress Controller and the application must agree on a protocol. By default, many applications expect encrypted traffic, but local Ingress Controllers often communicate with backends via plain HTTP to reduce overhead.

Synchronizing these layers requires configuring the application to operate in an **insecure** or **HTTP-only** mode internally, while the Ingress Controller maintains the secure HTTPS connection to the outside world.

---

### Basic Troubleshooting Guide

If the application is unreachable, follow this sequence to isolate the point of failure in the network chain.

#### 1. Verify the Edge Gateway (Host to Cluster)

Ensure the local host can reach the cluster's entry point.

* **Command:** `curl -kI https://localhost:8443`
* **Success:** An HTTP response code (e.g., **200**, **307**, **401**).
* **Failure:** `Connection refused` indicates the Docker container is stopped or the port mapping is incorrect.

#### 2. Inspect the Ingress Resource (Routing Logic)

Check if the routing rules are correctly applied and recognized by the controller.

* **Command:** `kubectl get ingress -n <namespace>`
* **Key Detail:** The `ADDRESS` column should contain an internal IP. If it is empty, the Ingress Controller has not successfully bound the route.
* **Command:** `kubectl describe ingress <name> -n <namespace>`
* **Key Detail:** Check the `Backends` section to ensure the service name and port (e.g., **80**) match the actual service.

#### 3. Validate Service and Pod Health (Internal Path)

Confirm the application is actually listening on the expected port.

* **Command:** `kubectl get endpoints <service-name> -n <namespace>`
* **Success:** A list of internal IP addresses and ports.
* **Failure:** `<none>` indicates the service exists, but the pods are either not running or the selector labels do not match.

#### 4. Check Application Logs (Protocol Handshake)

Determine if the application is receiving the traffic but rejecting it.

* **Command:** `kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name>`
* **Look for:** `TLS handshake error` or `garbage prefixed with http`. These indicate that the Ingress is trying to speak HTTP to an HTTPS pod, or vice versa.

---

### Summary Table: Error Code Translation

| Status Code | Likely Source | Meaning |
| --- | --- | --- |
| **Connection Refused** | Docker/k3d | The port is not open on the host machine. |
| **404 Not Found** | Ingress Controller | The network path is open, but no routing rule matches the URL/Path. |
| **502/503 Service Unavailable** | Kubernetes Service | The service has no healthy pods to receive the traffic. |
| **500 Internal Server Error** | Application/Backend | The traffic reached the pod, but a protocol mismatch or application error occurred. |

---
