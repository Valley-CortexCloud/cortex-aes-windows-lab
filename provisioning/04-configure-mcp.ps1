<#
  04 - MCP server configuration.
  Cortex AES explicitly detects MCP servers. The highest-signal artifact is the
  MCP config file for each host app. We write real configs pointing at published
  @modelcontextprotocol servers (run via npx) for:
    - Claude Desktop : %APPDATA%\Claude\claude_desktop_config.json
    - Cursor         : %USERPROFILE%\.cursor\mcp.json
    - VS Code        : a sample workspace .vscode\mcp.json
  We also create a local folder a filesystem MCP server would expose, and
  optionally pre-fetch the server packages so node_modules exist on disk too.
#>
$ErrorActionPreference = "Continue"

$fsRoot = "C:\koi-lab-workspace"
New-Item -ItemType Directory -Force -Path $fsRoot | Out-Null
"// Koi lab sample workspace - filesystem MCP root" | Set-Content "$fsRoot\README.txt"

# Shared server definitions (as a PS hashtable we render to JSON per host)
$servers = @{
  filesystem = @{ command = "npx"; args = @("-y","@modelcontextprotocol/server-filesystem", $fsRoot) }
  memory     = @{ command = "npx"; args = @("-y","@modelcontextprotocol/server-memory") }
  github     = @{
    command = "npx"; args = @("-y","@modelcontextprotocol/server-github")
    env = @{ GITHUB_PERSONAL_ACCESS_TOKEN = "REPLACE_ME_lab_token" }
  }
  "sequential-thinking" = @{ command = "npx"; args = @("-y","@modelcontextprotocol/server-sequential-thinking") }
}

function Write-Json($path, $obj) {
  $dir = Split-Path -Parent $path
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
  Write-Host "  wrote $path" -ForegroundColor Green
}

Write-Host "Writing MCP configs ..." -ForegroundColor Yellow

# Claude Desktop
Write-Json "$env:APPDATA\Claude\claude_desktop_config.json" @{ mcpServers = $servers }

# Cursor
Write-Json "$env:USERPROFILE\.cursor\mcp.json" @{ mcpServers = $servers }

# VS Code workspace-scoped (modern VS Code MCP config shape uses "servers")
$vscodeServers = @{}
foreach ($k in $servers.Keys) {
  $vscodeServers[$k] = @{ command = $servers[$k].command; args = $servers[$k].args }
}
Write-Json "$fsRoot\.vscode\mcp.json" @{ servers = $vscodeServers }

# Optional: pre-fetch the server packages so node_modules are present on disk.
$npx = Get-Command npx -ErrorAction SilentlyContinue
if ($npx) {
  Write-Host "Pre-fetching MCP server packages (best-effort) ..." -ForegroundColor Yellow
  foreach ($pkg in @(
      "@modelcontextprotocol/server-filesystem",
      "@modelcontextprotocol/server-memory",
      "@modelcontextprotocol/server-github",
      "@modelcontextprotocol/server-sequential-thinking")) {
    Start-Job -ScriptBlock { param($p) npx -y $p --help 2>$null } -ArgumentList $pkg | Out-Null
  }
  Start-Sleep -Seconds 2
  Get-Job | Stop-Job -ErrorAction SilentlyContinue
  Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
} else {
  Write-Warning "npx not found; configs written but packages not pre-fetched. Install Node (01) for full fidelity."
}

Write-Host "MCP configuration done." -ForegroundColor Green
