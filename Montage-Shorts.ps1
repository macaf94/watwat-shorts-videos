[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Clips,
    [string] $Subtitles,
    [Parameter(Mandatory)] [string] $Output,
    [string] $FFmpeg = 'ffmpeg',
    [ValidateSet('Fit','Fill')] [string] $Framing = 'Fit'
)

$ErrorActionPreference = 'Stop'
$ffmpegPath = (Get-Command $FFmpeg -CommandType Application).Source
$probePath = Join-Path (Split-Path $ffmpegPath) 'ffprobe.exe'
if (!(Test-Path -LiteralPath $probePath)) { throw 'ffprobe.exe doit accompagner ffmpeg.exe.' }

$files = @(Get-ChildItem -LiteralPath $Clips -File |
    Where-Object { $_.Extension -in '.mp4', '.mov', '.mkv', '.webm' } |
    Sort-Object Name)
if (!$files.Count) { throw 'Aucun clip dans le dossier indiqué.' }
$destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
if ([IO.Path]::GetExtension($destination) -ine '.mp4') { throw 'La sortie doit se terminer par .mp4.' }
if (Test-Path -LiteralPath $destination) { throw 'Le fichier de sortie existe déjà.' }
if (!(Test-Path -LiteralPath (Split-Path $destination) -PathType Container)) {
    throw 'Le dossier de sortie doit exister.'
}

$subtitlePath = $null
if ($Subtitles) {
    $subtitlePath = (Get-Item -LiteralPath $Subtitles).FullName
    if ([IO.Path]::GetExtension($subtitlePath) -ine '.srt') { throw 'Utilisez un fichier .srt en UTF-8.' }
}

function Invoke-FFmpeg {
    param([string[]] $Arguments)
    & $ffmpegPath -hide_banner -loglevel error -nostdin -y @Arguments
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg a échoué (code $LASTEXITCODE)." }
}

$framingFilter = if ($Framing -eq 'Fill') {
    'scale=1080:1920:force_original_aspect_ratio=increase:force_divisible_by=2:reset_sar=1,crop=1080:1920'
} else {
    'scale=1080:1920:force_original_aspect_ratio=decrease:force_divisible_by=2:reset_sar=1,pad=1080:1920:(ow-iw)/2:(oh-ih)/2'
}
$temp = Join-Path (Split-Path $destination) ('.watwat-' + [guid]::NewGuid().ToString('N'))
New-Item -Path $temp -ItemType Directory | Out-Null
Push-Location -LiteralPath $temp
try {
    $playlist = @()
    for ($index = 0; $index -lt $files.Count; $index++) {
        $clip = $files[$index].FullName
        $part = 'part-{0:D5}.mp4' -f $index
        Write-Host "[$($index + 1)/$($files.Count)] $($files[$index].Name)"
        $audio = & $probePath -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 $clip
        if ($LASTEXITCODE -ne 0) { throw "Impossible de lire $clip." }
        $inputs = @('-i', $clip)
        $audioMap = '0:a:0'
        if (!$audio) {
            $inputs += @('-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo')
            $audioMap = '1:a:0'
        }
        Invoke-FFmpeg -Arguments ($inputs + @(
            '-map', '0:v:0', '-map', $audioMap,
            '-vf', "$framingFilter,fps=30,format=yuv420p",
            '-af', 'aresample=async=1:first_pts=0,apad',
            '-c:v', 'libx264', '-preset', 'fast', '-crf', '19',
            '-c:a', 'aac', '-ar', '48000', '-ac', '2', '-b:a', '192k', '-shortest', $part
        ))
        $playlist += "file '$part'"
    }
    Set-Content -LiteralPath 'clips.txt' -Value $playlist -Encoding Ascii
    $concat = @('-f', 'concat', '-safe', '1', '-i', 'clips.txt')
    if ($subtitlePath) {
        Copy-Item -LiteralPath $subtitlePath -Destination 'captions.srt'
        $video = @('-vf', "subtitles=captions.srt:charenc=UTF-8:force_style='FontName=Arial,FontSize=18,Outline=2,Shadow=0,Alignment=2,MarginV=48'", '-c:v', 'libx264', '-crf', '19', '-preset', 'fast', '-c:a', 'copy')
    } else {
        $video = @('-c', 'copy')
    }
    Invoke-FFmpeg -Arguments ($concat + $video + @('-movflags', '+faststart', 'result.mp4'))
    [IO.File]::Move((Join-Path $temp 'result.mp4'), $destination)
    Write-Host "Vidéo créée : $destination"
} finally {
    Pop-Location
    Get-ChildItem -LiteralPath $temp -File | Remove-Item
    Remove-Item -LiteralPath $temp
}
