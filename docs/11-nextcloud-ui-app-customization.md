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
