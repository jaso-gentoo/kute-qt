## v1.3-rc1 — 2026-10-08

### Added
- Lyrics button(`Ctrl+D`) in Now Playing panel (`Ctrl+Q`)
- Audio visualizer over the volume slider

### Changed
- Browse tab options reordered: Playlists / Albums / Artists
- Disabled mipmap filtering on thumbnails

### Fixed
- Playlist delete button was not redesigned
- Playlist cover images were stored in cache and lost on cache cleanup

## v1.3-rc0 — 2026-10-08

### Added
- Renderer backend selection in settings (OpenGL / Vulkan on Linux, Vulkan / D3D11 on Windows)

### Changed
- Performance improvements across library sort, track model, playlist handling
- Redesigned track delete and add-to-playlist buttons

### Fixed
- Track/playlist removal animation was not shown for the last item in the list
- Track metadata was not saving on Windows 11
- Renderer indicator was stuck on "initializing" on Windows
- Renderer button in settings required two clicks

## v1.2-rc0 — 2026-10-06

### Added
- Playlists support

### Fixed
- A lot of things...
