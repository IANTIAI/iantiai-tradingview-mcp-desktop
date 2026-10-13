import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFileSync } from 'node:fs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(root, '.vendor/tradingview-mcp'), 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const client = new Client({ name: 'iantiai-tool-documentation', version: '1.0.0' });
const transport = new StdioClientTransport({ env: process.env, command: process.execPath, args: [resolve(root, 'mcp-server.mjs')], stderr: 'inherit' });
try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  writeFileSync(resolve(root, 'docs/tools.json'), JSON.stringify(tools, null, 2) + '\n');
  const sections = [
    ['Connection and discovery', n => n.startsWith('tv_')],
    ['Charts and symbols', n => n.startsWith('chart_') || n.startsWith('symbol_') || /^(quote_|depth_)/.test(n)],
    ['Pine Script development', n => n.startsWith('pine_')],
    ['Chart and indicator data', n => n.startsWith('data_')],
    ['Indicators', n => n.startsWith('indicator_')],
    ['Watchlists and chart panes', n => /^(watchlist_|pane_)/.test(n)],
    ['Tabs, layouts and capture', n => /^(tab_|layout_|capture_|ui_)/.test(n)],
  ];
  let md = '# MCP tool reference\n\nThis list is exported from the limited adapter using a real MCP handshake. The current release exposes **' + tools.length + ' tools**. These are callable functions, not separate applications.\n\n`ACTIVE` means the MCP handshake and chart health check succeeded. It does not validate an indicator\'s calculations.\n\n';
  for (const [title, filter] of sections) {
    md += '## ' + title + '\n\n| Tool | What it does |\n| --- | --- |\n';
    for (const tool of tools.filter(t => filter(t.name))) md += '| `' + tool.name + '` | ' + tool.description.replaceAll('|', '\\|').replaceAll('\n', ' ') + ' |\n';
    md += '\n';
  }
  md += '## Parameters\n\nSee [tools.json](tools.json) for the exact parameter names, required fields, enum values, descriptions and defaults. It is exported from this release rather than inferred from upstream documentation.\n\n## Boundaries\n\nThe adapter excludes trade execution, alerts, replay, arbitrary JavaScript evaluation, generic clicks and keystrokes, forced app restarts, and automatic updates. Saving a Pine script is private saving, not public publication. Preserve the current editor contents before writing or creating scripts.\n';
  writeFileSync(resolve(root, 'docs/TOOLS.md'), md);
  console.log('Exported ' + tools.length + ' tool definitions.');
} finally { await client.close(); await transport.close(); }

