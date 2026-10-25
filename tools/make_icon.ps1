# Генератор иконки приложения (1024x1024, без альфа-канала).
# Запуск: powershell -ExecutionPolicy Bypass -File tools\make_icon.ps1
Add-Type -AssemblyName System.Drawing

function New-RoundedPath {
    param(
        [single]$x, [single]$y, [single]$w, [single]$h, [single]$r
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Фон: диагональный градиент
$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(29, 78, 216),
    [System.Drawing.Color]::FromArgb(79, 70, 229),
    45.0
)
$g.FillRectangle($gradient, $rect)

# Лист календаря
$pagePath = New-RoundedPath 232 272 560 560 88
$g.FillPath([System.Drawing.Brushes]::White, $pagePath)

# Шапка листа
$headerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(67, 56, 202))
$headerPath = New-RoundedPath 232 272 560 150 88
$g.FillPath($headerBrush, $headerPath)
$g.FillRectangle([System.Drawing.Brushes]::White, 232, 347, 560, 75)

# Ячейки смен 3x3
$chipColors = @(
    @(59, 130, 246), @(59, 130, 246), @(148, 163, 184),
    @(139, 92, 246), @(59, 130, 246), @(148, 163, 184),
    @(148, 163, 184), @(59, 130, 246), @(59, 130, 246)
)

$chipSize = 120
$gap = 40
$x0 = 292
$y0 = 453
$index = 0

foreach ($row in 0..2) {
    foreach ($col in 0..2) {
        $c = $chipColors[$index]
        $chipBrush = New-Object System.Drawing.SolidBrush(
            [System.Drawing.Color]::FromArgb(255, $c[0], $c[1], $c[2])
        )
        $chipPath = New-RoundedPath ($x0 + $col * ($chipSize + $gap)) ($y0 + $row * ($chipSize + 24)) $chipSize $chipSize 26
        $g.FillPath($chipBrush, $chipPath)
        $chipBrush.Dispose()
        $chipPath.Dispose()
        $index++
    }
}

$outPath = Join-Path $PSScriptRoot "..\ShiftCalendar\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"
$resolved = [System.IO.Path]::GetFullPath($outPath)
$dir = [System.IO.Path]::GetDirectoryName($resolved)
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$bmp.Save($resolved, [System.Drawing.Imaging.ImageFormat]::Png)

$gradient.Dispose()
$headerBrush.Dispose()
$pagePath.Dispose()
$headerPath.Dispose()
$g.Dispose()
$bmp.Dispose()

Write-Output "OK: $resolved"
