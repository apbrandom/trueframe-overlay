<#
.SYNOPSIS
  Installs TrueFrame Overlay into RivaTuner Statistics Server (RTSS).
  https://github.com/apbrandom/trueframe-overlay

.EXAMPLE
  .\install.ps1                      # interactive: detects the resolution, asks you to confirm
  .\install.ps1 -Resolution 1440     # skip the question (1080 | 1440 | 2160)
  .\install.ps1 -Language ru         # skip the language question (en | ru); Russian words are drawn as images
  .\install.ps1 -Hotkey keep         # do not touch the OSD toggle hotkey
  .\install.ps1 -DryRun              # show what would be changed, change nothing
  .\install.ps1 -Uninstall           # restore the RTSS settings saved before the install
#>
[CmdletBinding()]
param(
    [ValidateSet('', '1080', '1440', '2160')][string]$Resolution = '',
    [ValidateSet('auto', 'en', 'ru')][string]$Language = 'auto',
    [string]$Hotkey = 'Ctrl+Shift+F10',     # 'keep' = leave current, 'none' = clear
    [string]$RtssPath = '',
    [switch]$NoRestart,
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$NoPause,
    [switch]$Elevated
)
$ErrorActionPreference = 'Stop'
$OverlayName = 'TrueFrame'
$Latin1 = [Text.Encoding]::GetEncoding(28591)    # byte-preserving read/write (RTSS configs may contain ANSI paths)

# ---------- elevation (RTSS lives in Program Files) ----------
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not $DryRun -and -not (Test-Admin)) {
    Write-Host 'Administrator rights are required to edit RTSS settings. Requesting elevation...'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath), '-Elevated')
    foreach ($k in $PSBoundParameters.Keys) {
        if ($k -eq 'Elevated') { continue }
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) { if ($v.IsPresent) { $a += "-$k" } } else { $a += "-$k"; $a += ('"{0}"' -f $v) }
    }
    # No -Wait: this launcher window closes as soon as UAC is accepted; the elevated window does the work.
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $a }
    catch { Write-Host 'Elevation was cancelled. Nothing was changed.' -ForegroundColor Red; exit 1 }
    exit 0
}

# ---------- helpers ----------
function Find-Rtss {
    if ($RtssPath) { return $RtssPath }
    foreach ($p in @("${env:ProgramFiles(x86)}\RivaTuner Statistics Server", "$env:ProgramFiles\RivaTuner Statistics Server")) {
        if (Test-Path (Join-Path $p 'RTSS.exe')) { return $p }
    }
    $proc = Get-Process RTSS -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) { return (Split-Path $proc.Path) }
    return $null
}

function Get-IniValue([string]$Path, [string]$Section, [string]$Key) {
    if (-not (Test-Path $Path)) { return $null }      # fresh RTSS: plugin settings files do not exist until first use
    $in = $false
    foreach ($l in ([IO.File]::ReadAllText($Path, $Latin1) -split "\r?\n")) {
        if ($l -match '^\s*\[(.+?)\]\s*$') { $in = ($Matches[1] -ieq $Section); continue }
        if ($in -and $l -match ('^\s*' + [regex]::Escape($Key) + '\s*=\s*(.*?)\s*$')) { return $Matches[1] }
    }
    return $null
}

function Set-IniValue([string]$Path, [string]$Section, [string]$Key, [string]$Value) {
    Write-Host ("   [{0}] {1}={2}   ({3})" -f $Section, $Key, $Value, (Split-Path $Path -Leaf))
    $text = if (Test-Path $Path) { [IO.File]::ReadAllText($Path, $Latin1) } else { '' }     # a missing file is created
    $nl = if ($text.Contains("`n") -and -not $text.Contains("`r`n")) { "`n" } else { "`r`n" }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]]($text -split "\r?\n"))
    $in = $false; $done = $false; $last = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^\s*\[(.+?)\]\s*$') { $in = ($Matches[1] -ieq $Section); if ($in) { $last = $i }; continue }
        if ($in) {
            if ($l.Trim() -ne '') { $last = $i }
            if (-not $done -and $l -match ('^(\s*' + [regex]::Escape($Key) + '\s*=\s*)')) {
                $lines[$i] = $Matches[1] + $Value      # keeps the file's own spacing style
                $done = $true
            }
        }
    }
    if (-not $done) {
        if ($last -ge 0) { $lines.Insert($last + 1, "$Key=$Value") }
        else {
            # new section at the end, keeping the final line break
            $at = if ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.Count - 1 } else { $lines.Count }
            $lines.InsertRange($at, [string[]]@("[$Section]", "$Key=$Value"))
        }
    }
    if (-not $DryRun) {
        $dir = Split-Path $Path
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        [IO.File]::WriteAllText($Path, ($lines -join $nl), $Latin1)
    }
}

function Backup-File([string]$Path) {
    $b = "$Path.overlay-backup"
    if (Test-Path $b) { return }
    if (Test-Path $Path) {
        Write-Host ("   backup: {0}" -f (Split-Path $b -Leaf))
        if (-not $DryRun) { Copy-Item $Path $b }
    }
    else {
        # the file does not exist yet (fresh RTSS): an empty backup marks "it did not exist", so Uninstall can remove it again
        Write-Host ("   {0} does not exist yet, it will be created" -f (Split-Path $Path -Leaf))
        if (-not $DryRun) {
            $dir = Split-Path $Path
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
            [IO.File]::WriteAllBytes($b, [byte[]]@())
        }
    }
}

function ConvertTo-HotkeyValue([string]$s) {
    # RTSS hotkey format: low word = virtual key code, high word = modifiers (Shift=1, Ctrl=2, Alt=4)
    $mods = 0; $vk = $null
    foreach ($part in ($s -split '\+')) {
        $p = $part.Trim()
        if     ($p -match '^(ctrl|control)$') { $mods = $mods -bor 2 }
        elseif ($p -match '^shift$')          { $mods = $mods -bor 1 }
        elseif ($p -match '^alt$')            { $mods = $mods -bor 4 }
        elseif ($p -match '^f(\d{1,2})$')     { $n = [int]$Matches[1]; if ($n -lt 1 -or $n -gt 24) { throw "Bad key '$p'" }; $vk = 0x6F + $n }
        elseif ($p -match '^[a-z0-9]$')       { $vk = [int][char]$p.ToUpper() }
        elseif ($p -match '^scrolllock$')     { $vk = 0x91 }
        elseif ($p -match '^pause$')          { $vk = 0x13 }
        else { throw "Unknown key '$p' in hotkey '$s'" }
    }
    if (-not $vk) { throw "No main key in hotkey '$s'" }
    return ('{0:X8}' -f (($mods -shl 16) -bor $vk))
}

function Get-DesktopSize {
    try {
        Add-Type -ErrorAction Stop -TypeDefinition 'using System.Runtime.InteropServices; public class RtssOvlScreen { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); }'
    } catch { }
    try {
        [void][RtssOvlScreen]::SetProcessDPIAware()      # report real pixels even with Windows scaling
        return [pscustomobject]@{ W = [RtssOvlScreen]::GetSystemMetrics(0); H = [RtssOvlScreen]::GetSystemMetrics(1) }
    } catch { return $null }
}

function Test-RussianUi {
    # only used to pick the default answer of the language question
    try { return ((Get-UICulture).TwoLetterISOLanguageName -eq 'ru') } catch { return $false }
}

function Stop-Rtss {
    if (Get-Process MSIAfterburner -ErrorAction SilentlyContinue) {
        throw 'MSI Afterburner is running and hosts RTSS. Close Afterburner first, then run this script again.'
    }
    Write-Host ' - closing RTSS'
    if ($DryRun) { return }
    Get-Process RTSS, PresentMonDataProvider -ErrorAction SilentlyContinue | Stop-Process -Force
    for ($i = 0; $i -lt 20 -and (Get-Process RTSS -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 250 }
}

function Start-Rtss([string]$Dir) {
    if ($NoRestart) { Write-Host ' - RTSS was not restarted (-NoRestart). Start it manually.'; return }
    Write-Host ' - starting RTSS'
    if (-not $DryRun) { Start-Process (Join-Path $Dir 'RTSS.exe') -WorkingDirectory $Dir }
}

# The elevated window is a separate console: keep it open long enough to read the result.
# Success: closes by itself after 15 s (any key closes it earlier). Error: waits for Enter.
function Wait-Close([bool]$Failed) {
    if ($NoPause -or $DryRun) { return }
    Write-Host ''
    if ($Failed) { Read-Host 'Press Enter to close'; return }
    Write-Host 'This window closes in 15 seconds (press any key to close it now)...'
    for ($i = 0; $i -lt 30; $i++) {
        try { if ([Console]::KeyAvailable) { break } } catch { break }
        Start-Sleep -Milliseconds 500
    }
}

# ---------- main ----------
$rtss = Find-Rtss
if (-not $rtss -or -not (Test-Path (Join-Path $rtss 'Plugins\Client\OverlayEditor.dll'))) {
    Write-Host 'RivaTuner Statistics Server (RTSS) was not found.' -ForegroundColor Red
    Write-Host 'Install RTSS (the "Statistics Server", NOT the old 2008 "RivaTuner v2.24"): https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/' -ForegroundColor Red
    Write-Host 'RTSS also comes with MSI Afterburner. If RTSS is installed in a custom folder, pass -RtssPath.' -ForegroundColor Red
    Wait-Close $true
    exit 1
}
$client = Join-Path $rtss 'Plugins\Client'
$cfg = [ordered]@{
    Layout   = Join-Path $client 'OverlayEditor.cfg'
    Hotkey   = Join-Path $client 'HotkeyHandler.cfg'
    Config   = Join-Path $rtss 'Profiles\Config'
}
$ovlDir = Join-Path $client 'Overlays'
$presets = [ordered]@{ '1080' = 'TrueFrame_1080p'; '1440' = 'TrueFrame_1440p'; '2160' = 'TrueFrame_4k' }
# English overlays are ready .ovl files. Russian ones are templates: the words are drawn into a PNG sprite sheet
# on this PC (tools\TextSprites.ps1), because RTSS itself cannot draw Cyrillic text.
$enFiles = @(foreach ($b in $presets.Values) { "$b.ovl" })
$ruTemplates = @(foreach ($b in $presets.Values) { "${b}_ru.template" })
Write-Host "RTSS found: $rtss"

try {
    if ($Uninstall) {
        Stop-Rtss
        foreach ($p in $cfg.Values) {
            $b = "$p.overlay-backup"
            if (-not (Test-Path $b)) { continue }
            if ((Get-Item $b).Length -eq 0) {
                # the file was created by the installer. Plugin settings files are removed; the global RTSS Config is kept, RTSS rewrites it itself
                if ((Split-Path $p -Leaf) -ne 'Config') { Write-Host ("   remove: {0} (created by the installer)" -f (Split-Path $p -Leaf)); if (-not $DryRun) { Remove-Item $p -Force -ErrorAction SilentlyContinue } }
            }
            else { Write-Host ("   restore: {0}" -f (Split-Path $p -Leaf)); if (-not $DryRun) { Copy-Item $b $p -Force } }
        }
        $mine = @(Get-ChildItem -Path $ovlDir -Filter 'TrueFrame*' -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.ovl', '.png' })
        if ($mine.Count) { Write-Host ("   remove: {0} overlay file(s)" -f $mine.Count); if (-not $DryRun) { $mine | Remove-Item -Force } }
        Start-Rtss $rtss
        Write-Host 'Done. RTSS settings are restored.' -ForegroundColor Green
    }
    else {
        # 1) resolution
        if (-not $Resolution) {
            $scr = Get-DesktopSize
            $def = '3'
            if ($scr) { if ($scr.H -ge 1900) { $def = '3' } elseif ($scr.H -ge 1300) { $def = '2' } else { $def = '1' } }
            Write-Host ''
            Write-Host 'Which resolution do you play at? The overlay text size is tuned for it.'
            Write-Host '  [1] 1080p  (1920x1080)'
            Write-Host '  [2] 1440p  (2560x1440)'
            Write-Host '  [3] 4K     (3840x2160)'
            if ($scr) { Write-Host ("Detected desktop resolution: {0}x{1}" -f $scr.W, $scr.H) }
            $ans = Read-Host "Choose 1-3 [Enter = $def]"
            if (-not $ans) { $ans = $def }
            $Resolution = @{ '1' = '1080'; '2' = '1440'; '3' = '2160' }[$ans.Trim()]
            if (-not $Resolution) { throw 'Invalid choice.' }
        }

        # 2) language
        if ($Language -eq 'auto') {
            $def = if (Test-RussianUi) { '2' } else { '1' }
            Write-Host ''
            Write-Host 'Overlay language:'
            Write-Host '  [1] English'
            Write-Host '  [2] Russian'
            $ans = Read-Host "Choose 1-2 [Enter = $def]"
            if (-not $ans) { $ans = $def }
            $pick = @{ '1' = 'en'; '2' = 'ru' }[$ans.Trim()]
            if (-not $pick) { throw 'Invalid choice.' }
            $Language = $pick
        }
        $Language = $Language.ToLower()

        $srcDir = $null
        foreach ($d in 'overlays', 'dist') { $c = Join-Path $PSScriptRoot $d; if (Test-Path (Join-Path $c $enFiles[0])) { $srcDir = $c; break } }
        if (-not $srcDir) { throw "Overlay files not found next to the script (expected an 'overlays' folder)." }
        foreach ($f in $enFiles) { if (-not (Test-Path (Join-Path $srcDir $f))) { throw "Overlay file $f is missing in $srcDir." } }
        $sprites = $null
        foreach ($c in (Join-Path $PSScriptRoot 'tools\TextSprites.ps1'), (Join-Path $PSScriptRoot 'TextSprites.ps1')) { if (Test-Path $c) { $sprites = $c; break } }
        $ruReady = [bool]$sprites
        foreach ($f in $ruTemplates) { if (-not (Test-Path (Join-Path $srcDir $f))) { $ruReady = $false } }
        if ($Language -eq 'ru' -and -not $ruReady) {
            Write-Host 'Russian overlay files (overlays\*_ru.template, tools\TextSprites.ps1) were not found, installing the English overlay.' -ForegroundColor Yellow
            $Language = 'en'
        }

        $fileName = $presets[$Resolution] + $(if ($Language -eq 'ru') { '_ru' } else { '' }) + '.ovl'
        $label = @{ '1080' = '1080p'; '1440' = '1440p'; '2160' = '4K' }[$Resolution] + ', ' + @{ 'en' = 'English'; 'ru' = 'Russian' }[$Language]
        $target = Join-Path $ovlDir $fileName

        # 3) hotkey
        $hk = $null
        if ($Hotkey -ne 'keep') {
            $hk = if ($Hotkey -eq 'none') { '00000000' } else { ConvertTo-HotkeyValue $Hotkey }
            $cur = Get-IniValue $cfg.Hotkey 'Settings' 'OSDToggleHotkey'
            if ($cur -and $cur -ne '00000000' -and $cur -ne $hk -and -not $Yes) {
                $r = Read-Host "An OSD toggle hotkey is already set (code $cur). Replace it with $Hotkey ? [y/N]"
                if ($r -notmatch '^(y|yes)$') { $hk = $null }
            }
        }

        Write-Host ''
        Write-Host ("Installing '{0}' for {1}{2}" -f $OverlayName, $label, $(if ($DryRun) { ' (dry run)' } else { '' }))
        Stop-Rtss
        Write-Host ' - saving backups of RTSS settings (first install only)'
        foreach ($p in $cfg.Values) { Backup-File $p }

        Write-Host ' - copying overlays (all resolutions and languages, so you can switch later)'
        if (-not $DryRun) {
            if (-not (Test-Path $ovlDir)) { New-Item -ItemType Directory -Path $ovlDir | Out-Null }
            foreach ($f in $enFiles) { Copy-Item (Join-Path $srcDir $f) (Join-Path $ovlDir $f) -Force }
            $legacy = Join-Path $ovlDir 'TrueFrame.ovl'      # file name used by the first beta installer
            if (Test-Path $legacy) { Remove-Item $legacy -Force }
        }
        if ($ruReady) {
            Write-Host ' - drawing the Russian words (RTSS cannot draw Cyrillic text itself, so they become images)'
            if (-not $DryRun) {
                try {
                    foreach ($f in $ruTemplates) {
                        & $sprites -Template (Join-Path $srcDir $f) -OutOvl (Join-Path $ovlDir ($f -replace '\.template$', '.ovl'))
                    }
                }
                catch {
                    if ($Language -ne 'ru') {
                        Write-Host ("   Russian overlay was skipped: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
                    }
                    else {
                        Write-Host ("   Could not draw the Russian words ({0}). Installing the English overlay instead." -f $_.Exception.Message) -ForegroundColor Yellow
                        $Language = 'en'
                        $target = Join-Path $ovlDir ($presets[$Resolution] + '.ovl')
                    }
                    foreach ($f in $ruTemplates) { foreach ($e in '.ovl', '.png') { Remove-Item (Join-Path $ovlDir ($f -replace '\.template$', $e)) -Force -ErrorAction SilentlyContinue } }
                }
            }
        }
        Write-Host ' - updating RTSS settings'
        Set-IniValue $cfg.Layout 'Settings' 'Layout' $target
        Set-IniValue $cfg.Config 'Plugins' 'OverlayEditor.dll' '1'
        Set-IniValue $cfg.Config 'Plugins' 'HotkeyHandler.dll' '1'
        if ($hk) { Set-IniValue $cfg.Hotkey 'Settings' 'OSDToggleHotkey' $hk }

        Start-Rtss $rtss
        Write-Host ''
        Write-Host 'Done. Start a game: the overlay appears automatically.' -ForegroundColor Green
        if ($hk -and $hk -ne '00000000') { Write-Host "Show/hide hotkey: $Hotkey" }
        Write-Host 'To change the resolution or language later: run install.cmd again, or in RTSS use OverlayEditor -> Layouts -> Load.'
    }
}
catch {
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Wait-Close $true
    exit 1
}
Wait-Close $false
