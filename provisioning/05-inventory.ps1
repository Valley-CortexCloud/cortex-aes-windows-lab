<#
  05 - Ground-truth inventory.
  Enumerates everything we deliberately planted, so you have an authoritative
  list to compare against what Cortex AES reports in the console. This is your
  discovery-accuracy scorecard for the POV.
  Output: expected-inventory.json (next to this script) + a copy on the Desktop.
#>
$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-VSCodeExtensions($cli) {
  $c = Get-Command $cli -ErrorAction SilentlyContinue
  if (-not $c) { return @() }
  try { (& $cli --list-extensions --show-versions 2>$null) } catch { @() }
}

function Get-BrowserExtensions($extRoot) {
  if (-not (Test-Path $extRoot)) { return @() }
  Get-ChildItem $extRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $id = $_.Name
    $verDir = Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    $name = $id
    if ($verDir) {
      $manifest = Join-Path $verDir.FullName "manifest.json"
      if (Test-Path $manifest) {
        try {
          $m = Get-Content $manifest -Raw | ConvertFrom-Json
          if ($m.name) { $name = $m.name }
        } catch {}
      }
    }
    [pscustomobject]@{ id = $id; name = $name; version = ($verDir.Name) }
  }
}

function Get-ForceList($regPath) {
  if (-not (Test-Path $regPath)) { return @() }
  (Get-ItemProperty $regPath).PSObject.Properties |
    Where-Object { $_.Name -match '^\d+$' } |
    ForEach-Object { ($_.Value -split ';')[0] }
}

function Get-McpServers($path) {
  if (-not (Test-Path $path)) { return $null }
  try {
    $j = Get-Content $path -Raw | ConvertFrom-Json
    $node = if ($j.mcpServers) { $j.mcpServers } elseif ($j.servers) { $j.servers } else { $null }
    if ($node) { @{ file = $path; servers = ($node.PSObject.Properties.Name) } } else { @{ file = $path; servers = @() } }
  } catch { @{ file = $path; servers = "PARSE_ERROR" } }
}

$inv = [ordered]@{
  generated_utc = (Get-Date).ToUniversalTime().ToString("o")
  hostname      = $env:COMPUTERNAME
  serial        = (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
  os            = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
  user          = $env:USERNAME

  vscode_extensions = @(Get-VSCodeExtensions "code")
  cursor_extensions = @(Get-VSCodeExtensions "cursor")

  chrome_extensions_installed = @(Get-BrowserExtensions "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions")
  edge_extensions_installed   = @(Get-BrowserExtensions "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions")
  chrome_forcelist_ids        = @(Get-ForceList "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist")
  edge_forcelist_ids          = @(Get-ForceList "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist")

  mcp_configs = @(
    (Get-McpServers "$env:APPDATA\Claude\claude_desktop_config.json"),
    (Get-McpServers "$env:USERPROFILE\.cursor\mcp.json"),
    (Get-McpServers "C:\koi-lab-workspace\.vscode\mcp.json")
  ) | Where-Object { $_ -ne $null }

  ai_tools_present = [ordered]@{
    ollama         = [bool](Get-Command ollama -ErrorAction SilentlyContinue)
    cursor         = (Test-Path "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe") -or [bool](Get-Command cursor -ErrorAction SilentlyContinue)
    windsurf       = (Test-Path "$env:LOCALAPPDATA\Programs\Windsurf\Windsurf.exe")
    claude_desktop = (Test-Path "$env:LOCALAPPDATA\AnthropicClaude") -or (Test-Path "$env:APPDATA\Claude")
  }
}

$json = $inv | ConvertTo-Json -Depth 8
$out1 = Join-Path $here "expected-inventory.json"
$out2 = "$env:USERPROFILE\Desktop\expected-inventory.json"
$json | Set-Content -Path $out1 -Encoding UTF8
$json | Set-Content -Path $out2 -Encoding UTF8 -ErrorAction SilentlyContinue

Write-Host "`nGround-truth inventory written to:" -ForegroundColor Green
Write-Host "  $out1"
Write-Host "  $out2"
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host ("  VS Code extensions : {0}" -f $inv.vscode_extensions.Count)
Write-Host ("  Chrome ext (disk)  : {0}  (forcelist {1})" -f $inv.chrome_extensions_installed.Count, $inv.chrome_forcelist_ids.Count)
Write-Host ("  Edge ext (disk)    : {0}  (forcelist {1})" -f $inv.edge_extensions_installed.Count, $inv.edge_forcelist_ids.Count)
Write-Host ("  MCP config files   : {0}" -f $inv.mcp_configs.Count)
Write-Host ("  AI tools present   : {0}" -f (($inv.ai_tools_present.GetEnumerator() | Where-Object {$_.Value}).Name -join ', '))
