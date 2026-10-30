# Caffeine

A native macOS app that keeps your Mac awake from the menu bar. No windows, no Dock, no dependencies: a single Swift file and a build script.

While active, the display does not turn off due to inactivity, and therefore the system does not idle-sleep either.

## Features

- Lives only in the menu bar (`LSUIElement`), with no Dock icon.
- Activate and deactivate with one click; the icon switches between an empty and a full cup.
- Hide the menu bar icon without quitting the app; bring it back with `⌥⌘C` or by reopening the app.
- Releases the power assertion when deactivated or when you quit.
- No network, no special permissions, no persistent state.
- Reproducible build with `build_app.sh` (app, `.dmg`, and `.zip`).

## Requirements

- macOS 11 Big Sur or later.
- To build: Command Line Tools (`xcode-select --install`), which include `swiftc`.
- Architecture: the default build produces **Apple Silicon (arm64)**. See [Architectures](#architectures) for Intel and universal binaries.

## Installation

### Option A: DMG

1. Open `dist/Caffeine-1.0.0.dmg`.
2. Drag **Caffeine** to the **Applications** folder.
3. On first launch, macOS will block the app because it is ad-hoc signed (not notarized). Authorize it once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Caffeine.app
   open /Applications/Caffeine.app
   ```

   You can also do it from the UI: **System Settings → Privacy & Security → "Open Anyway"**. On macOS 15 and later, the old right-click → Open shortcut no longer bypasses Gatekeeper.

4. The cup icon appears in the menu bar. There is no window or Dock icon: that is expected.

### Option B: build from source

```bash
./build_app.sh
open Caffeine.app
```

The script leaves `Caffeine.app` in the project root and the artifacts in `dist/`.

## Usage

Click the menu bar icon. The app's menu labels are in Spanish; English translations are in parentheses.

| Action | Effect |
| --- | --- |
| **Activar** (Activate) | Creates a power assertion; the display does not sleep due to inactivity. |
| **Desactivar** (Deactivate) | Releases the assertion and returns to normal macOS behavior. |
| **Salir** (Quit) | Releases the assertion (if active) and quits the app. Shortcut: `⌘Q`. |
| **Ocultar icono** (Hide icon) | Removes the icon from the menu bar; the app keeps running and the assertion stays active. Bring it back with `⌥⌘C`. |

The app always starts deactivated; it does not remember state between launches.

### What it does and does not prevent

- **Yes**, it prevents user-idle sleep while active.
- **No**, it does not prevent sleep when you close the lid, on low battery, from the Apple menu, or for other system reasons.
- The assertion is released automatically if the process ends, even if the app closes unexpectedly.

### Hiding the menu bar icon

The menu includes **Ocultar icono (⌥⌘C)**. When you hide it:

- The app **does not quit**: it keeps running in the background.
- If it was active, the power assertion **stays in effect**: the Mac stays awake.
- To bring it back, press `⌥⌘C` from any app or reopen `Caffeine.app` from Finder/Spotlight. Both paths show the icon again.

The shortcut is global and does not require Accessibility permissions. The hidden state is not saved: every time you open the app, the icon is visible.

## Building

```bash
./build_app.sh
```

Output:

```
Caffeine.app                     # ready-to-run app
dist/Caffeine-1.0.0.dmg          # drag-and-drop installer
dist/Caffeine-1.0.0.zip          # compressed app
```

### Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `VERSION` | `1.0.0` | `CFBundleShortVersionString` and artifact names. |
| `BUILD_NUMBER` | `1` | `CFBundleVersion`. |
| `BUNDLE_ID` | `com.local.caffeine` | Bundle identifier. Change it before distributing the app. |
| `MIN_MACOS` | `11.0` | Minimum macOS version for the binary and `Info.plist`. |
| `ARCHS` | `arm64 x86_64` | Architectures to attempt. Unsupported ones are skipped with a warning. |
| `SIGN_IDENTITY` | empty | Signing identity (`Developer ID Application: ...`). If empty, ad-hoc signing. |
| `NOTARY_PROFILE` | empty | `notarytool` profile. Enables notarization (requires `SIGN_IDENTITY`). |

Example:

```bash
VERSION=1.0.1 BUILD_NUMBER=2 ./build_app.sh
```

### Architectures

The script tries to build each architecture in `ARCHS` and combines them with `lipo`.

- **Apple Silicon:** works with Command Line Tools.
- **Intel:** build from source on the Intel Mac itself; the script detects the architecture when the cross-build fails and produces a valid binary for that machine.
- **Universal (arm64 + x86_64):** requires the full Xcode toolchain. Command Line Tools include the SDK but not the Swift compatibility libraries for the cross architecture, so the x86_64 build fails at link time. With Xcode installed:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ./build_app.sh
  lipo -info Caffeine.app/Contents/MacOS/Caffeine   # arm64 x86_64
  ```

## Distributing without Gatekeeper warnings

For the app to open with a double-click on any Mac, without `xattr` or "Open Anyway", it needs a **Developer ID** signature and notarization. This requires an Apple Developer Program account and a **Developer ID Application** certificate in the keychain.

1. Store the notarization credentials once:

   ```bash
   xcrun notarytool store-credentials "caffeine-notary" \
     --apple-id "you@example.com" \
     --team-id "TEAMID" \
     --password "app-specific-password"
   ```

2. Build with signing and notarization:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
   NOTARY_PROFILE="caffeine-notary" \
   ./build_app.sh
   ```

The script signs with hardened runtime and a timestamp, notarizes the app, staples it, and repeats the process with the DMG. Without those variables, the app remains ad-hoc signed and Gatekeeper will ask for confirmation on each new Mac.

## How it works

- `AppDelegate` creates an `NSStatusItem` and its menu (`Activar`/`Desactivar`, `Ocultar icono`, `Salir`).
- When activating, it calls `IOPMAssertionCreateWithName` with `kIOPMAssertionTypeNoDisplaySleep`: while the display cannot turn off due to inactivity, the system does not idle-sleep for that reason either.
- When deactivating or quitting, it calls `IOPMAssertionRelease`.
- `applicationDidFinishLaunching` uses `setActivationPolicy(.accessory)` and `Info.plist` sets `LSUIElement`, which is why there is no Dock icon or window.
- The icon is drawn with SF Symbols (`cup.and.saucer` / `cup.and.saucer.fill`) as a template, so it adapts to light and dark mode.
- `Ocultar icono` sets `statusItem.isVisible` to `false` without quitting the app; `⌥⌘C` toggles visibility from any app using `RegisterEventHotKey` (Carbon), without Accessibility permissions.
- `applicationShouldHandleReopen` shows the icon again if you reopen the app from Finder or Spotlight.

It does not use the sandbox, entitlements, or the network. The power assertion belongs to the system (IOKit) and disappears with the process.

## Project structure

```
caffeine/
├── Caffeine.swift        # app code (single file)
├── build_app.sh          # build, signing, and artifacts
├── README.md
├── Caffeine.app          # generated by the script
└── dist/                 # generated by the script (.dmg and .zip)
```

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| "Caffeine is damaged and can't be opened" | Gatekeeper quarantine on an ad-hoc signed app. `xattr -dr com.apple.quarantine /Applications/Caffeine.app`. |
| "Cannot verify the developer" | System Settings → Privacy & Security → "Open Anyway". |
| The icon does not appear when opening the app | The menu bar is full or an app such as Bartender/Ice is hiding it; check that the process is still alive with `pgrep -fl Caffeine`. |
| I hid the icon and don't know how to get it back | Press `⌥⌘C` or reopen `Caffeine.app`; the icon reappears. |
| `swiftc: command not found` | Install the tools: `xcode-select --install`. |
| `ld: symbol(s) not found for architecture x86_64` | Normal with Command Line Tools only. Use a Mac of that architecture or install full Xcode for a universal binary. |
| The app does not prevent sleep | Check that the icon is in the full state (`cup.and.saucer.fill`) and that the system is not sleeping because the lid is closed or the battery is low. |

## Notes

- The default bundle ID is `com.local.caffeine`; use your own before distributing.
- It does not include an app icon for Finder; the menu bar icon is a system SF Symbol.
- This project is not affiliated with any other app named Caffeine.
