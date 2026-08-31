# Nextcloud Blue-Green Deployment & Cutover Hands-On Guide

This guide contains the exact commands to deploy **Nextcloud Blue**, test it via preview routing, perform a **1-second live cutover in APISIX**, and redeploy Green.

---

## 1. Deploy Nextcloud Blue Stack

Deploy the Blue service and deployment alongside your existing live Green deployment:

```bash
kubectl apply -f manifests/04-nextcloud-app/nextcloud-blue-deployment.yaml
```

Check pod startup status:
```bash
kubectl get pods -n nextcloud-system -l deployment.color=blue
```

---

## 2. Test & Verify on Blue

1. **Access the Preview Route:**
   Open `https://blue.sengporkeat.com` (or your private APISIX preview route) in your browser.

2. **Run Verification Checklist:**
   * ✅ Log in via Keycloak OIDC.
   * ✅ Verify UI theme and custom apps.
   * ✅ Open a test document in Collabora Office.
   * ✅ Upload a test image/file to verify MinIO S3 streaming.

---

## 3. The 1-Second Live Cutover (Go Live)

Update the APISIX upstream for `nextcloud.sengporkeat.com` to route all incoming live traffic to `nextcloud-service-blue:8080`:

```bash
# Update APISIX live route to point to Blue
curl -X PATCH http://apisix-admin:9180/apisix/admin/routes/nextcloud-service \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -d '{"upstream": {"nodes": {"nextcloud-service-blue.nextcloud-system.svc.cluster.local:8080": 1}}}'
```
⚡ **All live users are now instantly using Blue with zero seconds of downtime.**

---

## 4. Redeploy / Sync Green for the Next Development Cycle

Now that Blue is handling 100% of live traffic, prepare Green for your next sprint:

### Option A: Update Green with the latest Docker image
```bash
kubectl set image deployment/nextcloud-green nextcloud=nextcloud:your-new-tag -n nextcloud-system
```

### Option B: Reload ConfigMaps / PHP settings on Green
```bash
kubectl rollout restart deployment/nextcloud-green -n nextcloud-system
```

### Option C: Scale Green to 0 to save RAM when idle
```bash
kubectl scale deployment/nextcloud-green --replicas=0 -n nextcloud-system
```

---

## 5. Instant Emergency Rollback

If a critical bug is discovered on Blue:
```bash
# Immediately revert APISIX back to Green (0.1 seconds)
curl -X PATCH http://apisix-admin:9180/apisix/admin/routes/nextcloud-service \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -d '{"upstream": {"nodes": {"nextcloud-service.nextcloud-system.svc.cluster.local:8080": 1}}}'
```
