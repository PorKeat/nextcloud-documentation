# 7. Redis Distributed Caching Architecture & ObjectStore Compatibility

This guide documents the Redis caching configuration and the **ObjectStore / S3 locking design rules**.

---

## 1. Why `filelocking` is Disabled with MinIO S3 Object Storage

In Nextcloud architectures with **Primary S3 Object Storage (`\OC\Files\ObjectStore\S3`)**:
* S3 is inherently an atomic, immutable object store with built-in versioning and object-level concurrency.
* Attempting to layer Nextcloud's POSIX-style transactional lock provider (`memcache.locking => \OC\Memcache\Redis`) over S3 creates **irreconcilable lock collisions (`LockedException: existing lock on file: none`)**, resulting in `HTTP 423 Locked` errors during multi-part stream uploads.
* Nextcloud's official enterprise documentation explicitly advises **disabling transactional `memcache.locking`** when S3 is used as primary object storage.

---

## 2. Production Configuration (`config.php`)

Redis is leveraged for **high-performance memory and session distribution**, while S3 handles object-level concurrency natively:

```php
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.distributed' => '\\OC\\Memcache\\Redis',
'filelocking.enabled' => false,
'redis' => array (
  'host' => 'nextcloud-redis',
  'port' => 26379,
  'password' => '<REDIS_PASSWORD>',
  'redis::sentinel' => 'mymaster',
  'timeout' => 1.5,
  'read_timeout' => 1.5,
),
```
