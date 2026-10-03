# kute

Music player for Linux, written in C++/Qt6/QML.

## Features

- Folder-based library, FLAC/MP3/OGG/OPUS/WAV/M4A/AAC
- Artists / Playlist / Now Playing
- Search, sort, reorder
- Metadata editor (ID3v2 / FLAC Vorbis)
- Lyrics (plain + LRC with live sync), lrclib.net download
- Discord Rich Presence
- MPRIS (`playerctl`, waybar, etc.)
- Light / dark theme, Matugen integration

## Dependencies

- Qt 6.5+ (Core, Gui, Quick, QuickControls2, Multimedia, Network, DBus)
- TagLib
- CMake 3.20+
- C++17 compiler

### Arch
```bash
sudo pacman -S qt6-base qt6-multimedia qt6-declarative taglib cmake ninja
```

### Gentoo
```bash
sudo emerge dev-qt/qtbase dev-qt/qtmultimedia dev-qt/qtdeclarative media-libs/taglib dev-build/cmake dev-build/ninja
```

### Debian/Ubuntu
```bash
sudo apt install qt6-base-dev qt6-multimedia-dev qt6-declarative-dev libtag1-dev cmake ninja-build
```

## Build

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/kute
```

## Install

```bash
sudo cmake --install build --prefix /usr/local
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+O` | Open folder |
| `Ctrl+F` | Search in current list |
| `Ctrl+E` | Settings |
| `Ctrl+X` | Edit track metadata |
| `Ctrl+D` | Lyrics |
| `Ctrl+Q` | Toggle Now Playing |
| `Ctrl+1` / `Ctrl+2` | Home / Artists |
| `←` / `→` | Switch sub-tab in modal |
| `↑` / `↓` | Previous / next track |
| `Space` | Play / pause |
| `Ctrl+Shift+E` | Reorder mode |
