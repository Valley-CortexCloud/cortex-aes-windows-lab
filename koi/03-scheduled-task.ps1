<#
  METHOD 1b (Agentless on a schedule) - simulate an MDM/EDR cadence with a
  Windows Scheduled Task that runs the Koi script package periodically.
  Use this to mimic how Jamf/Intune/CrowdStrike would run the agentless script,
  without an actual MDM in the lab.

  PREREQUISITES
    - Run elevated. Koi script at koi\artifacts\mdm.ps1.
#>
[CmdletBinding()]
param(
  [int]$IntervalMinutes = 60,
  [string]$ScriptPath = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\artifacts\mdm.ps1",
  [string]$TaskName = "KoiLab-AgentlessRun"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $ScriptPath)) { throw "Koi script not found at $ScriptPath." }
$ScriptPath = (Resolve-Path $ScriptPath).Path

$action    = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
$trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
             -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Registered scheduled task '$TaskName' (every $IntervalMinutes min, as SYSTEM)." -ForegroundColor Green
Write-Host "Run it now to test:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Remove it later:     Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
