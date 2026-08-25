# 7. Enterprise Security Hardening & HSTS Guide

This guide covers the security hardening implemented to ensure real client IP visibility, brute-force protection accuracy, and browser-enforced HSTS encryption.

---

## 1. Real Client IP Visibility (`trusted_proxies`)

Because Nextcloud sits behind the Tiyi WAF and Traefik Ingress, Nextcloud must be configured to trust the proxy subnets to extract the genuine user IP from the `X-Forwarded-For` header.

### Configuration Applied
```bash
# Trust WAF subnet
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 0 --value="10.1.18.0/24"

# Trust K8s node subnet
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 1 --value="10.1.16.0/24"

# Trust internal Pod CIDR
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set trusted_proxies 2 --value="10.233.0.0/18"

# Enable forwarded headers
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
```

### Why This is Critical
* **Prevents Global Lockouts:** Prevents Nextcloud's brute-force detector from banning the shared WAF IP address if one user types the wrong password repeatedly.
* **Accurate Audit Logs:** User logins, file sharing events, and activity logs reflect the real public IP address of the client.

---

## 2. HTTP Strict Transport Security (HSTS)

HSTS instructs browsers that the site must only be accessed over secure HTTPS connections, preventing SSL-stripping and man-in-the-middle attacks.

### Traefik Middleware (`manifests/07-traefik-security-headers-middleware.yaml`)
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: nextcloud-security-headers
  namespace: nextcloud-system
spec:
  headers:
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    forceSTSHeader: true
    customResponseHeaders:
      X-Robots-Tag: "noindex, nofollow"
```

### Verification
```bash
curl -I -s -k https://nextcloud.sengporkeat.com/login | grep -i strict-transport-security
# Expected output:
# strict-transport-security: max-age=31536000; includeSubDomains; preload
```

---

## 3. Storage & S3 Isolation Checklist

1. **MinIO S3 Access:** Accessible strictly via internal network (`10.1.18.7:9000`). Port `9000` is blocked from external internet routing.
2. **Bucket Policy:** The `nextcloud-data` bucket is strictly configured as **Private** (no anonymous read/write).
