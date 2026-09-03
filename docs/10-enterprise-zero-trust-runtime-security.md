# 10. Enterprise Zero-Trust Runtime Security & Resilience Architecture

This document provides a deep-dive educational and architectural reference on how the Nextcloud enterprise cluster achieves bank-grade resilience, multi-master High Availability (HA), Linux kernel isolation, and ransomware-proof data protection.

---

## 🏗️ 1. Multi-Master Kubernetes Control-Plane High Availability (HA)

### A. The Challenge: Single Entry Point Bottleneck
In standard single-endpoint installations, all nodes resolve the Kubernetes API server domain (`lb.kubesphere.local`) to the IP of the first master node (`Node 1 - 10.1.16.11`). When Node 1 experiences hardware or network failure:
* Requests to `https://lb.kubesphere.local:6443` fail with `dial tcp 10.1.16.11:6443: connect: no route to host`.
* Local cluster operations and automated reconciliation stall even when surviving master nodes are 100% healthy.

### B. The Distributed Loopback Architecture
By mapping `lb.kubesphere.local` to `127.0.0.1` locally in `/etc/hosts` across all control-plane nodes:
* **Node 1** communicates with its own local `kube-apiserver` on `127.0.0.1:6443`.
* **Node 2** communicates with its own local `kube-apiserver` on `127.0.0.1:6443`.
* **Node 3** communicates with its own local `kube-apiserver` on `127.0.0.1:6443`.

```
                    ┌───────────────────────────────┐
                    │       etcd 3-Node Raft        │
                    │      Consensus Quorum         │
                    └───────▲───────────────▲───────┘
                            │               │
            ┌───────────────┴───┐       ┌───┴───────────────┐
            │  Node 2 (10.1.16.12)│     │  Node 3 (10.1.16.13)│
            │  127.0.0.1:6443   │       │  127.0.0.1:6443   │
            │  (Active Master)  │       │  (Active Master)  │
            └───────────────────┘       └───────────────────┘
```

**Resilience Guarantee:** With a 3-node etcd cluster, the system can tolerate a complete physical outage of any 1 node without losing quorum, data, or control-plane access.

---

## 🔒 2. Linux Kernel Pod Security Standards (CIS Benchmark Compliance)

Container isolation relies on the host Linux kernel namespaces and control groups (cgroups). To prevent container breakouts and privilege escalation attacks, multi-layered security contexts are enforced.

```
+-------------------------------------------------------------------+
|                        Host Linux Kernel                          |
|  +-------------------------------------------------------------+  |
|  |                Seccomp Filter (RuntimeDefault)              |  |
|  |   - Drops unapproved system calls (ptrace, reboot, etc.)    |  |
|  +------------------------------▲------------------------------+  |
|                                 |                                 |
|  +------------------------------┴------------------------------+  |
|  |                     Container Process                       |  |
|  |  * allowPrivilegeEscalation: false                          |  |
|  |  * capabilities.drop: ["ALL"]                               |  |
|  |  * capabilities.add: [NET_BIND_SERVICE, CHOWN, SETUID]      |  |
|  |  * runAsNonRoot: true (UID 33 www-data for push daemon)     |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------------+
```

### A. Seccomp (Secure Computing Mode)
* **Profile:** `RuntimeDefault`
* **Mechanism:** Restricts the list of system calls (syscalls) a container process can make to the host Linux kernel. Dangerous syscalls such as `reboot`, `sys_ptrace`, and kernel module loaders are unconditionally intercepted and blocked.

### B. Linux Capability Drops (`capabilities: drop: ["ALL"]`)
* By default, Docker/Kubernetes containers inherit unnecessary Linux capabilities (e.g., raw socket access, disk management).
* **Nextcloud Web Containers:** Drop `ALL` capabilities and whitelist only the 5 strictly required POSIX permissions:
  * `NET_BIND_SERVICE`: Bind Apache to port 80/8080.
  * `CHOWN`, `SETUID`, `SETGID`: Allow Apache to drop privileges from startup to `www-data`.
  * `DAC_OVERRIDE`: Read and write mounted PVC file assets.
* **Notify Push Daemon:** Drops `ALL` capabilities with zero additions and executes as non-root user `33` (`www-data`).

### C. Prevention of Privilege Escalation (`allowPrivilegeEscalation: false`)
* Ensures that `setuid` or `setgid` binaries inside the container filesystem cannot elevate the process permissions to host root.

---

## 🌐 3. Layer 7 Real-Client IP & Anti-Brute-Force Architecture

### A. The Reverse Proxy Challenge
When client traffic passes through multiple proxy layers (**Tiyi WAF ➡️ APISIX ➡️ Traefik ➡️ Nextcloud**), Nextcloud's web server initially perceives incoming connections as originating from the internal Gateway IP.

```
[Attacker IP: 203.0.113.50]
        │
        ▼
[Tiyi WAF: 103.189.186.19]  (Appends X-Forwarded-For: 203.0.113.50)
        │
        ▼
[APISIX Gateway: 10.1.18.4]
        │
        ▼
[Traefik Ingress: 10.233.x.x]
        │
        ▼
[Nextcloud Pod: 10.233.x.x] ──> Looks at trusted_proxies & extracts Real IP!
```

### B. Trusted Proxy Validation
Nextcloud validates that incoming requests arrive exclusively from known proxy hops before trusting the `X-Forwarded-For` header:
* `trusted_proxies`: Registered CIDRs for WAF (`103.189.186.19`), internal APISIX (`10.1.18.4`), and cluster pod/service networks (`10.233.0.0/16`, `10.1.16.0/24`).
* `forwarded_for_headers`: Set to `HTTP_X_FORWARDED_FOR`.

### C. Native Brute-Force Rate Limiting (`auth.bruteforce.protection.enabled`)
* When an attacker attempts multiple incorrect password submissions against login endpoints:
  1. Nextcloud identifies the attacker's **real public IP** from the verified header.
  2. Nextcloud applies an exponential delay (from 100ms up to 30 seconds per attempt) exclusively to that offending IP.
  3. Legitimate users and the shared gateway are never penalized or blocked.

---

## 💾 4. Ransomware-Proof Backup Immutability (WORM Model)

### A. Threat Scenario
Ransomware operators and malicious actors prioritize compromising backup storage before deploying encryption payloads, ensuring victims cannot restore data.

### B. Object Locking (Write Once, Read Many)
* **Technology:** S3 Object Lock via MinIO backend.
* **Policy:** 30-Day Retention in `Compliance` / `Governance` mode.
* **Protection Mechanism:**
  * Once a PostgreSQL database dump or Velero snapshot is written to MinIO, the S3 storage engine enforces a cryptographic retention lock.
  * No API call, admin token, or root user can delete or overwrite the object until the 30-day window expires.
  * Guarantees a clean, uncorrupted recovery point at all times.

---

## 📊 Summary Architecture Matrix

| Layer | Component | Security / Resilience Mechanism | Standard Met |
| :--- | :--- | :--- | :--- |
| **Control Plane** | API Server & etcd | Local Loopback (`127.0.0.1:6443`) & 3-Node Raft | Multi-Master Zero Single-Point-of-Failure |
| **Edge / WAF** | Tiyi WAF & APISIX | Layer 7 Header Inspection & Geo/IP Filtering | OWASP Top 10 Mitigation |
| **Network** | Cilium eBPF | Kernel-level eBPF namespace isolation & DB lockdown | Zero-Trust Network Architecture |
| **Runtime eBPF** | Cilium Tetragon | Real-time `execve`/`openat` syscall monitoring & `Sigkill` | eBPF Zero-Trust Runtime Security |
| **Workload** | Nextcloud & Push | Seccomp RuntimeDefault, Capability Drops, Non-Root | CIS Kubernetes Benchmark |
| **Application** | Nextcloud Engine | Trusted Proxies & Anti-Brute-Force Rate Limiting | NIST SP 800-63B Authentication |
| **Storage** | MinIO & Velero | S3 Object Locking (WORM) & 3-Tier Backups | Immutable Ransomware Defense |
