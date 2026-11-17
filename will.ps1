# will: installs and updates WiliamMP's apps from their GitHub releases.
# An app is any repo of the owner with the "will-app" topic; it installs the
# -setup.exe of the latest release silently (NSIS /S, per user, no admin).
#
#   will list                 apps, installed and latest version
#   will install <app>...     install or reinstall
#   will install --all
#   will update               install newer versions of what is installed
#   will uninstall <app>...   remove (silent uninstaller); --all removes every installed app

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Invoke-WebRequest is very slow with the progress bar on
$owner = 'WiliamMP'
$api = 'https://api.github.com'
$cmd, $apps = $args

function Get-Catalog {
  Invoke-RestMethod "$api/users/$owner/repos?per_page=100" |
    ForEach-Object { $_ } | Where-Object { $_.topics -contains 'will-app' } | ForEach-Object { $_.name } | Sort-Object
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

function Get-Latest($name) {
  try { $r = Invoke-RestMethod "$api/repos/$owner/$name/releases/latest" } catch { return $null }
  $asset = $r.assets | Where-Object { $_.name -like '*-setup.exe' } | Select-Object -First 1
  if ($asset) { [pscustomobject]@{ Version = $r.tag_name.TrimStart('v'); Url = $asset.browser_download_url; File = $asset.name } }
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
