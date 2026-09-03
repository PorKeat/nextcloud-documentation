# 11. Nextcloud UI & App Customization Guide

This document outlines how to manage user interface elements, reduce activity feed noise, and handle built-in application features (like the Photos app) in your Nextcloud enterprise deployment.

---

## 1. Managing the Activity Feed

By default, the Nextcloud Activity app tracks almost every action (file changes, shares, calendar updates, contact syncs, etc.). This can quickly clutter the database and the user's activity stream.

### Reducing Global Activity Noise
To prevent users from being spammed with notifications and useless stream entries:
1. Go to **Settings -> Administration -> Activity**.
2. Uncheck unnecessary events under the **Stream** and **Email** columns. 
   * **Recommended to Keep:** File changes, File shares, Security (logins/passwords), Comments.
   * **Recommended to Disable:** Favorites, Calendar, Tasks, Contacts (unless actively used as primary team tools).

### Removing Categories from the Activity Sidebar
The left sidebar in the Activity app automatically generates navigation filters based on the apps you have installed. 
* Nextcloud does **not** allow you to hide an active app from the Activity sidebar.
* **The Fix:** If your team does not use Nextcloud for Calendars, Tasks, or Contacts, you must disable the apps completely.
  * Go to **Settings -> Apps -> Your apps**.
  * Click **Disable** on the apps you don't use (e.g., `Contacts`, `Calendar`, `Tasks`). 
  * *Result:* They will instantly disappear from the Activity sidebar and free up server resources.

---

## 2. Nextcloud Photos: "Places" and "Map" Tabs

In Nextcloud version 25 and newer, the official **Photos** app natively includes **Places** and **Map** tabs in its left sidebar.

### Hardcoded UI Elements
* These tabs scan your images for EXIF GPS metadata to plot them on a map.
* **Important:** These two tabs are permanently hardcoded into the Photos app's user interface. 
* There is **no configuration file, database toggle, or OCC command** to hide just the "Places" or "Map" tabs while keeping the rest of the Photos app.

### How to Handle Them
1. **Option A (Ignore):** If you use the Photos app, simply ignore the tabs. They do not consume extra resources unless you actively browse them or run facial/location recognition background jobs.
2. **Option B (Disable Maps App):** If you are seeing a completely separate app called "Maps" in your top navigation bar, you *can* disable that standalone app via **Settings -> Apps -> Your apps -> Maps -> Disable**.
3. **Option C (Alternatives):** Some enterprises completely disable the official Nextcloud Photos app and install community alternatives (like the *Memories* app) which offer much stricter configuration options for metadata and UI elements.

---

## 3. Disabling Built-in "Ads", Pop-ups, and Telemetry

Nextcloud comes with several built-in apps that act as pop-ups, welcome screens, or enterprise upgrade prompts. You don't need to dive into the database to remove them—you can cleanly disable them via the `occ` terminal.

### The "First Run" Welcome Pop-up
Every time a new user logs in, they get a welcome wizard pop-up. To disable it for everyone:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable firstrunwizard
```

### File Recommendations (Top of Files App)
Nextcloud puts a "Recommendations" banner at the top of the files app guessing which files you want. If you find this annoying or want to save database CPU cycles:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable recommendations
```

### Enterprise Support / Upgrade Prompts
If you are running the free community version, Nextcloud will occasionally show Admin prompts or include a "Support" app linking to their paid plans. 
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable support
```

### Telemetry / Usage Data
To stop Nextcloud from sending basic usage statistics back to their servers:
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable survey_client
```

### Update Notifications
If you manage updates entirely via Kubernetes/Helm and don't want admins getting web pop-ups saying "A new version of Nextcloud is available":
```bash
kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:disable updatenotification
```

### Hiding Hardcoded App Elements via Custom CSS
If you want to keep the Photos app but absolutely must hide the "Places", "Map", or "People" buttons from the sidebar, you can use the Custom CSS app to visually remove them.

1. **Install the Custom CSS app:**
   ```bash
   kubectl exec -n nextcloud-system deployment/nextcloud -- php occ app:install theming_customcss
   ```
2. Go to **Settings -> Administration -> Theming** and scroll down to the Custom CSS box.
3. Paste the following exact code:
   ```css
   /* Hide specific sidebar items in the Photos app */
   li[data-id-app-nav-item="places"],
   li[data-id-app-nav-item="maps"],
   li[data-id-app-nav-item="faces"],
   li[data-id-app-nav-item="people"],
   li[data-id-app-nav-item="on-this-day"] {
       display: none !important;
   }
   ```
4. **Force the server to apply the changes:**
   ```bash
   kubectl exec -n nextcloud-system deployment/nextcloud -- php occ maintenance:theme:update
   ```

---

## 4. Developing & Deploying In-House Custom Nextcloud Apps

When advanced UI or workflow modifications are required (e.g. forcing documents to open in new browser tabs, custom authentication hooks, or custom button handlers), **never modify Nextcloud core files or official signed apps directly**.

### Why Build an In-House Custom App?
* **Zero Integrity Failures:** Nextcloud verifies the GPG signatures of official apps (e.g., `richdocuments`, `viewer`). Tampering with them triggers `INVALID_HASH / Signature Failed` in the Admin Overview.
* **Persistent Across Upgrades:** Custom apps placed in `/var/www/html/custom_apps/` live on persistent storage (Longhorn PV) and survive container rollouts, pod restarts, and Nextcloud core updates.
* **Native Lifecycle:** Custom apps are enabled, disabled, and managed natively via the standard `occ app:*` CLI and Nextcloud UI.

### Production Case Study: The `office_newtab` Custom App

A real-world in-house app created to automatically open Office files (`.docx`, `.xlsx`, `.pptx`, `.odt`, `.csv`) in a dedicated, secure browser tab on regular left-click.

#### 📁 App Directory Structure
```
/var/www/html/custom_apps/office_newtab/
├── appinfo/
│   └── info.xml              # Nextcloud app metadata & namespace definition
├── lib/
│   └── AppInfo/
│       └── Application.php   # PHP bootstrap class injecting frontend script
└── js/
    └── office-newtab.js      # Secure client-side click interceptor
```

#### 1. `appinfo/info.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<info>
    <id>office_newtab</id>
    <name>Office New Tab</name>
    <description>Securely opens Nextcloud Office documents in a new tab on click</description>
    <version>1.0.0</version>
    <licence>AGPL-3.0-or-later</licence>
    <author>Unity Workspace</author>
    <namespace>OfficeNewTab</namespace>
    <category>customization</category>
    <dependencies>
        <nextcloud min-version="25" max-version="35"/>
    </dependencies>
</info>
```

#### 2. `lib/AppInfo/Application.php`
```php
<?php

declare(strict_types=1);

namespace OCA\OfficeNewTab\AppInfo;

use OCP\AppFramework\App;
use OCP\AppFramework\Bootstrap\IBootContext;
use OCP\AppFramework\Bootstrap\IBootstrap;
use OCP\AppFramework\Bootstrap\IRegistrationContext;
use OCP\Util;

class Application extends App implements IBootstrap {
    public const APP_ID = 'office_newtab';

    public function __construct() {
        parent::__construct(self::APP_ID);
    }

    public function register(IRegistrationContext $context): void {
    }

    public function boot(IBootContext $context): void {
        Util::addScript(self::APP_ID, 'office-newtab');
    }
}
```

#### 3. `js/office-newtab.js`
```javascript
// Open Office files in a secure new browser tab on click
;(function() {
  "use strict";

  function isOfficeFile(mime, name) {
    return /^(application\/(vnd\.(ms-|openxmlformats|oasis)|msword|msexcel)|text\/csv)/i.test(mime || "") ||
           /\.(docx?|xlsx?|pptx?|odt|ods|odp|csv)$/i.test(name || "");
  }

  function openOfficeInNewTab(fileId) {
    if (!fileId) return false;
    var url = (window.OC && OC.generateUrl) 
      ? OC.generateUrl("/apps/richdocuments/index?fileId=" + encodeURIComponent(fileId))
      : "/apps/richdocuments/index?fileId=" + encodeURIComponent(fileId);
    
    // Strict security: prevent tabnabbing with noopener,noreferrer
    var newWindow = window.open(url, "_blank", "noopener,noreferrer");
    if (newWindow) {
      newWindow.focus();
      return true;
    }
    return false;
  }

  // Intercept user left click on file row in capture phase
  document.addEventListener("click", function(e) {
    if (e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey) {
      return;
    }

    // Do not intercept actions menu, selection checkboxes, favorites
    if (e.target.closest("[data-cy-files-list-row-checkbox], [data-cy-files-list-row-action], .action-menu, .file-actions, .favorite, input[type=\"checkbox\"], a[data-action]")) {
      return;
    }

    var row = e.target.closest("[data-cy-files-list-row], tr[data-file], tr[data-mime], .file-item");
    if (!row) return;

    var mime = row.getAttribute("data-cy-files-list-row-mime") || row.getAttribute("data-mime") || "";
    var fileId = row.getAttribute("data-cy-files-list-row-fileid") || row.getAttribute("data-id") || row.getAttribute("data-file-id");
    var name = row.getAttribute("data-cy-files-list-row-name") || row.getAttribute("data-file") || "";

    if (isOfficeFile(mime, name) && fileId) {
      e.preventDefault();
      e.stopPropagation();
      openOfficeInNewTab(fileId);
    }
  }, true);

  // Fallback: intercept Viewer if opened programmatically
  function hookViewer() {
    if (window.OCA && window.OCA.Viewer && !window.OCA.Viewer._hookedForNewTab) {
      window.OCA.Viewer._hookedForNewTab = true;
      var originalOpenWith = window.OCA.Viewer.openWith.bind(window.OCA.Viewer);
      window.OCA.Viewer.openWith = function(handlerId, options) {
        if (handlerId === "richdocuments") {
          var fileId = (options && options.fileInfo && options.fileInfo.id) || (options && options.fileId) || (options && options.id);
          if (fileId && openOfficeInNewTab(fileId)) {
            return;
          }
        }
        return originalOpenWith(handlerId, options);
      };
    }
  }

  hookViewer();
  window.addEventListener("DOMContentLoaded", hookViewer);
})();
```

#### Managing In-House Apps
```bash
# Enable app
kubectl exec -n nextcloud-system deployment/nextcloud -c nextcloud -- su -s /bin/bash www-data -c 'php occ app:enable office_newtab'

# Disable app
kubectl exec -n nextcloud-system deployment/nextcloud -c nextcloud -- su -s /bin/bash www-data -c 'php occ app:disable office_newtab'

# List custom apps
kubectl exec -n nextcloud-system deployment/nextcloud -c nextcloud -- su -s /bin/bash www-data -c 'php occ app:list' | grep office_newtab
```
