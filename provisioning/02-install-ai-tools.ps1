<#
  02 - AI / agentic tools.
  These are the "AI tools and models on the endpoint" that Cortex AES surfaces.
  We install a spread for discovery variety:
    - Ollama          : local model runtime (via Chocolatey - reliable)
    - Cursor          : AI-native VS Code fork
    - Windsurf        : AI-native IDE (Codeium)
    - Claude Desktop  : hosts MCP servers via claude_desktop_config.json

  DESIGN: every install here is BEST-EFFORT and BOUNDED. GUI installers get a
  hard timeout so a slow/hanging one can never stall the bootstrap (that was the
  original bug - Claude Desktop's launcher never exits under -Wait). Order of
  preference per tool: winget (if present) -> validated direct download -> skip.

  Even if a GUI app is skipped, step 04 still writes its MCP config file, so Koi
  has MCP artifacts to discover regardless.
#>
$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dl = "$env:TEMP\koi-lab-dl"; New-Item -ItemType Directory -Force -Path $dl | Out-Null

$haveWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

function Save-Url($url, $out) {
  # Download with a timeout; treat an HTML error page / tiny file as a failure.
  try {
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 120 -MaximumRedirection 5
  } catch {
    Write-Warning "  download failed: $url -> $($_.Exception.Message)"
    return $false
  }
  if (-not (Test-Path $out)) { return $false }
  $size = (Get-Item $out).Length
  if ($size -lt 500KB) {
    Write-Warning "  download looks bad (only $size bytes - likely a redirect/error page): $url"
    Remove-Item $out -Force -ErrorAction SilentlyContinue
    return $false
  }
  return $true
}

function Invoke-Installer($path, [string[]]$arguments, [int]$timeoutSec = 180) {
  # Run an installer but NEVER block forever. If it outlives the timeout, leave it
  # running in the background and move on.
  try {
    $p = Start-Process -FilePath $path -ArgumentList $arguments -PassThru -ErrorAction Stop
    if ($p.WaitForExit($timeoutSec * 1000)) {
      Write-Host "  installer exited (code $($p.ExitCode))."
    } else {
      Write-Warning "  installer still running after ${timeoutSec}s - continuing; it will finish in the background."
    }
  } catch {
    Write-Warning "  could not launch installer: $($_.Exception.Message)"
  }
}

function Try-Winget($id) {
  if (-not $haveWinget) { return $false }
  Write-Host "  winget install $id ..." -ForegroundColor DarkCyan
  try {
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

# --- Ollama (Chocolatey is reliable here) ---
Write-Host "Installing Ollama (local model runtime) ..." -ForegroundColor Yellow
choco install ollama -y --no-progress 2>$null
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  if (-not (Try-Winget "Ollama.Ollama")) { Write-Warning "Ollama not installed - skipping (non-fatal)." }
}

# --- Cursor ---
Write-Host "Installing Cursor (AI IDE) ..." -ForegroundColor Yellow
if (-not (Try-Winget "Anysphere.Cursor")) {
  $cur = "$dl\CursorSetup.exe"
  if (Save-Url "https://www.cursor.com/api/download?platform=win32-x64-user&releaseTrack=stable" $cur) {
    Invoke-Installer $cur @("/VERYSILENT","/NORESTART") 180
  } else {
    Write-Warning "Cursor skipped - install manually if you want it (its MCP config is still written in step 04)."
  }
}

# --- Windsurf (Codeium) ---
Write-Host "Installing Windsurf (AI IDE) ..." -ForegroundColor Yellow
if (-not (Try-Winget "Codeium.Windsurf")) {
  Write-Warning "Windsurf skipped - no winget package found and direct URLs are unstable. Install manually if desired (non-fatal for the lab)."
}

# --- Claude Desktop (Squirrel installer: silent by default, then launches app) ---
Write-Host "Installing Claude Desktop ..." -ForegroundColor Yellow
if (-not (Try-Winget "Anthropic.ClaudeForDesktop")) {
  $cd = "$dl\ClaudeSetup.exe"
  if (Save-Url "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe" $cd) {
    # No -Wait: this is a Squirrel installer that launches the app and does not
    # exit cleanly. Bounded wait handles it.
    Invoke-Installer $cd @() 120
    # The installer auto-launches Claude; close the window so the lab box stays tidy.
    Start-Sleep -Seconds 5
    Get-Process "claude" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  } else {
    Write-Warning "Claude Desktop skipped (its MCP config is still written in step 04)."
  }
}

Write-Host "`nAI-tools step complete (best-effort installs; any skips above are non-fatal)." -ForegroundColor Green
