param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\Www\wwwroot'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($outputRoot)

# Original geometric wb monogram. Shared outlines keep SVG and raster icons identical.
$background = @(
    @('M',17,1), @('L',47,1), @('C',55.837,1,63,8.163,63,17),
    @('L',63,47), @('C',63,55.837,55.837,63,47,63),
    @('L',17,63), @('C',8.163,63,1,55.837,1,47),
    @('L',1,17), @('C',1,8.163,8.163,1,17,1), @('Z')
)
$w = @(
    @('M',7,23), @('L',11.5,45), @('L',16.5,45), @('L',22.5,33),
    @('L',28.5,45), @('L',33.5,45), @('L',38,23), @('L',31.7,23),
    @('L',29.3,35.6), @('L',24.4,26), @('L',20.6,26),
    @('L',15.7,35.6), @('L',13.3,23), @('Z')
)
$b = @(
    @('M',37,14), @('L',43,14), @('L',43,26),
    @('C',44.7,24.5,46.8,24,49,24), @('C',55.8,24,59,28.6,59,35),
    @('C',59,41.5,55.4,46,48.9,46), @('C',46.4,46,44.2,45.2,42.7,43.6),
    @('L',42.1,45), @('L',37,45), @('Z'),
    @('M',43,35), @('C',43,31.5,44.8,29.3,48.1,29.3),
    @('C',51.4,29.3,53.1,31.5,53.1,35), @('C',53.1,38.5,51.4,40.7,48.1,40.7),
    @('C',44.8,40.7,43,38.5,43,35), @('Z')
)
$layers = @(
    @{ Color = '#173b36'; Commands = $background },
    @{ Color = '#c5f36b'; Commands = $w },
    @{ Color = '#f7f8ec'; Commands = $b }
)
function SvgPath($commands) {
    return (($commands | ForEach-Object {
        $values = @($_ | Select-Object -Skip 1 | ForEach-Object {
            ([double]$_).ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        })
        $_[0] + ($values -join ' ')
    }) -join ' ')
}
$svgPaths = foreach ($layer in $layers) {
    '  <path fill="' + $layer.Color + '" fill-rule="evenodd" d="' + (SvgPath $layer.Commands) + '"/>'
}
$svg = @(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="With Bugs">',
    '  <title>With Bugs</title>',
    ($svgPaths -join "`n"),
    '</svg>'
) -join "`n"
[IO.File]::WriteAllText((Join-Path $outputRoot 'favicon.svg'), $svg + "`n", [Text.UTF8Encoding]::new($false))

function DrawingPath($commands) {
    $path = [Drawing.Drawing2D.GraphicsPath]::new([Drawing.Drawing2D.FillMode]::Alternate)
    $current = [Drawing.PointF]::Empty
    foreach ($command in $commands) {
        switch ($command[0]) {
            'M' { $path.StartFigure(); $current = [Drawing.PointF]::new($command[1], $command[2]) }
            'L' {
                $next = [Drawing.PointF]::new($command[1], $command[2])
                $path.AddLine($current, $next); $current = $next
            }
            'C' {
                $next = [Drawing.PointF]::new($command[5], $command[6])
                $path.AddBezier($current, [Drawing.PointF]::new($command[1], $command[2]),
                    [Drawing.PointF]::new($command[3], $command[4]), $next)
                $current = $next
            }
            'Z' { $path.CloseFigure() }
        }
    }
    return $path
}

# Supersampling gives the 16-pixel tab icon clear edges without font dependencies.
$master = [Drawing.Bitmap]::new(1024,1024,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($master)
$graphics.Clear([Drawing.Color]::Transparent)
$graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.ScaleTransform(16,16)
foreach ($layer in $layers) {
    $path = DrawingPath $layer.Commands
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($layer.Color))
    $graphics.FillPath($brush,$path)
    $brush.Dispose(); $path.Dispose()
}
$graphics.Dispose()
$images = @{}
foreach ($size in @(16,32,48,64,128,180,256)) {
    $bitmap = [Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($master,[Drawing.Rectangle]::new(0,0,$size,$size))
    $g.Dispose()
    $stream = [IO.MemoryStream]::new()
    $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
    $images[$size] = $stream.ToArray()
    $stream.Dispose(); $bitmap.Dispose()
}
$master.Dispose()
[IO.File]::WriteAllBytes((Join-Path $outputRoot 'apple-touch-icon.png'),$images[180])

# PNG-compressed ICO entries support legacy favicon discovery and multiple DPI sizes.
$iconSizes = @(16,32,48,64,128,256)
$iconStream = [IO.MemoryStream]::new()
$writer = [IO.BinaryWriter]::new($iconStream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$iconSizes.Count)
$offset = 6 + 16 * $iconSizes.Count
foreach ($size in $iconSizes) {
    $dimension = if ($size -eq 256) { 0 } else { $size }
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
    $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32)
    $writer.Write([uint32]$images[$size].Length); $writer.Write([uint32]$offset)
    $offset += $images[$size].Length
}
foreach ($size in $iconSizes) { $writer.Write([byte[]]$images[$size]) }
$writer.Flush()
[IO.File]::WriteAllBytes((Join-Path $outputRoot 'favicon.ico'),$iconStream.ToArray())
$writer.Dispose(); $iconStream.Dispose()
Write-Output 'Generated SVG favicon, six-size ICO, and 180-pixel Apple touch icon.'
