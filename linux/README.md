# AI Usages for Ubuntu

Native **GNOME Shell extension** for Ubuntu 24.04 (GNOME 46) that shows AI quota
gauges in the top bar. Click the indicators to expand quotas, reset countdowns
and 30-day usage trends.

This directory is the Linux port of the macOS app in the repository root. The
macOS Swift sources are untouched.

## How it works

```
GNOME Shell extension (GJS)      top-bar gauge, popup, preferences
        │  Gio.Subprocess, only while polling
        ▼
aiusages-collect (Python 3)      short-lived process, prints JSON
        ├── OpenCode Go     SQLite credential + REST   (0.2s)
        ├── Google AI Pro   libsecret → OAuth refresh → REST (0.2s)
        │                   + agy CLI every 30 min for Gemini 4 Argon (6s)
        └── OpenRouter      /credits, /key, /activity
```

There is no resident daemon: the collector runs for ~0.3s per poll (up to ~7s
when the Antigravity CLI refresh is due) and writes its result to
`~/.cache/aiusages/state.json`, which the extension uses for an instant first
paint after a shell restart.

## Requirements

- Ubuntu 24.04 with the stock GNOME 46 session (X11 or Wayland)
- OpenCode Go credentials (`~/.local/share/opencode/opencode.db`)
- Google AI Pro signed in through `agy` (Antigravity CLI)
- Optional: an OpenRouter API key (set it in the extension preferences)

No third-party Python packages are needed. `python3-gi`, libsecret and SQLite
are part of a stock Ubuntu install.

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/dwyi84/usages/main/linux/remote-install.sh | sh
```

To uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/dwyi84/usages/main/linux/remote-install.sh | sh -s -- --uninstall
```

### From a local clone

```bash
make install            # from this directory
```

Then restart the shell so GNOME notices the new extension:

- X11: press `Alt+F2`, type `r`, press Enter
- Wayland: log out and back in

Open the popup and choose **Settings** to pick providers, the refresh interval
and which quota each top-bar bar represents.

## Development

```bash
make test               # stdlib unittest suite (no pytest required)
make collect            # print the collector JSON
make pack              # build dist/aiusages@melissasoft.shell-extension.zip
make install-local      # copy the extension into the user extension dir
```

After changing JavaScript, `Alt+F2` → `r` reloads the extension. Watch the logs
with:

```bash
journalctl -f -o cat /usr/bin/gnome-shell | grep -i aiusages
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no_credentials` for OpenCode | Sign in with the `opencode` CLI; the collector reads `opencode.db` read-only |
| Google card shows 4 groups (no Argon) | `agy` was not found or is not logged in: run `agy --print /usage` once |
| Google values are stale | The token in GNOME Keyring expired and refresh failed; run `agy` once to re-authenticate |
| OpenRouter card empty | Add the API key in Settings (stored in GNOME Keyring) |
| Collector not found | Set the absolute path in Settings → General → Collector path |

## Notes

- Google' OAuth refresh uses the same public client id/secret that the
  `agy` binary embeds. If Google rotates it, the collector still falls back to
  the `agy` CLI, which is always authoritative.
- The Agy CLI is only invoked when its cached result is older than 30 minutes,
  so normal polls stay at ~0.3s and do not spawn the 230MB binary.
- Secrets live in GNOME Keyring (`service=com.melissasoft.aiusages`,
  `username=openrouter_api_key`). The refreshed Google access token is cached
  separately in `~/.cache/aiusages/state.json` (mode 0600); the keyring entry
  owned by `agy` is never modified.
