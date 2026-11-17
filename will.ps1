# will: installs and updates WiliamMP's apps from their GitHub releases.
# An app is any repo of the owner with the "will-app" topic; it installs the
# -setup.exe of the latest release silently (NSIS /S, per user, no admin).
#
#   will list                 apps, installed and latest version
#   will install <app>...     install or reinstall
#   will install --all
#   will update               update will itself, then newer versions of what is installed
#   will uninstall <app>...   remove (silent uninstaller); --all removes every installed app

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Invoke-WebRequest is very slow with the progress bar on
$owner = 'WiliamMP'
$api = 'https://api.github.com'
$cmd, $apps = $args

# the one API call per command; GITHUB_TOKEN, if set, lifts the 60/hour limit
# The last good list is kept next to the script and used when the API fails.
function Get-Catalog {
  $cache = Join-Path $PSScriptRoot 'catalog.txt'
  $headers = @{}
  if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
  try {
    $names = Invoke-RestMethod "$api/users/$owner/repos?per_page=100" -Headers $headers |
      ForEach-Object { $_ } | Where-Object { $_.topics -contains 'will-app' } | ForEach-Object { $_.name } | Sort-Object
    Set-Content $cache $names
    $names
  } catch {
    if (-not (Test-Path $cache)) { throw "GitHub indisponível e sem lista salva: $($_.Exception.Message)" }
    Write-Warning 'GitHub API indisponível (limite de 60/hora?), usando a última lista salva'
    Get-Content $cache
  }
}

# the uninstall entry the NSIS installer writes (version and uninstaller path)
function Get-Entry($name) {
  $keys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $name } | Select-Object -First 1
}

function Get-Installed($name) {
  $k = Get-Entry $name
  if ($k) { $k.DisplayVersion }
}

function Uninstall-App($name) {
  $k = Get-Entry $name
  if (-not $k) { Write-Warning "${name}: não está instalado"; return }
  Write-Host "${name} $($k.DisplayVersion): desinstalando"
  # ponytail: the NSIS uninstaller relaunches itself from %TEMP%, so -Wait returns before it finishes
  Start-Process $k.UninstallString.Trim('"') -ArgumentList '/S' -Wait
}

# Not the API (60 requests/hour without login): github.com/<repo>/releases/latest
# redirects to .../releases/tag/<tag>, and the Tauri setup is named <app>_<version>_x64-setup.exe.
# ponytail: assumes productName == repo name; read the release assets via the API if one differs
function Get-Latest($name) {
  try { $r = Invoke-WebRequest "https://github.com/$owner/$name/releases/latest" -Method Head -UseBasicParsing } catch { return $null }
  $uri = if ($r.BaseResponse.ResponseUri) { $r.BaseResponse.ResponseUri } else { $r.BaseResponse.RequestMessage.RequestUri } # 5.1 / 7
  if ("$uri" -notmatch '/releases/tag/(.+)$') { return $null } # no release yet
  $tag = $Matches[1]
  $version = $tag.TrimStart('v')
  $file = "${name}_${version}_x64-setup.exe"
  [pscustomobject]@{ Version = $version; Url = "https://github.com/$owner/$name/releases/download/$tag/$file"; File = $file }
}

function Install-App($name, $latest) {
  if (-not $latest) { $latest = Get-Latest $name }
  if (-not $latest) { Write-Warning "${name}: nenhuma release com -setup.exe"; return }
  $exe = Join-Path $env:TEMP $latest.File
  Write-Host "${name} $($latest.Version): baixando"
  Invoke-WebRequest $latest.Url -OutFile $exe -UseBasicParsing
  Write-Host "${name} $($latest.Version): instalando"
  $p = Start-Process $exe -ArgumentList '/S' -Wait -PassThru
  Remove-Item $exe
  if ($p.ExitCode) { Write-Warning "${name}: instalador saiu com codigo $($p.ExitCode)" }
}

$catalog = @(Get-Catalog)
switch ($cmd) {
  'list' {
    $catalog | ForEach-Object {
      $l = Get-Latest $_
      $have = Get-Installed $_
      [pscustomobject]@{
        App       = $_
        Instalado = $(if ($have) { $have } else { '-' })
        Ultima    = $(if ($l) { $l.Version } else { 'sem release' })
      }
    } | Format-Table -AutoSize
  }
  'install' {
    if ($apps -contains '--all') { $apps = $catalog }
    if (-not $apps) { throw 'uso: will install <app>... | will install --all' }
    foreach ($n in $apps) {
      if ($catalog -notcontains $n) { Write-Warning "${n}: não existe (veja: will list)"; continue }
      Install-App $n
    }
  }
  'update' {
    # self-update first; only the installed copy, never a checkout of the repo.
    # Safe while running: PowerShell has already read the whole script.
    if ($PSScriptRoot -eq (Join-Path $env:LOCALAPPDATA 'will')) {
      $self = $PSCommandPath
      $new = "$self.new" # bytes straight to a file: .Content would be decoded as Latin-1 on 5.1
      Invoke-WebRequest 'https://raw.githubusercontent.com/WiliamMP/will-get/main/will.ps1' -OutFile $new -UseBasicParsing
      $b64 = { param($f) [Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) } # Get-FileHash fails on 5.1 started from pwsh 7
      if ((& $b64 $new) -ne (& $b64 $self)) {
        Move-Item $new $self -Force
        Write-Host 'will atualizado'
      } else { Remove-Item $new }
    }
    $n = 0
    foreach ($app in $catalog) {
      $have = Get-Installed $app
      if (-not $have) { continue }
      $l = Get-Latest $app
      # ponytail: plain x.y.z tags only; a "-beta" suffix breaks [version]
      if ($l -and [version]$l.Version -gt [version]$have) { Install-App $app $l; $n++ }
    }
    if (-not $n) { Write-Host 'tudo atualizado' }
  }
  'uninstall' {
    if ($apps -contains '--all') { $apps = $catalog | Where-Object { Get-Installed $_ } }
    if (-not $apps) { throw 'uso: will uninstall <app>... | will uninstall --all' }
    foreach ($n in $apps) { Uninstall-App $n }
  }
  default { 'uso: will list | will install <app>... | will install --all | will update | will uninstall <app>...' }
}
