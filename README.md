# Nextcloud Enterprise Kubernetes Documentation

A production-grade, enterprise documentation repository and manifest library for Nextcloud on Kubernetes.

---

## 📁 Repository Structure

```
nextcloud-documentation/
├── 🏛️ docs/       # Architecture blueprints, security models, concepts & "How It Works"
├── 🛠️ setup/      # Hands-on installation guides, configuration commands & performance tuning
└── 📦 manifests/  # Production-ready Kubernetes YAML manifests (01 to 12)
```

---

## 🏛️ 1. Architecture, Concepts & "How It Works" (`docs/`)

Conceptual blueprints, system designs, network flows, and disaster recovery strategies:

* [01 - Master Enterprise Infrastructure & Security Architecture](docs/01-master-enterprise-architecture.md) ⭐
* [02 - Network Firewall & Port Flow Matrix](docs/02-network-firewall-ports.md)
* [03 - Kubernetes Core Services & Stack Breakdown](docs/03-kubernetes-services-stack.md)
* [04 - Keycloak SSO & OIDC Security Architecture](docs/04-keycloak-sso-architecture.md)
* [05 - Cilium eBPF Zero-Trust Namespace Network Isolation](docs/05-cilium-ebpf-zero-trust-isolation.md) ⭐
* [06 - Nextcloud Blue-Green Zero-Downtime Deployment Strategy](docs/06-blue-green-deployment-strategy.md) ⭐
* [07 - 3-Tier Enterprise Disaster Recovery & Backup Architecture](docs/07-enterprise-3tier-backup-architecture.md)
* [08 - High-Performance Files Backend (Notify Push) Architecture](docs/08-high-performance-notify-push-architecture.md) ⭐
* [09 - MinIO S3 & Redis Sentinel Diagnostic Reference](docs/09-minio-s3-redis-troubleshooting.md)

---

## 🛠️ 2. Step-by-Step Setup & Configuration Guides (`setup/`)

Hands-on step-by-step setup guides, cut-and-paste commands, and configuration walkthroughs:

* [01 - WAF & Reverse Proxy Setup](setup/01-waf-reverse-proxy-setup.md)
* [02 - SSL Automation with Name.com](setup/02-ssl-namecom-automation.md)
* [03 - Let's Encrypt Manual DNS Certificate Guide](setup/03-letsencrypt-manual-dns-certificate.md)
* [04 - Security Hardening & HSTS Middleware Setup](setup/04-security-hardening-hsts.md)
* [05 - Keycloak Standalone Traefik Ingress Guide](setup/05-keycloak-standalone-traefik-guide.md)
* [06 - User OIDC SSO Nextcloud Integration Guide](setup/06-user-oidc-sso-guide.md)
* [07 - Storage Setup & Server-Side Encryption](setup/07-encryption-storage-guide.md)
* [08 - Collabora Nextcloud Office Setup](setup/08-collabora-nextcloud-office-setup.md)
* [09 - Collabora Custom Fonts in Kubernetes](setup/09-collabora-custom-fonts-k8s.md)
* [10 - Nextcloud UI Theming & App Customization](setup/10-nextcloud-ui-app-customization.md)
* [11 - Velero Kubernetes Backup & S3 Installation Guide](setup/11-velero-backup-installation-guide.md) ⭐
* [12 - Cilium eBPF Zero-Trust Isolation Setup & Testing](setup/12-cilium-ebpf-isolation-setup.md) ⭐
* [13 - Blue-Green Deployment & Live Cutover Hands-On Guide](setup/13-blue-green-deployment-cutover-guide.md) ⭐
* [14 - Notify Push High-Performance Backend Setup & Tuning](setup/14-notify-push-tuning-setup-guide.md) ⭐

---

## 📦 3. Production Kubernetes Manifests (`manifests/`)

* `01-traefik-ingressroute.yaml` - Traefik IngressRoute definitions
* `02-traefik-nodeport-service.yaml` - Traefik NodePort services (`31497`/`31270`)
* `03-nextcloud-deployment.yaml` - Nextcloud Green (Primary) deployment & volumes
* `04-collabora-ingressroute.yaml` - Collabora Office IngressRoute
* `05-collabora-deployment.yaml` - Collabora Online deployment
* `06-metallb-config.yaml` - MetalLB IPAddressPool & L2Advertisement
* `07-traefik-security-headers-middleware.yaml` - Traefik Security Headers Middleware
* `08-keycloak-ingress-single-domain.yaml` - Keycloak IngressRoute
* `09-database-backup-cronjob.yaml` - PostgreSQL nightly S3 backup CronJob
* `10-cilium-nextcloud-isolation.yaml` - Cilium eBPF Zero-Trust isolation policies
* `11-nextcloud-blue-deployment.yaml` - Nextcloud Blue (Preview/Dev) deployment & service
* `12-notify-push-deployment.yaml` - Nextcloud Notify Push WebSocket service & deployment
