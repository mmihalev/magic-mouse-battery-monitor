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
SCRIPT_PATH="$INSTALL_DIR/check_magic_mouse_battery.sh"
PLIST_NAME="com.user.magic-mouse-battery-monitor.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
SHORTCUT_NAME="Mouse Battery Monitor"

DEFAULT_THRESHOLDS="20,15,10"
DEFAULT_INTERVAL=600  # 10 minutes

echo ""
echo "🪫 Installing Magic Mouse Battery Monitor"
echo "═══════════════════════════════════════════"
echo ""

# Ask for settings during new installations (skip during automated updates)
if [ "$1" != "update" ]; then
    echo "⚙️  Configuration (Press Enter to use defaults):"
    
    read -p "   Battery thresholds (default: $DEFAULT_THRESHOLDS): " USER_THRESHOLDS
    USER_THRESHOLDS=${USER_THRESHOLDS:-$DEFAULT_THRESHOLDS}
    
    read -p "   Check interval in seconds (default: $DEFAULT_INTERVAL): " USER_INTERVAL
    if [[ ! "$USER_INTERVAL" =~ ^[0-9]+$ ]]; then
        USER_INTERVAL=$DEFAULT_INTERVAL
    fi
    echo ""
else
    USER_THRESHOLDS=$DEFAULT_THRESHOLDS
    USER_INTERVAL=$DEFAULT_INTERVAL
fi

# ── Step 1: Create the checker script ─────────────────────────────────────────
echo "📄 Step 1: Creating battery check script..."
mkdir -p "$INSTALL_DIR"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
# Detects ALL connected Bluetooth mice (by device type, not name) and shows
# macOS notifications as battery drops through configurable thresholds.
# Detection: system_profiler (Minor Type == Mouse) + ioreg (BatteryPercent)

BATTERY_THRESHOLDS=${BATTERY_THRESHOLDS:-"20,15,10"}
STATE_DIR="/tmp/magic-mouse-battery-monitor"

mkdir -p "$STATE_DIR"

if [ "$1" = "update" ]; then
    echo "🔄 Checking for updates..."
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
            exec "$TMP_INSTALL"
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

chmod +x "$SCRIPT_PATH"
echo "   Script saved to: $SCRIPT_PATH"
echo ""


# ── Step 2: Create the Shortcut ─────────────────────────────────────────────
if shortcuts list 2>/dev/null | grep -qF "$SHORTCUT_NAME"; then
    echo "✅ Shortcut \"$SHORTCUT_NAME\" already exists."
else
    echo "📱 Step 2: Create the Shortcut"
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
    echo "  Please click 'Add Shortcut' to import it, then return here."
    echo ""
    
    open "$SHORTCUT_FILE"
    
    read -p "   Press [Enter] once you've added the Shortcut..."
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
echo ""
echo "📝 To configure thresholds or interval, edit:"
echo "   $PLIST_DEST"
echo "   (Reload with: launchctl unload \"$PLIST_DEST\" && launchctl load \"$PLIST_DEST\")"
echo ""
echo "🗑  To pause or uninstall:"
echo "   launchctl unload \"$PLIST_DEST\""
echo "   rm \"$PLIST_DEST\""
