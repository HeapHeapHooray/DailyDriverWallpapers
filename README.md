# DailyDriverWallpapers
### The (live) wallpapers I use on my daily driver desktop.

An automated installer script is included to download, install the required KDE Plasma wallpaper plugin, and configure the video wallpapers on your **primary monitor**.

---

## What the installer does

1. **Installs the plugin**: Downloads and installs the latest [Smart Video Wallpaper Reborn](https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn) plugin for KDE Plasma via `kpackagetool6`.
2. **Targets the primary monitor only**: Applies the live wallpaper plugin exclusively to your main display, leaving secondary displays unaffected.
3. **Populates playlist**: Automatically indexes all video wallpapers in the repository (`.mp4`, `.webm`, `.mkv`, etc.).
4. **Optimized playback settings**:
   - **On a timer**: Videos cycle smoothly on a timer instead of basic slideshow loop.
   - **Crossfade transitions**: Seamlessly crossfades between wallpapers.
   - **Unpaused playback**: Configures `PauseMode` so videos do not pause when windows are active, maximized, or in fullscreen.

---

## Installation

### Option 1: Quick Install (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/HeapHeapHooray/DailyDriverWallpapers/refs/heads/main/install.sh | bash -s
```

### Option 2: Clone and Run Locally

```bash
git clone https://github.com/HeapHeapHooray/DailyDriverWallpapers.git ~/DailyDriverWallpapers
cd ~/DailyDriverWallpapers
./install.sh
```

---

## Usage & Options

```text
Usage: install.sh [OPTIONS]

Options:
  -d, --dir <DIR>    Custom directory for wallpapers (default: ~/DailyDriverWallpapers)
  -h, --help         Show this help message
```
