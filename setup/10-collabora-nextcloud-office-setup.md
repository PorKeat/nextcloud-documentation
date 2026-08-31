# 10. Collabora (Nextcloud Office) Routing & Setup Guide

This guide documents the architecture and fixes required to successfully route Nextcloud Office (Collabora / WOPI) traffic through a Kubernetes Traefik ingress and an external WAF, bypassing Hairpin NAT issues.

---

## 1. The Architecture Challenge: Hairpin NAT
When setting up Collabora, Nextcloud and Collabora must communicate with each other. 
1. The **Browser** talks to Collabora via the public URL.
2. **Nextcloud** talks to Collabora via the internal WOPI URL.
3. **Collabora** talks to Nextcloud to download the document.

If both domains (`nextcloud.sengporkeat.com` and `collabora.sengporkeat.com`) point to an external WAF or LoadBalancer IP, internal pods attempting to reach those domains will hit a **Hairpin NAT (Loopback)** issue and fail with `No route to host`.

---

## 2. The Fix: Internal DNS Bypass via `hostAliases`

To fix the Hairpin NAT issue, we force the Nextcloud and Collabora pods to bypass the external LoadBalancer and route traffic directly to Traefik's internal Kubernetes `ClusterIP` (e.g., `10.233.23.138`).

Patch both deployments to inject the local DNS override:

```bash
# Patch Nextcloud
kubectl patch deployment nextcloud -n nextcloud-system -p '{"spec":{"template":{"spec":{"hostAliases":[{"ip":"10.233.23.138","hostnames":["collabora.sengporkeat.com","nextcloud.sengporkeat.com"]}]}}}}'

# Patch Collabora
kubectl patch deployment collabora -n nextcloud-system -p '{"spec":{"template":{"spec":{"hostAliases":[{"ip":"10.233.23.138","hostnames":["collabora.sengporkeat.com","nextcloud.sengporkeat.com"]}]}}}}'
```

---

## 3. Traefik IngressRoute Configuration

Because the WAF connects via HTTP (`port 80 / web`) but Nextcloud connects internally via HTTPS (`port 443 / websecure`), the Traefik `IngressRoute` for Collabora **must listen on both entryPoints** and have TLS enabled.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: collabora-ingress
  namespace: nextcloud-system
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`collabora.sengporkeat.com`)
      kind: Rule
      services:
        - name: collabora
          port: 9980
  tls: {}
```

---

## 4. Nextcloud WOPI Configuration

Configure Nextcloud to use the standard public domain for both internal and external WOPI communication, and secure the WOPI allowlist to internal Kubernetes IPs.

```bash
# Set WOPI URLs
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:app:set richdocuments wopi_url --value="https://collabora.sengporkeat.com"
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:app:set richdocuments public_wopi_url --value="https://collabora.sengporkeat.com"

# Disable strict internal cert verification (since we bypass the WAF internally)
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:app:set richdocuments disable_certificate_verification --value="yes"

# Secure WOPI Allowlist to internal K8s subnets
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:app:set richdocuments wopi_allowlist --value="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# Activate Configuration
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ richdocuments:activate-config
```

---

## 5. Tiyi WAF Configuration

When adding `collabora.sengporkeat.com` to the external WAF, the Upstream (Backend) configuration must be an **exact clone** of the Nextcloud configuration.

* **Upstream IP & Port:** Use the exact same NodePort as Nextcloud (e.g., `http://10.1.16.11:31497`). 
* **Why?** Traefik acts as a single entry point. It receives all traffic on port `31497`, reads the `Host: collabora.sengporkeat.com` HTTP header, and automatically routes the traffic internally to the Collabora pod on port `9980`.
