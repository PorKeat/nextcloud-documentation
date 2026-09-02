# 18. HashiCorp Vault Secrets Management & Web UI Guide

This guide details how to operate, unseal, manage credentials, and access the Web Dashboard for **HashiCorp Vault (`10.1.18.8:8200`)**.

---

## 🌐 1. Accessing the Vault Web UI

* **URL:** [`https://10.1.18.8:8200/ui`](https://10.1.18.8:8200/ui)
* **Auth Method:** `Token`
* **Token:** *(Paste your Initial Root Token)*

> **Browser Note:** If the browser prompts that the connection is not private, click **Advanced ➡️ Proceed to 10.1.18.8** (or type `thisisunsafe` in Chrome).

---

## 🔓 2. Unsealing Vault (CLI)

When the Vault server reboots, it starts in a **Sealed** state. Unseal it by providing 3 threshold keys:

```bash
# Export environment
export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="/opt/vault/tls/vault-ca.crt"

# Step 1: Provide Key 1
vault operator unseal

# Step 2: Provide Key 2
vault operator unseal

# Step 3: Provide Key 3
vault operator unseal
```

Verify status:
```bash
vault status
# Expected: Sealed: false
```

---

## 💾 3. Storing & Managing Secrets (KV v2)

### Storing All System Secrets in 1 Command:
```bash
# 1. Nextcloud Core
vault kv put secret/nextcloud \
  db_host="nextcloud-db-rw" \
  db_name="nextcloud" \
  db_user="admin" \
  db_password="B4r#hfdA!2" \
  minio_access_key="jrka8bLRhQKnFBax3WB9" \
  minio_secret_key="bnZZ0y8iNArMrqNYjeQhLA7FdAYvMbrsSLaHAWmZ" \
  admin_user="admin" \
  admin_password="Az@1af#23f4"

# 2. Collabora Office
vault kv put secret/collabora \
  admin_user="admin" \
  admin_password="Co8#gdw2fe"

# 3. Automated Backups & MinIO
vault kv put secret/backups \
  minio_endpoint="https://10.1.18.7:9000" \
  minio_admin_user="admin" \
  minio_admin_password="7gz7gMCF1" \
  velero_bucket="velero" \
  db_backup_bucket="db-backups" \
  db_dump_password="B4r#hfdA!2"

# 4. Keycloak SSO
vault kv put secret/keycloak \
  admin_user="admin" \
  realm="nextcloud" \
  client_id="nextcloud-k8s"

# 5. Infrastructure Nodes
vault kv put secret/infrastructure \
  node1_ip="10.1.16.11" \
  node2_ip="10.1.16.12" \
  node3_ip="10.1.16.13" \
  minio_ip="10.1.18.7" \
  vault_ip="10.1.18.8"
```

---

## 🔍 4. Reading and Versioning Secrets

```bash
# List all secret paths
vault kv list secret/

# Read Nextcloud credentials
vault kv get secret/nextcloud

# View version metadata history (v1, v2, etc.)
vault kv metadata get secret/nextcloud
```
