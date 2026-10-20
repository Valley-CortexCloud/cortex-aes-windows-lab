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

Write-Host @"

AIDR will stay EMPTY until a supported coding agent actually RUNS a task.
Claude Desktop chats do NOT count. Generate a session with whichever you have creds for:

  FREE (Gemini - free API key, no card. NOTE: 'Sign in with Google' is deprecated
  for Gemini CLI; use a free API key from https://aistudio.google.com/apikey in a
  project with billing OFF):
    `$env:GEMINI_API_KEY = "AIza...your-free-key..."
    gemini -p "create a file koi-test.txt with 'hello from the koi lab'" --yolo

  Or Claude Code (needs Anthropic API key / subscription):
    claude                                          # then /login
    claude -p "create a file koi-test.txt with hello" --dangerously-skip-permissions

Either fires the agent's hooks -> Koi records a session in Runtime Agent Activity,
governed by the enforcement policy Koi already deployed.

(--yolo / --dangerously-skip-permissions auto-approve actions - lab use only.)
"@ -ForegroundColor Cyan
