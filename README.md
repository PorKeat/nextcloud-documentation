# Nextcloud Enterprise Kubernetes Runbook & Master Index

**Maintainer:** `alexkgm`  
**Workspace:** `unity-workspace`  
**API Key Configured:** Name.com DNS Token  

---

## 📚 Documentation Index (Separated & Easy to Read)

| Document | Topic & Details |
| :--- | :--- |
| **[`docs/01-network-firewall-ports.md`](docs/01-network-firewall-ports.md)** | **Full IP matrix, subnets, and all firewall ACL rules/ports** required for router admins. |
| **[`docs/02-waf-reverse-proxy-setup.md`](docs/02-waf-reverse-proxy-setup.md)** | **Tiyi WAF Site & Upstream Pool setup**, SSL termination, and passive health checks. |
| **[`docs/03-kubernetes-services-stack.md`](docs/03-kubernetes-services-stack.md)** | **Nextcloud, Collabora, MetalLB, and Traefik** architecture and configs. |
| **[`docs/04-ssl-namecom-automation.md`](docs/04-ssl-namecom-automation.md)** | **Automated Let's Encrypt renewal** using Name.com DNS API Token. |

---

## 🛠 Kubernetes Manifests (`manifests/`)

* `01-traefik-ingressroute.yaml` &mdash; IngressRoute with sticky session cookies and multi-IP matching.
* `02-traefik-nodeport-service.yaml` &mdash; Traefik NodePort service (Port `31497`).
* `03-nextcloud-deployment.yaml` &mdash; 3-replica Nextcloud deployment with S3 MinIO backend.
* `04-collabora-ingressroute.yaml` &mdash; IngressRoutes inside `nextcloud-system`.
* `05-collabora-deployment.yaml` &mdash; Collabora Online office document editor.
* `06-metallb-config.yaml` &mdash; MetalLB IPAddressPool (`10.1.16.200`) and L2Advertisement.

---

## ⚡ Automation Scripts (`scripts/`)

* `setup-automated-ssl.sh` &mdash; 1-click Let's Encrypt certificate issuance using your Name.com API token.
