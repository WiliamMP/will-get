# Installs only the `will` command; apps are installed one by one with it. After formatting the PC:
#   irm https://raw.githubusercontent.com/WiliamMP/will-get/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$dir = Join-Path $env:LOCALAPPDATA 'will'
New-Item -ItemType Directory -Force $dir | Out-Null
# Saved as will-get.ps1, not will.ps1: PowerShell would pick a will.ps1 over will.cmd
# and the execution policy blocks it on a fresh Windows. The shim runs it with Bypass.
Invoke-WebRequest 'https://raw.githubusercontent.com/WiliamMP/will-get/main/will.ps1' -OutFile "$dir\will-get.ps1" -UseBasicParsing
Set-Content "$dir\will.cmd" '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0will-get.ps1" %*' -Encoding Ascii
Remove-Item "$dir\will.ps1" -ErrorAction SilentlyContinue # from older installs

$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($path -split ';') -notcontains $dir) { [Environment]::SetEnvironmentVariable('Path', "$path;$dir", 'User') }
$env:Path += ";$dir"

Write-Host "will instalado. Abra um terminal novo e use: will list | will install <app> | will install --all"
