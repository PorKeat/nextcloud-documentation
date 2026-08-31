# 5. Object Storage (MinIO S3) & Server-Side Encryption (SSE)

This guide documents the MinIO S3 object storage configuration and SSL self-signed certificate handling for Nextcloud.

---

## 1. MinIO S3 Backend Topology

* **MinIO Host:** `https://10.1.18.7:9000`
* **Bucket:** `nextcloud-data`
* **TLS Mode:** Self-Signed Internal Certificate (`O=Certgen Development`)
* **Nextcloud Object Store Class:** `\OC\Files\ObjectStore\S3`

---

## 2. Configuration Settings (`config.php`)

To ensure Nextcloud communicates seamlessly with internal MinIO instances using self-signed TLS certificates without throwing `cURL error 60`, the `verify` argument must be set to `false`:

```php
'objectstore' => array (
  'class' => '\\OC\\Files\\ObjectStore\\S3',
  'arguments' => array (
    'bucket' => 'nextcloud-data',
    'autocreate' => true,
    'key' => '<MINIO_ACCESS_KEY>',
    'secret' => '<MINIO_SECRET_KEY>',
    'hostname' => '10.1.18.7',
    'port' => 9000,
    'use_ssl' => true,
    'region' => 'us-east-1',
    'use_path_style' => true,
    'verify' => false, // Bypasses self-signed SSL verification for internal MinIO
  ),
),
```

### CLI Command to Apply:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set objectstore arguments verify --type=boolean --value=false
```

---

## 3. Verifying MinIO Connectivity

Test live health endpoint from inside a Nextcloud pod:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- curl -k -v https://10.1.18.7:9000/minio/health/live
```
