# 14. Injecting Custom Fonts into Collabora (Kubernetes ConfigMap)

While Nextcloud provides a web UI to upload custom fonts, it occasionally fails to parse complex or non-Western fonts (like Khmer fonts such as Koulen or Battambang). When this happens, Nextcloud displays broken vertical bars in the preview, and the fonts fail to load in your documents.

The most reliable, enterprise-grade way to add custom fonts to Collabora in a Kubernetes environment is to inject the `.ttf` files directly into the Collabora pod's operating system using a `ConfigMap`.

## Step 1: Download Your Fonts
Create a temporary folder on your server and download your desired `.ttf` files into it.

```bash
mkdir -p /tmp/custom-fonts
cd /tmp/custom-fonts

# Example: Downloading Khmer fonts directly from Google Fonts
wget -q -O Koulen-Regular.ttf https://github.com/google/fonts/raw/main/ofl/koulen/Koulen-Regular.ttf
wget -q -O Battambang-Regular.ttf https://github.com/google/fonts/raw/main/ofl/battambang/Battambang-Regular.ttf
```

## Step 2: Create a Kubernetes ConfigMap
Bundle the downloaded font files into a Kubernetes ConfigMap in the exact same namespace as your Collabora deployment.

```bash
kubectl create configmap collabora-custom-fonts -n nextcloud-system --from-file=/tmp/custom-fonts/
```

## Step 3: Mount the Fonts into Collabora
Collabora uses a highly secure `chroot` jail (located at `/opt/cool/systemplate`) to render documents safely. Because of this security feature, you must mount the font ConfigMap into BOTH the standard system fonts folder *and* the systemplate fonts folder.

Run this patch command to automatically inject the volume mounts into your running Deployment:

```bash
kubectl patch deployment collabora -n nextcloud-system -p '{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {
            "name": "custom-fonts",
            "configMap": {
              "name": "collabora-custom-fonts"
            }
          }
        ],
        "containers": [
          {
            "name": "collabora",
            "volumeMounts": [
              {
                "name": "custom-fonts",
                "mountPath": "/usr/share/fonts/truetype/custom",
                "readOnly": true
              },
              {
                "name": "custom-fonts",
                "mountPath": "/opt/cool/systemplate/usr/share/fonts/truetype/custom",
                "readOnly": true
              }
            ]
          }
        ]
      }
    }
  }
}'
```

## Step 4: Restart and Clean Up
Restart the Collabora pod so it rebuilds its font cache, and safely remove your temporary files.

```bash
# Restart the pod
kubectl rollout restart deployment collabora -n nextcloud-system

# Clean up the temporary folder
rm -rf /tmp/custom-fonts
```

Wait about 30 seconds for the pod to start. Once it does, refresh any open documents in Nextcloud, and your custom fonts will appear in the dropdown menu automatically!
