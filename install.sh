#!/usr/bin/env bash
#
# install_daily_driver_wallpapers.sh
# Clone DailyDriverWallpapers, install the Smart Video Wallpaper Reborn plugin,
# and set the video wallpapers on the primary monitor.
#
# Wallpapers Repository: https://github.com/HeapHeapHooray/DailyDriverWallpapers
# Plugin Repository:     https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

WALLPAPERS_REPO="https://github.com/HeapHeapHooray/DailyDriverWallpapers.git"
# If running directly inside a wallpapers folder containing videos, use it directly
if compgen -G "$SCRIPT_DIR/*.mp4" >/dev/null 2>&1; then
    TARGET_DIR="$SCRIPT_DIR"
else
    TARGET_DIR="$HOME/DailyDriverWallpapers"
fi
PLUGIN_ID="luisbocanegra.smart.video.wallpaper.reborn"
PLUGIN_FALLBACK_URL="https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn/releases/download/v2.16.0/plasma-smart-video-wallpaper-reborn-v2.16.0.tar.gz"

ALL_MONITORS=false

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Clone DailyDriverWallpapers into the home directory, install the Smart Video Wallpaper
Reborn KDE Plasma plugin, and configure the video wallpapers on your monitor(s).

Options:
  -a, --all, --all-monitors
                     Apply wallpapers to all connected monitors (default: primary monitor only)
  -d, --dir <DIR>    Custom directory for wallpapers (default: ~/DailyDriverWallpapers)
  -h, --help         Show this help message
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all|--all-monitors)
            ALL_MONITORS=true
            shift
            ;;
        -d|--dir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --dir requires a path argument." >&2
                exit 1
            fi
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

export PATH="$HOME/.local/bin:$PATH"

echo "=================================================="
echo "==> DailyDriverWallpapers & Video Wallpaper Setup"
echo "=================================================="

# Step 1: Detect KDE Plasma tools
echo ""
echo "==> [1/4] Checking KDE Plasma environment..."
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS_BIN="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS_BIN="qdbus"
else
    echo "Error: Neither qdbus6 nor qdbus was found." >&2
    exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    KPACKAGE_BIN="kpackagetool6"
elif command -v kpackagetool5 >/dev/null 2>&1; then
    KPACKAGE_BIN="kpackagetool5"
else
    echo "Error: Neither kpackagetool6 nor kpackagetool5 was found." >&2
    exit 1
fi
echo "--> Found Plasma tools: $QDBUS_BIN and $KPACKAGE_BIN"

# Step 2: Clone or update DailyDriverWallpapers
echo ""
echo "==> [2/4] Setting up wallpapers directory at $TARGET_DIR..."
if [[ -d "$TARGET_DIR/.git" ]]; then
    echo "--> Existing git repository found at $TARGET_DIR. Updating..."
    git -C "$TARGET_DIR" pull --rebase 2>/dev/null || echo "--> Note: Skipped git update (local changes present or offline). Using local repository files."
elif [[ -d "$TARGET_DIR" ]]; then
    echo "--> Directory $TARGET_DIR already exists (non-git). Keeping existing files..."
else
    echo "--> Cloning $WALLPAPERS_REPO into $TARGET_DIR..."
    git clone "$WALLPAPERS_REPO" "$TARGET_DIR"
fi

# Ensure there are video files present
shopt -s nullglob
VIDEO_FILES=("$TARGET_DIR"/*.mp4 "$TARGET_DIR"/*.webm "$TARGET_DIR"/*.mkv "$TARGET_DIR"/*.mov)
shopt -u nullglob

if [[ ${#VIDEO_FILES[@]} -eq 0 ]]; then
    echo "Error: No video files found in $TARGET_DIR." >&2
    exit 1
fi
echo "--> Found ${#VIDEO_FILES[@]} video file(s) in $TARGET_DIR"

# Step 3: Install Smart Video Wallpaper Reborn plugin
echo ""
echo "==> [3/4] Installing Smart Video Wallpaper Reborn plugin..."
INSTALLED_WALLPAPERS="$($KPACKAGE_BIN -t Plasma/Wallpaper -l 2>/dev/null || true)"

if echo "$INSTALLED_WALLPAPERS" | grep -qw "$PLUGIN_ID" && [[ -d "$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID" ]]; then
    echo "--> Plugin '$PLUGIN_ID' is already installed."
else
    echo "--> Fetching plugin release package..."
    TMP_DIR="$(mktemp -d -t smart-video-pkg-XXXXXX)"
    cleanup() {
        rm -rf "$TMP_DIR"
    }
    trap cleanup EXIT

    # Get latest release URL via GitHub API or fallback to known good release URL
    DOWNLOAD_URL=""
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_URL="$(curl -sSL "https://api.github.com/repos/luisbocanegra/plasma-smart-video-wallpaper-reborn/releases/latest" 2>/dev/null \
            | grep "browser_download_url.*\.tar\.gz" \
            | cut -d '"' -f 4 \
            | head -n 1 || true)"
    fi
    if [[ -z "$DOWNLOAD_URL" ]]; then
        DOWNLOAD_URL="$PLUGIN_FALLBACK_URL"
    fi

    echo "--> Downloading plugin package from $DOWNLOAD_URL..."
    PKG_ARCHIVE="$TMP_DIR/plugin.tar.gz"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$DOWNLOAD_URL" -o "$PKG_ARCHIVE"
    else
        wget -q "$DOWNLOAD_URL" -O "$PKG_ARCHIVE"
    fi

    echo "--> Extracting plugin..."
    mkdir -p "$TMP_DIR/extracted"
    tar -xzf "$PKG_ARCHIVE" -C "$TMP_DIR/extracted"

    # Remove any existing broken/partial installation
    rm -rf "$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID" 2>/dev/null || true

    echo "--> Installing plugin via $KPACKAGE_BIN..."
    "$KPACKAGE_BIN" -t Plasma/Wallpaper -i "$TMP_DIR/extracted"

    # Ensure executable permissions on helper scripts if present
    HELPER_SCRIPT="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID/contents/ui/tools/gdbus_get_signal.sh"
    if [[ -f "$HELPER_SCRIPT" ]]; then
        chmod +x "$HELPER_SCRIPT"
    fi
    echo "--> Plugin successfully installed."
fi

# Step 4: Configure wallpaper on monitor(s)
echo ""
if [[ "$ALL_MONITORS" == true ]]; then
    echo "==> [4/4] Setting video wallpapers on all connected monitors..."
else
    echo "==> [4/4] Setting video wallpapers on the primary monitor..."
fi

python3 - <<PYEOF
import glob
import json
import os
import subprocess
import sys

target_dir = os.path.expanduser("$TARGET_DIR")
qdbus_bin = "$QDBUS_BIN"
plugin_id = "$PLUGIN_ID"
all_monitors = "$ALL_MONITORS" == "true"

# Gather all supported video files
extensions = ("*.mp4", "*.webm", "*.mkv", "*.mov", "*.avi")
video_paths = []
for ext in extensions:
    video_paths.extend(glob.glob(os.path.join(target_dir, ext)))

video_paths.sort()
if not video_paths:
    print(f"Error: No videos found in {target_dir}", file=sys.stderr)
    sys.exit(1)

# Build VideoUrls data array matching Smart Video Wallpaper Reborn schema
video_entries = []
for path in video_paths:
    video_entries.append({
        "filename": f"file://{os.path.abspath(path)}",
        "enabled": True,
        "duration": 0,
        "customDuration": 0,
        "playbackRate": 0.0,
        "alternativePlaybackRate": 0.0,
        "loop": False,
        "dayNightPhase": 0
    })

video_urls_json_str = json.dumps(json.dumps(video_entries))

js_condition = "true" if all_monitors else "d.screen === 0"

js_script = f"""
let allDesktops = desktops();
let configuredCount = 0;
for (let i = 0; i < allDesktops.length; i++) {{
    let d = allDesktops[i];
    if ({js_condition}) {{
        d.wallpaperPlugin = "{plugin_id}";
        d.currentConfigGroup = ["Wallpaper", "{plugin_id}", "General"];
        d.writeConfig("VideoUrls", {video_urls_json_str});
        d.writeConfig("PauseMode", 3); // 3: never pause video on maximized/fullscreen windows
        d.writeConfig("ChangeWallpaperMode", 2); // 2: on a timer
        d.writeConfig("CrossfadeEnabled", true); // enable smooth crossfade transition
        configuredCount++;
    }}
}}
print("Configured " + configuredCount + " desktop(s).");
"""

res = subprocess.run([qdbus_bin, "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", js_script], capture_output=True, text=True)

if res.returncode != 0:
    print(f"Error executing Plasma script: {res.stderr.strip()}", file=sys.stderr)
    sys.exit(res.returncode)

output = res.stdout.strip()
print(f"--> {output}")
PYEOF

if [[ "$ALL_MONITORS" == true ]]; then
    MONITOR_DESC="all connected monitors"
else
    MONITOR_DESC="your primary monitor"
fi

echo ""
echo "=================================================="
echo "==> All done! Smart Video Wallpaper Reborn is now"
echo "    active on $MONITOR_DESC with videos from:"
echo "    $TARGET_DIR"
echo "=================================================="
