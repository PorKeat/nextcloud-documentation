# 21. Nextcloud Performance & Latency Optimization Guide

This guide details the architectural causes of web latency in distributed enterprise Nextcloud deployments and provides step-by-step performance optimizations for **PHP OPcache**, **Longhorn I/O**, **Redis caching**, and **Cloudflare Edge acceleration**.

---

## ⏱️ 1. Latency Breakdown & Architecture Analysis

In an enterprise Kubernetes cluster protected by Cloudflare and WAF gateways, a single user click passes through multiple layers:

```
[User Browser]
      │  (~150ms DNS & TLS Handshake)
      ▼
[Cloudflare Edge]
      │  (~50ms Edge Transit)
      ▼
[Tiyi WAF (103.189.186.19)]
      │  (~10ms HTTP Inspection)
      ▼
[Traefik Ingress (Port 31497)]
      │  (~5ms Load Balancing)
      ▼
[Nextcloud Pod (PHP-Apache)] ───► [PostgreSQL (5432)] (~0.88ms)
      │                     ───► [Redis (6379)]      (~4.69ms)
      │                     ───► [MinIO S3 (9000)]   (~15ms)
      ▼
[HTML Response Stream]
```

### Measured Component Latencies:
* **PostgreSQL Query Latency:** `0.88 ms` (Near-instant)
* **Redis Cache (Distributed + Locking):** `4.69 ms` (Near-instant)
* **PHP Framework Bootstrap (`base.php`):** Originally `~1,285 ms` without full OPcache!
* **Network & Multi-Proxy Overhead:** `~200 - 300 ms`

---

## 🚀 2. Optimization 1: PHP OPcache Tuning (RAM Caching)

### The Problem:
Nextcloud contains **13,647 PHP files**. By default, PHP OPcache was configured with:
* `opcache.max_accelerated_files = 10000`
* `opcache.memory_consumption = 128MB`

Because the file limit was 10,000, over **3,640 PHP files could not fit into RAM**. On every web request, PHP was forced to read uncached PHP files from the Longhorn distributed storage volume over the network, re-parsing and compiling them into bytecode.

### The Solution:
Deploy an optimized `opcache-tuning.ini` in the `nextcloud-php-custom-ini` ConfigMap:

```ini
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=512
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=100000
opcache.revalidate_freq=60
opcache.save_comments=1
opcache.jit=1255
opcache.jit_buffer_size=128M
```

### Verification:
```bash
kubectl exec deployment/nextcloud -n nextcloud-system -c nextcloud -- php -r '
echo "Memory: " . ini_get("opcache.memory_consumption") . "MB\n";
echo "Max Files: " . ini_get("opcache.max_accelerated_files") . "\n";
'
```
Output:
```text
Memory: 512MB
Max Files: 100000
```
All 13,647 PHP files now reside permanently in host RAM with zero disk I/O penalties.

---

## ⚡ 3. Optimization 2: Cloudflare Edge Caching for Static Assets

### The Problem:
On every page view, the user's browser requests dozens of static files (`core.js`, icons, CSS, WebFonts). If these requests travel all the way to Kubernetes, they consume web server concurrency and add network latency.

### The Solution:
Create a Cloudflare **Cache Rule** in your Cloudflare dashboard:
1. Navigate to **Caching ➔ Cache Rules ➔ Create Rule**.
2. **Rule Name:** `Nextcloud Static Assets Cache`
3. **If incoming requests match:**
   * `URI Path` starts with `/nextcloud/apps/` OR `/apps/` OR `/core/`
   * AND `File Extension` is in `["js", "css", "svg", "png", "jpg", "woff2", "ico"]`
4. **Cache Eligibility:** `Eligible for cache`
5. **Edge Cache TTL:** `7 days`
6. **Browser Cache TTL:** `4 hours`

Nextcloud automatically appends cache-busting query strings (e.g. `?v=34.0.3`) when apps update, guaranteeing that users always receive updated assets when Nextcloud is upgraded.

---

## 🛡️ 4. Resolution of the First-Time Login 404 (`index.php_oidc`)

### The Problem:
When Nextcloud runs under a subpath (`/nextcloud`), upstream `user_oidc` bug #766 causes the initial post-login redirect to be mangled into `/nextcloud/index.php_oidc/login/1`, displaying a purple **"Page not found"** error until the user clicks "Back to Nextcloud".

### The Solution:
Add a persistent rewrite rule to `/var/www/html/.htaccess`:

```apache
# Workaround for user_oidc subpath redirect bug
RewriteRule ^(?:nextcloud/)?index\.php_oidc.* /nextcloud/apps/files/ [R=302,L]
```

When this mangled redirect URL is requested, Apache intercepts it and immediately redirects the authenticated user directly to their files dashboard (`/apps/files/`) with zero error screens.
