<#
.SYNOPSIS
  TrueFrame Overlay - turns a language .template into a ready RTSS overlay (.ovl + .png).
  https://github.com/apbrandom/trueframe-overlay

.DESCRIPTION
  RTSS draws overlay text with its own raster font, which has ASCII only (plus the degree sign), whatever the
  Windows language is. So every Russian word is drawn here as an image: the words are rendered with the same
  Windows GDI text renderer RTSS uses for its own text (same face, height, weight, anti-aliasing), packed into a
  PNG sprite sheet, and the overlay shows them through RTSS image tags <I=...>.

  Placeholders in the template:  [[word|size]]   size = the layer text size in percent (100 = body, 80 = small ...).
  The sprites are white; RTSS tints them with the layer text color, so warning/critical colors keep working.
  The word is drawn once at 100% and scaled by size, exactly as RTSS scales its own text tier.

.EXAMPLE
  .\TextSprites.ps1 -Template ..\overlays\TrueFrame_4k_ru.template -OutOvl C:\temp\TrueFrame_4k_ru.ovl
#>
param([Parameter(Mandatory)][string]$Template, [Parameter(Mandatory)][string]$OutOvl)
$ErrorActionPreference = 'Stop'

$cs = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
public static class TfText {
    [StructLayout(LayoutKind.Sequential)] public struct SIZE { public int cx; public int cy; }
    [StructLayout(LayoutKind.Sequential)] public struct BIH { public int biSize; public int biWidth; public int biHeight; public short biPlanes; public short biBitCount; public int biCompression; public int biSizeImage; public int biXPelsPerMeter; public int biYPelsPerMeter; public int biClrUsed; public int biClrImportant; }
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontW(int h, int w, int esc, int ori, int weight, uint italic, uint underline, uint strike, uint charset, uint outPrec, uint clipPrec, uint quality, uint pitch, string face);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr hdc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool TextOutW(IntPtr hdc, int x, int y, string s, int n);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextExtentPoint32W(IntPtr hdc, string s, int n, out SIZE sz);
    [DllImport("gdi32.dll")] static extern uint SetTextColor(IntPtr hdc, uint c);
    [DllImport("gdi32.dll")] static extern int SetBkMode(IntPtr hdc, int m);
    [DllImport("gdi32.dll")] static extern bool GdiFlush();
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr hdc, ref BIH bmi, uint usage, out IntPtr bits, IntPtr hSection, uint offset);

    // white text on black, ANTIALIASED_QUALITY (4) like the RTSS raster font; returns coverage 0..255
    public static byte[] Render(string face, int height, int weight, string text, out int w, out int h) {
        IntPtr dc = CreateCompatibleDC(IntPtr.Zero);
        IntPtr font = CreateFontW(height, 0, 0, 0, weight, 0, 0, 0, 1, 0, 0, 4, 0, face);
        IntPtr oldFont = SelectObject(dc, font);
        SIZE sz; GetTextExtentPoint32W(dc, text, text.Length, out sz);
        w = Math.Max(1, sz.cx); h = Math.Max(1, sz.cy);
        BIH bi = new BIH(); bi.biSize = 40; bi.biWidth = w; bi.biHeight = -h; bi.biPlanes = 1; bi.biBitCount = 32;
        IntPtr bits; IntPtr dib = CreateDIBSection(dc, ref bi, 0, out bits, IntPtr.Zero, 0);
        IntPtr oldBmp = SelectObject(dc, dib);
        SetBkMode(dc, 1); SetTextColor(dc, 0x00FFFFFF);
        TextOutW(dc, 0, 0, text, text.Length);
        GdiFlush();
        byte[] px = new byte[w * h * 4]; Marshal.Copy(bits, px, 0, px.Length);
        SelectObject(dc, oldBmp); SelectObject(dc, oldFont); DeleteObject(dib); DeleteObject(font); DeleteDC(dc);
        byte[] cov = new byte[w * h];
        for (int i = 0; i < cov.Length; i++) cov[i] = Math.Max(px[i * 4], Math.Max(px[i * 4 + 1], px[i * 4 + 2]));
        return cov;
    }
    public static byte[] Fake(string text, int height, out int w, out int h) {   // test stub for hosts without GDI
        h = Math.Abs(height) + 9; w = Math.Max(1, text.Length * h / 2); byte[] c = new byte[w * h];
        for (int i = 0; i < c.Length; i++) c[i] = (byte)((i % 7 == 0) ? 255 : 0); return c;
    }
    // white pixels, alpha = coverage
    public static void Blit(byte[] atlas, int aw, int x, int y, byte[] cov, int w, int h) {
        for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) {
            int o = ((y + j) * aw + x + i) * 4;
            atlas[o] = 255; atlas[o + 1] = 255; atlas[o + 2] = 255; atlas[o + 3] = cov[j * w + i];
        }
    }
    static uint[] crcTab;
    static uint Crc(byte[] d, uint c) {
        if (crcTab == null) { crcTab = new uint[256]; for (uint n = 0; n < 256; n++) { uint k = n; for (int i = 0; i < 8; i++) k = ((k & 1) != 0) ? 0xEDB88320u ^ (k >> 1) : k >> 1; crcTab[n] = k; } }
        foreach (byte x in d) c = crcTab[(c ^ x) & 0xFF] ^ (c >> 8); return c;
    }
    static void BE(Stream s, uint v) { s.WriteByte((byte)(v >> 24)); s.WriteByte((byte)(v >> 16)); s.WriteByte((byte)(v >> 8)); s.WriteByte((byte)v); }
    static void Chunk(Stream s, string type, byte[] data) {
        byte[] t = System.Text.Encoding.ASCII.GetBytes(type);
        BE(s, (uint)data.Length); s.Write(t, 0, 4); s.Write(data, 0, data.Length);
        byte[] all = new byte[4 + data.Length]; Buffer.BlockCopy(t, 0, all, 0, 4); Buffer.BlockCopy(data, 0, all, 4, data.Length);
        BE(s, Crc(all, 0xFFFFFFFFu) ^ 0xFFFFFFFFu);
    }
    public static void SavePng(string path, int w, int h, byte[] rgba) {
        byte[] raw = new byte[h * (w * 4 + 1)];
        for (int y = 0; y < h; y++) Buffer.BlockCopy(rgba, y * w * 4, raw, y * (w * 4 + 1) + 1, w * 4);
        MemoryStream z = new MemoryStream(); z.WriteByte(0x78); z.WriteByte(0x9C);
        using (DeflateStream ds = new DeflateStream(z, CompressionMode.Compress, true)) ds.Write(raw, 0, raw.Length);
        uint a = 1, b = 0; foreach (byte x in raw) { a = (a + x) % 65521; b = (b + a) % 65521; }
        BE(z, (b << 16) | a);
        using (FileStream fs = new FileStream(path, FileMode.Create)) {
            fs.Write(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }, 0, 8);
            MemoryStream ih = new MemoryStream(); BE(ih, (uint)w); BE(ih, (uint)h); ih.Write(new byte[] { 8, 6, 0, 0, 0 }, 0, 5);
            Chunk(fs, "IHDR", ih.ToArray()); Chunk(fs, "IDAT", z.ToArray()); Chunk(fs, "IEND", new byte[0]);
        }
    }
}
'@
if (-not ('TfText' -as [type])) { Add-Type -TypeDefinition $cs }

$text = [IO.File]::ReadAllText($Template, [Text.Encoding]::UTF8)
function Get-Master([string]$k) { if ($text -match "(?m)^$k=(.*?)\r?$") { return $Matches[1] } else { throw "[Master] $k is missing in the template" } }
$face = Get-Master 'FontFace'; $fh = [int](Get-Master 'FontHeight'); $fw = [int](Get-Master 'FontWeight'); $zoom = [int](Get-Master 'ZoomRatio')
$baseH = $fh * $zoom                        # negative = character height in pixels, as RTSS passes it to CreateFont
$fake = [bool]$env:TF_FAKE_GDI

# one sprite per distinct word, drawn at 100%
$rx = [regex]'\[\[([^|\]]+)\|(\d+)\]\]'
$sprites = [ordered]@{}
foreach ($m in $rx.Matches($text)) {
    $word = $m.Groups[1].Value
    if ($sprites.Contains($word)) { continue }
    $w = 0; $h = 0
    $cov = if ($fake) { [TfText]::Fake($word, $baseH, [ref]$w, [ref]$h) } else { [TfText]::Render($face, $baseH, $fw, $word, [ref]$w, [ref]$h) }
    $sprites[$word] = [pscustomobject]@{ W = $w; H = $h; Cov = $cov; Y = 0 }
}

# vertical sprite sheet, 2 px gap
$aw = 1; $ah = 0
foreach ($s in $sprites.Values) { $s.Y = $ah; $ah += $s.H + 2; if ($s.W -gt $aw) { $aw = $s.W } }
$atlas = New-Object byte[] ($aw * [Math]::Max(1, $ah) * 4)
foreach ($s in $sprites.Values) { [TfText]::Blit($atlas, $aw, 0, $s.Y, $s.Cov, $s.W, $s.H) }
$png = [IO.Path]::ChangeExtension($OutOvl, '.png')
[TfText]::SavePng($png, $aw, [Math]::Max(1, $ah), $atlas)

# <I=shownW,shownH,spriteX,spriteY,spriteW,spriteH>: shown size = sprite size * (layer text size / 100)
$out = $rx.Replace($text, {
    param($m)
    $s = $sprites[$m.Groups[1].Value]; $pct = [int]$m.Groups[2].Value
    '<I={0},{1},0,{2},{3},{4}>' -f [int][Math]::Round($s.W * $pct / 100.0), [int][Math]::Round($s.H * $pct / 100.0), $s.Y, $s.W, $s.H
})
$out = $out -replace '(?m)^EmbeddedImage=.*$', ('EmbeddedImage=' + [IO.Path]::GetFileName($png))

# safety net: RTSS can only draw ASCII and the degree sign as text
foreach ($ch in $out.ToCharArray()) { if ([int]$ch -gt 127 -and [int]$ch -ne 176) { throw ('Unsupported character U+{0:X4} outside [[word|size]] in the template' -f [int]$ch) } }

[IO.File]::WriteAllText($OutOvl, $out, [Text.Encoding]::GetEncoding(28591))   # ASCII + degree sign (0xB0), as RTSS expects
Write-Host ("   rendered {0} words -> {1} ({2}x{3}), {4}" -f $sprites.Count, [IO.Path]::GetFileName($png), $aw, $ah, [IO.Path]::GetFileName($OutOvl))
