# 6. Enterprise OpenID Connect (OIDC / SSO) Setup Guide

This guide explains how the official **`user_oidc`** (OpenID Connect) application is installed, managed, and configured for Single Sign-On (SSO) with providers like Keycloak, Authentik, Okta, and Google.

---

## 1. Clean Production Installation (No `--force`)

Because cutting-edge Nextcloud builds (Nextcloud 34+) may have app store API version delays, `user_oidc` is deployed using official pre-compiled production release bundles with all vendor dependencies:

```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- bash -c "
  cd /var/www/html/custom_apps && \
  rm -rf user_oidc user_oidc.tar.gz && \
  curl -fsSL -L https://github.com/nextcloud-releases/user_oidc/releases/download/v8.11.0/user_oidc-v8.11.0.tar.gz -o user_oidc.tar.gz && \
  tar -xzf user_oidc.tar.gz && \
  rm user_oidc.tar.gz && \
  chown -R www-data:www-data user_oidc
"

# Enable the app cleanly
kubectl exec -n nextcloud-system deployment/nextcloud -- su -s /bin/bash www-data -c "php occ app:enable user_oidc"
```

---

## 2. Web UI Configuration (Recommended)

1. Log in as an administrator at `https://nextcloud.sengporkeat.com`.
2. Go to **Administration Settings &rarr; Security** (`/settings/admin/security`).
3. Scroll down to the **OpenID Connect** section.
4. Click **Add Provider**:
   * **Identifier:** `keycloak` / `authentik` / `okta`
   * **Client ID:** `<YOUR_OIDC_CLIENT_ID>`
   * **Client Secret:** `<YOUR_OIDC_CLIENT_SECRET>`
   * **Discovery Endpoint:** `https://sso.example.com/realms/master/.well-known/openid-configuration`
   * **Scope:** `openid email profile`
5. Check **Auto-create new users on login** (Just-In-Time provisioning).
6. Click **Save**.

---

## 3. CLI Configuration (Alternative via `occ`)

You can also create and manage OIDC providers via command line:

```bash
# List configured providers
kubectl exec -n nextcloud-system deployment/nextcloud -- su -s /bin/bash www-data -c "php occ user_oidc:provider"
```
