# Nextcloud Enterprise Kubernetes Documentation

A production-grade, enterprise documentation repository and modular manifest library for Nextcloud on Kubernetes.

---

## 📁 Repository Structure

```
nextcloud-documentation/
├── 🏛️ docs/       # Architecture blueprints, security models, concepts & "How It Works" (01 to 09)
├── 🛠️ setup/      # Hands-on installation guides, configuration commands & performance tuning (01 to 14)
└── 📦 manifests/  # Modular Kubernetes YAML manifests organized by component subfolders
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
* [09 - MinIO S3 & Valkey (formerly Redis) Sentinel Diagnostic Reference](docs/09-minio-s3-redis-troubleshooting.md)
* [10 - Enterprise Zero-Trust Runtime Security & Resilience Architecture](docs/10-enterprise-zero-trust-runtime-security.md) ⭐
* [11 - HashiCorp Vault Enterprise Secrets Architecture](docs/11-hashicorp-vault-enterprise-secrets.md) ⭐

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
* [15 - Enterprise Security Hardening & Threat Mitigation](setup/15-enterprise-security-hardening.md) ⭐
* [16 - Disaster Recovery & Scheduled Backup Automation Guide](setup/16-disaster-recovery-backup-restore-guide.md) ⭐
* [17 - Automated System Health & Security Scorecard Audit](setup/17-system-health-security-audit.md) ⭐
* [18 - HashiCorp Vault Secrets Management & Web UI Guide](setup/18-hashicorp-vault-secrets-management.md) ⭐
* [19 - HashiCorp Vault Agent In-Memory Sidecar Injection Guide](setup/19-vault-agent-sidecar-injection-guide.md) ⭐
* [20 - Cilium Tetragon eBPF Runtime Security & Process Monitoring Guide](setup/20-cilium-tetragon-runtime-security.md) ⭐
* [21 - Nextcloud Performance & Latency Optimization Guide](setup/21-nextcloud-performance-latency-tuning.md) ⭐

---

## 📦 3. Modular Kubernetes Manifests (`manifests/`)

Organized into component-specific subfolders for easy maintenance, inspection, and updates:

### 🌐 `01-ingress-gateway/`
* `traefik-ingressroute.yaml` - Main IngressRoute definitions (dual HTTP & strict TLS 1.3 HTTPS)
* `traefik-tls13-strict-option.yaml` - Strict TLS 1.3 `TLSOption` enforcement
* `traefik-nodeport-service.yaml` - NodePort service exposures (`31497`/`31270`)
* `traefik-security-headers-middleware.yaml` - HSTS & security headers middleware
* `keycloak-ingress.yaml` - Keycloak single-domain routing
* `collabora-ingressroute.yaml` - Collabora Office WOPI routing

### 🔌 `02-networking-metallb/`
* `metallb-config.yaml` - MetalLB IPAddressPool and L2Advertisement

### 🐘 `02-database-cnpg/`
* `cnpg-nextcloud-cluster.yaml` - CloudNativePG PostgreSQL 3-node HA cluster with 1GB shared_buffers & enterprise tuning

### 🛡️ `03-security-cilium/`
* `cilium-nextcloud-isolation.yaml` - Cilium eBPF Zero-Trust isolation & DB lockdown
* `tetragon-nextcloud-process-monitor.yaml` - Tetragon eBPF process execution & file access TracingPolicy
* `tetragon-webshell-block.yaml` - Tetragon eBPF automated Sigkill webshell enforcement policy

### ☁️ `04-nextcloud-app/`
* `nextcloud-green-deployment.yaml` - Nextcloud Green (Primary/Live) stack
* `nextcloud-blue-deployment.yaml` - Nextcloud Blue (Preview/Dev) stack

### 📄 `05-collabora-office/`
* `collabora-deployment.yaml` - Collabora Online Office deployment

### ⚡ `06-high-performance-push/`
* `notify-push-deployment.yaml` - Notify Push WebSocket daemon & service

### 💾 `07-disaster-recovery-backup/`
* `velero-daily-schedule.yaml` - Automated Velero daily snapshot schedule (7-Day TTL)
* `database-backup-cronjob.yaml` - Nightly automated PostgreSQL S3 dump CronJob (7-Day Auto-Purge)

### 🔐 `08-vault-integration/`
* `vault-agent-injector.yaml` - Official HashiCorp Vault Agent Injector controller
* `vault-agent-template-example.yaml` - In-memory RAM (`tmpfs`) sidecar injection template

### ⚡ `09-cache-valkey/`
* `valkey-values.yaml` - Valkey Sentinel High Availability (BSD-3-Clause) Helm values

---

## 🔍 4. Automation & Health Scripts (`scripts/`)

* [`enterprise-health-audit.sh`](scripts/enterprise-health-audit.sh) — **1-Click System Health & Security Scorecard Audit Script**. Run directly on any node (`cluster-audit`) to verify cluster HA, database health, eBPF firewall lockdown, and backup retention.
* [`node1-rejoin-and-audit.sh`](scripts/node1-rejoin-and-audit.sh) — **Node 1 Recovery & Setup Script**. Run when Node 1 boots up to configure the local loopback and install the audit tool.
