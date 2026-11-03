# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0-beta] - 2026-11-03

### Added
- **Russian version of the overlay**, chosen in the installer. It shares one layout, one set of sensors and one design with the English version (both come from the same generator). Russian words are drawn as images, because RTSS cannot draw Cyrillic text (see [how it works](docs/how-it-works.md#languages)).
- Hardware names (GPU, CPU, RAM size) now have their own line instead of sharing a line with the header.
- Troubleshooting section in the README, including the "RivaTuner64.sys" error caused by installing the old RivaTuner v2.24 instead of RTSS.

### Changed
- The installer window no longer lingers: the launcher window closes right after the administrator prompt, and the install window closes by itself after a few seconds.
- Installing over a previous version simply replaces the files.
- `tools/make_overlay.py --all` also writes the Russian `*_ru.template` files; new `tools/TextSprites.ps1` turns them into finished overlays.

### Fixed
- Install on a fresh RTSS failed with "file HotkeyHandler.cfg not found". Missing RTSS settings files are now created (and removed again by `uninstall.cmd`).

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
