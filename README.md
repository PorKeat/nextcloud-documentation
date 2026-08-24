# Nextcloud Enterprise Kubernetes & WAF Runbook

**Maintainer:** `alexkgm`  
**Workspace:** `unity-workspace`  
**CNI:** Cilium | **Storage:** Longhorn | **Ingress:** Traefik | **WAF:** Tiyi WAF  

---

## 🚀 Quick Deployment Guide (Step-by-Step Commands)

Follow these exact steps in sequence to bring up the entire stack on a fresh 3-node Kubernetes cluster:

### Step 1: Create Namespaces & Secrets
```bash
# Create dedicated namespace
kubectl create namespace nextcloud-system

# Create database & S3 storage credentials secret
kubectl create secret generic nextcloud-credentials \
  --from-literal=db-password='<DB_PASSWORD>' \
  --from-literal=admin-password='<ADMIN_PASSWORD>' \
  --from-literal=s3-secret-key='<S3_SECRET_KEY>' \
  -n nextcloud-system
```

### Step 2: Configure MetalLB LoadBalancer (Optional VIP)
```bash
kubectl apply -f manifests/06-metallb-config.yaml
```

### Step 3: Deploy Traefik NodePort & IngressRoute
```bash
# Apply NodePort 31497 service
kubectl apply -f manifests/02-traefik-nodeport-service.yaml

# Apply IngressRoute with sticky session cookies
kubectl apply -f manifests/01-traefik-ingressroute.yaml
```

### Step 4: Deploy Nextcloud & Collabora Online Office
```bash
# Deploy Collabora Office
kubectl apply -f manifests/05-collabora-deployment.yaml

# Deploy 3-replica Nextcloud
kubectl apply -f manifests/03-nextcloud-deployment.yaml

# Verify all pods are running
kubectl get pods -n nextcloud-system -o wide
```

### Step 5: Automated Let's Encrypt SSL Generation
```bash
# On your node, run the automated Name.com DNS challenge script:
bash scripts/setup-automated-ssl.sh
```

### Step 6: Configure Tiyi WAF
1. **Frontend Site:** Create Site `nextcloud.sengporkeat.com`, set TLS Mode to **Uploaded**, and paste the generated `fullchain.pem` and `privkey.pem`.
2. **Upstream Pool:** Add Endpoints `http://10.1.16.11:31497`, `http://10.1.16.12:31497`, and `http://10.1.16.13:31497` with `Passive Only` health checks.

---

## 📚 Detailed Documentation Index

| Document | Topic & Details |
| :--- | :--- |
| **[`docs/01-network-firewall-ports.md`](docs/01-network-firewall-ports.md)** | **Full IP matrix, Cilium/MetalLB/Longhorn ports, and firewall ACL rules.** |
| **[`docs/02-waf-reverse-proxy-setup.md`](docs/02-waf-reverse-proxy-setup.md)** | **Tiyi WAF Site & Upstream Pool setup**, SSL termination, and passive health checks. |
| **[`docs/03-kubernetes-services-stack.md`](docs/03-kubernetes-services-stack.md)** | **Nextcloud, Collabora, MetalLB, and Traefik** architecture and configs. |
| **[`docs/04-ssl-namecom-automation.md`](docs/04-ssl-namecom-automation.md)** | **Automated Let's Encrypt renewal** using Name.com DNS API Token and cron jobs. |

---

## 🛠 Repository Structure

```
nextcloud/
├── README.md                            # Quickstart deployment commands & index
├── docs/                                # Detailed architectural & operational guides
│   ├── 01-network-firewall-ports.md     # Firewall rules & complete port matrix
│   ├── 02-waf-reverse-proxy-setup.md    # WAF frontend & upstream pool configuration
│   ├── 03-kubernetes-services-stack.md  # K8s components (Traefik, Cilium, MetalLB)
│   └── 04-ssl-namecom-automation.md     # Automated Name.com SSL & cron setup
├── manifests/                           # Production Kubernetes YAML manifests
│   ├── 01-traefik-ingressroute.yaml     # IngressRoute with sticky session cookies
│   ├── 02-traefik-nodeport-service.yaml # Traefik NodePort (Port 31497)
│   ├── 03-nextcloud-deployment.yaml     # 3-replica Nextcloud (MinIO S3 backend)
│   ├── 04-collabora-ingressroute.yaml   # IngressRoutes for Collabora Office
│   ├── 05-collabora-deployment.yaml     # Collabora Online document editor
│   └── 06-metallb-config.yaml           # MetalLB IPAddressPool (10.1.16.200) & L2
└── scripts/
    └── setup-automated-ssl.sh           # Let's Encrypt DNS-01 automated script
```
