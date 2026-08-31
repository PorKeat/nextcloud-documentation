# Enterprise Backup & Disaster Recovery Architecture

This document details the backup and disaster recovery architecture for the Nextcloud Kubernetes cluster. The environment uses a strict **3-Layer Backup Strategy** utilizing MinIO (S3) as the centralized storage backend.

## Architecture Diagram

The visual blueprint below outlines how the Kubernetes cluster, Nextcloud application, and backup tools interact with the MinIO Docker server for both **Live Data** and **Backup Data**.

```mermaid
graph LR
    %% Styling
    classDef storage fill:#ff0000,stroke:#fff,stroke-width:2px,color:#fff;
    classDef pod fill:#fff,stroke:#326ce5,stroke-width:2px,color:#333;
    classDef db fill:#f2a900,stroke:#fff,stroke-width:2px,color:#fff;
    classDef tool fill:#00b894,stroke:#fff,stroke-width:2px,color:#fff;

    User((User / Web)) -->|HTTPS| APISIX

    subgraph Kubernetes["Kubernetes Cluster (10.1.16.x)"]
        direction TB
        APISIX[APISIX Gateway]:::pod
        NC[Nextcloud App Pod]:::pod
        DB[(Database Pod)]:::db
        Velero[Velero Agent]:::tool
        DBCron[Database CronJob]:::tool
        
        APISIX -->|Routes Traffic| NC
        NC <-->|Read / Write| DB
        
        Velero -.->|Reads State| APISIX
        Velero -.->|Reads State| NC
        DBCron -.->|Dumps SQL| DB
    end

    subgraph Storage["MinIO Docker Server (10.1.18.7)"]
        direction TB
        B1[("Bucket: nextcloud-data<br>(Live Files)")]:::storage
        B2[("Bucket: velero<br>(K8s Configs)")]:::storage
        B3[("Bucket: db-backups<br>(SQL Dumps)")]:::storage
        Versioning[MinIO Bucket Versioning]
        
        Versioning -.->|Protects Files| B1
    end

    %% Live Data Flow
    NC ===>|Live S3 Stream| B1
    
    %% Backup Data Flow
    Velero ===>|S3 Backup API| B2
    DBCron ===>|S3 Backup API| B3
```

> **Legend:**
> * **Solid lines** (`===`) represent data moving to the storage server over S3 API.
> * **Dotted lines** (`-.-`) represent internal processes reading data or protecting buckets.

---

## The 3-Layer Backup Strategy

Enterprise environments never rely on a single tool to back up complex stateful applications. The architecture is split into three distinct layers using specialized tools:

### Layer 1: Infrastructure State (Velero)
* **Tool:** VMware Tanzu Velero (with AWS S3 Plugin)
* **Target:** `velero` MinIO Bucket
* **Function:** Velero acts as an infrastructure scanner. It takes hourly/daily snapshots of the Kubernetes cluster's "blueprint" (Deployments, StatefulSets, Services, APISIX routes, ConfigMaps, and Secrets) and pushes them to MinIO. 
* **Disaster Recovery:** If a namespace is accidentally deleted, `velero restore` rebuilds the entire Kubernetes architecture in seconds.

### Layer 2: Relational Database (CronJob / PITR)
* **Tool:** Dedicated Database Dump CronJob (or pgBackRest/Percona)
* **Target:** `db-backups` MinIO Bucket
* **Function:** Databases constantly write transactions to memory. Taking a raw disk snapshot of a live database can result in corrupted tables. Instead, a dedicated Backup CronJob safely exports the database memory into a highly compressed SQL file (`mysqldump` or `pg_dump`) and pushes that file directly to MinIO.

### Layer 3: File Protection (MinIO Versioning)
* **Tool:** MinIO Native Bucket Versioning
* **Target:** `nextcloud-data` MinIO Bucket
* **Function:** The actual Nextcloud user files (photos, documents) are already stored directly in a MinIO bucket. Velero does not back these up. Instead, MinIO Bucket Versioning keeps a hidden, immutable history of every file inside the bucket. 
* **Disaster Recovery:** To protect against accidental user deletion or ransomware, administrators can use MinIO's versioning to instantly roll back any file to a previous state.

---

## Warning: Single Point of Failure (SPOF)
In this architecture, the local MinIO Docker Server (`10.1.18.7`) acts as the target for *both* production data and backup data. While this provides excellent local recovery capabilities, it creates a Single Point of Failure. If the disks on the MinIO server fail completely, the live data and the backups will be lost simultaneously. 

**Recommendation for Production:** Implement a secondary offsite backup. Configure MinIO to actively mirror the `nextcloud-data`, `velero`, and `db-backups` buckets to a cheap, immutable cloud storage provider (e.g., AWS S3, Backblaze B2) to achieve true 3-2-1 compliance.
