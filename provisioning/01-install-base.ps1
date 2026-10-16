<#
  01 - Base applications.
  Browsers + IDEs + runtimes. These are the "hosts" that the agentic artifacts
  (extensions, MCP configs) live inside, and several are themselves discovered
  by Koi (VS Code, the browsers).
#>
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-Choco {
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path += ";C:\ProgramData\chocolatey\bin"
  }
}

Ensure-Choco

# Core "host" apps. Edge ships with Windows; we add Chrome + Firefox for broader
# browser-extension coverage, VS Code as the primary IDE, plus runtimes.
$packages = @(
  "googlechrome",
  "firefox",
  "vscode",
  "nodejs-lts",
  "python",
  "git",
  "7zip"
)

foreach ($p in $packages) {
  Write-Host "Installing $p ..." -ForegroundColor Yellow
  choco install $p -y --no-progress --ignore-checksums
}

# Refresh PATH for this session so `code`, `node`, `npx`, `python` resolve
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Base install done. Versions:" -ForegroundColor Green
foreach ($c in @("code","node","npx","python","git")) {
  $v = (& $c --version 2>$null) -join ' '
  Write-Host ("  {0,-8} {1}" -f $c, $v)
}
