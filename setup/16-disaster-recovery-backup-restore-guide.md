# 16. Disaster Recovery & Scheduled Backup Automation Guide

This guide details the automated backup schedules, 7-day retention (TTL auto-purge), and step-by-step 1-click disaster recovery procedures for the Nextcloud Kubernetes cluster.

---

## 📅 1. Automated Backup Schedules (7-Day Rolling Retention)

| Backup Layer | Schedule | Scope | Retention (TTL) | Destination |
| :--- | :--- | :--- | :--- | :--- |
| **Layer 1: Velero Snapshots** | `0 1 * * *` (1:00 AM UTC) | K8s manifests, secrets, configmaps, routes | **7 Days** (`ttl: 168h`) | MinIO S3 (`velero` bucket) |
| **Layer 2: PostgreSQL Dumps** | `0 2 * * *` (2:00 AM UTC) | Full `nextcloud` database SQL dump | **7 Days** (`mc rm --older-than 7d`) | MinIO S3 (`db-backups` bucket) |
| **Layer 3: MinIO S3 Object Lock** | Continuous | Nextcloud user files, photos, docs | **30 Days WORM** | MinIO S3 (`nextcloud-data` bucket) |

---

## 🚀 2. Operational & On-Demand Commands

### A. Check Scheduled Backup Status
```bash
# View active Velero schedules
kubectl get schedule -n velero

# View recent Velero backup snapshots
kubectl get backup.velero.io -n velero

# View PostgreSQL backup CronJob
kubectl get cronjob nextcloud-db-backup -n nextcloud-system
```

### B. Trigger an Instant On-Demand Backup
```bash
# 1. Trigger on-demand Velero cluster backup
cat << 'BACKUP_EOF' | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%F-%H%M)
  namespace: velero
spec:
  includedNamespaces:
  - nextcloud-system
  - traefik-system
  - metallb-system
  snapshotVolumes: false
  ttl: 168h0m0s
BACKUP_EOF

# 2. Trigger on-demand PostgreSQL S3 dump
kubectl create job --from=cronjob/nextcloud-db-backup manual-db-dump-$(date +%F-%H%M) -n nextcloud-system
```

---

## 🔄 3. 1-Click Disaster Recovery (Restore Procedure)

If a disaster strikes (e.g. cluster deletion, ransomware attack, or accidental database corruption), follow these steps to restore service in under 3 minutes:

### Step 1: Restore Kubernetes Infrastructure with Velero
```bash
# List available backups in MinIO S3
kubectl get backup.velero.io -n velero

# Restore all namespaces, secrets, and routes from the latest backup
velero restore create --from-backup <BACKUP_NAME>
```

### Step 2: Restore PostgreSQL Database Dump
```bash
# 1. Download latest dump from MinIO db-backups bucket
mc cp myminio/db-backups/latest-dump.sql.gz /tmp/restore.sql.gz

# 2. Stream uncompressed SQL directly into CloudNativePG Primary
gunzip -c /tmp/restore.sql.gz | kubectl exec -i -n nextcloud-system nextcloud-db-1 -- psql -U admin -d nextcloud
```

### Step 3: Verify Nextcloud Health
```bash
kubectl get pods -n nextcloud-system
curl -k -I https://nextcloud.sengporkeat.com
```
