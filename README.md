# AI Usages

A featherweight, native **macOS menu bar utility** for monitoring real-time quotas, token spend, and subscription renewal countdowns for **OpenCode Go**, **Google AI Pro** (Gemini Models, Claude & GPT, Gemini 4 Argon), and **OpenRouter**.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/macOS-13%2B-1f6feb?logo=apple)](https://www.apple.com/macos)
[![Architecture](https://img.shields.io/badge/Apple%20Silicon-arm64-purple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-dwyi84d-FFDD00?logo=buymeacoffee&logoColor=black&style=flat-square)](https://buymeacoffee.com/dwyi84d)

---

<p align="center">
  <img src="assets/screenshot.png" width="420" alt="AI Usages Screenshot">
</p>

---

## Highlights

- **Adaptive Vertical Segmented Gauges** — borderless, razor-sharp Retina segmented bars in your menu bar. Dynamically renders 1, 2, or 3 bars according to your active providers. Color automatically shifts from vibrant battery green to amber (≤35%) and critical red (≤15%).
- **Dual Dashboard Modes** — seamlessly toggle between **Quotas (한도 쿼터)** for subscription models (OpenCode Go, Google AI Pro) and **Tokens & Cost (토큰 & 비용)** for pay-as-you-go APIs (OpenRouter balance, today/month spend, token volume).
- **Hybrid Provider Management** — auto-detects locally installed developer tools (OpenCode SQLite DB, Antigravity CLI) with clear badges, placing active providers on top with easy checkbox controls.
- **Lightweight High-Speed REST Engine** — queries Google Cloud Code and OpenCode endpoints directly via sub-second REST API calls (0.2s) with automatic CLI fallback, saving CPU and battery.
- **Safe Rate-Limit Resilient Polling** — configurable intervals (1m, 3m, 5m default, 15m) with automatic exponential backoff on HTTP 429 and stale-while-revalidate caching.
- **Dynamic Renewal & Refresh Timers** — live countdowns for 5-hour rolling windows, weekly quotas, and monthly billing subscription renew dates (`Refreshes in Xh Ym` / `Renews in Xd Yh`).
- **Clean In-Menu Controls** — one-click **Launch at Login**, inline **Check for Updates**, and Buy Me a Coffee support. No separate preference windows, no clutter.
- **Bilingual Localization** — seamlessly adapts between English and Korean based on your macOS system language preferences.

---

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (arm64)
- OpenCode CLI and/or Antigravity CLI logged in (or OpenRouter API key)

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

### Linux (Ubuntu 24.04+ / GNOME 46)

A native GNOME Shell port lives in [`linux/`](linux/README.md). It shows the same
segmented gauges in the top bar, adapts automatically to system Light/Dark themes,
and reuses local OpenCode / Antigravity credentials through GNOME Keyring.

#### One-liner install

```bash
curl -fsSL https://raw.githubusercontent.com/dwyi84/usages/main/linux/remote-install.sh | sh
```

#### Build from source

```bash
make linux-test     # stdlib unittest suite
make linux-install  # installs the extension and collector for the current user
```

Reload the shell (`Alt+F2` → `r` on X11, or log out on Wayland) and enable
**AI Usages** in the Extensions app.

---

## Troubleshooting & Engineering History (Linux / GNOME Shell 46)

### Popup Right/Bottom Edge Ghosting & 1-Second Flicker on X11 (Resolved in `v0.2.13`)
- **Symptom:** On Ubuntu 24.04 (GNOME 46 / Mutter X11), opening the popup or scrolling down caused stale pixels / afterimages of the previous screen along the right and bottom edges of the card scroll area (flickering at 1-second intervals alongside top-bar updates, while GNOME Screenshot UI rendered cleanly because full-stage capture bypasses clipped redraws).
- **Root Cause:** `St.ScrollView` in GNOME Shell 46 had only `max-height: 480px` (no `min-height`) while its direct child `PopupMenuSection.actor` (`.aiusages-body`) carried `padding: 8px 12px`, and `scrollSection.actor` carried `clip_to_allocation: true`. Under X11 partial/clipped redraws, the `padding` on the `St.ScrollView` direct child combined with a non-fixed scroll viewport height caused `StScrollView`'s allocation/clip bounds and paint volume to mismatch on the right and bottom edges. (Earlier steps in `v0.2.10`–`v0.2.12` also disabled `St.ScrollView` fade offsets, replaced `St.DrawingArea` quota bars with `St.Widget`, flattened `.aiusages-menu` `box-shadow`, and set `Clutter.OffscreenRedirect.AUTOMATIC_FOR_OPACITY` on `BoxPointer`.)
- **Fix (`v0.2.13`):** Fixed `.aiusages-scroll` to `min-height: 480px; max-height: 480px;`, removed `padding` from `.aiusages-body` (moving padding onto `.aiusages-provider-card`, `.aiusages-mgmt-section`, and `.aiusages-section-divider`), and removed the extra `clip_to_allocation` wrapper on `scrollSection.actor`.

---

## Privacy & Security

AI Usages runs completely on your local machine:
- **No Telemetry & No Tracking:** Zero analytics or tracking libraries.
- **No Cloud Upload of Credentials:** Local session tokens and CLI engines are read locally and only used to query the official endpoints (`https://opencode.ai/zen/go/v1/usage`, Google's code assist prediction service, and OpenRouter).
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
