# 17. Automated System Health & Security Scorecard Audit

This guide explains how to run the automated **Enterprise Health & Security Audit** across any cluster node to verify high-availability, zero-trust network isolation, CIS security contexts, and backup retention.

---

## ⚡ 1. Fast 1-Click Execution

The audit utility is installed globally in `/usr/local/bin/cluster-audit` on all master nodes.

To run the audit from any directory:

```bash
cluster-audit
```

---

## 🔍 2. The 8 Automated Audit Checks

The script inspects every critical layer of the Kubernetes architecture:

1. **Control-Plane & API Server HA:** Tests local API loopback (`127.0.0.1:6443`) and etcd quorum.
2. **Nextcloud Replicas:** Verifies active healthy replicas in `nextcloud-system`.
3. **PostgreSQL Database HA:** Queries CloudNativePG primary status and replication health.
4. **Redis Sentinel Cache:** Checks Redis statefulset availability and session store connectivity.
5. **CIS Pod Security Standards:** Checks `seccompProfile: RuntimeDefault` and `allowPrivilegeEscalation: false`.
6. **Cilium eBPF Zero-Trust Isolation:** Verifies `CiliumNetworkPolicy` firewall rules on DB port 5432 and Redis port 6379.
7. **Velero Backup Automation:** Checks active daily 1:00 AM schedule with 7-Day TTL auto-purge.
8. **PostgreSQL S3 Backup CronJob:** Checks nightly 2:00 AM dump CronJob with 7-Day MinIO auto-pruning.

---

## 🖥️ 3. Node 1 Recovery & Setup Procedure

When **Node 1** (`10.1.16.11`) powers back on, run the automated rejoining and audit script:

```bash
# Run on Node 1:
curl -fsSL https://raw.githubusercontent.com/PorKeat/nextcloud-documentation/main/scripts/node1-rejoin-and-audit.sh | bash
# OR directly execute:
bash /root/node1-rejoin-and-audit.sh
```

---

## 📊 Sample Output & Scorecard

```text
============================================================
    🔍 STARTING ENTERPRISE HEALTH & SECURITY AUDIT...
============================================================
[1/8] Testing Control-Plane & API Server HA... ✅ PASS (API Server responsive, Quorum active)
[2/8] Testing Nextcloud Pods & Replicas...     ✅ PASS (3/3 replicas healthy and running)
[3/8] Testing PostgreSQL HA (CloudNativePG)... ✅ PASS (Primary: nextcloud-db-1 active)
[4/8] Testing Redis Sentinel Cluster...        ✅ PASS (Redis cache & session store online)
[5/8] Testing CIS Pod Security Contexts...     ✅ PASS (Seccomp RuntimeDefault + PrivEscalation: false enforced)
[6/8] Testing Cilium eBPF Network Policies...  ✅ PASS (2 CiliumNetworkPolicies active - DB port 5432 isolated)
[7/8] Testing Velero Backup Automation & 7-Day TTL... ✅ PASS (Schedule: 0 1 * * * | TTL: 7 Days auto-purge active)
[8/8] Testing PostgreSQL Nightly S3 Backup CronJob... ✅ PASS (Schedule: 0 2 * * * | Auto-prunes > 7 days to MinIO S3)

============================================================
       🏆 ENTERPRISE SYSTEM HEALTH & SECURITY SCORECARD
============================================================
 Total Score: 8 / 8 (100%)
 Final Grade: 🌟 A+ (Bank-Grade Production Ready)
============================================================
```
