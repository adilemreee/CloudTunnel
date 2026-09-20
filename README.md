<div align="center">

# ☁️ CloudTunnel

**A native SwiftUI app for managing Cloudflare Tunnels on macOS.**

Create, start, monitor and share tunnels — without wrestling with terminal commands.

![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Version](https://img.shields.io/badge/version-1.0.0-brightgreen)
![Localization](https://img.shields.io/badge/i18n-EN%20%C2%B7%20TR-informational)

**English** · [Türkçe](README.tr.md)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Data & File Locations](#data--file-locations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

---

## Overview

CloudTunnel is a control panel that sits on top of the `cloudflared` CLI. It exposes your
local development environment — MAMP sites, Docker containers, any `localhost` port — to the
internet in one click, then keeps track of running tunnels from the menu bar, streams their
logs live, and makes them shareable with your team.

The app keeps running in the menu bar after you close its window, so your tunnels stay up in
the background.

## Features

| Module | What it does |
|---|---|
| 📊 **Dashboard** | Active tunnel, Docker and error counts; environment status; one-click start/stop all |
| 🔗 **Tunnel Management** | Scans YAML configs under `~/.cloudflared`, maps UUID → name, manages DNS routes |
| ⚡ **Quick Tunnel** | Account-free `trycloudflare.com` tunnels; the public URL is captured automatically |
| 📡 **Port Scanner** | `lsof`-based port scan that identifies listening services and tunnels them directly |
| 🐳 **Docker** | Container list with port mappings; open a tunnel to a container in one step |
| 🖥️ **MAMP** | Site discovery, VHost create/edit, Apache & MySQL start/stop |
| 📁 **File Share** | Serves a folder you pick over a styled HTTP interface, behind a tunnel |
| 📜 **Live Logs** | Streams `cloudflared` output in real time through pipes, with level/source filters |
| 🔲 **QR Code** | Generates QR codes for public URLs; copy or save them to test from a phone |
| 👥 **Team Sharing** | Export/import tunnel sets as `.cloudtunnel` packages |
| 🔁 **Domain Migration** | Scans every config location for a domain and replaces it in bulk |
| 🕘 **History** | Persistent log history of tunnel and service events |
| 💾 **Backup** | JSON backups, automatic backups, and archived config files |
| 🎛️ **Menu Bar & Touch Bar** | Quick control from a popover; start/stop favorite tunnels from the Touch Bar |
| 🔔 **Notifications** | System notifications for tunnel start/stop and errors |
| 🌍 **Localization** | English and Turkish interface |

## Requirements

| Required | |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0+ (Swift 5.9) |
| [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) | `brew install cloudflared` |

Optional — only if you use the matching module:

- **Cloudflare account + `cloudflared login`** — for managed (persistent) tunnels and DNS routes
- **Docker Desktop** — for the Docker module
- **MAMP** (`/Applications/MAMP`) — for the MAMP module
- **python3** (`/usr/bin/python3`, ships with macOS) — for the File Share server

> The `cloudflared` path is resolved automatically (Homebrew, `/usr/local/bin`, `which`); if it
> can't be found, set it manually in Settings.

## Installation

```bash
git clone https://github.com/adilemreee/CloudTunnel.git
cd CloudTunnel
open CloudTunnel.xcodeproj
```

Pick the `CloudTunnel` scheme in Xcode and run it with **⌘R**.

The project file is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Regenerate it after changing `project.yml`:

```bash
xcodegen generate
```

To build from the command line:

```bash
xcodebuild -project CloudTunnel.xcodeproj -scheme CloudTunnel -configuration Release build
```

> **Note:** the app runs outside the sandbox (so it can launch `cloudflared`, `docker`, `lsof`
> and MAMP processes) and is signed ad-hoc.

## Quick Start

**1 · A temporary tunnel (fastest path)**

Go to the `Quick Tunnel` tab → enter a port (e.g. `3000`) → start.
Within seconds you get a `https://….trycloudflare.com` address; scan its QR code from a phone.

**2 · A persistent tunnel**

```bash
cloudflared login          # once, to authorize your Cloudflare account in the browser
```

Then `Tunnels` → **New Tunnel**: give it a name, hostname and local port. CloudTunnel creates
the tunnel, writes its `~/.cloudflared/<uuid>.yml` config, and points the DNS record at it.

**3 · Tunnels you already have**

Configs in `~/.cloudflared` are scanned automatically (**⇧⌘F** to rescan) and show up in the
list under their real names.

## Keyboard Shortcuts

All of these can be changed in Settings → Keyboard Shortcuts.

| Shortcut | Action |
|---|---|
| `⇧⌘T` | Start a quick tunnel |
| `⇧⌘R` / `⇧⌘S` | Start / stop all tunnels |
| `⇧⌘F` | Rescan config files |
| `⇧⌘P` | Scan ports |
| `⇧⌘Q` | Generate QR code |
| `⌘1` … `⌘5` | Dashboard · Tunnels · Quick Tunnel · Port Scanner · Logs |
| `⌘,` | Settings |

## Project Structure

```
CloudTunnel/
├── App/                  CloudTunnelApp.swift — @main, scene & environment setup
├── Core/                 DesignSystem, KeyboardShortcutManager, TouchBarController
├── Models/               Models.swift — tunnel, log and navigation models
├── Services/             Business logic (15 services)
│   ├── TunnelService         cloudflared process management (managed + quick)
│   ├── DockerService         container list & port mapping
│   ├── MAMPService           site/VHost management, Apache & MySQL control
│   ├── FileShareService      python3-based HTTP server
│   ├── PortScannerService    lsof scan & service identification
│   ├── LiveLogService        real-time log streaming
│   ├── TeamSharingService    .cloudtunnel export/import
│   ├── DomainMigrationService, BackupService, HistoryService,
│   │   QRCodeService, NetworkService, PortService,
│   │   MenuBarManager, NotificationHelper
├── Views/                One SwiftUI folder per module
└── Resources/            en.lproj · tr.lproj (Localizable.strings)
```

## Architecture

- **SwiftUI with AppKit bridges** — the interface is SwiftUI; AppKit is used for the menu bar
  (`NSStatusItem`), the Touch Bar (`NSTouchBar`) and file panels.
- **Service layer** — every capability is a `@MainActor`, `ObservableObject` service, held as a
  `@StateObject` at the `App` level and distributed via `environmentObject`.
- **Process-based integration** — external tools are driven through `Process` + pipes; long
  calls run inside `Task.detached`.
- **Design system** — `CTColors`, the typography scale and the card/glass modifiers live
  centrally in `Core/DesignSystem.swift`.
- **Persistence** — preferences in `@AppStorage`; history and backups as JSON under Application
  Support.

## Data & File Locations

| What | Where |
|---|---|
| Tunnel configs | `~/.cloudflared/*.yml` (configurable in Settings) |
| Event history | `~/Library/Application Support/CloudTunnel/history.json` |
| Backups | `~/Library/Application Support/CloudTunnel/Backups/*.json` |
| Shared packages | `*.cloudtunnel`, wherever you save it |
| Preferences | `UserDefaults` (`com.adilemre.CloudTunnel`) |

## Roadmap

See [`cloudtunnel_analysis.md`](cloudtunnel_analysis.md) for the detailed technical review and
suggestions. The highlights:

- 🔒 Move credentials into the Keychain, lock the app with Touch ID, encrypt backups
- 📊 Bandwidth / uptime / latency monitoring with threshold-based alerts
- 🌐 Cloudflare API integration (manage DNS and tunnels directly over the API)
- 🧩 Move services to dependency injection for testability
- 🌍 Localize the remaining hardcoded strings

## Contributing

Issues and pull requests are welcome. When sending code:

1. Follow the existing file layout and the style tokens in `Core/DesignSystem.swift`.
2. Add new user-facing strings through `NSLocalizedString` and update **both** `en.lproj` and
   `tr.lproj`.
3. If you changed `project.yml`, run `xcodegen generate` and include the generated project.

---

<div align="center">

**CloudTunnel** · built for macOS by [adilemreee](https://github.com/adilemreee)

</div>
