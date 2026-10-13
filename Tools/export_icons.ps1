# Crops the generated icon sheet and writes WoW-ready 32-bit TGA files into Media\.
# Source art is the Imagine session output. Re-run after replacing those images.
param(
    [string]$ImageDir = "C:\Users\hydro\.grok\sessions\E%3A%5CGithub%5Cstratagem\01a1332b-0b94-76e3-a3e4-80eb11f368ca\images",
    [switch]$MainOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public class IconExport {
    public struct Box { public int X, Y, W, H, Area; }

    static bool IsMagenta(Color p, int kr, int kg, int kb, int tol) {
        int dr = p.R - kr, dg = p.G - kg, db = p.B - kb;
        if (dr*dr + dg*dg + db*db <= tol * tol) return true;
        int max = Math.Max(p.R, Math.Max(p.G, p.B));
        int min = Math.Min(p.R, Math.Min(p.G, p.B));
        // JPEG fringe around the chroma key, not the navy/gold medallion.
        return p.R > 145 && p.B > 110 && p.G < 110 && (p.R - p.G) > 40 && (p.B - p.G) > 25 && (max - min) > 30;
    }

    static bool IsWhite(Color p) {
        int max = Math.Max(p.R, Math.Max(p.G, p.B));
        int min = Math.Min(p.R, Math.Min(p.G, p.B));
        return max > 228 && (max - min) < 22;
    }

    public static List<Box> Boxes(string path, int tol) {
        Bitmap bmp = new Bitmap(path);
        int w = bmp.Width, h = bmp.Height;
        Color key = bmp.GetPixel(1, 1);
        bool[] bg = new bool[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                bg[y * w + x] = IsMagenta(bmp.GetPixel(x, y), key.R, key.G, key.B, tol);
        bool[] seen = new bool[w * h];
        var boxes = new List<Box>();
        int[] qx = new int[w * h];
        int[] qy = new int[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int i = y * w + x;
                if (bg[i] || seen[i]) continue;
                int qs = 0, qe = 0;
                qx[qe] = x; qy[qe] = y; qe++; seen[i] = true;
                int minx = x, maxx = x, miny = y, maxy = y, area = 0;
                while (qs < qe) {
                    int cx = qx[qs], cy = qy[qs]; qs++; area++;
                    if (cx < minx) minx = cx; if (cx > maxx) maxx = cx;
                    if (cy < miny) miny = cy; if (cy > maxy) maxy = cy;
                    for (int dy = -1; dy <= 1; dy++) {
                        for (int dx = -1; dx <= 1; dx++) {
                            if (dx == 0 && dy == 0) continue;
                            int nx = cx + dx, ny = cy + dy;
                            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                            int ni = ny * w + nx;
                            if (seen[ni] || bg[ni]) continue;
                            seen[ni] = true;
                            qx[qe] = nx; qy[qe] = ny; qe++;
                        }
                    }
                }
                if (area > 1500) boxes.Add(new Box { X = minx, Y = miny, W = maxx - minx + 1, H = maxy - miny + 1, Area = area });
            }
        }
        bmp.Dispose();
        boxes.Sort(delegate(Box a, Box b) {
            int ay = a.Y / 40, by = b.Y / 40;
            if (ay != by) return ay.CompareTo(by);
            return a.X.CompareTo(b.X);
        });
        return boxes;
    }

    static Bitmap Keyed(Bitmap src, Rectangle crop, bool magenta, int tol) {
        Bitmap dst = new Bitmap(crop.Width, crop.Height, PixelFormat.Format32bppArgb);
        Color key = src.GetPixel(1, 1);
        for (int y = 0; y < crop.Height; y++) {
            for (int x = 0; x < crop.Width; x++) {
                Color p = src.GetPixel(crop.X + x, crop.Y + y);
                bool drop = magenta ? IsMagenta(p, key.R, key.G, key.B, tol) : IsWhite(p);
                dst.SetPixel(x, y, drop ? Color.FromArgb(0, p) : Color.FromArgb(255, p));
            }
        }
        return dst;
    }

    static Rectangle Content(Bitmap bmp) {
        int minx = bmp.Width, miny = bmp.Height, maxx = 0, maxy = 0;
        for (int y = 0; y < bmp.Height; y++)
            for (int x = 0; x < bmp.Width; x++)
                if (bmp.GetPixel(x, y).A > 16) {
                    if (x < minx) minx = x; if (y < miny) miny = y;
                    if (x > maxx) maxx = x; if (y > maxy) maxy = y;
                }
        if (maxx < minx) return new Rectangle(0, 0, bmp.Width, bmp.Height);
        return new Rectangle(minx, miny, maxx - minx + 1, maxy - miny + 1);
    }

    public static void Fit(Bitmap src, Rectangle crop, bool magenta, int tol, int size, int pad, string tgaPath, string pngPath) {
        Bitmap keyed = Keyed(src, crop, magenta, tol);
        Rectangle tight = Content(keyed);
        Bitmap trimmed = keyed.Clone(tight, PixelFormat.Format32bppArgb);
        keyed.Dispose();
        Bitmap canvas = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(canvas)) {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            int inner = size - pad * 2;
            float scale = Math.Min((float)inner / trimmed.Width, (float)inner / trimmed.Height);
            int dw = Math.Max(1, (int)Math.Round(trimmed.Width * scale));
            int dh = Math.Max(1, (int)Math.Round(trimmed.Height * scale));
            g.DrawImage(trimmed, (size - dw) / 2, (size - dh) / 2, dw, dh);
        }
        trimmed.Dispose();
        SaveTga(canvas, tgaPath);
        canvas.Save(pngPath, ImageFormat.Png);
        canvas.Dispose();
    }

    public static void SaveTga(Bitmap bmp, string path) {
        int w = bmp.Width, h = bmp.Height;
        using (FileStream fs = File.Create(path)) {
            byte[] header = new byte[18];
            header[2] = 2;
            header[12] = (byte)(w & 255);
            header[13] = (byte)((w >> 8) & 255);
            header[14] = (byte)(h & 255);
            header[15] = (byte)((h >> 8) & 255);
            header[16] = 32;
            header[17] = 8; // 8 bits of alpha, bottom-left origin
            fs.Write(header, 0, 18);
            for (int y = h - 1; y >= 0; y--) {
                for (int x = 0; x < w; x++) {
                    Color p = bmp.GetPixel(x, y);
                    fs.WriteByte(p.B);
                    fs.WriteByte(p.G);
                    fs.WriteByte(p.R);
                    fs.WriteByte(p.A);
                }
            }
        }
    }

    // The main icon sits on black, not magenta. Flood from the edges so the
    // navy medallion stays, including the dark metal inside the sword.
    public static void MainIcon(string srcPath, int size, int pad, string tgaPath, string pngPath) {
        Bitmap src = new Bitmap(srcPath);
        int w = src.Width, h = src.Height;
        Color key = src.GetPixel(2, 2);
        bool[] drop = new bool[w * h];
        int[] qx = new int[w * h];
        int[] qy = new int[w * h];
        int qe = 0, qs = 0;
        Action<int, int> push = null;
        push = delegate(int x, int y) {
            if (x < 0 || y < 0 || x >= w || y >= h) return;
            int i = y * w + x;
            if (drop[i]) return;
            Color p = src.GetPixel(x, y);
            int dr = p.R - key.R, dg = p.G - key.G, db = p.B - key.B;
            int max = Math.Max(p.R, Math.Max(p.G, p.B));
            int min = Math.Min(p.R, Math.Min(p.G, p.B));
            bool bg = (dr * dr + dg * dg + db * db) <= (36 * 36) || (max <= 16 && (max - min) <= 8);
            if (!bg) return;
            drop[i] = true;
            qx[qe] = x; qy[qe] = y; qe++;
        };
        for (int x = 0; x < w; x++) { push(x, 0); push(x, h - 1); }
        for (int y = 0; y < h; y++) { push(0, y); push(w - 1, y); }
        while (qs < qe) {
            int cx = qx[qs], cy = qy[qs]; qs++;
            push(cx - 1, cy); push(cx + 1, cy); push(cx, cy - 1); push(cx, cy + 1);
        }
        for (int pass = 0; pass < 2; pass++) {
            bool[] extra = new bool[w * h];
            for (int y = 1; y < h - 1; y++) {
                for (int x = 1; x < w - 1; x++) {
                    int i = y * w + x;
                    if (drop[i]) continue;
                    if (!(drop[i - 1] || drop[i + 1] || drop[i - w] || drop[i + w])) continue;
                    Color p = src.GetPixel(x, y);
                    int max = Math.Max(p.R, Math.Max(p.G, p.B));
                    int min = Math.Min(p.R, Math.Min(p.G, p.B));
                    if (max <= 24 && (max - min) <= 12) extra[i] = true;
                }
            }
            for (int i = 0; i < extra.Length; i++) if (extra[i]) drop[i] = true;
        }
        Bitmap keyed = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        int opaque = 0;
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                Color p = src.GetPixel(x, y);
                bool gone = drop[y * w + x];
                keyed.SetPixel(x, y, gone ? Color.FromArgb(0, p) : Color.FromArgb(255, p));
                if (!gone) opaque++;
            }
        }
        src.Dispose();
        if (opaque < (w * h) / 5) {
            keyed.Dispose();
            throw new InvalidOperationException("Main icon key removed too much. Opaque pixels: " + opaque);
        }
        Rectangle tight = Content(keyed);
        Bitmap trimmed = keyed.Clone(tight, PixelFormat.Format32bppArgb);
        keyed.Dispose();
        Bitmap canvas = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(canvas)) {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            int inner = size - pad * 2;
            float scale = Math.Min((float)inner / trimmed.Width, (float)inner / trimmed.Height);
            int dw = Math.Max(1, (int)Math.Round(trimmed.Width * scale));
            int dh = Math.Max(1, (int)Math.Round(trimmed.Height * scale));
            g.DrawImage(trimmed, (size - dw) / 2, (size - dh) / 2, dw, dh);
        }
        trimmed.Dispose();
        SaveTga(canvas, tgaPath);
        canvas.Save(pngPath, ImageFormat.Png);
        canvas.Dispose();
    }

    public static string DumpBoxes(string path, int tol) {
        var boxes = Boxes(path, tol);
        var parts = new List<string>();
        foreach (Box b in boxes) parts.Add(b.X + "," + b.Y + " " + b.W + "x" + b.H);
        return boxes.Count + " | " + string.Join(" ; ", parts.ToArray());
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing.dll

$root = Split-Path -Parent $PSScriptRoot
$media = Join-Path $root "Media"
New-Item -ItemType Directory -Force -Path $media | Out-Null

$sheet = Join-Path $ImageDir "3.jpg"
$arrow = Join-Path $ImageDir "1.jpg"
$icon = Join-Path $ImageDir "5.jpg"
if ($MainOnly) {
    [IconExport]::MainIcon($icon, 256, 12, (Join-Path $media "Icon.tga"), (Join-Path $media "Icon.png"))
    "Wrote Icon"
    Get-ChildItem $media -Filter Icon.tga | ForEach-Object { "{0} {1:N0} bytes" -f $_.Name, $_.Length }
    return
}
"Sheet: " + [IconExport]::DumpBoxes($sheet, 55)

$names = @(
    "cat_all", "cat_leveling", "cat_professions", "cat_reputation", "cat_exploration",
    "cat_legacy", "cat_collectibles", "cat_dungeons", "cat_favorites", "cat_options"
)
$boxes = [IconExport]::Boxes($sheet, 55)
if ($boxes.Count -ne 10) { throw "Expected 10 category icons, found $($boxes.Count)." }

$sheetBmp = New-Object System.Drawing.Bitmap $sheet
for ($i = 0; $i -lt 10; $i++) {
    $b = $boxes[$i]
    $crop = New-Object System.Drawing.Rectangle $b.X, $b.Y, $b.W, $b.H
    $tga = Join-Path $media ($names[$i] + ".tga")
    $png = Join-Path $media ($names[$i] + ".png")
    [IconExport]::Fit($sheetBmp, $crop, $true, 55, 128, 8, $tga, $png)
    "Wrote $($names[$i])"
}
$sheetBmp.Dispose()

$arrowBmp = New-Object System.Drawing.Bitmap $arrow
$ac = New-Object System.Drawing.Rectangle 0, 0, $arrowBmp.Width, $arrowBmp.Height
[IconExport]::Fit($arrowBmp, $ac, $true, 55, 128, 16, (Join-Path $media "arrow.tga"), (Join-Path $media "arrow.png"))
$arrowBmp.Dispose()
"Wrote arrow"

[IconExport]::MainIcon($icon, 256, 12, (Join-Path $media "Icon.tga"), (Join-Path $media "Icon.png"))
"Wrote Icon"
Get-ChildItem $media -Filter *.tga | ForEach-Object { "{0} {1:N0} bytes" -f $_.Name, $_.Length }
