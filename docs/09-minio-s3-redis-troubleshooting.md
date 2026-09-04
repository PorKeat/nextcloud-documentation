# 9. MinIO S3 + Valkey (formerly Redis) + Login Troubleshooting Guide

This guide documents all production issues encountered and resolved, covering MinIO S3 upload failures, in-memory caching/file-locking conflicts, Traefik upload buffering, and PostgreSQL DAV login crashes.

---

## 1. MinIO S3 SSL Certificate Error (`cURL error 60`)

### Symptom
All file uploads fail with:
```
Creation of bucket "nextcloud-data" failed. AWS HTTP error:
cURL error 60: SSL certificate problem: self-signed certificate
```

### Root Cause
MinIO at `https://10.1.18.7:9000` uses an internally self-signed TLS certificate (`O=Certgen Development`). PHP cURL (used by the AWS S3 SDK) rejected the certificate with a hard SSL verification failure.

### Fix

**Step 1:** Tell Nextcloud to bypass SSL verification for MinIO:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ config:system:set objectstore arguments verify --type=boolean --value=false
```

**Step 2:** Extract MinIO's TLS certificate and inject it permanently into pods via `postStart` lifecycle hook:
```bash
# Extract live cert from MinIO on node1
echo | openssl s_client -showcerts -connect 10.1.18.7:9000 2>/dev/null \
  | openssl x509 -outform PEM > /tmp/live-minio.crt

# Store as Kubernetes secret
kubectl create secret generic minio-tls-ca \
  --from-file=minio-ca.crt=/tmp/live-minio.crt \
  -n nextcloud-system --dry-run=client -o yaml | kubectl apply -f -
```

Add to Nextcloud Deployment `lifecycle.postStart`:
```yaml
lifecycle:
  postStart:
    exec:
      command:
      - /bin/bash
      - -c
      - cat /usr/local/share/ca-certificates/minio-ca.crt >> /etc/ssl/certs/ca-certificates.crt && update-ca-certificates
```

**Verify:**
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  curl -k https://10.1.18.7:9000/minio/health/live
# Expected: HTTP/1.1 200 OK
```

---

## 2. In-Memory Transactional Locking Conflict with S3 (`HTTP 423 Locked`)

### Symptom
Every file upload returns `HTTP 423 Locked`:
```
LockedException: files/... is locked, existing lock on file: none
```

### Root Cause
Nextcloud's `memcache.locking => \OC\Memcache\Redis` applies POSIX-style transactional file locks. When using **MinIO S3 as Primary Object Storage**, S3 handles atomic writes natively. Layering in-memory POSIX locks over S3 stream writes causes irreconcilable lock collisions — the lock is acquired, the S3 write starts, then fails, but the lock is never released, permanently blocking the filename.

### Fix
```bash
# Remove S3-incompatible transactional file locking
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ config:system:delete memcache.locking

# Disable file locking (S3 handles object-level concurrency natively)
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ config:system:set filelocking.enabled --type=boolean --value=false
```

**Correct `config.php` for S3 primary storage with Valkey:**
```php
'memcache.local'       => '\\OC\\Memcache\\APCu',
'memcache.distributed' => '\\OC\\Memcache\\Redis',  // kept for distributed cache (connected to Valkey)
'filelocking.enabled'  => false,                     // S3 handles concurrency natively
'redis' => array (
  'host'            => 'nextcloud-valkey-node-0.nextcloud-valkey-headless',
  'port'            => 6379,
  'password'        => '<VALKEY_PASSWORD>',
  'timeout'         => 0.0,
  'read_timeout'    => 0.0,
),
```

> **Note:** Valkey is still active for distributed caching, session storage, and WebSocket pub/sub messaging (`notify_push`). Only the S3-incompatible POSIX locking layer is removed.

---

## 3. Traefik Upload Buffering (WAF Disconnects on Large Uploads)

### Symptom
Browser shows `net::ERR_INTERNET_DISCONNECTED` during file upload.

### Root Cause
Tiyi WAF uses HTTP/2. Traefik forwards to Nextcloud over HTTP/1.1. Without buffering, chunked `PUT` payloads cause TCP stream resets between Tiyi WAF and Traefik.

### Fix

Apply Traefik Buffering middleware:
```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: upload-buffering-middleware
  namespace: nextcloud-system
spec:
  buffering:
    maxRequestBodyBytes: 10737418240   # 10 GB
    memRequestBodyBytes: 33554432      # 32 MB in memory
    retryExpression: "IsNetworkError() && Attempts() < 3"
EOF
```

Attach `upload-buffering-middleware` to the `nextcloud-route` IngressRoute alongside existing security headers middleware.

---

## 4. PostgreSQL DAV Savepoint Crash on OIDC Login (`HTTP 500`)

### Symptom
Every SSO login via Keycloak returns `500 Internal Server Error`:
```
SQLSTATE[3B001]: Invalid savepoint specification: 7
ERROR: savepoint "doctrine_2" does not exist
```

### Root Cause
On each OIDC login, `ProvisioningService` calls `AccountManager.updateAccount()`, which triggers `DAV\UserEventsListener` to sync the user's contact card inside a **nested PostgreSQL savepoint transaction**. Stale dead tuples in `oc_accounts`, `oc_addressbooks`, and `oc_cards` caused query plan failures that aborted the outer transaction, destroying the savepoint before it could be rolled back.

### Fix — Run in order:

```bash
# 1. VACUUM ANALYZE stale DAV and account tables
kubectl exec -n nextcloud-system nextcloud-db-1 -c postgres -- \
  psql -U postgres -d nextcloud -c 'VACUUM ANALYZE oc_accounts;'
kubectl exec -n nextcloud-system nextcloud-db-1 -c postgres -- \
  psql -U postgres -d nextcloud -c 'VACUUM ANALYZE oc_accounts_data;'
kubectl exec -n nextcloud-system nextcloud-db-1 -c postgres -- \
  psql -U postgres -d nextcloud -c 'VACUUM ANALYZE oc_addressbooks;'
kubectl exec -n nextcloud-system nextcloud-db-1 -c postgres -- \
  psql -U postgres -d nextcloud -c 'VACUUM ANALYZE oc_cards;'

# 2. Remove invalid DAV shares
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ dav:remove-invalid-shares

# 3. Resync system address book
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ dav:sync-system-addressbook

# 4. Full maintenance repair
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  php occ maintenance:repair
```

> If `500 Internal Server Error` on login reappears in future, re-run these 4 steps in order.

---

## 5. Full Production Stack Status (Post-Fix)

| Component | Status | Notes |
|:---|:---:|:---|
| **MinIO S3 Object Store** | ✅ Active | TLS trusted via `postStart` hook. `verify=false` applied. |
| **Redis Sentinel Cluster** | ✅ Active | Used for distributed cache & sessions only. Locking removed. |
| **APCu Local Cache** | ✅ Active | Per-pod in-memory opcode cache. |
| **Traefik Upload Buffering** | ✅ Active | 10GB max payload, 32MB in-memory, 3 retries on network error. |
| **PostgreSQL CNPG HA (3-node)** | ✅ Active | VACUUM'd and repaired. DAV sync healthy. |
| **Keycloak OIDC SSO** | ✅ Active | Login completes cleanly, user provisioning stable. |
| **Tiyi WAF** | ✅ Active | Upload streams pass through without disconnects. |

---

## 6. Maintenance Quick Reference

```bash
# Clear stale file scan cache
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ files:scan --all
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ files:cleanup

# Force DB repair after any upgrade or crash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ maintenance:repair

# Check S3 connectivity
kubectl exec -n nextcloud-system deployment/nextcloud -- \
  curl -k https://10.1.18.7:9000/minio/health/live

# Check Nextcloud live status
curl -s https://nextcloud.sengporkeat.com/status.php | python3 -m json.tool
```
