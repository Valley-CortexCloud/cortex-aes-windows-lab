<powershell>
# =====================================================================
# Koi/Cortex AES lab - machine bootstrap (runs once at first boot as SYSTEM)
# This ONLY does machine-level prep. The per-user "light-up" payload
# (IDE extensions, MCP configs, AI tools in the user profile) is meant to
# run interactively over RDP as the logged-in user, because Koi discovers
# per-user profiles and SYSTEM-installed per-user data would land in the
# wrong profile.
# =====================================================================
$ErrorActionPreference = "Continue"
$log = "C:\koi-lab-bootstrap.log"
function Log($m) { "$(Get-Date -Format o)  $m" | Tee-Object -FilePath $log -Append }

Log "Bootstrap starting."

# TLS 1.2 for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Long path support (some IDE extension trees are deep)
try {
  New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force | Out-Null
  Log "Enabled long paths."
} catch { Log "Long paths: $_" }

# Install Chocolatey
try {
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Log "Chocolatey installed."
  } else { Log "Chocolatey already present." }
} catch { Log "Chocolatey install failed: $_" }

$choco = "C:\ProgramData\chocolatey\bin\choco.exe"

# git (so the user can clone this repo on the box if they want)
try {
  & $choco install git -y --no-progress
  Log "git installed."
} catch { Log "git install failed: $_" }

# A convenience marker the user sees on the desktop
$readme = @"
Koi / Cortex AES lab box
========================
Machine prep ran at boot (log: C:\koi-lab-bootstrap.log).

NEXT: open an elevated PowerShell as THIS user and run the light-up payload:
  1. git clone <your repo>  (or copy the 'provisioning' folder over RDP)
  2. cd provisioning
  3. powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

Then deploy Koi from the 'koi' folder and validate in the AES console.
"@
Set-Content -Path "C:\Users\Public\Desktop\KOI-LAB-README.txt" -Value $readme -Force

Log "Bootstrap complete."
</powershell>
<persist>false</persist>
