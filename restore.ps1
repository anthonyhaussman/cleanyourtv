# Automated restore script for Chromecast with Google TV (Sabrina 4K / Boreal HD) on Windows PowerShell.
# Restores disabled packages, re-enables stock launcher (launcherx), and restores Home activity.
#
# Usage:
#   .\restore.ps1 -TvHost 192.168.1.19 [-List debloat.txt]
#   .\restore.ps1 192.168.1.19

param(
    [Parameter(Position = 0)][string]$TvHost = $env:TV_HOST,
    [Parameter(Position = 1)][string]$List
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$repo = $PSScriptRoot

if (-not $TvHost) {
    throw "Set TV_HOST or pass -TvHost <tv_ip>. Usage: .\restore.ps1 -TvHost 192.168.1.19 [-List debloat.txt]"
}
$env:TV_HOST = $TvHost

$py = Join-Path $repo 'tools\venv\Scripts\python.exe'
if (-not (Test-Path $py)) {
    $py = 'python'
}

$StockLauncher = 'com.google.android.apps.tv.launcherx'

Write-Host "=== CleanYourTV Restore Script ==="
Write-Host "Target TV: $TvHost"
Write-Host "Stock Launcher: $StockLauncher"

if ($List -and (Test-Path $List)) {
    Write-Host "Restoring packages from: $List"
    & (Join-Path $repo 'tools\restore.ps1') -TvHost $TvHost -List $List -Stock $StockLauncher
} else {
    Write-Host "Restoring stock launcher and default home..."
    & $py -I (Join-Path $repo 'tools\tv.py') "pm enable --user 0 $StockLauncher"
    & $py -I (Join-Path $repo 'tools\tv.py') "cmd package set-home-activity $StockLauncher/.MainActivity"
    & $py -I (Join-Path $repo 'tools\tv.py') "settings put global window_animation_scale 1.0"
    & $py -I (Join-Path $repo 'tools\tv.py') "settings put global transition_animation_scale 1.0"
    & $py -I (Join-Path $repo 'tools\tv.py') "settings put global animator_duration_scale 1.0"
}

Write-Host "Verifying home package resolution..."
$currentHome = & $py -I (Join-Path $repo 'tools\tv.py') "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME"
Write-Host "Current Home: $currentHome"
Write-Host "Restore completed successfully."
