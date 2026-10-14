param([Parameter(Mandatory=$true)][string]$Root, $Window, [switch]$CreateShortcut)
$ErrorActionPreference='Stop'
$taskIcon=Join-Path $Root 'app\assets\app-icon.ico'
if(!(Test-Path -LiteralPath $taskIcon)){throw 'Application icon is missing.'}
if($Window){
    if(!('IantiaiWindowIdentity' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IantiaiWindowIdentity {
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
}
'@
    }
    $taskResult=[IantiaiWindowIdentity]::SetCurrentProcessExplicitAppUserModelID('IANTIAI.TradingView.MCPDesktop')
    if($taskResult -ne 0){throw 'Could not set application identity.'}
    $Window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([uri]$taskIcon)
}
if($CreateShortcut){
    $taskPrograms=[Environment]::GetFolderPath('Programs')
    $taskShortcutFile=Join-Path $taskPrograms 'IANTIAI TradingView MCP Desktop.lnk'
    $taskShell=New-Object -ComObject WScript.Shell
    $taskShortcut=$taskShell.CreateShortcut($taskShortcutFile)
    $taskShortcut.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe'
    $taskShortcut.Arguments='"'+(Join-Path $Root 'launch.vbs')+'"'
    $taskShortcut.WorkingDirectory=$Root
    $taskShortcut.IconLocation=$taskIcon+',0'
    $taskShortcut.Description='IANTIAI TradingView MCP Desktop 1.0'
    $taskShortcut.Save()
}
