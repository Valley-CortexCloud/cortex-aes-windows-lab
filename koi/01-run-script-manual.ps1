<#
  METHOD 1 (Agentless) - run the Koi script package by hand.
  Best for LEARNING: you watch exactly what the discovery/remediation script does
  on a single run, with a full transcript. This mirrors the "Agentless (Koi script
  package)" deployment, except you're the scheduler instead of an MDM/EDR.

  PREREQUISITES
    - Run elevated (Administrator). On Windows the Koi PowerShell wrapper manages
      UAC/admin and pulls a signed WinPython to run the Python package.
    - Place the script you downloaded from the AES portal at koi\artifacts\mdm.ps1
      (Settings -> Deployment -> Agentless -> Download).

  WHAT TO WATCH
    - First run downloads WinPython (portable, signed) -> expect a one-time delay.
    - Discovery enumerates user profiles for IDE/browser extensions, MCP configs,
      AI tools. Network-config deployment (PAC/hosts) is OFF by default.
#>
[CmdletBinding()]
param(
  [string]$CustomerId   = $env:KOI_CUSTOMER_ID,
  [string]$CustomerSlug = $env:KOI_CUSTOMER_SLUG,
  [string]$ScriptPath   = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\artifacts\mdm.ps1"
)

$ErrorActionPreference = "Stop"

if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
  throw "Run this elevated (Administrator)."
}
if (-not (Test-Path $ScriptPath)) {
  throw "Koi script not found at $ScriptPath. Download it from the AES portal (Agentless) into koi\artifacts\."
}

$ts  = Get-Date -Format "yyyyMMdd-HHmmss"
$log = "$(Split-Path -Parent $ScriptPath)\..\run-$ts.transcript.log"
Start-Transcript -Path $log -Force | Out-Null

Write-Host "Running Koi script package (manual/agentless) ..." -ForegroundColor Cyan
Write-Host "  script : $ScriptPath"
Write-Host "  log    : $log"

# Pass customer identifiers if your portal script accepts them as params; harmless
# if it reads them from an embedded config instead.
$argList = @()
if ($CustomerId)   { $argList += @("-CustomerId", $CustomerId) }
if ($CustomerSlug) { $argList += @("-CustomerSlug", $CustomerSlug) }

$sw = [Diagnostics.Stopwatch]::StartNew()
powershell.exe -ExecutionPolicy Bypass -File $ScriptPath @argList
$sw.Stop()

Write-Host ("Run finished in {0:n1}s. Review transcript: {1}" -f $sw.Elapsed.TotalSeconds, $log) -ForegroundColor Green
Stop-Transcript | Out-Null

Write-Host "`nNow check Settings -> Deployment in the AES console: this host should report in." -ForegroundColor Yellow
