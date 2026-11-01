# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0-beta] - 2026-11-01

First public beta.

### Added
- RTSS OverlayEditor layout with GPU, CPU and RAM sensors, frametime graph, FPS and 1% Low.
- Frame generation aware FPS: shows `displayed (real)` only when frame generation is detected.
- Frametime graph based on frames that actually reached the screen (PresentMon `msBetweenDisplayChange`), smooth scrolling with a 3 s display delay.
- Presets for 1080p, 1440p and 4K, plus debug variants for bug reports.
- `install.cmd` / `uninstall.cmd`: one-click install with resolution detection, OSD hotkey (Ctrl+Shift+F10 by default) and backup/restore of RTSS settings. All three presets are installed, so the resolution can be changed later in RTSS or by running the installer again.
- Generator script (`tools/make_overlay.py`) - the single source of truth for all layouts.

### Known limitations
- Tested on one PC (RTX 5070 Ti + Ryzen AI 9 HX 370, RTSS 7.3.5) and mainly in GTA V Enhanced.
- Counter-Strike 2 and games with strict anti-cheat may block the RTSS overlay.
