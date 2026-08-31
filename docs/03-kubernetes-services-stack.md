# 3. Kubernetes Services Stack (Nextcloud, Collabora, MetalLB, Traefik)

---

## 1. MetalLB LoadBalancer (`manifests/02-networking-metallb/metallb-config.yaml`)

* **Role:** Layer 2 LoadBalancer for bare-metal Kubernetes.
* **Pool Range:** `10.1.16.200 - 10.1.16.200`
* **Interface Binding:** `eth0`
* **Enterprise Switch Note:** Physical switches with Dynamic ARP Inspection / IP Source Guard drop ARP requests for VIPs. That is why traffic is routed directly to physical NodePorts (`.11-.13:31497`).

---

## 2. Traefik Ingress Controller (`manifests/01-ingress-gateway/traefik-ingressroute.yaml`)

* **NodePort Service:** Exposes HTTP on Port `31497`.
* **Sticky Sessions:** 
  ```yaml
  sticky:
    cookie:
      name: nextcloud_session_sticky
      httpOnly: true
      secure: true
  ```
  *(Prevents multi-replica user session drops).*
* **Match Expression:**
  ```yaml
  match: Host("nextcloud.sengporkeat.com") || Host("10.1.16.200") || Host("10.1.16.11") || Host("10.1.16.12") || Host("10.1.16.13")
  ```

---

## 3. Nextcloud Deployment (`manifests/04-nextcloud-app/nextcloud-green-deployment.yaml`)

* **Replicas:** `3` pods
* **Database:** PostgreSQL (`nextcloud-db-rw:5432`)
* **Storage Backend:** MinIO S3 (`10.1.18.7:9000`, bucket: `nextcloud-data`)
* **Distributed Locking:** Redis Sentinel (`nextcloud-redis:26379`)

---

## 4. Collabora Online Office (`manifests/05-collabora-office/collabora-deployment.yaml`)

* **Service:** `collabora` on port `9980`
* **Role:** Real-time document editing for Nextcloud.
