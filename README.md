<img width="800" height="578" alt="image" src="https://github.com/user-attachments/assets/93a8de35-9f9b-4311-af5d-b7e40182fab6" /># kute

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

- **Linux**: any distro with glibc 2.35+ (Ubuntu 22.04+, Fedora 36+, Arch). AppImage is self-contained — no dependencies to install.
- **Windows**: Windows 10 or newer. The `.exe` is a portable binary.
  
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
