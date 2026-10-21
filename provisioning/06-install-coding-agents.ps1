<#
  06 - AI CODING AGENTS (for Runtime Agent Activity / AIDR).

  Koi's Runtime Agent Activity (AIDR) captures *coding agent* sessions via each
  agent's NATIVE HOOKS - every shell command, file access, and MCP tool call,
  correlated into the session that produced it.

  IMPORTANT: Claude DESKTOP (the chat app we installed in step 02) is NOT a
  coding agent and generates NO AIDR activity. The supported agents are Cursor,
  Claude Code, Codex CLI, GitHub Copilot CLI, Kiro, and Antigravity.

  This step installs the Claude Code CLI (Koi already deploys its enforcement
  hooks), so you can generate real agent sessions. See
  use-cases/aidr-runtime-activity.md for how to produce a session.
#>
$ErrorActionPreference = "Continue"

# Make sure npm (from step 01 / nodejs-lts) is on PATH for this session.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Warning "npm not found - run 01-install-base.ps1 first (installs Node.js). Skipping coding agents."
  return
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Host "Claude Code CLI already installed - skipping." -ForegroundColor DarkGray
} else {
  Write-Host "Installing Claude Code CLI (npm -g @anthropic-ai/claude-code) ..." -ForegroundColor Yellow
  # --allow-scripts lets the package's own postinstall run (npm blocks it by
  # default now). Capture combined output as strings so npm's stderr warnings
  # don't surface as a red PowerShell NativeCommandError.
  $npmOut = cmd /c "npm install -g --allow-scripts=@anthropic-ai/claude-code 2>&1"
  $npmOut | ForEach-Object { Write-Host "  $_" }
  # Refresh PATH so the freshly-installed global bin resolves this session.
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Host ("Claude Code CLI: " + ((claude --version 2>$null) -join ' ')) -ForegroundColor Green
} else {
  Write-Warning "Claude Code CLI not on PATH yet - open a NEW shell and check 'claude --version'."
}

# --- Gemini CLI (FREE with a personal Google account - best no-cost demo path) ---
if (Get-Command gemini -ErrorAction SilentlyContinue) {
  Write-Host "Gemini CLI already installed - skipping." -ForegroundColor DarkGray
} else {
  Write-Host "Installing Gemini CLI (npm -g @google/gemini-cli) - FREE tier, ~1000 req/day ..." -ForegroundColor Yellow
  $gOut = cmd /c "npm install -g --allow-scripts=@google/gemini-cli 2>&1"
  $gOut | ForEach-Object { Write-Host "  $_" }
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
}
if (Get-Command gemini -ErrorAction SilentlyContinue) {
  Write-Host ("Gemini CLI: " + ((gemini --version 2>$null) -join ' ')) -ForegroundColor Green
} else {
  Write-Warning "Gemini CLI not on PATH yet - open a NEW shell and check 'gemini --version'."
}

# --- Antigravity (FREE agentic IDE - the ONLY free agent that reports to Koi) ---
# NOTE: install is automated via winget, but the Google-account SIGN-IN is manual
# and interactive (and required - an API-key session silently disables Koi hooks).
$agInstalled = (Test-Path "$env:LOCALAPPDATA\Programs\Antigravity\Antigravity.exe") -or
               (Test-Path "$env:LOCALAPPDATA\Antigravity") -or
               (Test-Path "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe")
if ($agInstalled) {
  Write-Host "Antigravity already installed - skipping." -ForegroundColor DarkGray
} else {
  Write-Host "Installing Antigravity (winget Google.Antigravity) ..." -ForegroundColor Yellow
  if (-not (Try-Winget "Google.Antigravity")) {
    Write-Warning "Antigravity not installed (winget unavailable or failed). Download from https://antigravity.google - it's the FREE path that reports to Koi (needs Google-account login, NOT an API key)."
  }
}

Write-Host @"

AIDR will stay EMPTY until a supported coding agent actually RUNS a task.
Claude Desktop chats do NOT count. Generate a session with whichever you have creds for:

  *** CRITICAL KOI GOTCHA ***
  A GEMINI_API_KEY session loads Koi's hooks but NEVER dispatches them - so any
  Gemini/Antigravity run on an API key reports NOTHING to Koi, with no error.
  Hook dispatch requires a GOOGLE ACCOUNT sign-in. And Gemini CLI's free Google
  login is deprecated. Net result: the only FREE agent that actually reports to
  Koi is Antigravity signed in with a Google account.

  FREE working path -> Antigravity (Google's free agentic IDE), GOOGLE ACCOUNT login:
    1. Install from https://antigravity.google   (do NOT set GEMINI_API_KEY/modeProvider)
    2. Sign in with a Google account (free)
    3. Ask it to read/edit a file -> hooks dispatch -> Koi records the session

  Paid path -> Claude Code (needs Anthropic creds). Deliver managed settings
  file-based; do NOT also set Claude Code settings in the claude.ai admin console,
  which overrides file-based settings and silently stops Koi's hooks:
    claude                                          # then /login
    claude -p "create a file koi-test.txt with hello" --dangerously-skip-permissions

(--dangerously-skip-permissions auto-approves actions - lab use only.)
"@ -ForegroundColor Cyan
