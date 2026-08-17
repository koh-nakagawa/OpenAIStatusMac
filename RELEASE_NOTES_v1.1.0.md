## Xcode-free installation

This release adds a universal Apple silicon and Intel macOS application with the app, desktop widgets, Notification Center widgets, and the macOS 26 Control Widget in one archive.

### Install

Download `OpenAIStatusMac-unnotarized.zip`, verify the SHA-256 checksum if desired, extract it, and move `OpenAI Status.app` to `Applications`. Alternatively, clone the repository and run `./scripts/install.sh`.

### Important Gatekeeper notice

This free release is signed with an Apple Development certificate but is **not notarized** by Apple. macOS may block the first launch. Try opening the app once, then go to **System Settings → Privacy & Security** and choose **Open Anyway** for OpenAI Status.

Do not disable Gatekeeper and do not remove quarantine attributes.

After approval, launch the app once before adding the desktop or Control Center widgets. Xcode is not required for installation.
