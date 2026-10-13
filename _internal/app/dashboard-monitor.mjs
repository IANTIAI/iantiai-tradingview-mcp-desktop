import { createRequire } from 'node:module';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFileSync, renameSync, existsSync } from 'node:fs';
const root = process.argv[2];
const output = process.argv[3];
const require = createRequire(resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(root, '.vendor/tradingview-mcp'), 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
let client, transport, stopping = false;
function save(state) {
  writeFileSync(output + '.tmp', JSON.stringify({ updated: Date.now(), ...state }));
  renameSync(output + '.tmp', output);
}
async function close() {
  await client?.close().catch(() => {});
  await transport?.close().catch(() => {});
  client = transport = undefined;
}
process.on('SIGINT', () => { stopping = true; });
process.on('SIGTERM', () => { stopping = true; });
while (!stopping && !existsSync(output + '.stop')) {
  try {
    if (!client) {
      client = new Client({ name: 'iantiai-desktop-dashboard', version: '1.0.0' });
      transport = new StdioClientTransport({ env: process.env, command: process.execPath, args: [resolve(root, 'mcp-server.mjs')], stderr: 'inherit', windowsHide: true });
      await client.connect(transport, { timeout: 30000 });
    }
    const { tools } = await client.listTools({}, { timeout: 30000 });
    save({ mcp: true, tools: tools.length, connected: false, message: 'MCP ready; checking chart connection' });
    const result = await client.callTool({ name: 'tv_health_check', arguments: {} }, undefined, { timeout: 15000 });
    const payload = JSON.parse(result.content.find(c => c.type === 'text').text);
    save({ mcp: true, tools: tools.length, connected: !result.isError && payload.cdp_connected === true,
      message: result.isError ? (payload.error || 'Chart unavailable') : 'MCP and chart connected' });
  } catch (error) {
    save({ mcp: false, connected: false, message: error.message });
    await close();
  }
  await new Promise(r => setTimeout(r, 3000));
}
await close();



