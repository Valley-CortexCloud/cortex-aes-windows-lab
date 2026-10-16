<#
  Uninstall / rollback helper.
    - Service (MSI): removes KoiService; optional ROLLBACK=yes rolls back any
      config the script deployed (PAC/hosts/policies) before removing.
    - Scheduled task: unregisters the agentless task if present.
  Ref: docs/koi-windows-agent.md
#>
[CmdletBinding()]
param(
  [switch]$Rollback,
  [string]$MsiPath  = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\artifacts\Koi.msi",
  [string]$TaskName = "KoiLab-AgentlessRun"
)
$ErrorActionPreference = "Continue"

# Scheduled task
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Removed scheduled task '$TaskName'." -ForegroundColor Green
}

# Service via MSI
if (Test-Path $MsiPath) {
  $args = @("/x", "`"$MsiPath`"", "/qn")
  if ($Rollback) { $args += "ROLLBACK=yes"; Write-Host "Uninstalling WITH rollback ..." -ForegroundColor Yellow }
  else           { Write-Host "Uninstalling (no rollback) ..." -ForegroundColor Yellow }
  $p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
  Write-Host "msiexec exit code: $($p.ExitCode)"
} else {
  Write-Warning "Koi.msi not at $MsiPath - if the service was installed from elsewhere, uninstall it from that MSI."
}

if (Test-Path "C:\ProgramData\Koi") {
  Write-Host "Note: C:\ProgramData\Koi still present - remove manually if you want a clean slate." -ForegroundColor DarkYellow
}
