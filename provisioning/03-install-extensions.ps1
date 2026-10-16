<#
  03 - IDE + browser extensions.
  These are the highest-signal artifacts for Cortex AES discovery and risk
  scoring. We install a deliberate spread:
    - VS Code extensions via the `code` CLI (lands in %USERPROFILE%\.vscode\extensions)
    - Browser extensions via the enterprise force-install registry policy, which
      is the realistic silent-deploy method and lands files in the user profile.
  Pick a mix of benign and broad-permission items so the AES risk engine has
  something interesting to score. (All IDs below are well-known public extensions.)
#>
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# VS Code extensions
# ---------------------------------------------------------------------------
$code = Get-Command code -ErrorAction SilentlyContinue
if (-not $code) {
  $guess = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
  if (Test-Path $guess) { $code = $guess } else { $code = $null }
}

$vscodeExtensions = @(
  "ms-python.python",            # Python
  "github.copilot",              # AI pair programmer
  "github.copilot-chat",         # AI chat
  "continue.continue",           # open-source AI coding agent (MCP-capable)
  "eamodio.gitlens",             # broad repo access
  "ms-azuretools.vscode-docker", # docker
  "redhat.vscode-yaml",          # yaml
  "rangav.vscode-thunder-client" # HTTP client (network-capable)
)

if ($code) {
  foreach ($ext in $vscodeExtensions) {
    Write-Host "code --install-extension $ext" -ForegroundColor Yellow
    & $code --install-extension $ext --force 2>$null
  }
} else {
  Write-Warning "VS Code CLI not found; skipping VS Code extensions. Install VS Code (01) first."
}

# Cursor shares the VS Code extension model; install the same set if its CLI exists.
$cursor = Get-Command cursor -ErrorAction SilentlyContinue
if ($cursor) {
  foreach ($ext in @("ms-python.python","continue.continue","eamodio.gitlens")) {
    & cursor --install-extension $ext --force 2>$null
  }
}

# ---------------------------------------------------------------------------
# Browser extensions via enterprise force-install policy (requires admin)
# ---------------------------------------------------------------------------
# Chrome Web Store IDs. Format for the registry value: "<id>;<update-url>"
$chromeStoreUpdate = "https://clients2.google.com/service/update2/crx"
$chromeExtensions = @(
  "cjpalhdlnbpafiamejdnhcphjbkeiagm", # uBlock Origin
  "nngceckbapebfimnlniiiahkandclblb", # Bitwarden (password manager - broad perms)
  "aapbdbdomjkkjkaonfhkkikfgjllcleb", # Google Translate
  "bcjindcccaagfpapjjmafapmmgkkhgoa", # JSON Formatter
  "fmkadmapgofadopljbjfkapdkoienihi"  # React Developer Tools
)

function Set-ForceList($regPath, $ids, $updateUrl) {
  New-Item -Path $regPath -Force | Out-Null
  $i = 1
  foreach ($id in $ids) {
    New-ItemProperty -Path $regPath -Name "$i" -Value "$id;$updateUrl" -PropertyType String -Force | Out-Null
    $i++
  }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
  Write-Host "Writing Chrome force-install policy ..." -ForegroundColor Yellow
  Set-ForceList "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" $chromeExtensions $chromeStoreUpdate

  # Edge can also force-install from the Chrome Web Store update endpoint.
  Write-Host "Writing Edge force-install policy ..." -ForegroundColor Yellow
  Set-ForceList "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" $chromeExtensions $chromeStoreUpdate

  Write-Host @"
Browser policies written. The extensions install SILENTLY the next time Chrome/Edge
is launched by this user (give it ~1 min after launch). Launch each browser once so
the files land in the profile, then run 05-inventory.ps1.
"@ -ForegroundColor Green
} else {
  Write-Warning "Not elevated - skipped browser force-install registry. Re-run elevated for browser coverage."
}
