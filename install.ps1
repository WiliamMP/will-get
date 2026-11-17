# Installs the `will` command and then every app. After formatting the PC:
#   irm https://raw.githubusercontent.com/WiliamMP/will-get/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$dir = Join-Path $env:LOCALAPPDATA 'will'
New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest 'https://raw.githubusercontent.com/WiliamMP/will-get/main/will.ps1' -OutFile "$dir\will.ps1" -UseBasicParsing
# the shim bypasses the execution policy, which blocks scripts on a fresh Windows
Set-Content "$dir\will.cmd" '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0will.ps1" %*' -Encoding Ascii

$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($path -split ';') -notcontains $dir) { [Environment]::SetEnvironmentVariable('Path', "$path;$dir", 'User') }
$env:Path += ";$dir"

will install --all
