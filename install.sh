#!/bin/bash
# =============================================================================
# Magic Mouse Battery Monitor — All-in-One Installer
#
# This script:
# 1. Creates the battery checker script in ~/.local/bin/
# 2. Guides you to create the macOS Shortcut
# 3. Creates and loads the LaunchAgent to run it every 10 minutes
# =============================================================================

set -e

# Configurable settings for the setup
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="magic-mouse-battery-monitor.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
PLIST_NAME="com.user.magic-mouse-battery-monitor.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
SHORTCUT_NAME="Mouse Battery Monitor"
SCRIPT_VERSION="1.1.0"
RELEASE_MANIFEST_URL="https://raw.githubusercontent.com/mmihalev/magic-mouse-battery-monitor/main/.release-please-manifest.json"

DEFAULT_THRESHOLDS="20,15,10"
DEFAULT_INTERVAL=600  # 10 minutes
DEFAULT_AUTO_UPDATE_CHECK=0
DEFAULT_UPDATE_CHECK_INTERVAL=86400

get_installed_version() {
    if [ -f "$SCRIPT_PATH" ]; then
        awk -F'"' '/^SCRIPT_VERSION="/ { print $2; exit }' "$SCRIPT_PATH"
    fi
}

get_latest_release_version() {
    curl -fsSL "$RELEASE_MANIFEST_URL" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
v = data.get(".")
if isinstance(v, str) and v.strip():
    print(v.strip())
'
}

is_version_newer() {
    python3 - "$1" "$2" << 'PYEOF'
import re, sys
latest = sys.argv[1]
current = sys.argv[2]

def parse(v):
    base = re.split(r"[-+]", v, maxsplit=1)[0]
    parts = [int(p) for p in base.split(".") if p.isdigit()]
    return tuple(parts)

try:
    print(1 if parse(latest) > parse(current) else 0)
except Exception:
    print(0)
PYEOF
}

read_existing_settings() {
    local existing_thresholds existing_interval existing_auto_update_check existing_update_check_interval
    EXISTING_SETTINGS_FOUND=0
    existing_thresholds=""
    existing_interval=""
    existing_auto_update_check=""
    existing_update_check_interval=""
    if [ -f "$PLIST_DEST" ]; then
        EXISTING_SETTINGS_FOUND=1
        existing_thresholds=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:BATTERY_THRESHOLDS" "$PLIST_DEST" 2>/dev/null || true)
        existing_interval=$(/usr/libexec/PlistBuddy -c "Print :StartInterval" "$PLIST_DEST" 2>/dev/null || true)
        existing_auto_update_check=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:AUTO_UPDATE_CHECK" "$PLIST_DEST" 2>/dev/null || true)
        existing_update_check_interval=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:UPDATE_CHECK_INTERVAL" "$PLIST_DEST" 2>/dev/null || true)
    fi

    if [ -n "$existing_thresholds" ]; then
        USER_THRESHOLDS="$existing_thresholds"
    else
        USER_THRESHOLDS="$DEFAULT_THRESHOLDS"
    fi

    if [[ "$existing_interval" =~ ^[0-9]+$ ]]; then
        USER_INTERVAL="$existing_interval"
    else
        USER_INTERVAL="$DEFAULT_INTERVAL"
    fi

    if [ "$existing_auto_update_check" = "0" ] || [ "$existing_auto_update_check" = "1" ]; then
        USER_AUTO_UPDATE_CHECK="$existing_auto_update_check"
    else
        USER_AUTO_UPDATE_CHECK="$DEFAULT_AUTO_UPDATE_CHECK"
    fi

    if [[ "$existing_update_check_interval" =~ ^[0-9]+$ ]]; then
        USER_UPDATE_CHECK_INTERVAL="$existing_update_check_interval"
    else
        USER_UPDATE_CHECK_INTERVAL="$DEFAULT_UPDATE_CHECK_INTERVAL"
    fi

    # Prefer explicit values passed by the updater script, when available.
    if [ -n "${MMBM_USER_THRESHOLDS:-}" ]; then
        USER_THRESHOLDS="$MMBM_USER_THRESHOLDS"
    fi
    if [[ "${MMBM_USER_INTERVAL:-}" =~ ^[0-9]+$ ]]; then
        USER_INTERVAL="$MMBM_USER_INTERVAL"
    fi
    if [ "${MMBM_USER_AUTO_UPDATE_CHECK:-}" = "0" ] || [ "${MMBM_USER_AUTO_UPDATE_CHECK:-}" = "1" ]; then
        USER_AUTO_UPDATE_CHECK="$MMBM_USER_AUTO_UPDATE_CHECK"
    fi
    if [[ "${MMBM_USER_UPDATE_CHECK_INTERVAL:-}" =~ ^[0-9]+$ ]]; then
        USER_UPDATE_CHECK_INTERVAL="$MMBM_USER_UPDATE_CHECK_INTERVAL"
    fi
}

INSTALLED_VERSION=$(get_installed_version)
LATEST_RELEASE_VERSION=$(get_latest_release_version || true)

echo ""
echo "🪫 Installing Magic Mouse Battery Monitor"
echo "═══════════════════════════════════════════"
if [ -n "$INSTALLED_VERSION" ]; then
    if [ "$INSTALLED_VERSION" = "$SCRIPT_VERSION" ]; then
        echo "   Reinstalling version: $SCRIPT_VERSION"
    else
        echo "   Installed script version: $INSTALLED_VERSION"
        echo "   Version to install: $SCRIPT_VERSION"
        echo "   Updating: $INSTALLED_VERSION -> $SCRIPT_VERSION"
    fi
else
    echo "   Installed script version: not found"
    echo "   Version to install: $SCRIPT_VERSION"
fi
if [ -n "$LATEST_RELEASE_VERSION" ]; then
    if [ "$LATEST_RELEASE_VERSION" = "$SCRIPT_VERSION" ]; then
        echo "   Latest available version: $LATEST_RELEASE_VERSION (up to date)"
    elif [ "$(is_version_newer "$LATEST_RELEASE_VERSION" "$SCRIPT_VERSION")" = "1" ]; then
        echo "   Latest available version: $LATEST_RELEASE_VERSION (newer than this installer)"
    else
        echo "   Latest available version: $LATEST_RELEASE_VERSION"
    fi
else
    echo "   Latest available version: unavailable (network issue)"
fi
echo ""

# Ask for settings during new installations. During updates, preserve current
# settings by default and optionally let the user change them.
if [ "$1" = "update" ]; then
    read_existing_settings
    echo "🔄 Update mode detected."
    echo "   Current thresholds: $USER_THRESHOLDS"
    echo "   Current interval: $USER_INTERVAL seconds"
    echo "   Current automatic update checks: $USER_AUTO_UPDATE_CHECK"
    echo "   Current update check interval: $USER_UPDATE_CHECK_INTERVAL seconds"
    read -p "   Keep current settings? [Y/n]: " KEEP_SETTINGS
    if [ "$KEEP_SETTINGS" = "n" ] || [ "$KEEP_SETTINGS" = "N" ]; then
        echo ""
        echo "⚙️  Configuration (Press Enter at any step to keep current values)"
        echo ""
        read -p "   Battery thresholds (current: $USER_THRESHOLDS): " NEW_THRESHOLDS
        USER_THRESHOLDS=${NEW_THRESHOLDS:-$USER_THRESHOLDS}
        echo ""
        read -p "   Check interval in seconds (current: $USER_INTERVAL): " NEW_INTERVAL
        if [[ "$NEW_INTERVAL" =~ ^[0-9]+$ ]]; then
            USER_INTERVAL=$NEW_INTERVAL
        fi
        echo ""
        read -p "   Automatic update checks 1=enabled, 0=disabled (current: $USER_AUTO_UPDATE_CHECK): " NEW_AUTO_UPDATE_CHECK
        if [ "$NEW_AUTO_UPDATE_CHECK" = "0" ] || [ "$NEW_AUTO_UPDATE_CHECK" = "1" ]; then
            USER_AUTO_UPDATE_CHECK=$NEW_AUTO_UPDATE_CHECK
        fi
        echo ""
        read -p "   Update check interval in seconds (current: $USER_UPDATE_CHECK_INTERVAL): " NEW_UPDATE_CHECK_INTERVAL
        if [[ "$NEW_UPDATE_CHECK_INTERVAL" =~ ^[0-9]+$ ]]; then
            USER_UPDATE_CHECK_INTERVAL=$NEW_UPDATE_CHECK_INTERVAL
        fi
        echo ""
    else
        echo "   Keeping current settings."
        echo ""
    fi
else
    read_existing_settings
    if [ "$EXISTING_SETTINGS_FOUND" = "1" ]; then
        echo "⚙️  Configuration (Press Enter at any step to keep current values)"
    else
        echo "⚙️  Configuration (Press Enter at any step to use the default settings)"
    fi
    echo ""
    echo "   At what battery levels would you like to be notified?"
    echo "   (Example: '20,15,10' means you get an alert at 20%, again at 15%, etc.)"
    if [ -t 0 ]; then
        if [ "$EXISTING_SETTINGS_FOUND" = "1" ]; then
            read -p "   Battery thresholds (current: $USER_THRESHOLDS): " NEW_THRESHOLDS
        else
            read -p "   Battery thresholds (default: $DEFAULT_THRESHOLDS): " NEW_THRESHOLDS
        fi
        USER_THRESHOLDS=${NEW_THRESHOLDS:-$USER_THRESHOLDS}

        echo ""
        echo "   How often should the background task silently check your mouse?"
        echo "   (Example: 600 seconds = 10 minutes)"
        if [ "$EXISTING_SETTINGS_FOUND" = "1" ]; then
            read -p "   Check interval in seconds (current: $USER_INTERVAL): " NEW_INTERVAL
        else
            read -p "   Check interval in seconds (default: $DEFAULT_INTERVAL): " NEW_INTERVAL
        fi
        if [[ "$NEW_INTERVAL" =~ ^[0-9]+$ ]]; then
            USER_INTERVAL=$NEW_INTERVAL
        fi
        echo ""
        echo "   Should the script automatically check for new versions in the background?"
        if [ "$EXISTING_SETTINGS_FOUND" = "1" ]; then
            read -p "   Automatic update checks 1=enabled, 0=disabled (current: $USER_AUTO_UPDATE_CHECK): " NEW_AUTO_UPDATE_CHECK
        else
            read -p "   Automatic update checks 1=enabled, 0=disabled (default: $DEFAULT_AUTO_UPDATE_CHECK): " NEW_AUTO_UPDATE_CHECK
        fi
        if [ "$NEW_AUTO_UPDATE_CHECK" = "0" ] || [ "$NEW_AUTO_UPDATE_CHECK" = "1" ]; then
            USER_AUTO_UPDATE_CHECK=$NEW_AUTO_UPDATE_CHECK
        fi
        echo ""
        echo "   How often should it check for new versions?"
        if [ "$EXISTING_SETTINGS_FOUND" = "1" ]; then
            read -p "   Update check interval in seconds (current: $USER_UPDATE_CHECK_INTERVAL): " NEW_UPDATE_CHECK_INTERVAL
        else
            read -p "   Update check interval in seconds (default: $DEFAULT_UPDATE_CHECK_INTERVAL): " NEW_UPDATE_CHECK_INTERVAL
        fi
        if [[ "$NEW_UPDATE_CHECK_INTERVAL" =~ ^[0-9]+$ ]]; then
            USER_UPDATE_CHECK_INTERVAL=$NEW_UPDATE_CHECK_INTERVAL
        fi
        echo ""
    else
        echo "   Non-interactive mode detected. Keeping existing/default settings."
        echo ""
    fi
fi

# ── Step 1: Create the checker script ─────────────────────────────────────────
echo "📄 Step 1: Creating battery check script..."
mkdir -p "$INSTALL_DIR"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
# Detects ALL connected Bluetooth mice (by device type, not name) and shows
# macOS notifications as battery drops through configurable thresholds.
# Detection: system_profiler (Minor Type == Mouse) + ioreg (BatteryPercent)

SCRIPT_VERSION="__SCRIPT_VERSION__"
BATTERY_THRESHOLDS=${BATTERY_THRESHOLDS:-"20,15,10"}
STATE_DIR="/tmp/magic-mouse-battery-monitor"
AUTO_UPDATE_CHECK=${AUTO_UPDATE_CHECK:-"0"}
UPDATE_CHECK_INTERVAL=${UPDATE_CHECK_INTERVAL:-86400}
RELEASE_MANIFEST_URL="https://raw.githubusercontent.com/mmihalev/magic-mouse-battery-monitor/main/.release-please-manifest.json"
UPDATE_CHECK_STATE_FILE="$STATE_DIR/update-last-check"
UPDATE_NOTIFIED_VERSION_FILE="$STATE_DIR/update-last-notified-version"

mkdir -p "$STATE_DIR"

collect_installed_settings_for_update() {
    local plist_path
    plist_path="$HOME/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist"
    MMBM_USER_THRESHOLDS=""
    MMBM_USER_INTERVAL=""
    MMBM_USER_AUTO_UPDATE_CHECK=""
    MMBM_USER_UPDATE_CHECK_INTERVAL=""
    [ -f "$plist_path" ] || return

    MMBM_USER_THRESHOLDS=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:BATTERY_THRESHOLDS" "$plist_path" 2>/dev/null || true)
    MMBM_USER_INTERVAL=$(/usr/libexec/PlistBuddy -c "Print :StartInterval" "$plist_path" 2>/dev/null || true)
    MMBM_USER_AUTO_UPDATE_CHECK=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:AUTO_UPDATE_CHECK" "$plist_path" 2>/dev/null || true)
    MMBM_USER_UPDATE_CHECK_INTERVAL=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:UPDATE_CHECK_INTERVAL" "$plist_path" 2>/dev/null || true)
}

if [ "$1" = "version" ] || [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "magic-mouse-battery-monitor.sh $SCRIPT_VERSION"
    exit 0
fi

if [ "$1" = "update" ]; then
    echo "🔄 Checking for updates..."
    latest_version=$(curl -fsSL "$RELEASE_MANIFEST_URL" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
v = data.get(".")
if isinstance(v, str) and v.strip():
    print(v.strip())
')
    if [ -n "$latest_version" ]; then
        is_newer=$(python3 - "$latest_version" "$SCRIPT_VERSION" << 'PYEOF'
import re, sys
latest = sys.argv[1]
current = sys.argv[2]

def parse(v):
    base = re.split(r'[-+]', v, maxsplit=1)[0]
    parts = [int(p) for p in base.split('.') if p.isdigit()]
    return tuple(parts)

try:
    print(1 if parse(latest) > parse(current) else 0)
except Exception:
    print(0)
PYEOF
)
        if [ "$is_newer" != "1" ]; then
            echo "✅ Already up to date (installed: $SCRIPT_VERSION, latest: $latest_version)."
            exit 0
        fi
    fi

    UPDATE_URL="https://raw.githubusercontent.com/mmihalev/magic-mouse-battery-monitor/main/install.sh"
    CHECKSUM_URL="https://raw.githubusercontent.com/mmihalev/magic-mouse-battery-monitor/main/install.sh.sha256"
    TMP_INSTALL="/tmp/magic-mouse-battery-monitor-install.sh"
    TMP_CHECKSUM="/tmp/magic-mouse-battery-monitor-install.sh.sha256"
    
    if curl -sL "$UPDATE_URL" -o "$TMP_INSTALL" && curl -sL "$CHECKSUM_URL" -o "$TMP_CHECKSUM"; then
        EXPECTED_SHA=$(cat "$TMP_CHECKSUM" | grep "install.sh" | awk '{print $1}')
        ACTUAL_SHA=$(shasum -a 256 "$TMP_INSTALL" | awk '{print $1}')
        
        # Fallback if expected sha parsing failed but file is valid
        if [ -z "$EXPECTED_SHA" ]; then
            EXPECTED_SHA=$(cat "$TMP_CHECKSUM" | awk '{print $1}')
        fi

        if [ -n "$EXPECTED_SHA" ] && [ "$EXPECTED_SHA" = "$ACTUAL_SHA" ]; then
            echo "✅ Downloaded update is authentic and verified (SHA-256 match)."
            chmod +x "$TMP_INSTALL"
            echo "🚀 Running installer..."
            collect_installed_settings_for_update
            MMBM_USER_THRESHOLDS="$MMBM_USER_THRESHOLDS" \
            MMBM_USER_INTERVAL="$MMBM_USER_INTERVAL" \
            MMBM_USER_AUTO_UPDATE_CHECK="$MMBM_USER_AUTO_UPDATE_CHECK" \
            MMBM_USER_UPDATE_CHECK_INTERVAL="$MMBM_USER_UPDATE_CHECK_INTERVAL" \
            exec "$TMP_INSTALL" update
        else
            echo "❌ Error: Downloaded file failed SHA-256 verification. Update aborted."
            echo "   Expected: $EXPECTED_SHA"
            echo "   Actual:   $ACTUAL_SHA"
            rm -f "$TMP_INSTALL" "$TMP_CHECKSUM"
            exit 1
        fi
    else
        echo "❌ Error: Failed to download update or checksum. Check your internet connection."
        exit 1
    fi
fi

# Refresh runtime settings from LaunchAgent when running manually so update
# command reflects current configured values instead of shell defaults.
load_settings_from_launchagent() {
    local plist_path thresholds auto_update update_interval
    plist_path="$HOME/Library/LaunchAgents/com.user.magic-mouse-battery-monitor.plist"
    [ -f "$plist_path" ] || return

    thresholds=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:BATTERY_THRESHOLDS" "$plist_path" 2>/dev/null || true)
    auto_update=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:AUTO_UPDATE_CHECK" "$plist_path" 2>/dev/null || true)
    update_interval=$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:UPDATE_CHECK_INTERVAL" "$plist_path" 2>/dev/null || true)

    if [ -n "$thresholds" ]; then
        BATTERY_THRESHOLDS="$thresholds"
    fi
    if [ "$auto_update" = "0" ] || [ "$auto_update" = "1" ]; then
        AUTO_UPDATE_CHECK="$auto_update"
    fi
    if [[ "$update_interval" =~ ^[0-9]+$ ]]; then
        UPDATE_CHECK_INTERVAL="$update_interval"
    fi
}

load_settings_from_launchagent

get_latest_release_version() {
    curl -fsSL "$RELEASE_MANIFEST_URL" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
v = data.get(".")
if isinstance(v, str) and v.strip():
    print(v.strip())
'
}

is_version_newer() {
    python3 - "$1" "$2" << 'PYEOF'
import re, sys
latest = sys.argv[1]
current = sys.argv[2]

def parse(v):
    # Keep numeric semantic parts only (e.g., 1.2.3 from 1.2.3-beta)
    base = re.split(r'[-+]', v, maxsplit=1)[0]
    parts = [int(p) for p in base.split('.') if p.isdigit()]
    return tuple(parts)

try:
    print(1 if parse(latest) > parse(current) else 0)
except Exception:
    print(0)
PYEOF
}

auto_check_for_updates() {
    [ "$AUTO_UPDATE_CHECK" = "1" ] || return
    if ! [[ "$UPDATE_CHECK_INTERVAL" =~ ^[0-9]+$ ]]; then
        UPDATE_CHECK_INTERVAL=86400
    fi

    local now last_check latest notified newer
    now=$(date +%s)
    last_check=0
    [ -f "$UPDATE_CHECK_STATE_FILE" ] && last_check=$(cat "$UPDATE_CHECK_STATE_FILE" 2>/dev/null || echo 0)
    if ! [[ "$last_check" =~ ^[0-9]+$ ]]; then
        last_check=0
    fi

    if [ $((now - last_check)) -lt "$UPDATE_CHECK_INTERVAL" ]; then
        return
    fi

    echo "$now" > "$UPDATE_CHECK_STATE_FILE"
    latest=$(get_latest_release_version || true)
    [ -n "$latest" ] || return

    newer=$(is_version_newer "$latest" "$SCRIPT_VERSION")
    [ "$newer" = "1" ] || return

    notified=""
    [ -f "$UPDATE_NOTIFIED_VERSION_FILE" ] && notified=$(cat "$UPDATE_NOTIFIED_VERSION_FILE" 2>/dev/null || true)
    [ "$notified" = "$latest" ] && return

    osascript -e "display notification \"A new version ($latest) is available. Run ~/.local/bin/magic-mouse-battery-monitor.sh update\" with title \"Magic Mouse Battery Monitor Update\" sound name \"Sosumi\""
    echo "$latest" > "$UPDATE_NOTIFIED_VERSION_FILE"
}

auto_check_for_updates

get_connected_mice() {
    python3 << 'PYEOF'
import json, subprocess, sys
try:
    raw = subprocess.check_output(
        ["system_profiler", "SPBluetoothDataType", "-json"],
        stderr=subprocess.DEVNULL
    )
    data = json.loads(raw)
except Exception:
    sys.exit(0)

for entry in data.get("SPBluetoothDataType", []):
    for device_dict in entry.get("device_connected", []):
        for name, info in device_dict.items():
            if info.get("device_minorType", "").lower() == "mouse":
                addr = info.get("device_address", "")
                if addr:
                    print(f"{name}|{addr}")
PYEOF
}

get_battery_by_address() {
    local address="" battery=""
    while IFS= read -r line; do
        if echo "$line" | grep -q '"DeviceAddress" = '; then
            address=$(echo "$line" | sed 's/.*"DeviceAddress" = "//;s/"$//' | tr '-' ':' | tr '[:lower:]' '[:upper:]')
        elif echo "$line" | grep -q '"BatteryPercent" = '; then
            battery=$(echo "$line" | sed 's/.*= //')
            if [ -n "$address" ] && [ -n "$battery" ]; then
                echo "${address}|${battery}"
            fi
            address="" battery=""
        fi
    done < <(ioreg -r -k "BatteryPercent" -d 1 | grep -E '"DeviceAddress"|"BatteryPercent"')
}

IFS=',' read -ra thresholds <<< "$BATTERY_THRESHOLDS"
max_threshold=0
for t in "${thresholds[@]}"; do
    t=$(echo "$t" | tr -d ' ')
    [ "$t" -gt "$max_threshold" ] && max_threshold=$t
done

battery_data=$(get_battery_by_address)

get_connected_mice | while IFS='|' read -r name address; do
    norm_addr=$(echo "$address" | tr '-' ':' | tr '[:lower:]' '[:upper:]')
    battery=$(echo "$battery_data" | grep -F "$norm_addr|" | cut -d'|' -f2 | head -n1)

    if [ -z "$battery" ]; then continue; fi

    safe_addr=$(echo "$norm_addr" | tr ':' '_')
    state_file="$STATE_DIR/$safe_addr"

    notified=""
    [ -f "$state_file" ] && notified=$(cat "$state_file")

    if [ "$battery" -gt "$max_threshold" ]; then
        rm -f "$state_file"
        continue
    fi

    for t in "${thresholds[@]}"; do
        t=$(echo "$t" | tr -d ' ')
        echo "$notified" | grep -qw "$t" && continue
        if [ "$battery" -le "$t" ]; then
            osascript -e "display notification \"${name} battery is at ${battery}% (threshold: ${t}%). Please charge it soon.\" with title \"🪫 ${name} Battery Low\" sound name \"Sosumi\""
            echo "$t" >> "$state_file"
        fi
    done
done
EOF

sed -i '' "s/__SCRIPT_VERSION__/$SCRIPT_VERSION/g" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
echo "   Script saved to: $SCRIPT_PATH"
# Remove old script name if it exists.
rm -f "$INSTALL_DIR/check_magic_mouse_battery.sh"
echo ""


# ── Step 2: Create the Shortcut ─────────────────────────────────────────────
REFRESH_SHORTCUT=1
if shortcuts list 2>/dev/null | grep -qF "$SHORTCUT_NAME"; then
    echo "📱 Step 2: Refresh the Shortcut"
    echo "   Shortcut \"$SHORTCUT_NAME\" already exists."
    if [ -t 0 ]; then
        read -p "   Refresh it now to ensure script path is up to date? [Y/n]: " REFRESH_CHOICE
        if [ "$REFRESH_CHOICE" = "n" ] || [ "$REFRESH_CHOICE" = "N" ]; then
            REFRESH_SHORTCUT=0
        fi
    else
        REFRESH_SHORTCUT=0
        echo "   Non-interactive mode detected. Keeping existing Shortcut."
    fi
else
    echo "📱 Step 2: Create the Shortcut"
fi

if [ "$REFRESH_SHORTCUT" = "1" ]; then
    echo "   Generating Shortcut file..."

    SHORTCUT_PLIST="/tmp/MouseBatteryMonitor.plist"
    SHORTCUT_FILE="/tmp/Mouse Battery Monitor.shortcut"

    cat > "$SHORTCUT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>WFWorkflowActions</key>
	<array>
		<dict>
			<key>WFWorkflowActionIdentifier</key>
			<string>is.workflow.actions.runshellscript</string>
			<key>WFWorkflowActionParameters</key>
			<dict>
				<key>UUID</key>
				<string>\$(uuidgen)</string>
				<key>Script</key>
				<string>/bin/bash "$SCRIPT_PATH"</string>
			</dict>
		</dict>
	</array>
	<key>WFWorkflowClientVersion</key>
	<string>1146.12</string>
	<key>WFWorkflowIcon</key>
	<dict>
		<key>WFWorkflowIconGlyphNumber</key>
		<integer>59511</integer>
		<key>WFWorkflowIconStartColor</key>
		<integer>4282601983</integer>
	</dict>
	<key>WFWorkflowTypes</key>
	<array/>
</dict>
</plist>
EOF

    plutil -convert binary1 "$SHORTCUT_PLIST" -o "$SHORTCUT_FILE"
    shortcuts sign --mode anyone --input "$SHORTCUT_FILE" --output "$SHORTCUT_FILE" 2>/dev/null
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║         Install \"Mouse Battery Monitor\" Shortcut                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo "  The Shortcuts app will now open."
    echo ""
    echo "  ⚠️  IMPORTANT MACOS SECURITY CHECK ⚠️"
    echo "  macOS disables shell scripts in Shortcuts by default."
    echo "  If you see an error when running or importing:"
    echo "  1. Open Shortcuts app"
    echo "  2. Go to Shortcuts -> Settings... (Cmd + ,)"
    echo "  3. Click the 'Advanced' tab"
    echo "  4. Check the box for 'Allow Running Scripts'"
    echo ""
    if shortcuts list 2>/dev/null | grep -qF "$SHORTCUT_NAME"; then
        echo "  Please click 'Replace' to update it, then return here."
    else
        echo "  Please click 'Add Shortcut' to import it, then return here."
    fi
    echo ""
    
    open "$SHORTCUT_FILE"
    
    read -p "   Press [Enter] once you've completed the import..."
    echo ""

    if shortcuts list 2>/dev/null | grep -qF "$SHORTCUT_NAME"; then
        echo "✅ Shortcut detected!"
    else
        echo "⚠️  Shortcut \"$SHORTCUT_NAME\" not found. It may have failed to import."
    fi
    
    rm -f "$SHORTCUT_PLIST" "$SHORTCUT_FILE"
fi
echo ""


# ── Step 3: Create and Load the LaunchAgent ─────────────────────────────────
echo "⚙️  Step 3: Setting up background automation..."

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_DEST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.magic-mouse-battery-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/shortcuts</string>
        <string>run</string>
        <string>$SHORTCUT_NAME</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>BATTERY_THRESHOLDS</key>
        <string>$USER_THRESHOLDS</string>
        <key>AUTO_UPDATE_CHECK</key>
        <string>$USER_AUTO_UPDATE_CHECK</string>
        <key>UPDATE_CHECK_INTERVAL</key>
        <string>$USER_UPDATE_CHECK_INTERVAL</string>
    </dict>
    <key>StartInterval</key>
    <integer>$USER_INTERVAL</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/magic-mouse-battery-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/magic-mouse-battery-monitor-error.log</string>
</dict>
</plist>
EOF

if launchctl list 2>/dev/null | grep -q "com.user.magic-mouse-battery-monitor"; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

launchctl load "$PLIST_DEST"

echo ""
echo "═══════════════════════════════════════════"
echo "✅ Setup complete!"
echo ""
echo "   Monitor is now running silently in the background."
echo "   It checks the battery every $(( USER_INTERVAL / 60 )) minutes and uses thresholds: $USER_THRESHOLDS%"
if [ "$USER_AUTO_UPDATE_CHECK" = "1" ]; then
    echo "   Automatic update checks are enabled (every $USER_UPDATE_CHECK_INTERVAL seconds)."
else
    echo "   Automatic update checks are disabled."
fi
echo ""
echo "📝 To configure thresholds or interval, edit:"
echo "   $PLIST_DEST"
echo "   (Reload with: launchctl unload \"$PLIST_DEST\" && launchctl load \"$PLIST_DEST\")"
echo ""
echo "🗑  To pause or uninstall:"
echo "   launchctl unload \"$PLIST_DEST\""
echo "   rm \"$PLIST_DEST\""
