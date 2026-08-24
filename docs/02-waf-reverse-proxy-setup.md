# 2. Tiyi WAF & Reverse Proxy Configuration Guide

---

## 1. Site Configuration (Public Frontend)

* **Name:** `nextcloud`
* **Primary Host:** `nextcloud.sengporkeat.com`
* **TLS Mode:** `Uploaded` (Let's Encrypt certificates generated via `setup-automated-ssl.sh`)
* **HTTP Behavior:** `Redirect to HTTPS`
* **TLS Minimum:** `TLS 1.2` / `TLS 1.3`
* **WAF Status:** `Enabled` (Mode: Active Protection / Inspection)

---

## 2. Upstream Pool Configuration (Internal Backend)

* **Backend Source:** Upstream Pool
* **Target Endpoints:**
  * `http://10.1.16.11:31497` (Weight: 100)
  * `http://10.1.16.12:31497` (Weight: 100)
  * `http://10.1.16.13:31497` (Weight: 100)
* **Backend Protocol:** **`HTTP`** (SSL Termination mode — WAF handles HTTPS, talks HTTP to K8s NodePort).
* **Health Check:** `Passive Only` (Do not use strict 200 OK active probes, because Nextcloud returns 302 login redirects).

---

## 3. Global TLS Bypass Note

If backend HTTPS is ever used with self-signed certs, WAF requires `proxy_ssl_verify off;` (or disabling strict backend certificate verification) to prevent 502/SSL handshake drops.
