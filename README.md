# Magic Mouse Battery Monitor

[![release-please](https://github.com/mmihalev/magic-mouse-battery-monitor/actions/workflows/release-please.yml/badge.svg)](https://github.com/mmihalev/magic-mouse-battery-monitor/actions/workflows/release-please.yml)
[![Update Checksum](https://github.com/mmihalev/magic-mouse-battery-monitor/actions/workflows/update-checksum.yml/badge.svg)](https://github.com/mmihalev/magic-mouse-battery-monitor/actions/workflows/update-checksum.yml)

A modern macOS automation that monitors **all connected Bluetooth mice** and sends notifications as they drop through configurable thresholds (e.g., 20% → 15% → 10%).

*Tested on macOS 26.3.1*

It integrates neatly with the **macOS Shortcuts app**, allowing manual checks via Spotlight/Siri while a background LaunchAgent automatically triggers it every 10 minutes.

## How It Works

Instead of relying on fragile names like "Magic Mouse", this tool uses a two-stage detection method:
1. Uses `system_profiler` to find all connected devices whose actual OS-level type is a **Mouse**.
2. Cross-references their Bluetooth addresses against `ioreg` to extract battery levels.
3. Completely **brand/name independent** and supports multiple mice concurrently.
4. Notifications and de-duplication are handled independently per-mouse via state files in `/tmp/magic-mouse-battery-monitor/`.

### Why use Shortcuts instead of a direct background script?
Apple heavily restricts background shell scripts from invoking UI elements like native OS notifications due to security and permissions protocols.

Executing the display module via the **Shortcuts app** solves this because Shortcuts is a first-party application that intrinsically possesses the correct entitlements to render notifications seamlessly. It also creates excellent side benefits, such as allowing manual triggers via Siri or Spotlight!

## Installation

We have consolidated everything into a single, easy-to-use installer script that sets up the background agent and guides you through the Shortcut creation.

To install, simply run:
```bash
./install.sh
```

During installation, the script will:
1. Extract the core battery checker logic and save it to `~/.local/bin/check_magic_mouse_battery.sh`.
2. Open Shortcuts.app and provide instructions (with a pre-copied command) to create the "Mouse Battery Monitor" shortcut.
3. Automatically generate and load the background macOS `LaunchAgent` to run the shortcut automatically every 10 minutes.

## Configuration

The background timer is managed via a macOS LaunchAgent. To configure the thresholds or the interval, edit the generated plist file at `~/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist`:

| Setting | Key | Default | Example |
|---------|-----|---------|---------|
| **Thresholds** | `BATTERY_THRESHOLDS` | `20,15,10` | `30,20,10,5` |
| **Interval** | `StartInterval` | `600` (10 min) | `300` (5 min) |

After editing the file, reload the LaunchAgent to apply the changes:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist
launchctl load ~/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist
```

## Manual Checks

Since the checking logic is wrapped in a macOS Shortcut, you can trigger a battery check at any time directly:
- Using Spotlight (`Cmd + Space` → Type "Mouse Battery Monitor" and press Enter)
- Ask Siri ("Run Mouse Battery Monitor")
- Using the Shortcuts menu bar icon.

## Updating

You can update the background script to the latest version by running the update command from your terminal:
```bash
~/.local/bin/check_magic_mouse_battery.sh update
```
This will automatically download, verify, and apply the latest script from the main branch.

## Uninstallation

To remove the background task, run:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist
rm ~/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist
```
*(You can also optionally delete the Shortcut from the Shortcuts.app and remove the script from `~/.local/bin/check_magic_mouse_battery.sh`)*
