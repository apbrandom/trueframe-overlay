# TrueFrame Overlay

**See your *real* FPS when frame generation is on.** An overlay for RivaTuner Statistics Server (RTSS) with displayed and real FPS, 1% Low, a smooth frametime graph and the GPU, CPU and RAM sensors that matter.

[![Release](https://img.shields.io/github/v/release/apbrandom/trueframe-overlay?include_prereleases&label=release)](https://github.com/apbrandom/trueframe-overlay/releases)
[![License: MIT](https://img.shields.io/github/license/apbrandom/trueframe-overlay)](LICENSE)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)

**English** · [Русский](README.ru.md)

<img src="docs/screenshot.png" alt="TrueFrame Overlay screenshot" width="320">

## Install

You need Windows 10 or 11. Takes about two minutes.

1. **Install RTSS** from the [official Guru3D page](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/).
   You need *RivaTuner **Statistics Server***, not the old *RivaTuner v2.24*. Already have MSI Afterburner? RTSS usually comes with it, so skip this step.
2. **Download TrueFrame** and unzip it:

   <!-- update the version in this link on every release -->
   [![Download TrueFrame v0.2.0-beta](https://img.shields.io/badge/Download-TrueFrame_v0.2.0--beta-2ea44f?style=for-the-badge)](https://github.com/apbrandom/trueframe-overlay/archive/refs/tags/v0.2.0-beta.zip)

3. **Run `install.cmd`** in the unzipped folder and click **Yes** when Windows asks for administrator rights.
   If Windows warns about a downloaded file, click *Run* (or *More info → Run anyway*).
4. **Answer two questions:** your game resolution (press Enter to accept the detected one) and the overlay language.
5. **Start a game.** The overlay appears by itself. **Ctrl+Shift+F10** shows or hides it.

To remove TrueFrame, run **`uninstall.cmd`**. It restores your previous RTSS settings.

Something went wrong? See [Troubleshooting](#troubleshooting).

## Why

With DLSS Frame Generation and similar technologies, an FPS counter shows the *generated* frame rate: "120 FPS" can mean only 60 frames rendered by the game, and input latency follows the real number.

TrueFrame detects frame generation automatically and shows both numbers: **`120 (60)`** = displayed (real). Without frame generation you see one number.

## Features

- **Displayed and real FPS.** The real value in brackets appears only while frame generation is detected.
- **1% Low** FPS.
- **Frametime graph** of the frames that actually reached the screen, with average and worst frame time. Scrolls smoothly.
- **GPU:** load, temperature, clock, power, VRAM. **CPU:** load, busiest core, temperature, clock, power. **RAM:** used and load. Hardware names are filled in for every PC.
- **Yellow and red warnings** for high temperatures and loads.
- **Presets for 1080p, 1440p and 4K** with the same proportions on every screen.
- **English or Russian**, chosen in the installer.
- **Only RTSS is needed.** No HWiNFO, no MSI Afterburner. Your previous RTSS settings are backed up.

## Change resolution or language

Run `install.cmd` again and pick another resolution or language. It takes about 10 seconds.

All presets are already in RTSS, so you can also switch there: *Setup → Plugins → OverlayEditor → Setup → Layouts → Load*, then pick a file in `RTSS\Plugins\Client\Overlays`: `TrueFrame_1080p.ovl`, `TrueFrame_1440p.ovl` or `TrueFrame_4k.ovl` for English, the same name with `_ru` for Russian.

The overlay does not resize itself: RTSS layouts use fixed pixel sizes. If you play different games at different resolutions, switch the preset with the game.

## Troubleshooting

- **"Unable to load driver RivaTuner64.sys" or a window titled "RivaTuner v2.24".** That is the wrong program: an old 2008 graphics card tuner with a similar name. Uninstall it, restart Windows and install RTSS ([step 1](#install)). Do not disable driver signature checks, it is not needed.
- **"RTSS was not found".** Install RTSS first. If it is installed in a custom folder, run `.\install.ps1 -RtssPath "D:\RTSS"` in PowerShell from the TrueFrame folder.
- **"MSI Afterburner is running".** Close Afterburner (check the system tray too) and run `install.cmd` again.
- **You chose Russian but got English.** The installer could not draw the Russian words and fell back to English. Please [open an issue](https://github.com/apbrandom/trueframe-overlay/issues/new/choose) with a screenshot of the installer window.
- **No overlay in the game.** Press **Ctrl+Shift+F10**, check that RTSS is running (tray icon), and read the anti-cheat note below.

## Known limitations

- **Frame generation detection needs about 10 seconds** after you switch it on or off: it analyses the last 1024 frames.
- **The graph and the avg/max numbers are 3 seconds behind** by design. PresentMon, which provides the frame data, reports frames in batches with a variable lag; a fixed delay is what makes the graph scroll smoothly. The big FPS number is live.
- **Counter-Strike 2 and games with strict anti-cheat** may block the RTSS overlay. According to the RTSS documentation, CS2 also does not support RTSS's native frame rate counter, so the FPS number may stay empty there.
- **Beta, tested on one PC** (RTX 5070 Ti, Ryzen AI 9 HX 370). AMD and Intel graphics should work but are untested. The frame generation algorithm is validated on simulated frame data for 2x to 4x. Reports from other hardware and games are very welcome.

## Reporting a problem

Open an [issue](https://github.com/apbrandom/trueframe-overlay/issues/new/choose). The fastest way to get help: load the **debug** layout for your resolution (`overlays/TrueFrame_<resolution>_debug.ovl`), play for 30 seconds and attach a screenshot. Its extra lines show what the overlay has detected. A short *game compatibility report* is just as useful.

## More

- [How it works](docs/how-it-works.md): frame generation detection, 1% Low, the frametime graph, why Russian words are drawn as images.
- [Changelog](CHANGELOG.md)

<details>
<summary>What exactly does the installer change?</summary>

- Copies the English layouts to `RTSS\Plugins\Client\Overlays\TrueFrame_*.ovl`, draws the Russian ones there (`TrueFrame_*_ru.ovl` plus a small `TrueFrame_*_ru.png` with the Russian words) and makes the one you chose the active OverlayEditor layout.
- Creates RTSS settings files that do not exist yet on a fresh RTSS install.
- Enables the OverlayEditor and HotkeyHandler plugins.
- Sets the OSD show/hide hotkey. If you already have one, it asks before replacing it.
- Saves a copy of every changed RTSS file as `*.overlay-backup` (first install only), then restarts RTSS.

Advanced options (run in PowerShell from the TrueFrame folder):

| Command | What it does |
|---|---|
| `.\install.ps1 -DryRun` | Shows what would be changed, changes nothing |
| `.\install.ps1 -Resolution 1440` | Skips the resolution question (`1080`, `1440`, `2160`) |
| `.\install.ps1 -Language ru` | Skips the language question (`en`, `ru`) |
| `.\install.ps1 -Hotkey "Ctrl+Alt+O"` | Another hotkey. `keep` leaves yours untouched, `none` clears it |
| `.\install.ps1 -RtssPath "D:\RTSS"` | RTSS installed in a non-standard folder |

**Manual install (English only):** in RTSS open *Setup → Plugins → OverlayEditor → Setup → Layouts → Load* and pick a file from the `overlays` folder. The Russian overlay needs the installer, because its words are drawn on your PC.

</details>

<details>
<summary>Building from source</summary>

All layouts are generated by one script, so the presets and both languages never drift apart (the words live in one table inside the script):

```
python tools/make_overlay.py --all overlays
```

This writes the English `.ovl` files and the Russian `*_ru.template` files. The installer turns a template into a finished overlay with [`tools/TextSprites.ps1`](tools/TextSprites.ps1).

</details>

## Credits

- [RivaTuner Statistics Server](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/) by Alexey Nicolaychuk (Unwinder). TrueFrame is a layout for its OverlayEditor plugin and contains no RTSS code or files.
- [PresentMon](https://github.com/GameTechDev/PresentMon) by Intel, shipped with RTSS, provides the frame timing data.
- This project is not affiliated with Guru3D, MSI, NVIDIA or Intel.

## About

Made by Vadim ([@apbrandom](https://github.com/apbrandom)). Developed with the help of an AI assistant (Claude by Anthropic); the problem definition, design decisions and in-game testing are mine.

## License

[MIT](LICENSE)
