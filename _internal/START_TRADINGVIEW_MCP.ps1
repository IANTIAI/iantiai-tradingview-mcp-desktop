[CmdletBinding()]
param([switch]$UseLocalPackageCopy)
$ErrorActionPreference = 'Stop'
$taskEndpoint = 'http://127.0.0.1:9222'

function Get-TaskCdp {
    try { Invoke-RestMethod -Uri "$taskEndpoint/json/version" -TimeoutSec 2 }
    catch { return $null }
}

function Assert-TaskListener {
    $taskListeners = @(Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue)
    if (!$taskListeners.Count) { throw 'CDP answered but its listener could not be verified.' }
    foreach ($taskListener in $taskListeners) {
        if ($taskListener.LocalAddress -notin @('127.0.0.1', '::1')) {
            throw 'Port 9222 is not limited to loopback. Do not use this connection.'
        }
        $taskOwner = Get-Process -Id $taskListener.OwningProcess -ErrorAction Stop
        if ($taskOwner.ProcessName -ne 'TradingView') { throw 'Port 9222 belongs to another application.' }
    }
}

$taskExisting = Get-TaskCdp
if ($taskExisting) {
    Assert-TaskListener
    Write-Output "TradingView CDP already available at $taskEndpoint"
    exit 0
}
if (@(Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue).Count) {
    throw 'Port 9222 is occupied but is not responding as CDP. Nothing was started.'
}
if (@(Get-Process -Name TradingView -ErrorAction SilentlyContinue).Count) {
    Write-Host ''
    Write-Host 'TradingView laeuft noch.' -ForegroundColor Yellow
    Write-Host 'Bitte Skripte speichern und TradingView normal vollstaendig schliessen.'
    Write-Host 'Der MCP-Starter wartet und startet TradingView danach automatisch neu.'
    Write-Host 'Es wird kein Prozess gewaltsam beendet.'
    Write-Host ''

    $taskWaitSeconds = 0
    while (@(Get-Process -Name TradingView -ErrorAction SilentlyContinue).Count) {
        Start-Sleep -Seconds 1
        $taskWaitSeconds++
        if ($taskWaitSeconds -ge 600) {
            throw 'TradingView was not fully closed within 10 minutes. Please run the starter again.'
        }
    }
    Write-Host 'TradingView ist geschlossen. Starte jetzt mit MCP ...' -ForegroundColor Green
    Start-Sleep -Seconds 2
}

$taskPackage = Get-AppxPackage -Name 'TradingView.Desktop' -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
$taskCandidates = @(
    $(if ($taskPackage) { Join-Path $taskPackage.InstallLocation 'TradingView.exe' }),
    (Join-Path $env:LOCALAPPDATA 'TradingView\TradingView.exe'),
    (Join-Path $env:ProgramFiles 'TradingView\TradingView.exe')
)
$taskExe = $taskCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (!$taskExe) { throw 'TradingView Desktop executable not found for the current Windows user.' }
$taskInstalledExe = $taskExe
$taskRegisteredPackage = $taskPackage -and
    ([IO.Path]::GetFullPath($taskInstalledExe) -eq [IO.Path]::GetFullPath((Join-Path $taskPackage.InstallLocation 'TradingView.exe'))) -and
    ($taskPackage.Status.ToString() -eq 'Ok') -and
    ($taskPackage.SignatureKind.ToString() -in @('Store', 'System', 'Developer')) -and
    ($taskPackage.Publisher -eq 'CN="TradingView, Inc.", O="TradingView, Inc.", S=Ohio, C=US')

if ($UseLocalPackageCopy) {
    if (!$taskPackage -or !$taskExe.StartsWith($taskPackage.InstallLocation, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Local-package-copy mode requires the installed TradingView MSIX package.'
    }
    $taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.vendor\tradingview-desktop'))
    $taskSource = [IO.Path]::GetFullPath($taskPackage.InstallLocation)
    $taskDestination = [IO.Path]::GetFullPath((Join-Path $taskRoot (Split-Path $taskSource -Leaf)))
    if (!$taskDestination.StartsWith($taskRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Invalid local package destination.'
    }
    if (!(Test-Path -LiteralPath $taskDestination)) {
        New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
        Copy-Item -LiteralPath $taskSource -Destination $taskDestination -Recurse -ErrorAction Stop
    }
    $taskExe = Join-Path $taskDestination 'TradingView.exe'
    if (!(Test-Path -LiteralPath $taskExe -PathType Leaf)) { throw 'The local package copy is incomplete.' }
}

$taskSignature = Get-AuthenticodeSignature -LiteralPath $taskExe
if ($taskSignature.Status -ne 'Valid') {
    # MSIX is signed as a package; its embedded EXE need not have Authenticode.
    # Trust only the exact installed, Windows-registered TradingView package.
    if ($taskSignature.Status -ne 'NotSigned' -or !$taskRegisteredPackage) {
        throw "TradingView is neither a valid signed EXE nor the registered TradingView MSIX package: $($taskSignature.Status)"
    }
    if ($UseLocalPackageCopy -and ((Get-FileHash -LiteralPath $taskExe -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $taskInstalledExe -Algorithm SHA256).Hash)) {
        throw 'The copied TradingView executable differs from the installed package.'
    }
    Write-Output "Using Windows-registered TradingView package: $($taskPackage.PackageFullName) ($($taskPackage.SignatureKind), $($taskPackage.Status))"
}
Start-Process -FilePath $taskExe -ArgumentList '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=9222' -WindowStyle Normal | Out-Null
for ($taskAttempt = 0; $taskAttempt -lt 20; $taskAttempt++) {
    Start-Sleep -Seconds 1
    if (Get-TaskCdp) {
        Assert-TaskListener
        Write-Output "TradingView CDP ready: $taskEndpoint"
        Write-Output "Executable: $taskExe"
        exit 0
    }
}
throw 'TradingView did not expose CDP. For an MSIX installation, save/close Desktop and retry with -UseLocalPackageCopy. No process was force-closed.'

