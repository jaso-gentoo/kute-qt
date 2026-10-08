# kute

Music player for Linux and Windows, written in C++/Qt6/QML.

## Screenshots

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/12495107-bec8-4249-952a-5ae32b46f8e4" width="260"/></td>
    <td><img src="https://github.com/user-attachments/assets/02ebb28d-c7cb-4ec9-bec2-8ef548cf1455" width="260"/></td>
    <td><img src="https://github.com/user-attachments/assets/37e5f3c8-f580-40f8-a7f0-dcc7f9932abf" width="260"/></td>
  </tr>
</table>

## System requirements

- **Linux**: glibc-based distros with glibc 2.35+ (Ubuntu 22.04+, Fedora 36+, Arch). Musl-based (Alpine, Void) not supported. No dependencies to install.
- **Windows**: Windows 10 or newer. The `.exe` is a portable binary.

## Keyboard shortcuts

### Playback

- `Space` - Play / pause
- `Up arrow ` / `Down arrow` - Previous track / Next track
- `Left arrow` / `Right arrow` - 
- `Ctrl` + `W` - Like / unlike the currently playing track
- `Middle-click` On a track - like / unlike

### Navigation

- `Ctrl` + `O` - Open music folder dialog
- `Ctrl` + `1` - **Home page**
- `Ctrl` + `2` - Browse (Artists / Albums / Playlists)
- `Ctrl` + `F` - Toggle search bar
- `Ctrl` + `Q` - Toggle **Now Playing** side panel
- `Ctrl` + `E` - Toggle **Settings**
- `Ctrl` + `D` - Open **Lyrics** for the current track
- `Ctrl` + `X` - Open **Metadata editor** for the current track
- `Ctrl` + `Shift` + `E` - Toggle edit mode

### Inside windows

> Only active while the **Settings** / **Lyrics** / **Metadata editor** window is open:

- `Ctrl` + `S` - Save current edits (in the **Metadata editor** window)

### Context-sensitive

- `Esc` - To close **Settings** / **Lyrics** / **Metadata editor** window
- `Esc` - To close and clear search bar
- `Esc` - To return to **Browse page** from **Artists** / **Albums** / **Playlists** tabs

### Drag interactions

- Drag a track - **Home page** *(edit mode)* to reorder the library (only custom sorting style)
- Drag a playlist - **Browse page** -> **Playlists** *(edit mode)*. to reorder the playlist list
- Drag a track inside a playlist - **Playlist** *(edit mode)*. to reorder tracks in that playlist
- Click a playlist name - **Browse page** -> **Playlists** *(edit mode)* to Rename

## Configuration and cache

### Settings

- QSettings file — `~/.config/kute/kute.conf`

### Global

- Lyrics offsets — `~/.config/kute/offsets.json`

### Per-folder

kute stores playlists, liked tracks and custom sort order **per music folder**. Each folder gets its own set of files, named after a SHA-1 hash of the folder's absolute path — so switching between two libraries keeps their data separate.

- Playlists — `~/.config/kute/playlists/<sha1>.json`
- Liked tracks — `~/.config/kute/liked/<sha1>.json`
- Custom track order — `~/.config/kute/playlist_order/<sha1>.json`

### Other

- LRC files — `~/.config/kute/txts/`
- Cover / thumbnail caches — `~/.cache/kute/`
- Playlist cover thumbnails — `~/.cache/kute/kute/playlist_covers/`

### Matugen

Put a JSON file at `~/.config/kute/matugen/kute.json`. The file must exist before Matugen can be enabled in Settings — otherwise the toggle stays disabled.

Keys: `background`, `surface`, `onBackground`, `onSurface`, `primary`, `secondary`, `surfaceVariant`, `outline`.

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

### Building from source
- Requires `Qt 6.5+`, `TagLib`, `CMake 3.20+`, `C++17 compiler`.

- Build
```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

- Start
```bash
./build/kute
```
