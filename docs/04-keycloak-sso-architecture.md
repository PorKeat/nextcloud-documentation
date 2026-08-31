# 8. Enterprise Keycloak SSO Architecture & Security Hardening

This guide explains how to deploy Keycloak on a **Single Domain (`auth.sengporkeat.com`)** while enforcing **Path-Based IP Filtering (Public SSO vs. VPN/Office-Only Admin Console)**.

---

## 1. Single-Domain Architecture Topology

```mermaid
flowchart TD
    Req[Incoming Request to https://auth.sengporkeat.com] --> Traefik{Traefik Router}

    Traefik -->|Path: /realms/* or /.well-known/*| Public[🌍 Public Internet Allowed<br/>(User Login & Nextcloud SSO)]
    
    Traefik -->|Path: /admin/* or /realms/master/*| IPCheck{Check Client IP}
    
    IPCheck -->|IP is Office Wi-Fi / VPN CIDR| AdminAllow[✅ Admin Console Allowed]
    IPCheck -->|IP is Public Internet| AdminBlock[❌ 403 Forbidden / Dropped]
```

---

## 2. Keycloak Configuration (Single Domain)

Configure Keycloak with a single fixed hostname and trusted proxy headers:

```yaml
environment:
  # Single public domain for both user auth & admin
  KC_HOSTNAME: https://auth.sengporkeat.com
  
  # Proxy header configuration
  KC_PROXY_HEADERS: xforwarded
  KC_PROXY_TRUSTED_ADDRESSES: 10.1.18.0/24,10.1.16.0/24,10.233.0.0/18
  
  # Standard production HTTP port
  KC_HTTP_ENABLED: "true"
  KC_HTTP_PORT: "8080"
```

---

## 3. Traefik Path-Based Ingress (`manifests/01-ingress-gateway/keycloak-ingress.yaml`)

### A. Public Authentication Route (Open to the World)
Allows public users to authenticate into Nextcloud without granting access to administrative endpoints:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: keycloak-public-auth-route
  namespace: nextcloud-system
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - kind: Rule
    match: Host(`auth.sengporkeat.com`) && (PathPrefix(`/realms/`) || PathPrefix(`/resources/`) || PathPrefix(`/.well-known/`)) && !PathPrefix(`/realms/master/`)
    middlewares:
    - name: nextcloud-security-headers
      namespace: nextcloud-system
    services:
    - name: keycloak-service
      port: 8080
```

---

### B. Admin Console Route (VPN & Office Wi-Fi ONLY)
Protects `/admin` and `/realms/master` on the exact same domain using the IP Allowlist Middleware:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: office-vpn-allowlist
  namespace: nextcloud-system
spec:
  ipAllowList:
    sourceRange:
    - 10.1.16.0/24     # Office Wi-Fi / Internal K8s Subnet
    - 10.20.0.0/24     # Office VPN Subnet CIDR
    - 10.1.18.0/24     # WAF Internal Proxy Network
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: keycloak-admin-vpn-route
  namespace: nextcloud-system
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - kind: Rule
    match: Host(`auth.sengporkeat.com`) && (PathPrefix(`/admin`) || PathPrefix(`/realms/master`))
    middlewares:
    - name: office-vpn-allowlist
      namespace: nextcloud-system
    - name: nextcloud-security-headers
      namespace: nextcloud-system
    services:
    - name: keycloak-service
      port: 8080
```

---

## 4. User Experience Comparison

| Path Requested | Source IP | Result | User Impact |
| :--- | :--- | :---: | :--- |
| `https://auth.sengporkeat.com/realms/nextcloud/...` | Any Public Internet IP | ✅ **200 OK** | User sees Nextcloud SSO login page and logs in. |
| `https://auth.sengporkeat.com/admin/` | Office Wi-Fi (`10.1.16.x`) / VPN | ✅ **200 OK** | Admin console opens normally. |
| `https://auth.sengporkeat.com/admin/` | Public Internet (No VPN) | ❌ **403 Forbidden** | Request is immediately dropped at Traefik edge. |
