param([Parameter(Mandatory=$true)][string]$Root, [Parameter(Mandatory=$true)][string]$Node,
    [string]$ClaudeDirectory=(Join-Path $env:APPDATA 'Claude'),
    [string]$CodexDirectory=(Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'))
$ErrorActionPreference='Stop'
$taskClaudeDirectory=$ClaudeDirectory
if(Test-Path -LiteralPath $taskClaudeDirectory) {
    $taskFile=Join-Path $taskClaudeDirectory 'claude_desktop_config.json'
    $taskConfig=if(Test-Path -LiteralPath $taskFile){Get-Content -LiteralPath $taskFile -Raw|ConvertFrom-Json}else{[pscustomobject]@{}}
    if(!$taskConfig.PSObject.Properties['mcpServers']){$taskConfig|Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})}
    if(!$taskConfig.mcpServers.PSObject.Properties['iantiai-tradingview-desktop']) {
        if(Test-Path -LiteralPath $taskFile){Copy-Item -LiteralPath $taskFile -Destination ($taskFile+'.iantiai-backup-'+(Get-Date -Format 'yyyyMMddHHmmss'))}
        $taskConfig.mcpServers|Add-Member -NotePropertyName 'iantiai-tradingview-desktop' -NotePropertyValue ([pscustomobject]@{command=$Node;args=@((Join-Path $Root 'mcp-server.mjs'))})
        [IO.File]::WriteAllText($taskFile,($taskConfig|ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))
    }
}
$taskCodexDirectory=$CodexDirectory
if(Test-Path -LiteralPath $taskCodexDirectory) {
    $taskFile=Join-Path $taskCodexDirectory 'config.toml'
    $taskToml=if(Test-Path -LiteralPath $taskFile){Get-Content -LiteralPath $taskFile -Raw}else{''}
    if($taskToml -notmatch '(?m)^\[mcp_servers\.(?:iantiai_tradingview_desktop|tradingview_desktop)\]\s*$') {
        if(Test-Path -LiteralPath $taskFile){Copy-Item -LiteralPath $taskFile -Destination ($taskFile+'.iantiai-backup-'+(Get-Date -Format 'yyyyMMddHHmmss'))}
        $taskBlock="`r`n[mcp_servers.iantiai_tradingview_desktop]`r`ncommand = "+(ConvertTo-Json -InputObject $Node -Compress)+"`r`nargs = ["+(ConvertTo-Json -InputObject (Join-Path $Root 'mcp-server.mjs') -Compress)+"]`r`n"
        [IO.File]::WriteAllText($taskFile,$taskToml+$taskBlock,[Text.UTF8Encoding]::new($false))
    }
}
