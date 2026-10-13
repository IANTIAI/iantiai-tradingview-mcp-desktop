// Reads existing chart context; never changes watchlists, panes or scripts.
import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(root, '.vendor/tradingview-mcp'), 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const client = new Client({ name: 'iantiai-extension-live-check', version: '1.1.0' });
const transport = new StdioClientTransport({ env: process.env, command: process.execPath, args: [resolve(root, 'mcp-server.mjs')], stderr: 'inherit' });
try {
  await client.connect(transport);
  for (const name of ['tv_health_check', 'pane_list', 'watchlist_get', 'quote_get']) {
    try {
      const result = await client.callTool({ name, arguments: {} }, undefined, { timeout: 15000 });
      const payload = JSON.parse(result.content.find(c => c.type === 'text').text);
      const success = !result.isError && payload.success !== false;
      // Do not print account information, symbols or market data into test reports.
      console.log(JSON.stringify({ tool: name, success, ...(success ? {} : { error: payload.error || 'Tool reported a failure' }) }));
      if (!success) process.exitCode = 1;
    } catch (error) { console.log(JSON.stringify({ tool: name, success: false, error: error.message })); process.exitCode = 1; }
  }
} finally { await client.close(); await transport.close(); }
