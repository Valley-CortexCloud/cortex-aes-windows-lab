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

Write-Host @"

AIDR will stay EMPTY until a supported coding agent actually RUNS a task.
Claude Desktop chats do NOT count. To generate a session:

  1. Authenticate once:   claude     (then /login, or set ANTHROPIC_API_KEY)
  2. Run a task that uses a tool, e.g.:
       claude -p "create a file koi-test.txt containing hello from the koi lab" --dangerously-skip-permissions

That fires Claude Code's hooks -> Koi records a session in Runtime Agent Activity,
governed by the enforcement policy Koi already deployed.

(--dangerously-skip-permissions is for this throwaway lab only; never use it on a
real workstation.)
"@ -ForegroundColor Cyan
