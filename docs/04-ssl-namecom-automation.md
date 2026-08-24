# 4. Automated SSL Lifecycle (Name.com API & Cron Automation)

This guide explains how to configure automated SSL issuance and renewals using the Name.com DNS API plugin and a Linux Cron Job.

---

## 1. Prerequisites & Credentials Placeholder

Before running the renewal automation, obtain your API token from [Name.com API Settings](https://www.name.com/account/settings/api):

* **Provider:** Name.com
* **Username:** `<YOUR_NAMECOM_USERNAME>`
* **API Token:** `<YOUR_NAMECOM_API_TOKEN>`
* **Domain:** `<YOUR_DOMAIN>` (e.g., `nextcloud.example.com`)
* **Email:** `<YOUR_EMAIL>` (e.g., `admin@example.com`)

---

## 2. Renewal Script Overview (`scripts/setup-automated-ssl.sh`)

The script performs the automated DNS-01 challenge:

```bash
#!/bin/bash
set -e

NAMECOM_USER="<YOUR_NAMECOM_USERNAME>"
NAMECOM_TOKEN="<YOUR_NAMECOM_API_TOKEN>"
DOMAIN="<YOUR_DOMAIN>"
EMAIL="<YOUR_EMAIL>"

sudo mkdir -p /etc/letsencrypt
sudo bash -c "cat << 'CONFIG' > /etc/letsencrypt/namecom.ini
dns_namecom_username = ${NAMECOM_USER}
dns_namecom_api_token = ${NAMECOM_TOKEN}
CONFIG"
sudo chmod 600 /etc/letsencrypt/namecom.ini

sudo certbot certonly \
  --authenticator dns-namecom \
  --dns-namecom-credentials /etc/letsencrypt/namecom.ini \
  -d ${DOMAIN} \
  -m ${EMAIL} \
  --agree-tos \
  --non-interactive
```

---

## 3. Setting Up a Recurring Cron Job

To ensure certificates are automatically renewed without manual intervention:

1. Open root crontab on the node:
   ```bash
   sudo crontab -e
   ```
2. Add a cron schedule to execute the renewal script twice a month (on the 1st and 15th at 03:00 AM):
   ```bash
   0 3 1,15 * * /bin/bash /path/to/setup-automated-ssl.sh >> /var/log/certbot-renew.log 2>&1
   ```

---

## 4. Certificate Output Paths for WAF Upload

* **Certificate (Full Chain):** `/etc/letsencrypt/live/<YOUR_DOMAIN>/fullchain.pem`
* **Private Key:** `/etc/letsencrypt/live/<YOUR_DOMAIN>/privkey.pem`
