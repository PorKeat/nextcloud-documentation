# 1. Network Topology, IP Matrix & Firewall Rules

**Maintainer:** `alexkgm`  
**Workspace:** `unity-workspace`  
**CNI:** Cilium (`kube-system/cilium`)  
**Storage:** Longhorn Distributed Block Storage (`longhorn-system`)  
**LoadBalancer:** MetalLB Layer 2 (`metallb-system/speaker`)  

---

## IP & Subnet Matrix

| Role | IP / Subnet | Hostname / Description |
| :--- | :--- | :--- |
| **Public WAF** | `103.189.186.19` | Tiyi WAF Frontend (Public Entrypoint) |
| **WAF Internal Subnet** | `10.1.18.x` | Tiyi Upstream Routing Engine |
| **Keycloak Standalone VM** | `10.1.18.6:9090` | Keycloak Identity Provider (Docker Compose) |
| **K8s Node 1** | `10.1.16.11` | K8s Master / Worker (Traefik NodePort) |
| **K8s Node 2** | `10.1.16.12` | K8s Worker (Traefik NodePort) |
| **K8s Node 3** | `10.1.16.13` | K8s Worker (Traefik NodePort) |
| **MetalLB VIP** | `10.1.16.200` | Virtual IP Pool for LoadBalancer services |
| **MinIO S3 Storage** | `10.1.18.7:9000` | Object Storage backend for Nextcloud |

---

## Complete Firewall Port Matrix

### A. Public Internet / External Traffic (WAF Ingress)

| Source | Destination | Protocol | Port | Purpose |
| :--- | :--- | :---: | :---: | :--- |
| **Internet (Any)** | `103.189.186.19` (WAF) | TCP | `80` | HTTP redirects & automated SSL challenge validation |
| **Internet (Any)** | `103.189.186.19` (WAF) | TCP | `443` | Secure HTTPS web traffic (Nextcloud & Keycloak) |
| **Admin IP / VPN** | `10.1.16.11-13`, `10.1.18.6` | TCP | `22` | Secure SSH cluster & VM management |

---

### B. WAF to Backend Upstream Communication

| Source | Destination | Protocol | Port | Purpose |
| :--- | :--- | :---: | :---: | :--- |
| **WAF Subnet (`10.1.18.x`)** | `10.1.16.11-13` (Node IPs) | TCP | `31497` | **Nextcloud Traefik HTTP NodePort** |
| **WAF Subnet (`10.1.18.x`)** | `10.1.18.6` (Keycloak VM) | TCP | `9090` | **Keycloak Identity Provider Upstream** |
| **K8s Nodes (`10.1.16.x`)** | `10.1.18.6` (Keycloak VM) | TCP | `9090` | Nextcloud &rarr; Keycloak OIDC direct communication |
| **K8s Nodes (`10.1.16.x`)** | `10.1.18.7` (MinIO) | TCP | `9000` | Nextcloud S3 file read/write operations |

---

### C. Internal Kubernetes Cluster Traffic (3-Node K8s + Cilium + MetalLB + Longhorn)

*All 3 Kubernetes nodes (`10.1.16.11`, `10.1.16.12`, `10.1.16.13`) have unrestricted communication across these ports:*

| Component | Protocol | Port Range | Description / Purpose |
| :--- | :---: | :---: | :--- |
| **Kubernetes API Server** | TCP | `6443` | Control plane API endpoint |
| **etcd Server & Peer** | TCP | `2379 - 2380` | High-availability cluster state database |
| **Kubelet API** | TCP | `10250` | Node monitoring and container management |
| **Controller & Scheduler** | TCP | `10257, 10259` | Kubernetes controller manager & scheduler |
| **NodePort Services Range** | TCP | `30000 - 32767` | Range for all exposed NodePort services (including `31497`) |
| **MetalLB Speaker Memberlist** | **TCP & UDP** | `7946` | **MetalLB node coordination & leader election** |
| **Cilium VXLAN Overlay** | UDP | `8472` | Cilium encapsulated pod-to-pod network traffic |
| **Cilium Health Checks** | TCP | `4240` | Cilium node and agent health monitoring |
| **Longhorn Engine & Manager** | TCP | `9500 - 9502` | Distributed block storage data plane & CSI sync |
