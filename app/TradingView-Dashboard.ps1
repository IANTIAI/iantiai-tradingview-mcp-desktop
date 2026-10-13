[CmdletBinding()]
param([string]$BridgeRoot = (Split-Path -Parent $PSScriptRoot), [switch]$NoAutoStart)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$taskNode = (Get-Command node -ErrorAction Stop).Source
$taskSession = Join-Path $env:TEMP ('iantiai-tv-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskSession | Out-Null
$taskStatus = Join-Path $taskSession 'status.json'
$taskLog = Join-Path $taskSession 'mcp.log'
$taskStartupLog = Join-Path $taskSession 'startup.log'
$script:taskStarter = $null
$script:taskMonitor = $null
$taskPowerShell = Join-Path $PSHOME 'powershell.exe'
if (!(Test-Path -LiteralPath $taskPowerShell)) { $taskPowerShell = (Get-Command powershell.exe).Source }
foreach ($taskFile in @('mcp-server.mjs','START_TRADINGVIEW_MCP.ps1')) {
    if (!(Test-Path -LiteralPath (Join-Path $BridgeRoot $taskFile))) { throw "Missing file: $taskFile" }
}
[xml]$taskXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="IANTIAI | TradingView MCP Desktop" Width="720" Height="650" MinWidth="680" MinHeight="630" WindowStartupLocation="CenterScreen" Background="#000000" Foreground="#F5F7FA" FontFamily="Arial">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#101715"/><Setter Property="Foreground" Value="#E8F6F0"/><Setter Property="BorderBrush" Value="#263F35"/><Setter Property="Padding" Value="18,11"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#00E5A0"/><Setter TargetName="ButtonBorder" Property="Background" Value="#10251B"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid Margin="32,22,32,24"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel>
  <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0"><Image Name="LogoIan" Width="219" Height="64" Stretch="Uniform"/><Image Name="LogoTiai" Width="238" Height="64" Stretch="Uniform" Margin="10,0,0,0"/></StackPanel>
  <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,18"><Image Name="TagThink" Width="108" Height="12" Stretch="Uniform"/><Image Name="TagCode" Width="96" Height="12" Stretch="Uniform" Margin="10,0,0,0"/><Image Name="TagTrade" Width="118" Height="12" Stretch="Uniform" Margin="10,0,0,0"/><Image Name="TagLive" Width="84" Height="12" Stretch="Uniform" Margin="10,0,0,0"/></StackPanel>
  <Border Height="1" Margin="0,0,0,22"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#000000" Offset="0"/><GradientStop Color="#00E5A0" Offset="0.3"/><GradientStop Color="#B8FFE6" Offset="0.5"/><GradientStop Color="#3CAAFF" Offset="0.75"/><GradientStop Color="#000000" Offset="1"/></LinearGradientBrush></Border.Background></Border>
  <TextBlock Name="ProductTitle" Text="TradingView MCP Desktop" FontSize="20" HorizontalAlignment="Center" Margin="0,0,0,14"/>
  <TextBlock Name="Overall" Text="Checking connection ..." FontSize="14" Foreground="#F4C46A" HorizontalAlignment="Center"/>
 </StackPanel>
 <Border Grid.Row="1" Background="#0D1210" BorderBrush="#1C3027" BorderThickness="1" CornerRadius="9" Padding="20" Margin="0,22,0,18"><StackPanel><TextBlock Name="Desktop" Text="TradingView: checking" Margin="0,0,0,11"/><TextBlock Name="Bridge" Text="MCP server: starting" Margin="0,0,0,11"/><TextBlock Name="Connection" Text="Chart connection: waiting"/><TextBlock Text="Local connection | 127.0.0.1:9222" Foreground="#75877D" FontSize="12" Margin="0,15,0,0"/></StackPanel></Border>
 <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,15"><Button Name="Start" Content="Start TradingView" Margin="0,0,10,0"/><Button Name="Logs" Content="Logs"/></StackPanel>
 <TextBox Grid.Row="3" Name="Details" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#080B09" Foreground="#91A79B" BorderThickness="0" Padding="12" FontSize="12"/>
 <StackPanel Grid.Row="4" Margin="0,18,0,0"><TextBlock Text="TradingView stays open when this window is closed." Foreground="#75877D" FontSize="12" Margin="0,0,0,16"/><StackPanel Orientation="Horizontal"><Button Name="Website" Content="iantiai.com" Foreground="#00E5A0" Margin="0,0,10,0"/></StackPanel></StackPanel>
 </Grid>
</Window>
'@
$taskWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $taskXaml))
$taskControls = @{}
foreach ($taskName in @('Overall','Desktop','Bridge','Connection','Start','Logs','Details','Website')) { $taskControls[$taskName] = $taskWindow.FindName($taskName) }
$taskAssets = Join-Path $PSScriptRoot 'assets'
$taskLogoMap = @{ LogoIan='brand-ian.png'; LogoTiai='brand-tiai.png'; TagThink='brand-think.png'; TagCode='brand-code.png'; TagTrade='brand-trade.png'; TagLive='brand-live.png' }
foreach ($taskImageName in $taskLogoMap.Keys) { $taskWindow.FindName($taskImageName).Source = [Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $taskAssets $taskLogoMap[$taskImageName])) }
$taskFontUri = [uri]($taskAssets + '\')
$taskWindow.FindName('ProductTitle').FontFamily = [Windows.Media.FontFamily]::new($taskFontUri, './#Michroma')
$taskControls.Website.Add_Click({ Start-Process 'https://iantiai.com/' })
function Start-TaskHiddenCommand([string]$Command) {
    $taskInfo = New-Object System.Diagnostics.ProcessStartInfo
    $taskInfo.FileName = $taskPowerShell
    $taskEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $taskInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand ' + $taskEncoded
    $taskInfo.UseShellExecute = $false
    $taskInfo.CreateNoWindow = $true
    return [System.Diagnostics.Process]::Start($taskInfo)
}
function Convert-TaskLiteral([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }
function Start-TaskDesktop {
    if ($script:taskStarter -and !$script:taskStarter.HasExited) { return }
    $taskCommand = '& ' + (Convert-TaskLiteral (Join-Path $BridgeRoot 'START_TRADINGVIEW_MCP.ps1')) + ' *> ' + (Convert-TaskLiteral $taskStartupLog) + '; exit $LASTEXITCODE'
    $script:taskStarter = Start-TaskHiddenCommand $taskCommand
}
function Start-TaskMonitor {
    $taskCommand = '& ' + (Convert-TaskLiteral $taskNode) + ' ' + (Convert-TaskLiteral (Join-Path $PSScriptRoot 'dashboard-monitor.mjs')) + ' ' + (Convert-TaskLiteral $BridgeRoot) + ' ' + (Convert-TaskLiteral $taskStatus) + ' *> ' + (Convert-TaskLiteral $taskLog) + '; exit $LASTEXITCODE'
    $script:taskMonitor = Start-TaskHiddenCommand $taskCommand
}
$taskControls.Start.Add_Click({ Start-TaskDesktop })
$taskControls.Logs.Add_Click({ Start-Process explorer.exe -ArgumentList ('"' + $taskSession + '"') })
$taskTimer = New-Object Windows.Threading.DispatcherTimer
$taskTimer.Interval = [TimeSpan]::FromSeconds(2)
$taskTimer.Add_Tick({
    try {
        $taskRunning = @(Get-Process -Name TradingView -ErrorAction SilentlyContinue).Count -gt 0
        $taskControls.Desktop.Text = if ($taskRunning) { 'TradingView: running' } else { 'TradingView: closed' }
        $taskState = $null
        if (Test-Path -LiteralPath $taskStatus) { try { $taskState = Get-Content -LiteralPath $taskStatus -Raw | ConvertFrom-Json } catch {} }
        $taskFresh = $taskState -and (([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $taskState.updated) -lt 20000) -and !$script:taskMonitor.HasExited
        $taskControls.Bridge.Text = if ($taskFresh -and $taskState.mcp) { "MCP server: active | $($taskState.tools) tools" } else { 'MCP server: waiting / unavailable' }
        $taskActive = $taskFresh -and $taskState.connected
        $taskControls.Connection.Text = if ($taskActive) { 'Chart connection: connected' } else { 'Chart connection: disconnected' }
        $taskControls.Overall.Text = if ($taskActive) { 'ACTIVE - ready for MCP' } else { 'WAITING - connecting' }
        $taskControls.Overall.Foreground = if ($taskActive) { '#70DFAB' } else { '#F4C46A' }
        $taskLines = @()
        if ($taskFresh) { $taskLines += $taskState.message }
        if ($script:taskStarter -and $script:taskStarter.HasExited -and $script:taskStarter.ExitCode -ne 0) { $taskLines += 'TradingView startup failed. Open Logs for details.' }
        if ($script:taskMonitor.HasExited) { $taskLines += 'MCP monitor stopped. Restart this dashboard. See Logs for details.' }
        if ($script:taskStarter -and !$script:taskStarter.HasExited -and $taskRunning -and !$taskActive) { $taskLines += 'If TradingView was already running without MCP: save your work and close TradingView normally. The launcher will restart it automatically.' }
        $taskControls.Details.Text = $taskLines -join "`r`n"
    } catch { $taskControls.Details.Text = $_.Exception.Message }
})
$taskWindow.Add_Closed({
    $taskTimer.Stop()
    Set-Content -LiteralPath ($taskStatus + '.stop') -Value 'stop'
    if ($script:taskStarter -and !$script:taskStarter.HasExited) { Stop-Process -Id $script:taskStarter.Id -ErrorAction SilentlyContinue }
})
Start-TaskMonitor
if (!$NoAutoStart) { Start-TaskDesktop }
$taskTimer.Start()
$taskWindow.ShowDialog() | Out-Null





