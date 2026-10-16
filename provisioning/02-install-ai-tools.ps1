<#
  02 - AI / agentic tools.
  These are the "AI tools and models on the endpoint" that Cortex AES is built to
  surface. We install a spread so discovery has variety:
    - Cursor      : AI-native VS Code fork (its own extension + MCP surface)
    - Windsurf    : AI-native IDE (Codeium)
    - Claude Desktop : hosts MCP servers via claude_desktop_config.json
    - Ollama      : local model runtime (local LLMs on the endpoint)
  Some of these have no Chocolatey package; we pull official installers directly.
  Any single download that fails is logged and skipped - keep going.
#>
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dl = "$env:TEMP\koi-lab-dl"; New-Item -ItemType Directory -Force -Path $dl | Out-Null

function Get-File($url, $out) {
  try { Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 120; return $true }
  catch { Write-Warning "Download failed: $url -> $_"; return $false }
}

# --- Ollama (has a choco pkg; fall back to installer) ---
Write-Host "Installing Ollama (local model runtime) ..." -ForegroundColor Yellow
choco install ollama -y --no-progress 2>$null
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  $o = "$dl\OllamaSetup.exe"
  if (Get-File "https://ollama.com/download/OllamaSetup.exe" $o) { Start-Process $o -ArgumentList "/VERYSILENT" -Wait }
}

# --- Cursor ---
Write-Host "Installing Cursor (AI IDE) ..." -ForegroundColor Yellow
$cur = "$dl\CursorSetup.exe"
# User-scope installer; /S or /VERYSILENT depending on build - try silent, else interactive.
if (Get-File "https://downloader.cursor.sh/windows/nsis/x64" $cur) {
  Start-Process $cur -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
}

# --- Windsurf (Codeium) ---
Write-Host "Installing Windsurf (AI IDE) ..." -ForegroundColor Yellow
$ws = "$dl\WindsurfSetup.exe"
if (Get-File "https://windsurf.com/download/windows" $ws) {
  Start-Process $ws -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
}

# --- Claude Desktop (hosts MCP servers) ---
Write-Host "Installing Claude Desktop ..." -ForegroundColor Yellow
$cd = "$dl\ClaudeSetup.exe"
if (Get-File "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe" $cd) {
  Start-Process $cd -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
}

Write-Host @"

NOTE: Download URLs for AI IDEs change often. If any install above was skipped,
grab the current installer by hand on the box - the lab only needs the apps and
their config/extension footprint present on disk for Koi to discover. The MCP
config step (04) writes configs for Claude Desktop, Cursor and VS Code whether
or not the GUI apps launched.
"@ -ForegroundColor DarkYellow
