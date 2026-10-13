# Advanced configuration and verification

## Advanced: AI client connection

The bridge uses the MCP **stdio** transport. Configure your client's equivalent of `mcpServers`:

```json
{
  "mcpServers": {
    "iantiai-tradingview-desktop": {
      "command": "node",
      "args": ["C:/path/to/iantiai-tradingview-mcp-desktop/_internal/mcp-server.mjs"]
    }
  }
}
```

Replace the example path with your absolute repository path. Your AI client starts its own MCP server process; the dashboard's monitoring process does not replace that configuration.

## Verification

```powershell
node .\_internal\mcp-check.mjs             # Handshake, allowlist and offline Pine analysis
node .\_internal\mcp-check.mjs --live      # Adds read-only checks of the open chart
node .\_internal\scripts\export-tools.mjs # Regenerates tool reference and parameter schemas
```

For this packaging, the adapter handshake, 58-tool catalogue, allowlist and offline Pine analysis were checked against the existing pinned local runtime. The dashboard layout and PowerShell syntax were checked. A fresh installation on another PC and every individual live tool have not been tested.


## Automatic startup verification

The automated component download, installation and 58-tool smoke test passed on the development machine. Client configuration was checked with isolated sample Claude and Codex profiles, including preservation of existing settings and repeated runs. Runtime dependencies were refreshed within their supported version ranges and npm reported zero runtime vulnerabilities at this check. The no-runtime download branch was exercised; installing TradingView on a clean PC has not been tested. Sign-in and any Windows approval prompts still require the user.
