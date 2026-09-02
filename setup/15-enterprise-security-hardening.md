# 15. Enterprise Security Hardening & Threat Mitigation

This guide details the steps to enforce bank-grade security across the Nextcloud Kubernetes cluster, mitigating brute-force password attacks, container breakouts, and ransomware data destruction.

---

## 1. Real Client IP & Anti-Brute-Force Protection

Because incoming traffic routes through **Tiyi WAF ➡️ APISIX ➡️ Traefik**, Nextcloud must correctly identify the client's real public IP address to prevent accidental proxy bans and enable targeted brute-force rate limiting.

### A. Configure Trusted Proxies
Execute inside the Nextcloud application pod:

```bash
# Register WAF, Gateway, and internal Pod/Service CIDRs as trusted proxies
php occ config:system:set trusted_proxies 0 --value="10.1.18.4"
php occ config:system:set trusted_proxies 1 --value="10.1.16.0/24"
php occ config:system:set trusted_proxies 2 --value="10.233.0.0/18"
php occ config:system:set trusted_proxies 3 --value="10.233.0.0/16"
php occ config:system:set trusted_proxies 4 --value="103.189.186.19" # Tiyi WAF Gateway

# Enforce X-Forwarded-For Header
php occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
```

### B. Activate Brute-Force Rate Limiting
```bash
# Enable native Nextcloud brute-force attack mitigation
php occ config:system:set auth.bruteforce.protection.enabled --value=true --type=boolean

# Verify status
php occ config:system:get auth.bruteforce.protection.enabled
# Output: true
```

---

## 2. Linux Kernel Pod Security Context (CIS Benchmark Compliance)

To eliminate the risk of container breakouts or privilege escalation from potential web vulnerabilities (e.g. Apache/PHP exploits), all Nextcloud application and push pods are hardened with strict Linux kernel capability drops and Seccomp filters.

### Hardened Deployment Spec (`nextcloud-green-deployment.yaml`):

```yaml
spec:
  template:
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault  # Blocks dangerous Linux system calls
      containers:
      - name: nextcloud
        image: nextcloud:apache
        securityContext:
          allowPrivilegeEscalation: false # Disables SUID root escalation
          capabilities:
            drop:
            - ALL                         # Drops all unneeded Linux capabilities
            add:
            - NET_BIND_SERVICE
            - CHOWN
            - SETUID
            - SETGID
            - DAC_OVERRIDE
```

### Hardened Push Daemon Spec (`notify-push-deployment.yaml`):

```yaml
spec:
  template:
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
        runAsNonRoot: true              # Strictly runs as non-root user
        runAsUser: 33                   # www-data user ID
        runAsGroup: 33                  # www-data group ID
      containers:
      - name: notify-push
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL                       # Full capability lockdown
```

---

## 3. Ransomware-Proof Backup Immutability (MinIO WORM / Object Lock)

To guarantee that backup archives cannot be wiped or encrypted by ransomware or compromised administrative keys, Object Locking (Write Once, Read Many) is enforced on MinIO buckets.

### MinIO WORM Policy:
* **Retention Mode:** `Compliance` or `Governance`
* **Retention Period:** 30 Days
* **Result:** Objects written to `db-backups` and `velero` cannot be deleted, modified, or overwritten by any user or API token until the 30-day retention period expires.

---

## 4. Verification & Audit Commands

```bash
# 1. Verify running pod security contexts
kubectl get pods -n nextcloud-system -o custom-columns=NAME:.metadata.name,ALLOW_PRIVILEGE_ESC:.spec.containers[*].securityContext.allowPrivilegeEscalation,SECCOMP:.spec.securityContext.seccompProfile.type

# 2. Check active brute-force attempts logged
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ security:bruteforce:reset <IP_ADDRESS>
```
