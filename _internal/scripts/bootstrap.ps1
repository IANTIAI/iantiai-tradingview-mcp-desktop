$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskReadyFile=Join-Path $taskRoot '.vendor\ready.json'
$taskReady=$null
if(Test-Path -LiteralPath $taskReadyFile){try{$taskReady=Get-Content -LiteralPath $taskReadyFile -Raw|ConvertFrom-Json}catch{}}
$taskLockHash=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'runtime-package-lock.json') -Algorithm SHA256).Hash
if($taskReady -and $taskReady.version -eq '1.2' -and $taskReady.dependencyLock -eq $taskLockHash -and $taskReady.clientsConfigured -and (Test-Path -LiteralPath $taskReady.node) -and (Test-Path -LiteralPath (Join-Path $taskRoot '.vendor\tradingview-mcp\node_modules\@modelcontextprotocol\sdk\package.json'))) {
    $env:PATH=(Split-Path -Parent $taskReady.node)+';'+$env:PATH
    & (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1')
    exit
}
New-Item -ItemType Directory -Path (Join-Path $taskRoot '.vendor') -Force|Out-Null
$taskProgress=Join-Path $taskRoot '.vendor\setup-progress.txt'
$taskLog=Join-Path $taskRoot '.vendor\setup.log'
$taskDashboardSource=Get-Content -LiteralPath (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1') -Raw
[xml]$taskXml=[regex]::Match($taskDashboardSource,"(?s)\[xml\]\`$taskXaml = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$taskWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $taskXml))
$taskAssets=Join-Path $taskRoot 'app\assets'
$taskMap=@{LogoIan='brand-ian.png';LogoTiai='brand-tiai.png';TagThink='brand-think.png';TagCode='brand-code.png';TagTrade='brand-trade.png';TagLive='brand-live.png'}
foreach($taskKey in $taskMap.Keys){$taskWindow.FindName($taskKey).Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $taskAssets $taskMap[$taskKey]))}
$taskWindow.FindName('ProductTitle').FontFamily=[Windows.Media.FontFamily]::new([uri]($taskAssets+'\'),'./#Michroma')
$taskWindow.FindName('Overall').Text='Preparing your app automatically...'
$taskWindow.FindName('Start').IsEnabled=$false
$taskWindow.FindName('Logs').IsEnabled=$false
$taskWindow.FindName('Website').Add_Click({Start-Process 'https://iantiai.com/'})
function Convert-TaskLiteral([string]$Value){return "'"+$Value.Replace("'","''")+"'"}
$taskCommand='try { & '+(Convert-TaskLiteral (Join-Path $PSScriptRoot 'setup.ps1'))+' -ProgressFile '+(Convert-TaskLiteral $taskProgress)+' *> '+(Convert-TaskLiteral $taskLog)+'; exit 0 } catch { $_ | Out-File -LiteralPath '+(Convert-TaskLiteral $taskLog)+' -Append; exit 1 }'
$taskInfo=New-Object Diagnostics.ProcessStartInfo
$taskInfo.FileName=Join-Path $PSHOME 'powershell.exe'
$taskInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($taskCommand))
$taskInfo.UseShellExecute=$false
$taskInfo.CreateNoWindow=$true
$taskProcess=[Diagnostics.Process]::Start($taskInfo)
$script:taskSucceeded=$false
$taskWindow.FindName('Logs').Add_Click({Start-Process notepad.exe -ArgumentList ('"'+$taskLog+'"')})
$taskTimer=New-Object Windows.Threading.DispatcherTimer
$taskTimer.Interval=[TimeSpan]::FromSeconds(1)
$taskTimer.Add_Tick({
    if(Test-Path -LiteralPath $taskProgress){try{$taskWindow.FindName('Details').Text=Get-Content -LiteralPath $taskProgress -Raw}catch{}}
    if($taskProcess.HasExited){
        $taskTimer.Stop()
        if($taskProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $taskReadyFile)){$script:taskSucceeded=$true;$taskWindow.Close()}
        else{$taskWindow.FindName('Details').Text='Setup could not finish. Check your internet connection and open the log for details, then launch Start again.';$taskWindow.FindName('Overall').Text='Setup needs attention';$taskWindow.FindName('Logs').IsEnabled=$true}
    }
})
$taskWindow.Add_Closed({$taskTimer.Stop()})
$taskTimer.Start()
$taskWindow.ShowDialog()|Out-Null
if($script:taskSucceeded){
    $taskReady=Get-Content -LiteralPath $taskReadyFile -Raw|ConvertFrom-Json
    $env:PATH=(Split-Path -Parent $taskReady.node)+';'+$env:PATH
    & (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1')
}
