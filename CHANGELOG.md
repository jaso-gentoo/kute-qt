## v1.5-rc1 — 2026-11-13

### Added
- Hide header toggle in Settings → Appearance.
- Hide navigation bar toggle in Settings → Appearance.

### Changed
- Play/pause overlay icons on track hover in library and playlist views are now filled.
- Play/pause icon in the "NOW PLAYING" chip is now filled.

### Fixed
- Sort menu popup allowed clicks to pass through to the track list.
- Edit mode could be enabled from Browse while the sort field was not custom, and stayed enabled after returning to Home.

## v1.5-rc0 — 2026-11-12

### Added
- InfoPanel, NavBar position choice in settings.
- Visualizer toggle switch in settings.
- Cover shapes in NowPlaying

### Changed
- Discord RPC button was replaced with switch in settings.
- Sort options panel was replaced with hover panel.
- Navigation bar now contains hover button which shows additional options.
- Some UI things...

### Fixed
- Fixed an issue where the last item in a list would get stuck underneath the list.
- The drop indicator did not move along with the list scrolling.

## v1.4-rc0 — 2026-11-09
No changelog entry for v1.4-rc0.

## v1.3-rc2 — 2026-10-08

### Fixed
- The track was not hidden after exiting the Artists / Album tab on Windows
- The visualizer didn't work on Windows
- Renderer selection didn't work correctly on restart stage

## v1.3-rc1 — 2026-10-08

### Added
- Lyrics button (`Ctrl+D`) in Now Playing panel (`Ctrl+Q`)
- Audio visualizer over the volume slider

### Changed
- Browse tab options reordered: Playlists / Albums / Artists
- Disabled mipmap filtering on thumbnails
- Playlist delete button was redesigned

### Fixed
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
