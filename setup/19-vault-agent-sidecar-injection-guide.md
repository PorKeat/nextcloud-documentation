# 19. HashiCorp Vault Agent In-Memory Sidecar Injection Guide

This guide details how to use the **Official HashiCorp Vault Agent Injector** to securely deliver credentials directly into **In-Memory RAM (`tmpfs`)** at `/vault/secrets/` with **zero `etcd` disk footprint**.

---

## 🏛️ 1. Why In-Memory Vault Injection?

* **Zero `etcd` Footprint:** Secrets are never written to Kubernetes `etcd` storage. `kubectl get secrets` shows nothing to potential attackers.
* **Pure In-Memory Delivery:** Credentials reside in a POSIX `tmpfs` RAM volume inside the pod and are wiped the millisecond the container terminates.
* **Automated Rotation:** Vault Agent automatically renews leases and rotates passwords in memory when updated in the Vault Web UI.

---

## 🚀 2. How to Enable Vault Injection on Any Deployment

To connect any Kubernetes pod to Vault, simply add these **annotations** to your Deployment:

```yaml
spec:
  template:
    metadata:
      annotations:
        # 1. Enable Vault Sidecar Injection
        vault.hashicorp.com/agent-inject: "true"
        
        # 2. Select Vault Role
        vault.hashicorp.com/role: "nextcloud-role"
        
        # 3. Specify Target Secret and In-Memory Filename
        vault.hashicorp.com/agent-inject-secret-credentials.env: "secret/data/nextcloud"
        
        # 4. Define Template
        vault.hashicorp.com/agent-inject-template-credentials.env: |
          {{- with secret "secret/data/nextcloud" -}}
          export DB_USER="{{ .Data.data.db_user }}"
          export DB_PASSWORD="{{ .Data.data.db_password }}"
          export MINIO_ACCESS_KEY="{{ .Data.data.minio_access_key }}"
          export MINIO_SECRET_KEY="{{ .Data.data.minio_secret_key }}"
          {{- end -}}
```

---

## 🔍 3. Verifying In-Memory Secret Delivery

1. Inspect pod containers (shows `2/2` running with `vault-agent` sidecar):
   ```bash
   kubectl get pods -n nextcloud-system
   ```

2. Verify that secrets exist in RAM at `/vault/secrets/credentials.env`:
   ```bash
   kubectl exec -it <POD_NAME> -n nextcloud-system -c <APP_CONTAINER> -- cat /vault/secrets/credentials.env
   ```

3. Verify zero `etcd` footprint:
   ```bash
   kubectl get secrets -n nextcloud-system
   # Output: Confirms NO raw password objects are created in etcd!
   ```
