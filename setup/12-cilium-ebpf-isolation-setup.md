# Cilium eBPF Zero-Trust Isolation Setup Guide

This guide provides the hands-on commands to apply, verify, and test **Cilium eBPF Zero-Trust Network Isolation** on the `nextcloud-system` namespace.

---

## 1. Apply Cilium Network Policies

Run this command to apply the isolation policies to your Kubernetes cluster:

```bash
kubectl apply -f manifests/10-cilium-nextcloud-isolation.yaml
```

Verify that the policies are active:
```bash
kubectl get cnp -n nextcloud-system
```
*(Should output `VALID: True` for both `nextcloud-system-namespace-isolation` and `postgresql-database-lockdown`).*

---

## 2. Lock Down Redis NetworkPolicy

To ensure Redis is strictly accessible only by Nextcloud:

```bash
kubectl apply -f manifests/07-traefik-security-headers-middleware.yaml # Or apply the redis network policy
```

---

## 3. Verify Isolation with a Security Probe Test

To simulate a rogue pod in another namespace attempting to access your database:

1. **Deploy temporary test pod in `default` namespace:**
   ```bash
   kubectl run sec-probe --image=curlimages/curl -n default --command -- sleep 300
   ```

2. **Attempt connection to PostgreSQL:**
   ```bash
   kubectl exec sec-probe -n default -- nc -zv -w 3 nextcloud-db-rw.nextcloud-system.svc.cluster.local 5432
   ```
   * **Expected Result:** `Operation timed out` (Packet successfully dropped by eBPF).

3. **Attempt connection to Redis:**
   ```bash
   kubectl exec sec-probe -n default -- nc -zv -w 3 nextcloud-redis.nextcloud-system.svc.cluster.local 6379
   ```
   * **Expected Result:** `Operation timed out` (Packet successfully dropped by eBPF).

4. **Clean up probe:**
   ```bash
   kubectl delete pod sec-probe -n default
   ```

---

## 4. Emergency Rollback

If you need to instantly disable all isolation rules:

```bash
kubectl delete -f manifests/10-cilium-nextcloud-isolation.yaml
```
