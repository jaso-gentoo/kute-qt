<img width="821" height="517" alt="image" src="https://github.com/user-attachments/assets/871c2d11-5bf0-433a-97f5-ab61232e89fc" />
# kute

Music player for Linux and Windows, written in C++/Qt6/QML.

## Screenshots

<img width="821" height="517" alt="image" src="https://github.com/user-attachments/assets/e7605abc-05e9-4dda-a38b-267b45d70348" />
<img width="824" height="520" alt="image" src="https://github.com/user-attachments/assets/23c0de54-c432-4883-a273-9e3145d645ac" />
<img width="819" height="586" alt="image" src="https://github.com/user-attachments/assets/c7be5e50-3d0a-4846-8b76-9bca033266bb" />

## Dependencies

- Qt 6.5+ — Core, Gui, Quick, QuickControls2, Multimedia, Network, DBus (Linux)
- TagLib
- CMake 3.20+
- pkg-config (Linux)
- C++17 compiler

### Arch
sudo pacman -S qt6-base qt6-multimedia qt6-declarative taglib cmake ninja pkgconf

### Gentoo
sudo emerge dev-qt/qtbase dev-qt/qtmultimedia dev-qt/qtdeclarative media-libs/taglib dev-build/cmake dev-build/ninja dev-util/pkgconf

### Debian/Ubuntu
sudo apt install qt6-base-dev qt6-multimedia-dev qt6-declarative-dev libtag1-dev cmake ninja-build pkg-config

## Build

```bash
cd ~/kute-qt
      cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      cmake --build build
      ./build/kute
```

## Install

sudo cmake --install build --prefix /usr/local

## Keyboard shortcuts

### Playback

- Space — Play / pause
- Up arrow — Previous track
- Down arrow — Next track
- Ctrl+W — Like / unlike the currently playing track
- Middle-click on a track — Like / unlike that specific track

Space, Up, Down are ignored while a text input has focus (so you can type in search / rename / metadata fields without triggering playback).

### Navigation

- Ctrl+O — Open music folder dialog
- Ctrl+1 — Home (library / current filtered list)
- Ctrl+2 — Browse (Artists / Albums / Playlists)
- Ctrl+F — Toggle floating search bar (searches current list)
- Ctrl+Q — Toggle Now Playing side panel
- Ctrl+E — Toggle Settings modal
- Ctrl+D — Open Lyrics for the current track
- Ctrl+X — Open metadata editor for the current track
- Ctrl+Shift+E — Toggle reorder / edit mode

### Inside modals

Only active while the Settings / Track / Lyrics modal is open:

- Left arrow / Right arrow — Previous / next sub-tab. In Track: Metadata <-> Text. In Lyrics: TXT <-> LRC
- Ctrl+S — Save current edits (in the Track modal)

### Context-sensitive

- Esc — If a modal is open, close it
- Esc — Else if the floating search is open, close it and clear the search text
- Esc — Else if an artist / album filter is applied, clear it and return to Browse

### Drag interactions

- Drag a track — Home (edit mode). Reorders the library (custom sorting style)
- Drag a playlist — Browse -> Playlists (edit mode). Reorders the playlist list
- Drag a track inside a playlist — Playlist detail (edit mode). Reorders tracks in that playlist
- Click a playlist name — Browse -> Playlists (edit mode). Rename
- Middle-click on a track — Home. Like / unlike

## Configuration and cache

- Settings (QSettings) — ~/.config/kute/
- LRC files — ~/.config/kute/txts/
- Liked tracks — ~/.config/kute/liked.json
- Playlists — ~/.config/kute/playlists.json
- Custom track order — ~/.config/kute/playlist_order.json
- Lyrics offsets — ~/.config/kute/offsets.json
- Cover / thumbnail caches — ~/.cache/kute/
- Playlist cover thumbnails — ~/.cache/kute/kute/playlist_covers/

### Matugen

Put a palette JSON at ~/.config/kute/matugen/kute.json (keys: background, surface, onBackground, onSurface, primary, secondary, surfaceVariant, outline). Enable Matugen in Settings — colors will follow the file and reload automatically when it changes.

`kute.json`
```json
{
  "primary": "{{colors.primary.default.hex}}",
  "secondary": "{{colors.tertiary.default.hex}}",
  "background": "{{colors.background.default.hex}}",
  "surface": "{{colors.surface_container.default.hex}}",
  "surfaceVariant": "{{colors.surface_container_high.default.hex}}",
  "outline": "{{colors.outline.default.hex}}",
  "onBackground": "{{colors.on_background.default.hex}}",
  "onSurface": "{{colors.on_surface_variant.default.hex}}"
}
```
