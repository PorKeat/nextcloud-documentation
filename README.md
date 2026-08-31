# Nextcloud Enterprise Kubernetes Documentation

A production-grade, enterprise documentation repository and manifest library for Nextcloud on Kubernetes.

---

## 📁 Repository Structure Overview

```
nextcloud-documentation/
├── 🏛️ docs/       # Architecture blueprints, security designs, and disaster recovery concepts
├── 🛠️ setup/      # Step-by-step installation, setup, configuration, and performance tuning guides
└── 📦 manifests/  # Production-ready Kubernetes YAML manifests (Deployments, Services, Policies, CronJobs)
```

---

## 🏛️ 1. Architecture & Security Blueprints (`docs/`)

High-level architectural designs, network maps, zero-trust security models, and disaster recovery strategies:

* [00 - Master Enterprise Infrastructure & Security Architecture](docs/00-master-enterprise-architecture.md) ⭐
* [01 - Network Firewall & Port Matrix](docs/01-network-firewall-ports.md)
* [03 - Kubernetes Services & Stack Breakdown](docs/03-kubernetes-services-stack.md)
* [08 - Keycloak SSO Architecture & Security](docs/08-keycloak-sso-architecture-security.md)
* [09 - MinIO S3 & Redis Sentinel Troubleshooting](docs/09-minio-s3-redis-troubleshooting.md)
* [15 - 3-Tier Enterprise Backup Architecture](docs/15-enterprise-backup-architecture.md)
* [18 - Cilium eBPF Zero-Trust Namespace Network Isolation](docs/18-cilium-ebpf-network-isolation.md) ⭐
* [19 - Nextcloud Blue-Green Zero-Downtime Deployment Strategy](docs/19-blue-green-deployment-strategy.md) ⭐

---

## 🛠️ 2. Step-by-Step Setup & Configuration Guides (`setup/`)

Hands-on deployment walkthroughs, installation steps, and performance tuning:

* [02 - WAF & Reverse Proxy Setup](setup/02-waf-reverse-proxy-setup.md)
* [04 - SSL Automation with Name.com](setup/04-ssl-namecom-automation.md)
* [05 - Encryption & Storage Setup](setup/05-encryption-storage-guide.md)
* [06 - User OIDC SSO Integration Guide](setup/06-user-oidc-sso-guide.md)
* [07 - Security Hardening & HSTS Setup](setup/07-security-hardening-hsts.md)
* [08 - Keycloak Standalone Traefik Ingress Guide](setup/08-keycloak-standalone-traefik-guide.md)
* [10 - Collabora Nextcloud Office Setup](setup/10-collabora-nextcloud-office-setup.md)
* [11 - Nextcloud UI & App Customization](setup/11-nextcloud-ui-app-customization.md)
* [12 - Let's Encrypt Manual DNS Certificate Guide](setup/12-letsencrypt-manual-dns-certificate.md)
* [14 - Collabora Custom Fonts in Kubernetes](setup/14-collabora-custom-fonts-k8s.md)
* [16 - Velero Kubernetes Backup & Installation Guide](setup/16-velero-installation-guide.md) ⭐
* [20 - High-Performance Files Backend (Notify Push) Setup & Tuning](setup/20-notify-push-tuning-setup-guide.md) ⭐

---

## 📦 3. Kubernetes Manifests (`manifests/`)

Ready-to-apply Kubernetes manifests:

* `01-traefik-ingressroute.yaml` - Traefik ingress routes
* `02-traefik-nodeport-service.yaml` - Traefik NodePort service definition
* `03-nextcloud-deployment.yaml` - Primary Nextcloud deployment & volumes
* `04-collabora-ingressroute.yaml` - Collabora Office routing
* `05-collabora-deployment.yaml` - Collabora Office deployment
* `06-metallb-config.yaml` - MetalLB IPAddressPool & L2Advertisement
* `07-traefik-security-headers-middleware.yaml` - Security headers middleware
* `08-keycloak-ingress-single-domain.yaml` - Keycloak SSO ingress route
* `17-database-backup-cronjob.yaml` - PostgreSQL nightly S3 backup CronJob
* `18-cilium-nextcloud-isolation.yaml` - Cilium eBPF Zero-Trust isolation policies
* `19-nextcloud-blue-deployment.yaml` - Nextcloud Blue-Green deployment & service
* `20-notify-push-deployment.yaml` - High-Performance Files Backend (Notify Push)
