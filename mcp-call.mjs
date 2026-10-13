// Call a tool through the same limited MCP server registered in Codex.
// Usage: node mcp-call.mjs <tool-name> [JSON-arguments]
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const directory = dirname(fileURLToPath(import.meta.url));
const upstream = resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(directory, '.vendor/tradingview-mcp'));
const require = createRequire(resolve(upstream, 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const name = process.argv[2];
if (!name) throw new Error('Usage: node mcp-call.mjs <tool-name> [JSON-arguments]');
const args = JSON.parse(process.argv[3] || '{}');
const client = new Client({ name: 'iantiai-mcp-local-client', version: '1.0.0' });
const transport = new StdioClientTransport({ env: process.env, command: process.execPath,
  args: [resolve(directory, 'mcp-server.mjs')], stderr: 'inherit' });
try {
  await client.connect(transport);
  const result = await client.callTool({ name, arguments: args });
  console.log(JSON.stringify(result, null, 2));
  if (result.isError) process.exitCode = 1;
} finally {
  await client.close();
  await transport.close();
}


