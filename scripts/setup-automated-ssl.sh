#!/bin/bash
# ==============================================================================
# Automated Let's Encrypt SSL Generator & Cron Job Script
# ==============================================================================
# Usage:
#   1. Manual execution:   sudo bash setup-automated-ssl.sh
#   2. Cron automation:    Run automatically every month via crontab
# ==============================================================================

set -e

# --- Configuration (Replace with your actual credentials) ---
NAMECOM_USER="<YOUR_NAMECOM_USERNAME>"
NAMECOM_TOKEN="<YOUR_NAMECOM_API_TOKEN>"
DOMAIN="nextcloud.example.com"
EMAIL="admin@example.com"

echo "[INFO] Creating/Updating Name.com credentials configuration..."
sudo mkdir -p /etc/letsencrypt
sudo bash -c "cat << 'CONFIG' > /etc/letsencrypt/namecom.ini
dns_namecom_username = ${NAMECOM_USER}
dns_namecom_api_token = ${NAMECOM_TOKEN}
CONFIG"
sudo chmod 600 /etc/letsencrypt/namecom.ini

echo "[INFO] Requesting/Renewing Certificate from Let's Encrypt..."
sudo certbot certonly \
  --authenticator dns-namecom \
  --dns-namecom-credentials /etc/letsencrypt/namecom.ini \
  -d ${DOMAIN} \
  -m ${EMAIL} \
  --agree-tos \
  --non-interactive

echo "[SUCCESS] SSL Certificate successfully updated!"
echo "Certificate location: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "Private Key location: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
