# Changelog

## 0.3.2 — 2026-10-29

- Stow joins the harbour: a menu bar manager that tucks away the icons you rarely need.

## 0.3.1 — 2026-10-29

- Uninstalling an app now also removes its login item: Harbor asks the app to unregister itself first (apps built with HarborKit 0.2 or later).

## 0.3 — 2026-10-29

- **A harbour, seen from above.** The window is now a harbour. Installed apps lie moored at their berths, and apps you don’t have yet wait at anchor beyond the breakwater. Installing sails a boat in through the mouth as the download arrives, and an update comes alongside on a supply boat. A second row of berths opens along the breakwater past six apps. At night, lamps light the quay. Nothing moves unless something is happening.
- **Uninstall.** An app’s page can remove the app and everything it keeps on your Mac: settings, caches, saved windows, logs, support files and its permissions. It all goes to the Trash.
- Harbor’s own page, the harbour master’s office, holds its version, updates and the check for updates.
- App pages link to the app’s website only.
- When an app has several copies, Harbor shows and updates the one in Applications and ignores Xcode builds and the Trash.

## 0.2 — 2026-10-29

- **One-click Install and Update.** Harbor downloads the app’s release, checks it against the catalog’s SHA-256, quits the app if it’s running, replaces it in place and opens it again. **Update All** updates everything at once, and Harbor updates itself.
- A new icon: a marina from above, boats tied along a pier inside a breakwater.

## 0.1 — 2026-10-29

First release: a shelf of the Harbor apps with install and update status from a published catalog, each app's page with its settings drawn from the schema it ships (applied live through HarborKit), permission status, harbor:// links, English and Turkish.
