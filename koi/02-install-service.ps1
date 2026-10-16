<#
  METHOD 2 (Installed) - Koi Windows Service via MSI.
  Production-like: a native Windows Service (KoiService) self-schedules the script
  package (default hourly). Only initial deployment is needed.

  PREREQUISITES
    - Run elevated (Administrator).
    - Place the MSI you were provided at koi\artifacts\Koi.msi.
    - Have your CUSTOMERID and CUSTOMERSLUG from the AES portal.

  Ref: docs/koi-windows-agent.md
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CustomerId,
  [Parameter(Mandatory=$true)][string]$CustomerSlug,
  [int]$IntervalMinutes = 0,   # 0 = leave default (60). Set e.g. 5 for fast lab feedback.
  [string]$MsiPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\artifacts\Koi.msi"
)

$ErrorActionPreference = "Stop"
if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
  throw "Run this elevated (Administrator)."
}
if (-not (Test-Path $MsiPath)) { throw "Koi.msi not found at $MsiPath." }

$logDir = Split-Path -Parent $MsiPath
$instLog = "$logDir\..\msi-install-$(Get-Date -Format yyyyMMdd-HHmmss).log"

$args = @("/i", "`"$MsiPath`"",
          "CUSTOMERID=`'$CustomerId`'",
          "CUSTOMERSLUG=`'$CustomerSlug`'")
if ($IntervalMinutes -gt 0) { $args += "INTERVAL=$IntervalMinutes" }
$args += @("/qn", "/l*v", "`"$instLog`"")

Write-Host "Installing KoiService ..." -ForegroundColor Cyan
Write-Host "  msiexec $($args -join ' ')"
$p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
Write-Host "msiexec exit code: $($p.ExitCode)  (0 or 3010 = success; 3010 = reboot advised)"

# Verify per docs/koi-windows-agent.md
Write-Host "`nVerifying install ..." -ForegroundColor Yellow
$ok = $true
if (Test-Path "C:\ProgramData\Koi") { Write-Host "  [ok] C:\ProgramData\Koi exists" } else { Write-Host "  [!!] C:\ProgramData\Koi missing"; $ok=$false }
foreach ($f in @("KoiService.exe","mdm.ps1")) {
  if (Test-Path "C:\ProgramData\Koi\$f") { Write-Host "  [ok] $f present" } else { Write-Host "  [!!] $f missing"; $ok=$false }
}
$svc = sc.exe query KoiService 2>&1
Write-Host "  sc.exe query KoiService:`n$svc"
if (Test-Path "C:\ProgramData\Koi\KoiService.log") { Write-Host "  [ok] KoiService.log present" } else { Write-Host "  [..] KoiService.log not yet written (appears once the service runs)" }

if ($ok) { Write-Host "`nKoiService installed. It starts automatically and runs on its schedule." -ForegroundColor Green }
else     { Write-Host "`nSomething looks off - review $instLog" -ForegroundColor Red }
