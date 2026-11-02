# AI Usages

A featherweight, native **macOS menu bar utility** for monitoring real-time quotas and subscription renewal countdowns for **OpenCode Go** and **Google AI Pro** (Gemini Models, Claude & GPT, Gemini 4 Argon).

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/macOS-13%2B-1f6feb?logo=apple)](https://www.apple.com/macos)
[![Architecture](https://img.shields.io/badge/Apple%20Silicon-arm64-purple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-dwyi84d-FFDD00?logo=buymeacoffee&logoColor=black&style=flat-square)](https://buymeacoffee.com/dwyi84d)

---

## Highlights

- **Twin Vertical Segmented Gauges** — borderless, razor-sharp Retina segmented bars in your menu bar. Left bar tracks OpenCode Go remaining quota, right bar tracks Google AI Pro remaining quota. Color dynamically shifts from vibrant battery green to amber (≤35%) and critical red (≤15%).
- **Zero Authentication Hassle** — reads local credentials automatically. OpenCode uses your local SQLite session token, and Google AI synchronizes seamlessly via the local CLI background engine. No manual API keys required.
- **Remaining Quota Oriented** — displays exact remaining percentages (`% remaining` / `% 남음`) rather than confusing used numbers.
- **Dynamic Renewal & Refresh Timers** — live countdowns for 5-hour rolling windows, weekly quotas, and monthly billing subscription renew dates (`Refreshes in Xh Ym` / `Renews in Xd Yh`).
- **Clean In-Menu Controls** — configurable refresh intervals (15s, 30s, 1m, 5m), one-click **Launch at Login**, and inline **Check for Updates**. No separate preference windows, no clutter.
- **Bilingual Localization** — seamlessly adapts between English and Korean based on your macOS system language preferences.
- **In-App GitHub Updates** — checks GitHub Releases, notifies of new releases, downloads the update, and replaces the app in place with automatic relaunch.

---

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (arm64)
- OpenCode CLI and/or Antigravity CLI logged in

---

## Installation

### Homebrew (recommended)

```bash
brew install --cask dwyi84/tap/aiusages
```

This installs **AI Usages.app** to `/Applications`. Because the app is signed with an ad-hoc local certificate, Gatekeeper may prompt on first launch — right-click **AI Usages.app** and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine "/Applications/AI Usages.app"
```

### Manual Download

1. Download the latest `AIUsages-<version>.zip` from [Releases](https://github.com/dwyi84/usages/releases).
2. Unzip and drag `AI Usages.app` into `/Applications`.
3. Launch the app from Spotlight or Launchpad.

### Build from Source

```bash
git clone https://github.com/dwyi84/usages.git
cd usages
make install
```

---

## Privacy & Security

AI Usages runs completely on your local machine:
- **No Telemetry & No Tracking:** Zero analytics or tracking libraries.
- **No Cloud Upload of Credentials:** Local session tokens and CLI engines are read locally and only used to query the official endpoints (`https://opencode.ai/zen/go/v1/usage` and Google's code assist prediction service).
- **Network Requests:** Only queries your own quota status and optional GitHub Releases version checks.

---

## License

Released under the [MIT License](LICENSE).

---

## Support

If AI Usages helps you keep track of your AI quotas at a glance, consider buying me a coffee — it keeps the meters glowing! ☕

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-dwyi84d-FFDD00?logo=buymeacoffee&logoColor=black&style=for-the-badge)](https://buymeacoffee.com/dwyi84d)

<p align="center">Crafted by MelissaSoft · Made with ❤️ on Apple Silicon.</p>
<p align="center">Copyright © 2026 Dawoon Yi / MelissaSoft</p>
