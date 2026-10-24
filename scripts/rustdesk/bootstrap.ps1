[CmdletBinding()]
param(
  [string]$ConfigPath = $env:RUSTDESK_CONFIG_FILE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DotfilesRepository = 'DotNaos/dotfiles'
$DotfilesRef = if ($env:RUSTDESK_DOTFILES_REF) { $env:RUSTDESK_DOTFILES_REF } else { 'main' }
$ScriptUrl = "https://raw.githubusercontent.com/$DotfilesRepository/$DotfilesRef/scripts/rustdesk/bootstrap.ps1"
$ConfigUrl = "https://raw.githubusercontent.com/$DotfilesRepository/$DotfilesRef/config/rustdesk.env"
$ReleaseApi = 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest'

function Write-Log {
  param([string]$Message)
  Write-Host "[rustdesk] $Message"
}

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Enter-Administrator {
  if (Test-Administrator) {
    return $false
  }

  $scriptPath = $PSCommandPath
  if (-not $scriptPath) {
    $scriptPath = Join-Path ([IO.Path]::GetTempPath()) 'dotfiles-rustdesk-bootstrap.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $ScriptUrl -OutFile $scriptPath
  }

  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
  if ($ConfigPath) {
    $arguments += @('-ConfigPath', "`"$ConfigPath`"")
  }
  $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Elevated RustDesk bootstrap failed with exit code $($process.ExitCode)."
  }
  return $true
}

function Read-RepositoryConfig {
  param([string]$Path)

  if (-not $Path) {
    if ($PSScriptRoot) {
      $candidate = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'config\rustdesk.env'
      if (Test-Path $candidate) {
        $Path = $candidate
      }
    }
  }

  if (-not $Path) {
    $Path = Join-Path ([IO.Path]::GetTempPath()) 'dotfiles-rustdesk.env'
    Write-Log "Loading public configuration from $ConfigUrl"
    Invoke-WebRequest -UseBasicParsing -Uri $ConfigUrl -OutFile $Path
  }

  if (-not (Test-Path $Path)) {
    throw "RustDesk config not found: $Path"
  }

  $values = @{}
  foreach ($line in Get-Content $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
      continue
    }
    $parts = $trimmed -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }
    $values[$parts[0].Trim()] = $parts[1].Trim().Trim([char[]]"'`"")
  }
  return $values
}

function Get-ConfigValue {
  param(
    [hashtable]$RepositoryConfig,
    [string]$EnvironmentName,
    [string]$RepositoryName
  )

  $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
  if ($environmentValue) {
    return $environmentValue
  }
  if ($RepositoryConfig.ContainsKey($RepositoryName)) {
    return [string]$RepositoryConfig[$RepositoryName]
  }
  return ''
}

function Invoke-RustDesk {
  param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)

  $output = & $script:RustDeskBinary @Arguments | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "RustDesk CLI failed: $($Arguments -join ' ')"
  }
  return $output.Trim()
}

function Wait-ForCondition {
  param(
    [scriptblock]$Condition,
    [string]$FailureMessage,
    [int]$Attempts = 30
  )

  foreach ($attempt in 1..$Attempts) {
    if (& $Condition) {
      return
    }
    Start-Sleep -Seconds 2
  }
  throw $FailureMessage
}

if (Enter-Administrator) {
  return
}
$repositoryConfig = Read-RepositoryConfig -Path $ConfigPath
$configString = Get-ConfigValue $repositoryConfig 'RUSTDESK_CONFIG_STRING' 'RUSTDESK_REPO_CONFIG_STRING'
$idServer = Get-ConfigValue $repositoryConfig 'RUSTDESK_ID_SERVER' 'RUSTDESK_REPO_ID_SERVER'
$relayServer = Get-ConfigValue $repositoryConfig 'RUSTDESK_RELAY_SERVER' 'RUSTDESK_REPO_RELAY_SERVER'
$publicKey = Get-ConfigValue $repositoryConfig 'RUSTDESK_PUBLIC_KEY' 'RUSTDESK_REPO_PUBLIC_KEY'

if (-not $configString -and (-not $idServer -or -not $publicKey)) {
  throw 'Set RUSTDESK_CONFIG_STRING, or configure both RUSTDESK_ID_SERVER and RUSTDESK_PUBLIC_KEY.'
}

$release = Invoke-RestMethod -Uri $ReleaseApi
$version = [string]$release.tag_name
$architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$assetArchitecture = switch ($architecture) {
  'X64' { 'x86_64' }
  'Arm64' { 'aarch64' }
  default { throw "Unsupported Windows architecture: $architecture" }
}
$assetName = "rustdesk-$version-$assetArchitecture.exe"
$asset = $release.assets | Where-Object name -eq $assetName | Select-Object -First 1
if (-not $asset) {
  throw "RustDesk release asset not found: $assetName"
}

$script:RustDeskBinary = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
$installedVersion = ''
if (Test-Path $script:RustDeskBinary) {
  $installedVersion = Invoke-RustDesk '--version'
}

if ($installedVersion -eq $version) {
  Write-Log "RustDesk $version is already installed."
} else {
  $installer = Join-Path ([IO.Path]::GetTempPath()) $assetName
  Write-Log "Downloading RustDesk $version ($assetName)."
  Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $installer
  Start-Process -FilePath $installer -ArgumentList '--silent-install' -Wait
  Wait-ForCondition { Test-Path $script:RustDeskBinary } 'RustDesk binary was not installed.'
}

$service = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
if (-not $service) {
  Invoke-RustDesk '--install-service' | Out-Null
  Wait-ForCondition { $null -ne (Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue) } 'RustDesk service was not installed.'
}
Set-Service -Name 'RustDesk' -StartupType Automatic
Start-Service -Name 'RustDesk'

$actualVersion = Invoke-RustDesk '--version'
if ($actualVersion -ne $version) {
  throw "Expected RustDesk $version, found $actualVersion."
}
Write-Log "Verified RustDesk CLI version $actualVersion."

if ($configString) {
  Invoke-RustDesk '--config' $configString | Out-Null
} else {
  Invoke-RustDesk '--option' 'custom-rendezvous-server' $idServer | Out-Null
  Invoke-RustDesk '--option' 'relay-server' $relayServer | Out-Null
  Invoke-RustDesk '--option' 'key' $publicKey | Out-Null
}

if ($env:RUSTDESK_PASSWORD) {
  Invoke-RustDesk '--password' $env:RUSTDESK_PASSWORD | Out-Null
}

$currentIdServer = Invoke-RustDesk '--option' 'custom-rendezvous-server'
$currentKey = Invoke-RustDesk '--option' 'key'
if (-not $currentIdServer) {
  throw 'RustDesk did not apply an ID server.'
}
if (-not $currentKey) {
  throw 'RustDesk did not apply a public server key.'
}
if (-not $configString -and $currentIdServer -ne $idServer) {
  throw 'RustDesk ID server verification failed.'
}
if (-not $configString -and $currentKey -ne $publicKey) {
  throw 'RustDesk public key verification failed.'
}

Restart-Service -Name 'RustDesk'
Wait-ForCondition { (Get-Service -Name 'RustDesk').Status -eq 'Running' } 'RustDesk service is not running.'

$deviceId = ''
foreach ($attempt in 1..10) {
  $deviceId = Invoke-RustDesk '--get-id'
  if ($deviceId -and $deviceId -ne '0') {
    break
  }
  Start-Sleep -Seconds 2
}
if (-not $deviceId -or $deviceId -eq '0') {
  throw 'RustDesk did not return a device ID.'
}
Write-Output "RustDesk ID: $deviceId"
