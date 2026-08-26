# 12. Generating Let's Encrypt SSL Certificates Manually (DNS Challenge)

This guide explains how to generate a free SSL certificate from Let's Encrypt using the manual DNS challenge method. This is highly useful for internal servers, WAFs, or servers without a public web port (like Jitsi or internal Nextcloud routing).

## Prerequisites
Ensure `certbot` is installed on your server:
```bash
sudo apt update
sudo apt install certbot -y
```

## Step 1: Run the Certbot Command
Run the following command to request a certificate for your domain (e.g., `unity.sengporkeat.com`). 

```bash
sudo certbot certonly --manual --preferred-challenges dns -d unity.sengporkeat.com
```
* `certonly`: Just generates the keys without trying to configure a web server.
* `--manual`: Pauses the process so you can manually add the DNS record.
* `--preferred-challenges dns`: Forces Let's Encrypt to use a DNS TXT record for verification instead of a file upload.

## Step 2: Create the DNS TXT Record
Certbot will pause and provide a **random string** of characters. It will ask you to deploy a DNS TXT record under the name `_acme-challenge.<your-subdomain>`.

1. Log into your DNS provider (e.g., Name.com, Cloudflare).
2. Create a new **TXT** record.
3. **Host / Name:** `_acme-challenge.unity` *(Do not include the root domain here if your provider appends it automatically)*.
4. **Answer / Value:** Paste the random string provided by Certbot.
5. Save the record.

## Step 3: Verify Propagation (CRITICAL STEP)
**DO NOT PRESS ENTER IN CERTBOT YET!** 
If you press Enter before the DNS record has populated across the global internet, Let's Encrypt will fail the check, throw an `unauthorized` error, and you will have to start completely over from Step 1.

Open a second terminal window (or use your local computer) and run:
```bash
nslookup -type=txt _acme-challenge.unity.sengporkeat.com 8.8.8.8
```
*Keep running this command every 30 seconds.* 
**Only press Enter in the Certbot window AFTER the `nslookup` command outputs the exact new string you just pasted.**

## Step 4: Accessing Your Certificates
Once successful, Certbot will save your keys in the `/etc/letsencrypt/live/` directory.

You can view or copy them directly to your clipboard using:
```bash
# To get the Private Key:
sudo cat /etc/letsencrypt/live/unity.sengporkeat.com/privkey.pem

# To get the Certificate:
sudo cat /etc/letsencrypt/live/unity.sengporkeat.com/cert.pem

# To get the Full Chain (Intermediate):
sudo cat /etc/letsencrypt/live/unity.sengporkeat.com/fullchain.pem
```
