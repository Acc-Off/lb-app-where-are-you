param(
    [string]$SourceDir = "./minimap",
    [string]$OutputDir = "./output",
    [int]$TileSize = 256
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-ImageInfo([string]$Path) {
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        return [pscustomobject]@{
            Width = $image.Width
            Height = $image.Height
        }
    }
    finally {
        $image.Dispose()
    }
}

function Save-ScaledBitmap($sourceBitmap, [int]$width, [int]$height, [string]$path) {
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($sourceBitmap, 0, 0, $width, $height)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedSourceDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir $SourceDir))
$resolvedOutputDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir $OutputDir))
$combinedDir = Join-Path $resolvedOutputDir 'combined'
$tilesDir = Join-Path $resolvedOutputDir 'tiles'
$layerName = 'render'
$layerDir = Join-Path $tilesDir $layerName

New-Directory $resolvedOutputDir
New-Directory $combinedDir
New-Directory $tilesDir
New-Directory $layerDir

$files = Get-ChildItem -LiteralPath $resolvedSourceDir -Filter 'minimap_sea_*.png' | Sort-Object Name
if ($files.Count -ne 6) {
    throw "Expected 6 minimap images, found $($files.Count)."
}

$parsed = foreach ($file in $files) {
    if ($file.BaseName -notmatch '^minimap_sea_(\d+)_(\d+)$') {
        throw "Unexpected file name: $($file.Name)"
    }

    [pscustomobject]@{
        File = $file
        Row = [int]$Matches[1]
        Col = [int]$Matches[2]
    }
}

$rows = [int](($parsed | Measure-Object -Property Row -Maximum).Maximum + 1)
$cols = [int](($parsed | Measure-Object -Property Col -Maximum).Maximum + 1)

if ($rows -ne 3 -or $cols -ne 2) {
    throw "Expected a 3x2 source grid based on filenames, got rows=$rows cols=$cols"
}

$firstInfo = Get-ImageInfo $parsed[0].File.FullName
$cellWidth = $firstInfo.Width
$cellHeight = $firstInfo.Height

foreach ($item in $parsed) {
    $info = Get-ImageInfo $item.File.FullName
    if ($info.Width -ne $cellWidth -or $info.Height -ne $cellHeight) {
        throw "Image size mismatch in $($item.File.Name): expected ${cellWidth}x${cellHeight}, got $($info.Width)x$($info.Height)"
    }
}

$combinedWidth = [int]($cellWidth * $cols)
$combinedHeight = [int]($cellHeight * $rows)
$combinedPath = Join-Path $combinedDir 'minimap_combined.png'

$combinedBitmap = New-Object System.Drawing.Bitmap($combinedWidth, $combinedHeight)
$graphics = [System.Drawing.Graphics]::FromImage($combinedBitmap)
try {
    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    foreach ($item in $parsed) {
        $image = [System.Drawing.Image]::FromFile($item.File.FullName)
        try {
            $x = $item.Col * $cellWidth
            $y = $item.Row * $cellHeight
            $graphics.DrawImage($image, $x, $y, $cellWidth, $cellHeight)
        }
        finally {
            $image.Dispose()
        }
    }

    $combinedBitmap.Save($combinedPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $maxDimension = [Math]::Max($combinedWidth, $combinedHeight)
    $maxZoom = [int][Math]::Ceiling([Math]::Log($maxDimension / $TileSize, 2))

    for ($z = 0; $z -le $maxZoom; $z++) {
        $scale = [Math]::Pow(2, $maxZoom - $z)
        $scaledWidth = [int][Math]::Max(1, [int][Math]::Ceiling($combinedWidth / $scale))
        $scaledHeight = [int][Math]::Max(1, [int][Math]::Ceiling($combinedHeight / $scale))
        $zoomDir = Join-Path $layerDir $z
        New-Directory $zoomDir

        $scaledBitmap = New-Object System.Drawing.Bitmap($scaledWidth, $scaledHeight)
        $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
        try {
            $scaledGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $scaledGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $scaledGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $scaledGraphics.DrawImage($combinedBitmap, 0, 0, $scaledWidth, $scaledHeight)

            $xTiles = [int][Math]::Ceiling($scaledWidth / $TileSize)
            $yTiles = [int][Math]::Ceiling($scaledHeight / $TileSize)

            for ($x = 0; $x -lt $xTiles; $x++) {
                $xDir = Join-Path $zoomDir $x
                New-Directory $xDir

                for ($y = 0; $y -lt $yTiles; $y++) {
                    $tileBitmap = New-Object System.Drawing.Bitmap($TileSize, $TileSize)
                    $tileGraphics = [System.Drawing.Graphics]::FromImage($tileBitmap)
                    try {
                        $tileGraphics.Clear([System.Drawing.Color]::Black)
                        $tileGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                        $tileGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                        $tileGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                        $tileGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                        $srcX = [int]($x * $TileSize)
                        $srcY = [int]($y * $TileSize)
                        $srcRect = New-Object System.Drawing.Rectangle($srcX, $srcY, [int]$TileSize, [int]$TileSize)
                        $dstRect = New-Object System.Drawing.Rectangle(0, 0, $TileSize, $TileSize)
                        $tileGraphics.DrawImage($scaledBitmap, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

                        $tilePath = Join-Path $xDir ($y.ToString() + '.png')
                        $tileBitmap.Save($tilePath, [System.Drawing.Imaging.ImageFormat]::Png)
                    }
                    finally {
                        $tileGraphics.Dispose()
                        $tileBitmap.Dispose()
                    }
                }
            }
        }
        finally {
            $scaledGraphics.Dispose()
            $scaledBitmap.Dispose()
        }
    }

    $metadata = [pscustomobject]@{
        source = [pscustomobject]@{
            directory = [System.IO.Path]::GetRelativePath($resolvedOutputDir, $resolvedSourceDir)
            files = ($parsed | Sort-Object Row, Col | ForEach-Object { $_.File.Name })
            layout = [pscustomobject]@{
                rows = $rows
                cols = $cols
                rowIndexFromFileName = $true
                colIndexFromFileName = $true
            }
            tileWidth = $cellWidth
            tileHeight = $cellHeight
        }
        combined = [pscustomobject]@{
            width = $combinedWidth
            height = $combinedHeight
            path = [System.IO.Path]::GetRelativePath($resolvedOutputDir, $combinedPath)
            aspectRatio = "${combinedWidth}:${combinedHeight}"
        }
        tiles = [pscustomobject]@{
            tileSize = $TileSize
            layer = $layerName
            maxZoom = $maxZoom
            outputRoot = [System.IO.Path]::GetRelativePath($resolvedOutputDir, $layerDir)
        }
        assumedWorldBounds = [pscustomobject]@{
            topLeft = @(-4140, 8400)
            bottomRight = @(4860, -5100)
            note = 'Assumed same as Los Santos fixed URL; verify with anchor points before production use.'
        }
    }

    $metadataPath = Join-Path $resolvedOutputDir 'metadata.json'
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

    Write-Host "Combined image: $combinedPath"
    Write-Host "Tiles output:   $layerDir"
    Write-Host "Metadata:       $metadataPath"
    Write-Host "Combined size:  ${combinedWidth}x${combinedHeight}"
    Write-Host "Max zoom:       $maxZoom"
}
finally {
    $graphics.Dispose()
    $combinedBitmap.Dispose()
}
