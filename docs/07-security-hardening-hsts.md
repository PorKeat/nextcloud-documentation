# 7. Redis Distributed Caching & File Locking Architecture

This guide covers the high-availability Redis Sentinel cluster configuration used for Nextcloud session caching and distributed transactional file locking.

---

## 1. Redis Cluster Specifications

* **Deployment:** Bitnami Redis Sentinel HA (2 Nodes)
* **Service:** `nextcloud-redis.nextcloud-system.svc.cluster.local`
* **Port:** `26379` (Sentinel) & `6379` (Direct)
* **Sentinel Master Group:** `mymaster`
* **Local In-Memory Cache:** `\OC\Memcache\APCu`
* **Distributed Memory Cache:** `\OC\Memcache\Redis`
* **Transactional Locking Cache:** `\OC\Memcache\Redis`

---

## 2. Configuration Settings (`config.php`)

To ensure file uploads and concurrent operations never encounter deadlocks or stale 423 locks during transient network events:

```php
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.distributed' => '\\OC\\Memcache\\Redis',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'filelocking.enabled' => true,
'filelocking.ttl' => 600, // 10-minute auto-expiry for orphaned locks
'redis' => array (
  'host' => 'nextcloud-redis',
  'port' => 26379,
  'password' => '<REDIS_PASSWORD>',
  'redis::sentinel' => 'mymaster',
  'timeout' => 1.5,
  'read_timeout' => 1.5,
),
```

---

## 3. Maintenance & Lock Flushing Commands

When network interruptions cause temporary file locks:

```bash
# Rescan and synchronize file caches
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ files:scan --all

# Clean orphaned file cache entries
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ files:cleanup
```
