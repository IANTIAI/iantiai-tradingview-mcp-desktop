// MCP protocol smoke test. Default is offline; --live only reads the open chart.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const directory = dirname(fileURLToPath(import.meta.url));
const upstream = resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(directory, '.vendor/tradingview-mcp'));
const require = createRequire(resolve(upstream, 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const client = new Client({ name: 'iantiai-setup-check', version: '1.0.0' });
const transport = new StdioClientTransport({
  env: process.env, command: process.execPath, args: [resolve(directory, 'mcp-server.mjs')], stderr: 'inherit',
});
try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  const names = tools.map(tool => tool.name);
  for (const required of ['pine_set_source', 'pine_compile', 'pine_get_errors', 'data_get_pine_tables', 'tv_health_check',
    'data_get_strategy_results', 'data_get_trades', 'data_get_equity', 'quote_get', 'depth_get',
    'watchlist_get', 'watchlist_add', 'watchlist_add_bulk', 'watchlist_remove',
    'pane_list', 'pane_set_layout', 'pane_focus', 'pane_set_symbol', 'layout_switch']) {
    assert(names.includes(required), `Missing tool: ${required}`);
  }
  for (const forbidden of ['tv_launch', 'tv_update', 'ui_evaluate', 'ui_click', 'ui_keyboard', 'tab_close']) {
    assert(!names.includes(forbidden), `Forbidden tool exposed: ${forbidden}`);
  }
  assert.equal(names.length, 58, 'Unexpected adapter tool count');
  assert(!names.some(name => /^(alert_|replay_|batch_)/.test(name)));
  const analysis = await client.callTool({ name: 'pine_analyze', arguments: {
    source: '//@version=6\nindicator("MCP offline check")\nplot(close)\n',
  } });
  assert(!analysis.isError, JSON.stringify(analysis));
  console.log(JSON.stringify({ stage: 'offline', success: true, tool_count: names.length, tools: names, analysis }, null, 2));
  if (process.argv.includes('--live')) {
    for (const name of ['tv_health_check', 'chart_get_state']) {
      const result = await client.callTool({ name, arguments: {} });
      console.log(JSON.stringify({ stage: 'live', tool: name, result }, null, 2));
      assert(!result.isError, `Live tool failed: ${name}`);
    }
  }
  if (process.argv.includes('--pine')) {
    const opened = await client.callTool({ name: 'pine_editor_open', arguments: {} });
    console.log(JSON.stringify({ stage: 'pine', tool: 'pine_editor_open', result: opened }, null, 2));
    assert(!opened.isError, 'Pine editor could not be opened');
    const source = await client.callTool({ name: 'pine_get_source', arguments: {} });
    assert(!source.isError, 'Pine source could not be read');
    // Do not print the user's current script into setup logs.
    const payload = JSON.parse(source.content.find(item => item.type === 'text').text);
    assert(payload.success === true, 'Pine source returned an unsuccessful result');
    assert(typeof payload.source === 'string', 'Pine source is not a string');
    console.log(JSON.stringify({ stage: 'pine', tool: 'pine_get_source', success: payload.success,
      source_read: typeof payload.source === 'string', source_characters: payload.source?.length ?? null }, null, 2));
  }
} finally {
  await client.close();
  await transport.close();
}


