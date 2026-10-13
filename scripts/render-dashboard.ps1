# Documentation illustration from the production WPF layout; representative status.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskSource = Get-Content -LiteralPath (Join-Path $taskRoot 'app\TradingView-Dashboard.ps1') -Raw
[xml]$taskXml = [regex]::Match($taskSource, "(?s)\[xml\]\`$taskXaml = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$taskView = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $taskXml))
$taskAssets = Join-Path $taskRoot 'app\assets'
$taskMap = @{LogoIan='brand-ian.png';LogoTiai='brand-tiai.png';TagThink='brand-think.png';TagCode='brand-code.png';TagTrade='brand-trade.png';TagLive='brand-live.png'}
foreach ($taskKey in $taskMap.Keys) { $taskView.FindName($taskKey).Source = [Windows.Media.Imaging.BitmapImage]::new([uri](Join-Path $taskAssets $taskMap[$taskKey])) }
$taskView.FindName('ProductTitle').FontFamily = [Windows.Media.FontFamily]::new([uri]($taskAssets+'\'),'./#Michroma')
$taskView.FindName('Overall').Text = 'ACTIVE - ready for MCP'
$taskView.FindName('Overall').Foreground = '#00E5A0'
$taskView.FindName('Desktop').Text = 'TradingView: running'
$taskView.FindName('Bridge').Text = 'MCP server: active | 58 tools'
$taskView.FindName('Connection').Text = 'Chart connection: connected'
$taskView.FindName('Details').Text = 'MCP and chart connected'
$taskPanel = New-Object Windows.Controls.Grid
$taskPanel.Background = [Windows.Media.Brushes]::Black
$taskPanel.Resources = $taskView.Resources
[Windows.Documents.TextElement]::SetForeground($taskPanel, [Windows.Media.Brushes]::White)
[Windows.Documents.TextElement]::SetFontFamily($taskPanel, [Windows.Media.FontFamily]::new('Arial'))
$taskContent = $taskView.Content
$taskView.Content = $null
$taskPanel.Children.Add($taskContent) | Out-Null
$taskPanel.Width = 720
$taskPanel.Height = 650
$taskPanel.Measure([Windows.Size]::new(720,650))
$taskPanel.Arrange([Windows.Rect]::new(0,0,720,650))
$taskPanel.UpdateLayout()
$taskRender = [Windows.Media.Imaging.RenderTargetBitmap]::new(720,650,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$taskRender.Render($taskPanel)
$taskEncoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
$taskEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($taskRender))
$taskStream = [IO.File]::Create((Join-Path $taskRoot 'docs\images\dashboard.png'))
try { $taskEncoder.Save($taskStream) } finally { $taskStream.Close(); $taskView.Close() }

