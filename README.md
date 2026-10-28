<p align="center">
  <img src="docs/assets/icon.png" width="128" height="128" alt="Harbor icon">
</p>

<h1 align="center">Harbor</h1>

<p align="center">
  <b>All your Harbor apps, one quiet place.</b><br>
  A free, open-source hub for the Harbor Mac apps: see them all, hear about updates,<br>
  and change their settings in one window.
</p>

<p align="center">
  <a href="https://github.com/Kaandis/harbor/releases/latest"><img src="https://img.shields.io/github/v/release/Kaandis/harbor?label=download&color=8f8881" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-111" alt="macOS 15+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://kaandis.github.io/harbor/">Website</a> ·
  <a href="https://github.com/Kaandis/harbor/releases/latest/download/Harbor.zip">Download</a> ·
  <a href="README.tr.md">Türkçe</a>
</p>

<p align="center">
  <img src="docs/assets/shots/shelf.png" width="720" alt="Harbor's shelf with Inlet and Ferry">
</p>

## What it does

- **Every app at a glance.** [Inlet](https://kaandis.github.io/inlet/) and [Ferry](https://kaandis.github.io/ferry/), and whatever comes next: installed, current, or waiting for you.
- **Updates, told not taken.** When an app has a new version Harbor says so; **Get** and **Update** open the app’s website. Harbor never downloads or installs anything itself.
- **Settings in one place.** Each app ships a `settings-schema.json` describing its preferences. Harbor draws them and the app applies a change at once.
- **Permissions at a glance.** Apps report which permissions they have, so you can see what’s missing.
- **Links from the apps.** An app’s **Settings…** menu item opens its Harbor page (`harbor://app/ferry`) when Harbor is installed.

<p align="center">
  <img src="docs/assets/shots/ferry.png" width="720" alt="Ferry's page in Harbor with its settings">
</p>

## Why it works this way

- **A harbour, not a store.** No accounts, no installs, no background updater. You stay in charge of what lands on your Mac.
- **The app owns its settings.** Values live in each app’s own preferences, described by a schema the app ships, so the app works the same with or without Harbor. Harbor writes the value, then posts `app.harbor.settingsChanged`; the app picks it up through [HarborKit](https://github.com/Kaandis/harbor-kit).
- **One small file from the internet.** Harbor learns the latest versions from [`catalog.json`](https://kaandis.github.io/harbor/catalog.json) on its website, at most every 12 hours or when you press **Check for Updates**. It sends nothing.
- **Quiet.** With its window in the background Harbor used 0.01 s of CPU over 30 seconds on an M4 Pro, with no wakeups. Closing the window quits it.

## Install

1. Download **[Harbor.zip](https://github.com/Kaandis/harbor/releases/latest/download/Harbor.zip)** and unzip it.
2. Move **Harbor.app** to Applications.
3. The first time, right-click Harbor and choose **Open** (builds aren’t notarized yet), or run:

```bash
xattr -dr com.apple.quarantine /Applications/Harbor.app
```

Harbor needs no special permissions.

## For app makers

A Harbor app:

1. keeps every setting as a plain `UserDefaults` key and describes them in `Resources/settings-schema.json` (see [Ferry’s](https://github.com/Kaandis/ferry/blob/main/Ferry/Resources/settings-schema.json));
2. calls `SettingsBridge.listen()` at launch, and optionally `SettingsBridge.publishPermissions(_:)`;
3. opens `HarborLink.openSettings(appID:)` from its Settings menu item, falling back to its own window;
4. is listed in [`docs/catalog.json`](docs/catalog.json).

## Build from source

```bash
brew install xcodegen
git clone https://github.com/Kaandis/harbor.git
cd harbor
xcodegen generate
open Harbor.xcodeproj
```

## Disclaimer

Harbor is an independent project and is not affiliated with, endorsed by or sponsored by Apple Inc. Mac and macOS are trademarks of Apple Inc., registered in the U.S. and other countries.

## License

[MIT](LICENSE)
