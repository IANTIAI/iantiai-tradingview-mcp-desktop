$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskMarker=Join-Path $taskRoot '.vendor\installed.json'
$taskInstalled=$null
if(Test-Path -LiteralPath $taskMarker){try{$taskInstalled=Get-Content -LiteralPath $taskMarker -Raw|ConvertFrom-Json}catch{}}
$taskSdk=Join-Path $taskRoot '.vendor\tradingview-mcp\node_modules\@modelcontextprotocol\sdk\package.json'
if($taskInstalled -and $taskInstalled.installed -and $taskInstalled.root -eq $taskRoot -and (Test-Path -LiteralPath $taskInstalled.node) -and (Test-Path -LiteralPath $taskSdk)) {
    $env:PATH=(Split-Path -Parent $taskInstalled.node)+';'+$env:PATH
    & (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1')
    exit
}
New-Item -ItemType Directory -Path (Join-Path $taskRoot '.vendor') -Force|Out-Null
$taskProgress=Join-Path $taskRoot '.vendor\setup-progress.txt'
$taskLog=Join-Path $taskRoot '.vendor\setup.log'
$taskDashboardSource=Get-Content -LiteralPath (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1') -Raw
[xml]$taskXml=[regex]::Match($taskDashboardSource,"(?s)\[xml\]\`$taskXaml = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$taskWindow=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $taskXml))
& (Join-Path $PSScriptRoot 'set-app-icon.ps1') -Root $taskRoot -Window $taskWindow
$taskAssets=Join-Path $taskRoot 'app\assets'
$taskMap=@{LogoIan='brand-ian.png';LogoTiai='brand-tiai.png';TagThink='brand-think.png';TagCode='brand-code.png';TagTrade='brand-trade.png';TagLive='brand-live.png'}
foreach($taskKey in $taskMap.Keys){$taskWindow.FindName($taskKey).Source=[Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $taskAssets $taskMap[$taskKey]))}
$taskWindow.FindName('ProductTitle').FontFamily=[Windows.Media.FontFamily]::new([uri]($taskAssets+'\'),'./#Michroma')
$taskWindow.FindName('Overall').Text='Installing automatically on first start...'
$taskWindow.FindName('Desktop').Text='TradingView: checked during installation'
$taskWindow.FindName('Bridge').Text='MCP components: ready to install'
$taskWindow.FindName('Connection').Text='AI connection: configured during installation'
$taskWindow.FindName('Details').Text='First start: installing and connecting detected AI clients automatically. The bundled components are reused. Next start: quick check, then TradingView opens directly.'
$taskWindow.FindName('Start').Content='Install'
$taskWindow.FindName('Start').IsEnabled=$false
$taskWindow.FindName('Logs').IsEnabled=$false
$taskWindow.FindName('Website').Add_Click({Start-Process 'https://iantiai.com/'})
$taskWindow.FindName('Logs').Add_Click({Start-Process notepad.exe -ArgumentList ('"'+$taskLog+'"')})
$script:taskInstallProcess=$null
$script:taskSucceeded=$false
function Convert-TaskLiteral([string]$Value){return "'"+$Value.Replace("'","''")+"'"}
$taskTimer=New-Object Windows.Threading.DispatcherTimer
$taskTimer.Interval=[TimeSpan]::FromMilliseconds(300)
$taskWindow.FindName('Start').Add_Click({
    $taskWindow.FindName('Start').IsEnabled=$false
    $taskWindow.FindName('Start').Content='Installing...'
    $taskWindow.FindName('Overall').Text='Installing your app...'
    $taskCommand='try { & '+(Convert-TaskLiteral (Join-Path $PSScriptRoot 'setup.ps1'))+' -ProgressFile '+(Convert-TaskLiteral $taskProgress)+' *> '+(Convert-TaskLiteral $taskLog)+'; exit 0 } catch { $_ | Out-File -LiteralPath '+(Convert-TaskLiteral $taskLog)+' -Append; exit 1 }'
    $taskInfo=New-Object Diagnostics.ProcessStartInfo
    $taskInfo.FileName=Join-Path $PSHOME 'powershell.exe'
    $taskInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($taskCommand))
    $taskInfo.UseShellExecute=$false
    $taskInfo.CreateNoWindow=$true
    $script:taskInstallProcess=[Diagnostics.Process]::Start($taskInfo)
    $taskTimer.Start()
})
$taskTimer.Add_Tick({
    if(Test-Path -LiteralPath $taskProgress){try{$taskWindow.FindName('Details').Text=Get-Content -LiteralPath $taskProgress -Raw}catch{}}
    if($script:taskInstallProcess -and $script:taskInstallProcess.HasExited){
        $taskTimer.Stop()
        if($script:taskInstallProcess.ExitCode -eq 0 -and (Test-Path -LiteralPath $taskMarker)){$script:taskSucceeded=$true;$taskWindow.Close()}
        else{$taskWindow.FindName('Overall').Text='Installation needs attention';$taskWindow.FindName('Details').Text='Installation did not finish. Open Logs for details, then click Install to retry.';$taskWindow.FindName('Logs').IsEnabled=$true;$taskWindow.FindName('Start').Content='Install';$taskWindow.FindName('Start').IsEnabled=$true}
    }
})
$taskWindow.Add_Closed({$taskTimer.Stop()})
$taskWindow.Add_ContentRendered({
    if(!$script:taskInstallProcess){$taskWindow.FindName('Start').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}
})
$taskWindow.ShowDialog()|Out-Null
if($script:taskSucceeded){
    $taskInstalled=Get-Content -LiteralPath $taskMarker -Raw|ConvertFrom-Json
    $env:PATH=(Split-Path -Parent $taskInstalled.node)+';'+$env:PATH
    & (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1')
}
