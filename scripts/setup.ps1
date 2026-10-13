[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskVendor = Join-Path $taskRoot '.vendor\tradingview-mcp'
$taskCommit = 'c05b8f5755ed8e64ea242de88ddbf46aa24d56a4'
foreach ($taskCommand in @('git','node','npm')) { Get-Command $taskCommand -ErrorAction Stop | Out-Null }
if (!(Test-Path -LiteralPath $taskVendor)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $taskVendor) -Force | Out-Null
    git clone https://github.com/tradesdontlie/tradingview-mcp.git $taskVendor
    if ($LASTEXITCODE -ne 0) { throw 'Upstream clone failed.' }
}
git -C $taskVendor checkout --detach $taskCommit
if ($LASTEXITCODE -ne 0) { throw 'Could not select the pinned upstream commit.' }
Push-Location $taskVendor
try {
    npm ci --ignore-scripts
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
} finally { Pop-Location }
node (Join-Path $taskRoot 'mcp-check.mjs')
if ($LASTEXITCODE -ne 0) { throw 'MCP smoke test failed.' }
Write-Host 'Setup complete. Double-click START_IANTIAI_TRADINGVIEW.vbs.' -ForegroundColor Green
