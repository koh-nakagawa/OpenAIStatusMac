# OpenAI Status for Mac

English | [日本語](README_JPN.md)

An unofficial, open-source macOS app built with SwiftUI and WidgetKit for monitoring the official OpenAI status page.

- View the overall status, individual services, and active incidents
- Add small and medium widgets to the desktop or Notification Center
- Add a Control Widget to Control Center on macOS 26 or later
- Receive macOS notifications for new incidents, service degradation, and recovery
- Choose which event types and services should trigger notifications
- Avoid repeated alerts by notifying only when the status changes

> [!IMPORTANT]
> This is an unofficial personal project. It is not provided, endorsed, or affiliated with OpenAI.

## Japanese guide

- [Qiita: Building a macOS OpenAI status monitor with SwiftUI and WidgetKit](https://qiita.com/KohN/items/42685192921c730d5f8b)
- [Japanese README](README_JPN.md)

## Install without Xcode

The universal prebuilt app supports both Apple silicon and Intel Macs running macOS 14 or later. The Control Center widget is available only on macOS 26 or later.

### Browser download

1. Open the [latest GitHub Release](https://github.com/koh-nakagawa/OpenAIStatusMac/releases/latest).
2. Download `OpenAIStatusMac-unnotarized.zip`.
3. Extract the ZIP and move `OpenAI Status.app` to your `Applications` folder.
4. Try to open the app once.
5. If macOS blocks it, open **System Settings → Privacy & Security** and click **Open Anyway** for OpenAI Status.
6. Launch the app and allow notifications when prompted.

This free build is signed with an Apple Development certificate but is not notarized by Apple. The one-time Gatekeeper approval is therefore expected. Do not disable Gatekeeper and do not remove quarantine attributes.

The release also includes `OpenAIStatusMac-unnotarized.zip.sha256` for checksum verification.

### Install from Git

This downloads the same verified release archive and installs the app in `~/Applications`:

```sh
git clone https://github.com/koh-nakagawa/OpenAIStatusMac.git
cd OpenAIStatusMac
./scripts/install.sh
```

The installer never disables Gatekeeper or removes quarantine attributes. If the first launch is blocked, use the same **Open Anyway** procedure above.

After launching the app once, add the desktop, Notification Center, or Control Center widget as described below. Xcode, Git, and an Apple ID are not required when installing from the browser.

## Build from source

Source development requires:

- macOS 14.0 or later
- Xcode 26.0 or later, required to compile the ControlWidget API from the macOS 26 SDK
- Git
- An Apple ID added to Xcode for Widget Extension registration

Run:

```sh
git clone https://github.com/koh-nakagawa/OpenAIStatusMac.git
cd OpenAIStatusMac
./scripts/setup.sh
```

`setup.sh` checks the development environment, runs the tests, verifies access to the official status API, performs an unsigned Debug build, and opens the Xcode project.

When Xcode opens:

1. Select the blue `OpenAIStatusMac` project icon in the navigator.
2. Select the `OpenAI Status` target and open `Signing & Capabilities`.
3. Choose your Apple ID team under `Team`.
4. Select the `OpenAIStatusWidget` target and choose the same team.
5. Select the `OpenAI Status` scheme and `My Mac` as the run destination.
6. Press Run.
7. Allow notifications when macOS prompts you on the first launch.

If Xcode reports that a Bundle Identifier is unavailable, replace both identifiers with values unique to you:

```text
Example:
com.yourname.OpenAIStatusMonitor
com.yourname.OpenAIStatusMonitor.Widget
```

The host app and Widget Extension must be signed with the same team.

## Add the desktop widget

Launch the app once, then:

1. Right-click the desktop.
2. Choose **Edit Widgets**.
3. Search for `OpenAI Status`.
4. Add the small or medium widget to the desktop.

On macOS 26 or later, you can also add the `OpenAI Status` control from Control Center's editing interface. The desktop widget and Control Widget are separate implementations.

## Notifications

Open notification settings from the bell button in the app header or from the app's Settings menu.

| Notification | Default |
| --- | --- |
| New incidents | ON |
| Service degradation or outage | ON |
| Incident or service recovery | ON |
| Incident updates | OFF |
| Status-fetch failures | OFF |
| Monitored services | All services |

The app checks the status approximately once per minute while it is running. Monitoring continues after closing the window as long as the app process remains active, but stops when the app quits.

The widget requests another timeline update after approximately 15 minutes. macOS determines the actual refresh time based on power and system conditions.

## Run verification only

```sh
./scripts/verify.sh
```

The script verifies:

- plist, entitlements, and Xcode project syntax
- Four SwiftPM/XCTest tests
- Live decoding of the official OpenAI status API
- An unsigned Debug build of the host app and embedded Widget Extension

Widget registration itself requires signing. After verification, set the same Xcode team for both targets.

## Data sources

- `https://status.openai.com/api/v2/summary.json`
- `https://status.openai.com/api/v2/incidents.json`

No API key or OpenAI account is required. Requests use HTTPS. The app does not store credentials or status-response bodies.

## Project structure

```text
OpenAIStatusMac.xcodeproj       macOS app and Widget Extension
OpenAIStatus/App               SwiftUI UI, monitoring, and notification settings
OpenAIStatus/Shared            API models, client, and notification-diff policy
OpenAIStatus/Widget            WidgetKit and ControlWidget implementation
Tests                          XCTest coverage
Verification                   Live API verifier
scripts/setup.sh               First-run setup
scripts/verify.sh              Reproducible verification
scripts/install.sh             Xcode-free installer for the latest release
scripts/build-release-zip.sh   Maintainer release packager
```

## Troubleshooting

### `Embedded binary is not signed with the same certificate as the parent app.`

Set the same Signing Team for the `OpenAI Status` and `OpenAIStatusWidget` targets.

### The build succeeds, but the widget is missing from the gallery

Check that:

- You launched the app at least once.
- The Widget Extension uses the same Signing Team as the host app.
- App Sandbox and Outgoing Connections are enabled in `OpenAIStatusWidget.entitlements`.
- You launched the current Xcode build rather than an older copy of the app.

The Debug warning `not stripping binary because it is signed` is a known, non-fatal warning for this project.

### Notifications do not appear

1. Open notification settings from the bell button.
2. Confirm that the macOS authorization status is `Allowed`.
3. Send a test notification from the settings window.
4. Check **System Settings → Notifications** in macOS.

## Distribution and security

GitHub Releases are the only official binary-download location for this project. The current prebuilt app is Apple Development-signed and unnotarized, so macOS requires one manual Gatekeeper approval on first launch. It is not equivalent to a Developer ID-signed and notarized release.

Maintainers can reproduce the archive with `OPENAI_STATUS_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/build-release-zip.sh 1.1.0`. The script selects a valid Apple Development identity from the Keychain, verifies the host app and embedded Widget Extension signatures, requires the same signing Team ID for both, packages the app with `ditto`, and writes a SHA-256 checksum. `OPENAI_STATUS_CODE_SIGN_IDENTITY` can select a specific certificate when more than one identity is installed.

## License

[MIT License](LICENSE)

OpenAI, ChatGPT, and related names belong to their respective owners.
