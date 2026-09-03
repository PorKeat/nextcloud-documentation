# Master Enterprise Infrastructure & Security Architecture

This document provides the complete, end-to-end architectural blueprint for the Nextcloud Enterprise Private Cloud, integrating Edge Gateways, Ingress Routing, eBPF Zero-Trust Security, High-Availability Data Stores, Object Storage, and Disaster Recovery.

---

## 1. Complete System Architecture Diagram

```mermaid
graph TD
    %% Styling
    classDef edge fill:#6c5ce7,stroke:#fff,stroke-width:2px,color:#fff;
    classDef gateway fill:#fdcb6e,stroke:#fff,stroke-width:2px,color:#333;
    classDef security fill:#d63031,stroke:#fff,stroke-width:2px,color:#fff;
    classDef app fill:#0984e3,stroke:#fff,stroke-width:2px,color:#fff;
    classDef db fill:#f39c12,stroke:#fff,stroke-width:2px,color:#fff;
    classDef storage fill:#e74c3c,stroke:#fff,stroke-width:2px,color:#fff;
    classDef backup fill:#00b894,stroke:#fff,stroke-width:2px,color:#fff;

    Client((Internet Users / Mentors / Office)) -->|HTTPS / WAF| WAF[Tiyi WAF / Reverse Proxy<br>103.189.186.19]:::edge

    subgraph API_Gateway_Layer["1. Gateway & Edge Routing Layer"]
        WAF -->|Proxy Rewrite| APISIX[Apache APISIX Gateway<br>Route & Traffic Splitter]:::gateway
        APISIX -->|NodePort 31270/31497| Traefik[Traefik Ingress Controller<br>traefik-system]:::gateway
    end

    subgraph Security_Boundary["2. Cilium eBPF Zero-Trust Security Boundary"]
        CiliumPolicy[Cilium eBPF Kernel Policy<br>Enforces Namespace Isolation & DB Lockdown]:::security
    end

    subgraph Kubernetes_Cluster["3. Kubernetes Application & Compute Layer (10.1.16.x)"]
        direction TB

        subgraph Blue_Green_App["Nextcloud Blue-Green Stack"]
            NC_Green["🟢 Nextcloud Green (Live Pods)"]:::app
            NC_Blue["🔵 Nextcloud Blue (Preview / Dev Pods)"]:::app
            Collabora["📄 Collabora Online Office"]:::app
            Push["⚡ Nextcloud Notify Push"]:::app
        end

        subgraph HA_Database_and_Cache["High-Availability Data Layer"]
            PG_RW[("🐘 PostgreSQL Primary (nextcloud-db-rw)")]:::db
            PG_RO[("🐘 PostgreSQL Replicas (CloudNativePG HA)")]:::db
            Redis[("🔴 Redis Sentinel & Cache")]:::db
        end

        subgraph Backup_Engines["Disaster Recovery Tools"]
            Velero[("⛵ Velero Agent (K8s Blueprints)")]:::backup
            DBCron[("⏰ PostgreSQL Dump CronJob (2:00 AM)")]:::backup
        end
    end

    subgraph Storage_Server["4. Centralized Storage Server (MinIO 10.1.18.7)"]
        direction TB
        B_Live[("🪣 Bucket: nextcloud-data<br>(Live User Files & Photos)")]:::storage
        B_Velero[("🪣 Bucket: velero<br>(K8s Cluster State)")]:::storage
        B_DB[("🪣 Bucket: db-backups<br>(Compressed SQL Dumps)")]:::storage

        Versioning["🛡️ MinIO Bucket Versioning<br>(Immutable Ransomware Protection)"]:::storage
        Versioning -.->|Protects| B_Live
    end

    %% Routing Flows
    Traefik ==>|Route to Live| NC_Green
    Traefik -.->|Preview Route| NC_Blue
    Traefik ==>|Office Route| Collabora
    Traefik ==>|WebSocket| Push

    %% App to Data Layer
    NC_Green & NC_Blue <==>|Read/Write SQL 5432| PG_RW
    PG_RW -.->|Streaming Replication| PG_RO
    NC_Green & NC_Blue <==>|Session & Locking 6379| Redis
    NC_Green & NC_Blue <==>|WOPI Document API 9980| Collabora

    %% Storage Streams (S3)
    NC_Green & NC_Blue ===>|Direct S3 API Stream| B_Live

    %% Backup Flows
    Velero ===>|S3 Backup API| B_Velero
    DBCron ===>|Pushes .sql.gz| B_DB
    DBCron -.->|Dumps DB| PG_RW
    Velero -.->|Scans State| Kubernetes_Cluster
```

---

## 2. Architectural Layer Breakdown

### Layer 1: Edge WAF & Gateways
* **Tiyi WAF (`103.189.186.19`):** Terminates external SSL certificates, mitigates DDoS attacks, and inspects HTTP traffic.
* **Apache APISIX:** Handles advanced traffic routing, proxy-rewriting (`^/nextcloud/(.*)` ➡️ `/${1}`), OIDC SSO integration, and Blue-Green traffic switching.
* **Traefik Ingress Controller:** Runs on Kubernetes nodes, providing internal load balancing and TLS pass-through.

### Layer 2: Cilium & Tetragon eBPF Zero-Trust Security Suite
* **Cilium eBPF Network Policies:** Enforces kernel-level packet filtering and namespace isolation.
  * **Cross-Namespace Deny:** Unauthorized namespaces (`default`, `dev`, `test`) cannot reach internal databases or pods.
  * **PostgreSQL Lockdown:** Only authorized Nextcloud pods and replication instances can establish connections to port `5432`.
* **Tetragon eBPF Runtime Security:** Operates directly inside the Linux kernel to intercept syscalls (`execve`, `openat`).
  * **Process Observability:** Real-time tracking of all binary executions and command arguments inside containers.
  * **Webshell & Exploit Prevention:** Real-time kernel intervention (`Sigkill`) against unauthorized shells or privilege escalation attempts.

### Layer 3: Application Compute & Blue-Green Releases
* **Nextcloud Blue-Green:** Two independent deployments (`nextcloud-green` and `nextcloud-blue`) alternate roles between **Live** and **Dev/Testing**, guaranteeing zero-downtime releases and instant rollbacks.
* **Collabora Online:** High-performance document editing cluster communicating via WOPI protocol.
* **Notify-Push:** High-speed WebSocket server for instantaneous client synchronization.

### Layer 4: High-Availability State Layer
* **CloudNativePG (PostgreSQL 15):** 3-node HA cluster with automated failover and synchronous replication.
* **Redis Sentinel:** Multi-node in-memory cluster handling PHP session persistence, file locking, and pub/sub caching.

### Layer 5: Object Storage & 3-Tier Disaster Recovery
* **MinIO Object Storage (`10.1.18.7:9000`):** Centralized S3 storage hosting all file assets.
* **Tier 1 (Infrastructure):** VMware Tanzu Velero snapshots Kubernetes YAML blueprints to the `velero` bucket.
* **Tier 2 (Database):** Automated Kubernetes CronJob dumps PostgreSQL every night at 2:00 AM to the `db-backups` bucket.
* **Tier 3 (User Files):** MinIO Bucket Versioning retains immutable history of modified/deleted files for instant rollback against ransomware.

---

## 3. Disaster Recovery Matrix

| Failure Scenario | Recovery Tool | Recovery Time Objective (RTO) |
| :--- | :--- | :--- |
| **Accidental Namespace Deletion** | `velero restore create --from-backup ...` | < 60 seconds |
| **Database Corruption / Data Loss** | Restore `.sql.gz` dump from `db-backups` | < 5 minutes |
| **Accidental File Deletion / Ransomware** | MinIO Bucket Versioning Rollback | < 1 minute |
| **Bad Application Release / Code Bug** | APISIX Instant Blue-Green Switchback | < 1 second |
