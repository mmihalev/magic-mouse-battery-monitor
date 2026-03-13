# Project Context: Magic Mouse Battery Monitor

This repository contains a macOS automation tool designed to monitor the battery levels of all connected Bluetooth mice (including, but not limited to, the Apple Magic Mouse). It notifies the user when the battery level drops below predefined thresholds (e.g., 20%, 15%, 10%).

## Architecture & Design
- **Single Installer**: `install.sh` is the grand unified installer. It contains the core monitoring logic as an embedded script, which it extracts to `~/.local/bin/check_magic_mouse_battery.sh` during installation.
- **Detection Mechanism**: Avoids relying on the exact device name. Instead, it uses `system_profiler SPBluetoothDataType` combined with `ioreg -c AppleDeviceManagementHIDEventService` to cross-reference Bluetooth addresses and reliably determine the battery levels of any connected mice.
- **Notification System**: Triggers a macOS Shortcut ("Mouse Battery Monitor") to handle the actual notification UI, solving permission issues and allowing visual integration with macOS.
- **Background Execution**: Utilizes a macOS `LaunchAgent` (`com.user.magic-mouse-battery-monitor.plist`) to run the check automatically every 10 minutes.
- **State Management**: State files are maintained in `/tmp/magic-mouse-battery-monitor/` to deduplicate and throttle notifications so the user isn't spammed with multiple alerts for the same threshold.

## Rules for AI Coding Agents
1. **MacOS Exclusivity**: This project is strictly for macOS. Only rely on built-in macOS tools like `system_profiler`, `ioreg`, `launchctl`, `osascript`, and the `Shortcuts` app.
2. **Monolithic Installer**: All updates to the core monitoring logic MUST be applied within the embedded setup inside `install.sh`. Do not create separate script files in the repository unless explicitly changing the architectural design.
3. **No Root Privilege**: The script runs entirely in user-space. Avoid operations that require `sudo`.
4. **Shell Scripting Best Practices**: Use POSIX-compliant or `bash`/`zsh` compatible commands (macOS defaults to `zsh`). Always quote variables.
5. **Idempotency**: `install.sh` must remain completely idempotent, capable of running multiple times without creating duplicate files, paths, or LaunchAgent configurations.
6. **Versioning and Updates**: We use Google `release-please` for versioning via GitHub Actions. The core script has a built-in `update` mechanism (e.g., `check_magic_mouse_battery.sh update`) that downloads and verifies the latest `install.sh` from the repository's `main` branch before executing it to upgrade itself.
7. **Conventional Commits**: All commit messages must strictly adhere to the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/#specification) (e.g., `feat:`, `fix:`, `chore:`). This naturally powers the `release-please` automation.
