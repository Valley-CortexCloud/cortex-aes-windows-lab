<#
.SYNOPSIS
  Orchestrates the "light-up" payload for the Koi / Cortex AES lab.

.DESCRIPTION
  Runs each provisioning step in order. Intended to be run OVER RDP, as the
  logged-in interactive user, from an ELEVATED PowerShell. Koi discovers
  per-user artifacts (IDE extensions, MCP configs, browser extensions, AI
  tools), so running as the real user populates the profiles Koi will scan.

.NOTES
  Safe to re-run. Each step is idempotent-ish (installers skip if present).
#>
[CmdletBinding()]
param(
  [switch]$SkipBase,        # skip base app installs (choco apps)
  [switch]$SkipAITools,     # skip Cursor/Windsurf/Claude Desktop/Ollama
  [switch]$SkipExtensions,  # skip VSCode + browser extensions
  [switch]$SkipMcp,         # skip MCP server configs
  [switch]$InventoryOnly    # only (re)generate expected-inventory.json
)

$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Section($t) { Write-Host "`n==================== $t ====================" -ForegroundColor Cyan }

# Elevation check
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Write-Warning "Not elevated. Browser force-install (registry) and some installs will fail. Re-run as Administrator."
}

if ($InventoryOnly) {
  & "$here\05-inventory.ps1"
  return
}

if (-not $SkipBase)       { Section "01 Base apps";        & "$here\01-install-base.ps1" }
if (-not $SkipAITools)    { Section "02 AI tools";         & "$here\02-install-ai-tools.ps1" }
if (-not $SkipExtensions) { Section "03 Extensions";       & "$here\03-install-extensions.ps1" }
if (-not $SkipMcp)        { Section "04 MCP servers";      & "$here\04-configure-mcp.ps1" }

Section "05 Inventory (ground truth for what Koi SHOULD find)"
& "$here\05-inventory.ps1"

Write-Host "`nLight-up payload complete." -ForegroundColor Green
Write-Host "Compare expected-inventory.json against what shows up in the AES console." -ForegroundColor Green
