# PotPlayer Lazy Pack - create a runtime-only release ZIP
[CmdletBinding()]
param(
    [string]$OutputZip = "D:\PotPlayer-Lazy-Pack.zip",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
function Write-Stage { param([string]$Text); Write-Host "[INFO] $Text" -ForegroundColor Cyan }
function Fail-Now { param([string]$Text); Write-Host "[FAIL] $Text" -ForegroundColor Red; exit 1 }

$SourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ($SourceRoot.TrimEnd('\') -ine 'D:\Potplayer') { Fail-Now "This pack is fixed to D:\Potplayer. Current path: $SourceRoot" }

$RequiredFiles = @(
    'Potplayer\PotPlayerMini64.exe', 'Potplayer\PotPlayerMini64.ini',
    'LAVFilters\LAVSplitter.ax', 'LAVFilters\LAVVideo.ax', 'LAVFilters\LAVAudio.ax',
    'madVR\install.bat', 'madVR\madVR.ax', 'madVR\madVR64.ax', 'madVR\settings.bin',
    'xyVSFilterSubFilter\x64\XySubFilter.dll',
    'Config\LAV.reg', 'Config\madVR.reg', 'Config\XySubFilter.reg'
)
$IncludedNames = @('Restore.cmd', 'Config', 'LAVFilters', 'madVR', 'Potplayer', 'xyVSFilterSubFilter')

Write-Host '============================================================'
Write-Host ' PotPlayer Personal Lazy Pack - Pack Utility'
Write-Host '============================================================'
Write-Host "Source: $SourceRoot"
Write-Host "Output: $OutputZip"
Write-Host ''

Write-Stage 'Checking required files...'
$Missing = @($RequiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Leaf) })
if ($Missing.Count) { $Missing | ForEach-Object { Write-Host "[FAIL] Missing: $_" -ForegroundColor Red }; Fail-Now "Package validation failed: $($Missing.Count) file(s) missing." }
Write-Host "[PASS] Required files found: $($RequiredFiles.Count)" -ForegroundColor Green

$OutputZip = [IO.Path]::GetFullPath($OutputZip)
$OutputParent = Split-Path -Parent $OutputZip
if (-not (Test-Path -LiteralPath $OutputParent -PathType Container)) { New-Item -ItemType Directory -Path $OutputParent -Force | Out-Null }
if (Test-Path -LiteralPath $OutputZip -PathType Leaf) {
    if (-not $Force) { $answer = Read-Host 'Output already exists. Overwrite it? [Y/N]'; if ($answer -notmatch '^(?i)y(?:es)?$') { Write-Host 'Cancelled.' -ForegroundColor Yellow; exit 0 } }
    Remove-Item -LiteralPath $OutputZip -Force
}

$StageRoot = Join-Path ([IO.Path]::GetTempPath()) ('Potplayer-LazyPack-' + [guid]::NewGuid().ToString('N'))
$StagePackage = Join-Path $StageRoot 'Potplayer'
try {
    New-Item -ItemType Directory -Path $StagePackage -Force | Out-Null
    Write-Stage 'Preparing runtime-only file list...'
    $SourceItems = @($IncludedNames | ForEach-Object {
        $itemPath = Join-Path $SourceRoot $_
        if (-not (Test-Path -LiteralPath $itemPath)) { Fail-Now "Required package item is missing: $_" }
        Get-Item -LiteralPath $itemPath
    })
    $FilesToCopy = @($SourceItems | ForEach-Object {
    if ($_.PSIsContainer) {
        Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Where-Object {
            $_.Name -notin @('.gitignore', 'README.md', 'README.MD') -and $_.FullName -notmatch '\\.git([\\/]|$)'
        }
    } else { $_ }
})
    $totalCopyBytes = [int64](($FilesToCopy | Measure-Object Length -Sum).Sum)
    $copyCount = $FilesToCopy.Count; $copyIndex = 0; $copiedBytes = [int64]0
    Write-Stage ("Copying {0:N0} files ({1:N1} MB)..." -f $copyCount, ($totalCopyBytes / 1MB))
    foreach ($file in $FilesToCopy) {
        $relative = $file.FullName.Substring($SourceRoot.Length).TrimStart('\')
        $destination = Join-Path $StagePackage $relative
        $destinationDir = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        $copyIndex++; $copiedBytes += [int64]$file.Length
        $percent = if ($totalCopyBytes) { [int][math]::Min(100, [math]::Round(($copiedBytes * 100) / $totalCopyBytes)) } else { 100 }
        Write-Progress -Activity 'Copying package files' -Status ("{0}/{1}  {2}" -f $copyIndex, $copyCount, $relative) -PercentComplete $percent
        if ($copyIndex -eq 1 -or $copyIndex -eq $copyCount -or $copyIndex % 25 -eq 0) { Write-Host ("[COPY {0,3}%] {1}/{2}  {3}" -f $percent, $copyIndex, $copyCount, $relative) }
    }
    Write-Progress -Activity 'Copying package files' -Completed
    Write-Host "[PASS] Copy stage complete: $copyCount files." -ForegroundColor Green

    Write-Stage 'Creating ZIP archive...'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($OutputZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $StageFiles = @(Get-ChildItem -LiteralPath $StageRoot -Recurse -File)
        $totalZipBytes = [int64](($StageFiles | Measure-Object Length -Sum).Sum); $zipCount = $StageFiles.Count; $zipIndex = 0; $zippedBytes = [int64]0
        foreach ($file in $StageFiles) {
            $entryName = $file.FullName.Substring($StageRoot.Length).TrimStart('\') -replace '\\', '/'
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            $zipIndex++; $zippedBytes += [int64]$file.Length
            $percent = if ($totalZipBytes) { [int][math]::Min(100, [math]::Round(($zippedBytes * 100) / $totalZipBytes)) } else { 100 }
            Write-Progress -Activity 'Compressing ZIP archive' -Status ("{0}/{1}  {2}" -f $zipIndex, $zipCount, $entryName) -PercentComplete $percent
            if ($zipIndex -eq 1 -or $zipIndex -eq $zipCount -or $zipIndex % 25 -eq 0) { Write-Host ("[ZIP  {0,3}%] {1}/{2}  {3}" -f $percent, $zipIndex, $zipCount, $entryName) }
        }
        Write-Progress -Activity 'Compressing ZIP archive' -Completed
    } finally { $archive.Dispose() }

    Write-Stage 'Verifying archive structure...'
    $archive = [IO.Compression.ZipFile]::OpenRead($OutputZip)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
        foreach ($path in @('Potplayer/Restore.cmd', 'Potplayer/Config/LAV.reg', 'Potplayer/Potplayer/PotPlayerMini64.exe', 'Potplayer/Potplayer/PotPlayerMini64.ini', 'Potplayer/madVR/settings.bin')) { if ($names -notcontains $path) { Fail-Now "Archive verification failed: missing $path" } }
        $badEntries = @($names | Where-Object { $_ -match '(^|/)\.git(/|$)' -or $_ -match '(^|/)(?:\.gitignore|README\.md|Restore\.log|Check-Package\.ps1)$' -or $_ -match '(^|/)(?:Backup-Before-Restore|Pack-LazyPack\.ps1|Pack-LazyPack\.cmd)(/|$)' })
        if ($badEntries.Count) { Fail-Now "Archive verification failed: excluded files were included: $($badEntries -join ', ')" }
    } finally { $archive.Dispose() }

    $zipInfo = Get-Item -LiteralPath $OutputZip; $hash = Get-FileHash -LiteralPath $OutputZip -Algorithm SHA256
    Write-Host ''; Write-Host '============================================================'; Write-Host ' PACK COMPLETE' -ForegroundColor Green; Write-Host '============================================================'
    Write-Host "Archive : $($zipInfo.FullName)"; Write-Host ("Size    : {0:N0} bytes" -f $zipInfo.Length); Write-Host "SHA-256 : $($hash.Hash)"; Write-Host ''
    exit 0
} catch { Write-Host "[FAIL] Packaging failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
finally { if (Test-Path -LiteralPath $StageRoot) { Remove-Item -LiteralPath $StageRoot -Recurse -Force -ErrorAction SilentlyContinue } }
