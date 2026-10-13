[CmdletBinding()]
param([string]$ProgressFile, [switch]$SkipClientConfiguration, [switch]$Verify)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskVendorRoot = Join-Path $taskRoot '.vendor'
$taskVendor = Join-Path $taskVendorRoot 'tradingview-mcp'
$taskCommit = 'c05b8f5755ed8e64ea242de88ddbf46aa24d56a4'
$taskComponentsPresent=Test-Path -LiteralPath (Join-Path $taskVendor 'node_modules\@modelcontextprotocol\sdk\package.json')
New-Item -ItemType Directory -Path $taskVendorRoot -Force | Out-Null
function Set-TaskProgress([string]$Message) {
    Write-Output $Message
    if ($ProgressFile) { Set-Content -LiteralPath $ProgressFile -Value $Message -Encoding utf8 }
}
function Invoke-TaskNode([string[]]$Arguments) {
    $taskInfo = New-Object Diagnostics.ProcessStartInfo
    $taskInfo.FileName = $taskNode
    $taskInfo.Arguments = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $taskInfo.WorkingDirectory = (Get-Location).Path
    $taskInfo.UseShellExecute = $false
    $taskInfo.CreateNoWindow = $true
    $taskInfo.RedirectStandardOutput = $true
    $taskInfo.RedirectStandardError = $true
    $taskProcess = [Diagnostics.Process]::Start($taskInfo)
    $taskOutput = $taskProcess.StandardOutput.ReadToEndAsync()
    $taskErrorOutput = $taskProcess.StandardError.ReadToEndAsync()
    $taskProcess.WaitForExit()
    Write-Output $taskOutput.Result
    Write-Output $taskErrorOutput.Result
    if ($taskProcess.ExitCode -ne 0) { throw "Component command failed ($($taskProcess.ExitCode))." }
}
$taskNode = Join-Path $taskVendorRoot 'node\node.exe'
if (!(Test-Path -LiteralPath $taskNode)) {
    $taskCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $taskNode = $null
    if ($taskCommand) {
        $taskVersionText = & $taskCommand.Source --version
        $taskVersionMatch = [regex]::Match($taskVersionText, '^v(\d+)\.')
        if ($LASTEXITCODE -eq 0 -and $taskVersionMatch.Success -and [int]$taskVersionMatch.Groups[1].Value -ge 18 -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $taskCommand.Source) 'npm.cmd'))) { $taskNode=$taskCommand.Source }
    }
}
if (!$taskNode -or (!$taskComponentsPresent -and !(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $taskNode) 'node_modules\npm\bin\npm-cli.js')))) {
    Set-TaskProgress 'Preparing the local runtime...'
    $taskArchitecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'x64' }
    $taskVersion = 'v24.13.1'
    $taskArchiveName = "node-$taskVersion-win-$taskArchitecture.zip"
    $taskArchive = Join-Path $taskVendorRoot $taskArchiveName
    $taskChecksums = (Invoke-WebRequest -Uri "https://nodejs.org/dist/$taskVersion/SHASUMS256.txt" -UseBasicParsing -TimeoutSec 60).Content
    $taskChecksumMatch = [regex]::Match($taskChecksums, '(?m)^([a-f0-9]{64})\s+' + [regex]::Escape($taskArchiveName) + '\s*$')
    if (!$taskChecksumMatch.Success) { throw 'Runtime checksum not available.' }
    Invoke-WebRequest -Uri "https://nodejs.org/dist/$taskVersion/$taskArchiveName" -OutFile $taskArchive -UseBasicParsing -TimeoutSec 300
    if ((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash -ne $taskChecksumMatch.Groups[1].Value) { throw 'Runtime checksum verification failed.' }
    $taskExtract = Join-Path $taskVendorRoot ('runtime-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskExtract
    $taskNodeDestination=Join-Path $taskVendorRoot 'node'
    New-Item -ItemType Directory -Path $taskNodeDestination -Force|Out-Null
    Get-ChildItem -LiteralPath (Join-Path $taskExtract "node-$taskVersion-win-$taskArchitecture") | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $taskNodeDestination -Recurse -Force }
    $taskNode = Join-Path $taskVendorRoot 'node\node.exe'
}
$env:PATH = (Split-Path -Parent $taskNode) + ';' + $env:PATH
$taskNpm = Join-Path (Split-Path -Parent $taskNode) 'node_modules\npm\bin\npm-cli.js'
if (!(Test-Path -LiteralPath (Join-Path $taskVendor 'package.json'))) {
    Set-TaskProgress 'Preparing the TradingView connection...'
    $taskArchive = Join-Path $taskVendorRoot 'bridge.zip'
    Invoke-WebRequest -Uri "https://codeload.github.com/tradesdontlie/tradingview-mcp/zip/$taskCommit" -OutFile $taskArchive -UseBasicParsing -TimeoutSec 300
    $taskExtract = Join-Path $taskVendorRoot ('bridge-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskExtract
    Copy-Item -LiteralPath (Join-Path $taskExtract "tradingview-mcp-$taskCommit") -Destination $taskVendor -Recurse -Force
}
$taskLockFile=Join-Path $PSScriptRoot 'runtime-package-lock.json'
$taskLockHash=(Get-FileHash -LiteralPath $taskLockFile -Algorithm SHA256).Hash
$taskInstalledLock=Join-Path $taskVendorRoot 'runtime-lock.sha256'
$taskLockMatches=(Test-Path -LiteralPath $taskInstalledLock) -and ((Get-Content -LiteralPath $taskInstalledLock -Raw).Trim() -eq $taskLockHash)
$taskBridgeLock=Join-Path $taskVendor 'package-lock.json'
if(!$taskLockMatches -and (Test-Path -LiteralPath $taskBridgeLock)){$taskLockMatches=(Get-FileHash -LiteralPath $taskBridgeLock -Algorithm SHA256).Hash -eq $taskLockHash}
if (!$taskLockMatches -or !(Test-Path -LiteralPath (Join-Path $taskVendor 'node_modules\@modelcontextprotocol\sdk\package.json'))) {
    if(!(Test-Path -LiteralPath $taskNpm)){throw 'Connection components need repair. The bundled runtime does not include npm; use a complete Node.js runtime for repair.'}
    Set-TaskProgress 'Installing connection components...'
    Copy-Item -LiteralPath $taskLockFile -Destination (Join-Path $taskVendor 'package-lock.json') -Force
    Push-Location $taskVendor
    try { Invoke-TaskNode @($taskNpm,'ci','--omit=dev','--ignore-scripts','--loglevel=error') }
    finally { Pop-Location }
    Set-Content -LiteralPath $taskInstalledLock -Value $taskLockHash
}
$taskTvPackage = Get-AppxPackage -Name 'TradingView.Desktop' -ErrorAction SilentlyContinue
$taskTvExe = @((Join-Path $env:LOCALAPPDATA 'TradingView\TradingView.exe'), (Join-Path $env:ProgramFiles 'TradingView\TradingView.exe')) | Where-Object { Test-Path -LiteralPath $_ }
if (!$taskTvPackage -and !$taskTvExe) {
    Set-TaskProgress 'Installing TradingView Desktop...'
    $taskWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (!$taskWinget) { throw 'Windows App Installer is required to install TradingView automatically.' }
    & $taskWinget.Source install --id TradingView.TradingViewDesktop --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw 'TradingView installation did not complete.' }
}
if($Verify){Set-TaskProgress 'Checking the connection components...';Invoke-TaskNode @((Join-Path $taskRoot 'mcp-check.mjs'))}
if (!$SkipClientConfiguration) { & (Join-Path $PSScriptRoot 'configure-clients.ps1') -Root $taskRoot -Node $taskNode }
@{ version='1.2'; node=$taskNode; commit=$taskCommit; dependencyLock=$taskLockHash; clientsConfigured=(!$SkipClientConfiguration) } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskVendorRoot 'ready.json') -Encoding utf8
if(!$SkipClientConfiguration){@{version='1.3';root=$taskRoot;node=$taskNode;installed=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskVendorRoot 'installed.json') -Encoding utf8}
Set-TaskProgress 'Ready. Restart your AI client if it was open during setup.'
