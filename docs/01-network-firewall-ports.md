# 1. Network Topology, IP Matrix & Firewall Rules

**Maintainer:** `alexkgm`  
**Workspace:** `unity-workspace`  

---

## IP & Subnet Matrix

| Role | IP / Subnet | Hostname / Description |
| :--- | :--- | :--- |
| **Public WAF** | `103.189.186.19` | Tiyi WAF Frontend (Public Entrypoint) |
| **WAF Internal Subnet** | `10.1.18.x` | Tiyi Upstream Routing Engine |
| **K8s Node 1** | `10.1.16.11` | K8s Master / Worker (Traefik NodePort) |
| **K8s Node 2** | `10.1.16.12` | K8s Worker (Traefik NodePort) |
| **K8s Node 3** | `10.1.16.13` | K8s Worker (Traefik NodePort) |
| **MetalLB VIP** | `10.1.16.200` | Optional Virtual IP (L2 Mode on `eth0`) |
| **MinIO S3 Storage** | `10.1.18.7:9000` | Object Storage backend for Nextcloud |

---

## Firewall / Router Port Matrix

To ensure zero 502/503 errors, your network administrator must configure the following Access Control List (ACL) rules on the core router/firewall:

| Source | Destination | Protocol | Port | Purpose |
| :--- | :--- | :---: | :---: | :--- |
| **Internet (Any)** | `103.189.186.19` (WAF) | TCP | `443` | Public HTTPS user traffic |
| **Internet (Any)** | `103.189.186.19` (WAF) | TCP | `80` | HTTP &rarr; HTTPS Redirect |
| **WAF Subnet (`10.1.18.x`)** | `10.1.16.11-13` (K8s Nodes) | TCP | `31497` | **Traefik HTTP NodePort** (Primary) |
| **WAF Subnet (`10.1.18.x`)** | `10.1.16.11-13` (K8s Nodes) | TCP | `80`, `443` | Standard HTTP/HTTPS (If using HostPort/VIP) |
| **K8s Nodes (`10.1.16.x`)** | `10.1.18.7` (MinIO) | TCP | `9000` | Nextcloud &rarr; S3 Bucket file read/write |
| **Office LAN / VPN** | `10.1.16.11-13` | TCP | `22` | SSH Cluster Administration |
| **K8s Intra-cluster** | `10.1.16.x` | TCP/UDP | `6443, 2379-2380, 10250, 7946` | Kubernetes control plane & Calico CNI |
