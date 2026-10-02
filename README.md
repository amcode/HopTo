# Hop To

A tiny Mac launcher that does one thing: press a shortcut, type a few letters, press Return. It opens apps and System Settings panes. That's it.

- **⌥ Space** (or your pick) opens a small panel from anywhere.
- **Fuzzy search** that understands prefixes and acronyms: `saf` → Safari, `vsc` → Visual Studio Code, `am` → Activity Monitor.
- **System Settings panes** with the words you'd actually type: `wifi`, `dark mode`, `bluetooth`, `input monitoring`.
- **Learns what you launch**, so your habits float to the top without ever beating a clear text match.
- **Nothing else.** No clipboard history, no workflows, no file search, no plugins, no accounts, no network.

Requires macOS 13 Ventura or later. No permissions needed.

## Install

Grab `HopTo-x.y.z.dmg` from the [latest release](https://github.com/amcode/HopTo/releases/latest), drag **Hop To** to Applications and open it. Press ⌥ Space.

## Using it

| Key | Does |
|---|---|
| ⌥ Space | Open / close the panel |
| Type | Filter apps and settings |
| ↑ ↓ | Move the selection |
| Return | Open the selected item |
| ⌘1 – ⌘9 | Open that row directly |
| Esc | Close |

With nothing typed, the panel shows what you've opened most recently.

Right-click the menu bar icon to change the shortcut (⌥ Space, ⌃ Space, ⌘⌥ Space, ⌘⇧ Space, ⌃⌥ Space), turn System Settings results off, add an extra folder of apps, forget launch history, or launch at login. ⌘ Space is deliberately not offered — that's Spotlight's.

## Build from source

```bash
git clone https://github.com/amcode/HopTo.git
cd HopTo
./build.sh          # runs the tests, then builds dist/Hop To.app (universal)
```

Needs the Xcode Command Line Tools (`xcode-select --install`). You can also open `Package.swift` in Xcode.

## Tests

```bash
swift test
```

`HopToCore` is a plain Swift library with no AppKit in it: the fuzzy matcher, the ranking (text score plus a capped usage boost), the usage store, the settings-pane catalogue and the hot key model are all unit-tested. The matcher tests pin down real launcher behaviour ("fin" must find Finder before Font Information; a typed prefix beats an acronym; exact matches beat habit).

## How it works

```
⌥ Space ──▶ LauncherPanel ──query──▶ SearchEngine ──▶ Matcher (fuzzy score)
                 │                        │         + UsageStore (habit boost)
                 │                        ▼
                 └──Return───▶ NSWorkspace.openApplication / x-apple.systempreferences:
```

- **Apps** come from scanning `/Applications`, `/System/Applications`, their `Utilities` folders, `~/Applications` and any folders you add, rescanned every couple of minutes. No Spotlight, no file watcher.
- **Settings panes** come from a built-in catalogue (friendly names and keywords) plus whatever the System Settings extensions folder contains, opened via `x-apple.systempreferences:` URLs.
- **The hot key** is a Carbon `RegisterEventHotKey`, which needs no Accessibility or Input Monitoring permission.

## Releasing

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `Release` workflow runs on GitHub's macOS runners: tests, universal build with the tag stamped into `Info.plist`, then a `.dmg`, `.zip` and `SHA256SUMS.txt` attached to the GitHub release.

### Signing and notarisation

Without secrets the build is ad-hoc signed and users see a Gatekeeper warning on first open. With a paid Apple Developer account, add these repository secrets and the next release is signed, notarised and stapled automatically:

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_P12` | `base64 -i cert.p12 \| pbcopy` — your Developer ID Application cert + key |
| `MACOS_CERTIFICATE_PWD` | the .p12 export password |
| `APPLE_ID` | your Apple ID email |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_APP_PASSWORD` | an app-specific password from appleid.apple.com |

## Website

The one-page site in `docs/` is published with GitHub Pages (Settings → Pages → Deploy from a branch → `main`, folder `/docs`). The download button reads the latest release from the GitHub API, so it updates itself when you tag a new version.

## Project layout

```
Package.swift
Sources/
  HopToCore/           pure logic (tested)
    Hop.swift
    Matcher.swift
    SearchEngine.swift
    UsageStore.swift
    SettingsCatalogue.swift
    Settings.swift       (incl. HotKey)
  HopTo/               the app (AppKit + Carbon wiring)
    main.swift
    AppDelegate.swift
    LauncherPanel.swift
    HotKeyRegistrar.swift
    Indexer.swift
Tests/HopToCoreTests/
docs/                  the website
Info.plist · HopTo.entitlements · AppIcon.iconset/ · build.sh
.github/workflows/{ci,release}.yml
```

## Licence

MIT — see [LICENSE](LICENSE).
