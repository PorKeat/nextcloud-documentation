# 20. Cilium Tetragon eBPF Runtime Security Setup & Policy Enforcement

This guide details how **Cilium Tetragon** is installed, managed, and configured for real-time kernel-level process observability, security auditing, and automated exploit prevention (`Sigkill`) across the enterprise Kubernetes cluster.

---

## 🏗️ 1. Architecture Overview

While **Cilium CNI** enforces Zero-Trust network policies at Layers 3, 4, and 7 (e.g., locking down PostgreSQL port 5432), **Tetragon** operates directly inside the Linux kernel using **eBPF CO-RE (Compile Once – Run Everywhere)** to monitor and enforce runtime security *inside* containers:

```
+-------------------------------------------------------------------------+
|                           Host Linux Kernel                             |
|  +-------------------------------------------------------------------+  |
|  |                 eBPF Kernel Probes (Tetragon Agent)               |  |
|  |   - sys_execve (Process executions, binary execution tracking)    |  |
|  |   - sys_openat (Sensitive file access auditing: config.php)      |  |
|  |   - Kernel Actions: Post (Audit), Sigkill (Instant Termination)   |  |
|  +------------------------------▲------------------------------------+  |
|                                 │                                       |
|  +------------------------------┴------------------------------------+  |
|  |                  Nextcloud Container (nextcloud-system)           |  |
|  |  * Apache / PHP Web Process (UID 33 www-data)                     |  |
|  |  * Disallowed: Webshells (/bin/sh), unauthorized network tools   |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 🚀 2. Helm Installation

Tetragon is installed into `kube-system` as a cluster-wide DaemonSet:

```bash
# 1. Add Cilium official Helm repository
helm repo add cilium https://helm.cilium.io/
helm repo update

# 2. Deploy Tetragon DaemonSet
helm upgrade --install tetragon cilium/tetragon -n kube-system

# 3. Verify DaemonSet rollout across all 3 nodes
kubectl rollout status ds/tetragon -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon -o wide
```

### Verify Status via `tetra` CLI:
```bash
kubectl exec -n kube-system ds/tetragon -c tetragon -- tetra status
```
Output:
```text
Health Status: running
```

---

## 🛡️ 3. Applying Nextcloud Tracing Policies

The Nextcloud security policies are located in `manifests/03-security-cilium/`:

### Policy A: Process Observability & File Integrity Auditing
Applies a namespaced tracing policy to audit shell execution attempts and sensitive configuration reads (`/var/www/html/config/config.php`):

```bash
kubectl apply -f manifests/03-security-cilium/tetragon-nextcloud-process-monitor.yaml
```

Verify active policy:
```bash
kubectl get tracingpoliciesnamespaced -n nextcloud-system
```

---

## 🔍 4. Streaming Real-Time Security Events

Use the `tetra` CLI to stream live process execution events in compact or JSON format:

```bash
# Stream all events originating in nextcloud-system in compact format
tetra getevents -o compact --namespaces nextcloud-system
```

### Example Live Output:
```text
🚀 process nextcloud-system/nextcloud-84d8bcbd7-sqs68 /usr/bin/head -n 2 /var/www/html/config/config.php
💥 exit    nextcloud-system/nextcloud-84d8bcbd7-sqs68 /usr/bin/head -n 2 /var/www/html/config/config.php 0
```

---

## 🛑 5. Hardened Webshell Enforcement (`Sigkill`)

To automatically terminate any unauthorized shell invocation (`/bin/sh`, `/bin/bash`, `/bin/zsh`) in the `nextcloud-system` namespace:

```bash
kubectl apply -f manifests/03-security-cilium/tetragon-webshell-block.yaml
```

When an attacker attempts to spawn a shell, the Linux kernel intercepts the syscall in eBPF and terminates the process via **SIGKILL** in under `0.001 ms`.
