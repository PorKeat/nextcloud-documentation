# 5. Nextcloud Encryption & S3 Storage Architecture

This guide explains how Server-Side Encryption interacts with multi-replica Kubernetes pods and remote MinIO S3 object storage.

---

## 1. The Multi-Replica Session Conflict (Root Cause of "Invalid Private Key")

When running multiple Nextcloud pod replicas behind a load balancer:

* **User-Key Mode (Default):** Nextcloud attempts to decrypt a user-specific private key using the login password and cache it in the active PHP session. When accessing via multiple browser tabs or concurrent background requests, requests hit different replicas where the key is not in memory, throwing:
  > *"Invalid private key for encryption app. Please update your private key password in your personal settings to recover access to your encrypted files."*
* **Master-Key Mode (Recommended for Multi-Pod Clusters):** Nextcloud uses a single, cluster-wide Master Key stored in the shared persistent volume. All pod replicas access the same key simultaneously, preventing session desynchronization.

---

## 2. Managing Encryption via `occ`

### Enable Master Key Mode (Current Production Setup)
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ encryption:enable-master-key
```

### Check Encryption Status
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ encryption:status
```

### Optional: Decrypt All Files & Disable Server-Side Encryption
If relying entirely on MinIO S3 Server-Side Encryption (SSE) for highest performance:
```bash
# 1. Enable Maintenance Mode
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ maintenance:mode --on

# 2. Decrypt all files (Interactive confirmation: type 'y')
kubectl exec -n nextcloud-system -it deployment/nextcloud -- php occ encryption:decrypt-all

# 3. Disable the module
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ encryption:disable
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable encryption

# 4. Disable Maintenance Mode
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ maintenance:mode --off
```

---

## 3. Comparison Matrix

| Mode | Storage Protection | Multi-Pod Stability | Performance |
| :--- | :---: | :---: | :---: |
| **Master Key Mode** | Protects raw S3 bucket | High (No session key errors) | Standard |
| **User Key Mode** | Encrypts per-user password | Low (Prone to session race conditions) | Slower |
| **MinIO S3 Native SSE** | Hardware / Bucket level | 100% Native | Fastest |
