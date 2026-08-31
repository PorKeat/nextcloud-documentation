# Nextcloud Enterprise Kubernetes & WAF Runbook

**Maintainer:** `alexkgm`  
**Workspace:** `unity-workspace`  
**CNI:** Cilium | **Storage:** Longhorn | **Ingress:** Traefik | **WAF:** Tiyi WAF | **SSO:** Keycloak / OpenID Connect  

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

### Step 3: Deploy Traefik NodePort, Security Headers & IngressRoute
```bash
# Apply NodePort 31497 service
kubectl apply -f manifests/02-traefik-nodeport-service.yaml

# Apply HSTS & Security Headers Middleware
kubectl apply -f manifests/07-traefik-security-headers-middleware.yaml

# Apply IngressRoute with sticky session cookies & security headers
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

### Step 5: Configure Trusted Proxies (Real Client IP)
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 0 --value="10.1.18.0/24"
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 1 --value="10.1.16.0/24"
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 2 --value="10.233.0.0/18"
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
```

### Step 6: Automated Let's Encrypt SSL Generation
```bash
# On your node, run the automated Name.com DNS challenge script:
bash scripts/setup-automated-ssl.sh
```

### Step 7: Configure Tiyi WAF (Exact Order of Operations)

In Tiyi WAF, configure resources in this exact sequence:

1. **Step 7.1 — Upload Certificate:**
   * Go to **Certificates / SSL** &rarr; **Add Certificate**.
   * Upload `fullchain.pem` (or Certificate + Chain) and `privkey.pem`.
2. **Step 7.2 — Create Upstream Pool:**
   * Go to **Upstream Pools** &rarr; **Create Pool**.
   * Add Endpoints: `http://10.1.16.11:31497`, `http://10.1.16.12:31497`, `http://10.1.16.13:31497`.
   * Set Backend Protocol to **`HTTP`** and Health Check to **`Passive Only`**.
3. **Step 7.3 — Create Frontend Site:**
   * Go to **Sites** &rarr; **Create Site**.
   * Host: `nextcloud.sengporkeat.com`.
   * Target: Select the Upstream Pool created in Step 7.2.
   * TLS Mode: Set to **`Uploaded`** and select the Certificate uploaded in Step 7.1.
   * HTTP Behavior: **`Redirect to HTTPS`**.

---

## 📚 Detailed Documentation Index

| Document | Topic & Details |
| :--- | :--- |
| **[`docs/01-network-firewall-ports.md`](docs/01-network-firewall-ports.md)** | **Full IP matrix, Cilium/MetalLB/Longhorn ports, and firewall ACL rules.** |
| **[`docs/02-waf-reverse-proxy-setup.md`](docs/02-waf-reverse-proxy-setup.md)** | **Tiyi WAF step-by-step workflow** (Certificate &rarr; Upstream Pool &rarr; Site). |
| **[`docs/03-kubernetes-services-stack.md`](docs/03-kubernetes-services-stack.md)** | **Nextcloud, Collabora, MetalLB, and Traefik** architecture and configs. |
| **[`docs/04-ssl-namecom-automation.md`](docs/04-ssl-namecom-automation.md)** | **Automated Let's Encrypt renewal** using Name.com DNS API Token and cron jobs. |
| **[`docs/05-encryption-storage-guide.md`](docs/05-encryption-storage-guide.md)** | **Server-Side Encryption vs S3 storage**, Master Key configuration, and session fix. |
| **[`docs/06-user-oidc-sso-guide.md`](docs/06-user-oidc-sso-guide.md)** | **Enterprise OpenID Connect (OIDC / SSO)** installation & Nextcloud setup. |
| **[`docs/07-security-hardening-hsts.md`](docs/07-security-hardening-hsts.md)** | **Real Client IP forwarding, HSTS header injection**, and MinIO storage isolation. |
| **[`docs/08-keycloak-sso-architecture-security.md`](docs/08-keycloak-sso-architecture-security.md)** | **Keycloak Split-Horizon architecture**, public OIDC vs VPN/Office-only admin console. |

---

## 🛠 Repository Structure

```
nextcloud/
├── README.md                                     # Quickstart deployment commands & index
├── docs/                                         # Detailed architectural & operational guides
│   ├── 01-network-firewall-ports.md              # Firewall rules & complete port matrix
│   ├── 02-waf-reverse-proxy-setup.md             # WAF frontend & upstream pool configuration
│   ├── 03-kubernetes-services-stack.md           # K8s components (Traefik, Cilium, MetalLB)
│   ├── 04-ssl-namecom-automation.md              # Automated Name.com SSL & cron setup
│   ├── 05-encryption-storage-guide.md            # Encryption modes & multi-replica stability
│   ├── 06-user-oidc-sso-guide.md                 # OpenID Connect (SSO) configuration
│   ├── 07-security-hardening-hsts.md             # Real client IP forwarding & HSTS
│   └── 08-keycloak-sso-architecture-security.md  # Keycloak split-horizon & VPN admin guide
├── manifests/                                    # Production Kubernetes YAML manifests
│   ├── 01-traefik-ingressroute.yaml              # IngressRoute with sticky cookies & HSTS
│   ├── 02-traefik-nodeport-service.yaml          # Traefik NodePort (Port 31497)
│   ├── 03-nextcloud-deployment.yaml              # 3-replica Nextcloud (MinIO S3 backend)
│   ├── 04-collabora-ingressroute.yaml            # IngressRoutes for Collabora Office
│   ├── 05-collabora-deployment.yaml              # Collabora Online document editor
│   ├── 06-metallb-config.yaml                    # MetalLB IPAddressPool (10.1.16.200) & L2
│   ├── 07-traefik-security-headers-middleware.yaml # Traefik HSTS security headers
│   └── 08-keycloak-ingress-split-horizon.yaml    # Keycloak Public OIDC vs VPN Admin routes
└── scripts/
    └── setup-automated-ssl.sh                    # Let's Encrypt DNS-01 automated script
```

## Backup & Disaster Recovery
* [15 - Enterprise Backup Architecture](docs/15-enterprise-backup-architecture.md)
* [16 - Velero Installation Guide (Layer 1)](docs/16-velero-installation-guide.md)

## Security & Network Isolation
* [18 - Cilium eBPF Zero-Trust Namespace Isolation](docs/18-cilium-ebpf-network-isolation.md)
