# 8. Keycloak Standalone VM with Traefik Edge Router

This guide covers the deployment of **Keycloak 26 + Dedicated Traefik Router** on the standalone VM (`10.1.18.6`), enforcing **Office Wi-Fi IP Allowlist on `/admin`** while keeping **Nextcloud OIDC login open worldwide**.

---

## 1. Network Topology

```mermaid
flowchart TD
    subgraph Public Internet
        User[Public User] -->|auth.sengporkeat.com| WAF[Tiyi WAF 103.189.186.19]
    end

    subgraph Keycloak Standalone VM [10.1.18.6]
        WAF -->|HTTP Port 80 (keycloak-pool)| TraefikAuth[Traefik Edge Container]
        
        TraefikAuth -->|Path: /realms/*, /.well-known/*| AllowPublic[🌍 ALLOW Public Users<br/>Nextcloud SSO Logins]
        TraefikAuth -->|Path: /admin/*| IPCheck{Check Client IP}
        
        IPCheck -->|Office Wi-Fi: 10.1.16.x / 103.189.186.x| AdminAllow[✅ ALLOW Admin Console]
        IPCheck -->|Outside Public IP| AdminDeny[❌ 403 Forbidden]
        
        AllowPublic --> KeycloakApp[Keycloak Container :8080]
        AdminAllow --> KeycloakApp
    end
```

---

## 2. Docker Compose Stack on `10.1.18.6` (`/root/keycloak/docker-compose.yaml`)

```yaml
name: unity-auth

services:
  traefik:
    image: traefik:v3.1
    container_name: traefik-auth
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/dynamic:/etc/traefik/dynamic:ro
    networks:
      - kc_net

  db:
    image: postgres:17.5-bullseye
    container_name: db-kc
    environment:
      POSTGRES_DB: db_keycloak
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - kc_net
    secrets:
      - postgres_password

  keycloak:
    image: quay.io/keycloak/keycloak:26.7.2
    container_name: keycloak
    depends_on:
      - db
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://db:5432/db_keycloak
      KC_DB_USERNAME: postgres
      KC_HOSTNAME: "https://auth.sengporkeat.com"
      KC_PROXY_HEADERS: "xforwarded"
      KC_PROXY_TRUSTED_ADDRESSES: "0.0.0.0/0"
      KC_HTTP_ENABLED: "true"
      KC_HTTP_PORT: "8080"
    volumes:
      - ./keycloak/themes:/opt/keycloak/themes
      - ./keycloak/providers:/opt/keycloak/providers
    networks:
      - kc_net
    secrets:
      - postgres_password
      - kc_admin_user
      - kc_admin_password
    entrypoint: ["/bin/bash", "-c"]
    command:
      - |
        export KC_DB_PASSWORD=$$(cat /run/secrets/postgres_password)
        export KC_BOOTSTRAP_ADMIN_USERNAME=$$(cat /run/secrets/kc_admin_user)
        export KC_BOOTSTRAP_ADMIN_PASSWORD=$$(cat /run/secrets/kc_admin_password)
        /opt/keycloak/bin/kc.sh start

volumes:
  postgres_data:
networks:
  kc_net:
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  kc_admin_user:
    file: ./secrets/kc_admin_user.txt
  kc_admin_password:
    file: ./secrets/kc_admin_password.txt
```

---

## 3. Traefik Dynamic Rules on `10.1.18.6` (`/root/keycloak/traefik/dynamic/keycloak-rules.yml`)

```yaml
http:
  routers:
    keycloak-root-redirect:
      rule: "Host(`auth.sengporkeat.com`) && Path(`/`)"
      entryPoints:
        - "web"
      middlewares:
        - "keycloak-realm-redirect"
      service: "keycloak-backend"

    keycloak-public-router:
      rule: "Host(`auth.sengporkeat.com`) && !PathPrefix(`/admin`)"
      entryPoints:
        - "web"
      service: "keycloak-backend"

    keycloak-admin-router:
      rule: "Host(`auth.sengporkeat.com`) && PathPrefix(`/admin`)"
      entryPoints:
        - "web"
      middlewares:
        - "office-wifi-allowlist"
      service: "keycloak-backend"

  middlewares:
    keycloak-realm-redirect:
      redirectRegex:
        regex: "^https?://auth\\.sengporkeat\\.com/?$"
        replacement: "https://auth.sengporkeat.com/realms/unity-workspace/account/"
        permanent: false

    office-wifi-allowlist:
      ipAllowList:
        sourceRange:
          - "10.1.16.0/24"      # Office Local Wi-Fi Subnet
          - "103.189.186.0/23"  # Office Public ISP Network
        ipStrategy:
          depth: 1

  services:
    keycloak-backend:
      loadBalancer:
        servers:
          - url: "http://keycloak:8080"
```

---

## 4. Tiyi WAF Configuration

* **Upstream Pool:** `keycloak-pool` pointing to **`http://10.1.18.6:80`** (Protocol: **`HTTP`**, Health Check: **`Passive Only`**).
* **Site:** `auth.sengporkeat.com` pointing to `keycloak-pool` with `auth-letsencrypt` SSL certificate.
