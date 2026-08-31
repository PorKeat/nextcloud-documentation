# Velero Installation & Backup Guide

This guide details how to install Velero into the Kubernetes cluster and configure it to back up infrastructure state to the local MinIO S3 server.

## Prerequisites
Before installing Velero, you must configure the MinIO backend:
1. Log into the MinIO Web Dashboard.
2. Create a new bucket named exactly: `velero`
3. Navigate to **Access Keys** and generate a new key (Do NOT reuse the Nextcloud access key, as it is restricted).
4. Save the `Access Key` and `Secret Key`.

## Step 1: Install the Velero CLI
Run this on your Kubernetes master node to install the Velero client tool:

```bash
wget -qO- https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz | tar xz
sudo mv velero-v1.14.0-linux-amd64/velero /usr/local/bin/velero
```

## Step 2: Create the Credentials File
Create a temporary text file to securely pass your MinIO credentials to the installer. Replace the placeholder keys with the new Access Key generated in the prerequisites.

```bash
cat << 'CREDS' > /tmp/credentials-velero
[default]
aws_access_key_id = YOUR_NEW_ACCESS_KEY
aws_secret_access_key = YOUR_NEW_SECRET_KEY
CREDS
```

## Step 3: Install Velero into Kubernetes
Execute the installation command. Note that we use the `aws` provider plugin because MinIO is fully S3-compatible. 

*Important:* Ensure the `region` in the config matches your MinIO server's region (default is `us-east-1`).

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket velero \
  --secret-file /tmp/credentials-velero \
  --use-node-agent \
  --backup-location-config region=us-east-1,s3ForcePathStyle="true",s3Url=https://10.1.18.7:9000,insecureSkipTLSVerify="true"
```

Verify the connection:
```bash
velero backup-location get
```
*(The Phase should report as **Available**).*

## Step 4: Running a Backup
Because we use a 3-Layer Architecture where databases and files are backed up independently, Velero is only used for backing up the Kubernetes infrastructure state (Deployments, ConfigMaps, Secrets, Services).

To prevent Velero from attempting (and failing) to take AWS-style EBS snapshots of the physical disks, you **must** pass the `--snapshot-volumes=false` flag.

```bash
# Take a backup of the entire nextcloud namespace
velero backup create nextcloud-infra-backup --include-namespaces nextcloud-system --snapshot-volumes=false

# Monitor the backup progress
velero backup describe nextcloud-infra-backup
```
