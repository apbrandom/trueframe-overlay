# TrueFrame Overlay

**An overlay for RivaTuner Statistics Server (RTSS) that shows your *real* FPS when frame generation is on, plus a smooth frametime graph and the sensors that matter. One-click install, nothing else needed.**

[Русская версия](README.ru.md) · [How it works](docs/how-it-works.md) · [Changelog](CHANGELOG.md)

<img src="docs/screenshot.png" alt="TrueFrame Overlay screenshot" width="320">

## Why

With DLSS Frame Generation and similar technologies, a normal FPS counter shows the *generated* frame rate. "120 FPS" on screen can mean only 60 frames actually rendered by the game, and input latency follows the real number.

TrueFrame detects frame generation automatically and shows both numbers: **`120 (60)`** = displayed (real). Without frame generation you simply see one number.

## Features

- **Displayed and real FPS.** The real value in brackets appears only while frame generation is detected.
- **1% Low** FPS.
- **Frametime graph** of the frames that actually reached the screen, with average and worst frame time. Scrolls smoothly.
- **GPU:** load, temperature, clock, power, VRAM. **CPU:** load, busiest core, temperature, clock, power. **RAM:** used and load.
- Hardware names are filled in automatically for every PC, each on its own line.
- **English or Russian.** The installer asks which one you want; both look identical, only the words differ.
- Yellow and red warnings for high temperatures and loads.
- Presets for **1080p, 1440p and 4K**, the same proportions on every screen.
- **Only RTSS is required.** No HWiNFO, no MSI Afterburner.
- One-click install and uninstall, your previous RTSS settings are backed up.

## Requirements

- Windows 10 or 11.
- [RivaTuner Statistics Server](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/) 7.3 or newer (tested with 7.3.5). RTSS is not included in this project, please download it from the official Guru3D page.
- Careful: you need **RTSS (RivaTuner *Statistics Server*)**, or MSI Afterburner, which bundles it. The old program called just "RivaTuner v2.24" is a different 2008 tool and will not work (see [Troubleshooting](#troubleshooting)).

## Install

1. Install RTSS.
2. Download the latest release from the [Releases](https://github.com/apbrandom/trueframe-overlay/releases) page and unzip it.
3. Double-click **`install.cmd`** and allow the administrator prompt (RTSS lives in Program Files).
4. Choose your game resolution (your screen resolution is detected and offered by default) and the overlay language.
5. Start a game. Show or hide the overlay with **Ctrl+Shift+F10**.

To remove it, double-click **`uninstall.cmd`**. It restores the RTSS settings saved before the first install.

## Changing the resolution or language

The overlay text size is tuned for each resolution, so use the matching preset. The installer puts **all three presets in both languages** into RTSS, so you can switch at any time:

- **Run `install.cmd` again** and pick the other resolution or language (about 10 seconds), or
- **In RTSS:** open *Setup → Plugins → OverlayEditor → Setup*, then *Layouts → Load* and select `TrueFrame_1080p.ovl`, `TrueFrame_1440p.ovl` or `TrueFrame_4k.ovl` (English) or the same name with `_ru` (Russian) from `RTSS\Plugins\Client\Overlays`.

The overlay does not scale itself to the game's resolution: RTSS layouts use fixed pixel sizes, so the three presets are tuned by hand. If you play different games at different resolutions, switch the preset when you switch the game.

<details>
<summary>What exactly does the installer change?</summary>

- Copies the English layouts to `RTSS\Plugins\Client\Overlays\TrueFrame_*.ovl`, draws the Russian ones there (`TrueFrame_*_ru.ovl` plus a small `TrueFrame_*_ru.png` with the Russian words, see [Russian](#russian-version)) and makes the one you chose the active OverlayEditor layout.
- Creates RTSS settings files that do not exist yet on a fresh RTSS install.
- Enables the OverlayEditor and HotkeyHandler plugins.
- Sets the OSD show/hide hotkey. If you already have one, it asks before replacing it.
- Saves a copy of every changed RTSS file as `*.overlay-backup` (first install only), then restarts RTSS.

Advanced options (run in PowerShell from the project folder):

| Command | What it does |
|---|---|
| `.\install.ps1 -DryRun` | Shows what would be changed, changes nothing |
| `.\install.ps1 -Resolution 1440` | Skips the resolution question (`1080`, `1440`, `2160`) |
| `.\install.ps1 -Language ru` | Skips the language question (`en`, `ru`) |
| `.\install.ps1 -Hotkey "Ctrl+Alt+O"` | Another hotkey. `keep` leaves yours untouched, `none` clears it |
| `.\install.ps1 -RtssPath "D:\RTSS"` | RTSS installed in a non-standard folder |

</details>

**Manual install (English only):** in RTSS open *Setup → Plugins → OverlayEditor → Setup*, then *Layouts → Load* and pick a file from the `overlays` folder. The Russian overlay needs the installer, because its images are drawn on your PC.

## Russian version

RTSS can only draw plain ASCII text with its built-in font: Cyrillic letters come out as squares, whatever the Windows language or region settings are. So in the Russian overlay each word (Видеокарта, Загрузка, Температура ...) is a small image. The installer draws these images on your PC with the same Windows text renderer RTSS uses, so they match the rest of the overlay. Numbers and units (MHz, W, GB, ms, FPS) are still normal RTSS text, so colors and warnings work as usual. If drawing the images fails for any reason, the installer falls back to English.

## Troubleshooting

- **"Unable to load driver RivaTuner64.sys" or a window titled "RivaTuner v2.24".** That is the wrong program: the 2008 *RivaTuner* graphics card tuner. TrueFrame needs **RivaTuner Statistics Server (RTSS)**, a separate program with a similar name. Uninstall RivaTuner v2.24, restart Windows, and install RTSS from the [Guru3D RTSS page](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/) (the installer window must say "RivaTuner Statistics Server 7.3.x"). Do not disable driver signature checks; no driver tricks are needed.
- **The installer says RTSS was not found.** RTSS is not installed or lives in a custom folder: use `-RtssPath "D:\RTSS"`.
- **MSI Afterburner is running.** Close it first, the installer restarts RTSS and Afterburner hosts it.
- **No overlay in the game.** Press **Ctrl+Shift+F10** (it may be hidden), check that RTSS is running (tray icon), and see the limitations below about anti-cheat.

## Known limitations

- **Frame generation detection needs about 10 seconds** after you switch it on or off: it analyses the last 1024 frames.
- **The graph and the avg/max numbers are 3 seconds behind** by design. PresentMon, which provides the frame data, reports frames in batches with a variable lag; showing them with a fixed delay is what makes the graph scroll smoothly. The big FPS number is live.
- **Counter-Strike 2 and games with strict anti-cheat** may block the RTSS overlay. According to the RTSS documentation, CS2 also does not support RTSS's native frame rate counter, so the FPS number may stay empty there.
- This is a beta tested on one PC (RTX 5070 Ti, Ryzen AI 9 HX 370). The current frame generation algorithm is validated on simulated frame data for 2x to 4x. Reports from other hardware and games are very welcome.

## Reporting a problem

Open an [issue](https://github.com/apbrandom/trueframe-overlay/issues/new/choose). The fastest way to get help: load the **debug** layout for your resolution (`overlays/TrueFrame_<resolution>_debug.ovl`), play for 30 seconds and attach a screenshot. Its extra lines show what the overlay has detected. A short *game compatibility report* is just as useful.

## Building from source

All layouts are generated by one script, so the presets and both languages never drift apart (the words live in one table inside the script):

```
python tools/make_overlay.py --all overlays
```

This writes the English `.ovl` files and the Russian `*_ru.template` files. The installer turns a template into a finished overlay with [`tools/TextSprites.ps1`](tools/TextSprites.ps1).

## Credits

- [RivaTuner Statistics Server](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/) by Alexey Nicolaychuk (Unwinder). TrueFrame is a layout for its OverlayEditor plugin and contains no RTSS code or files.
- [PresentMon](https://github.com/GameTechDev/PresentMon) by Intel, shipped with RTSS, provides the frame timing data.
- This project is not affiliated with Guru3D, MSI, NVIDIA or Intel.

## About

Made by Vadim ([@apbrandom](https://github.com/apbrandom)). Developed with the help of an AI assistant (Claude by Anthropic); the problem definition, design decisions and in-game testing are mine.

## License

[MIT](LICENSE)
