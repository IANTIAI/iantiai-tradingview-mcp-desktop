// Local, limited adapter for tradesdontlie/tradingview-mcp.
// Upstream is pinned in .local-tools; do not expose its unrestricted server.
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));
const upstream = resolve(process.env.IANTIAI_TV_UPSTREAM || resolve(directory, '.vendor/tradingview-mcp'));
const require = createRequire(resolve(upstream, 'package.json'));
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
process.env.TV_CDP_HOST = '127.0.0.1';
process.env.TV_CDP_PORT = '9222';
const load = (path) => import(pathToFileURL(resolve(upstream, 'src', path)).href);

const allowed = new Set([
  'tv_discover', 'tv_ui_state',
  'chart_get_state', 'chart_set_symbol', 'chart_set_timeframe', 'chart_set_type',
  'chart_manage_indicator', 'chart_get_visible_range', 'chart_set_visible_range',
  'chart_scroll_to_date', 'symbol_info', 'symbol_search',
  'pine_get_source', 'pine_set_source', 'pine_compile', 'pine_get_errors',
  'pine_save', 'pine_get_console', 'pine_smart_compile', 'pine_new', 'pine_open',
  'pine_list_scripts', 'pine_analyze', 'pine_check',
  'data_get_ohlcv', 'data_get_indicator', 'data_get_pine_lines',
  'data_get_pine_labels', 'data_get_pine_tables', 'data_get_pine_boxes',
  'data_get_study_values', 'capture_screenshot',
  'indicator_set_inputs', 'indicator_toggle_visibility', 'indicator_search', 'indicator_add',
  'tab_list', 'tab_new', 'tab_switch', 'layout_new', 'layout_list', 'ui_find_element',
  'data_get_strategy_results', 'data_get_trades', 'data_get_equity', 'quote_get', 'depth_get',
  'watchlist_get', 'watchlist_add', 'watchlist_add_bulk', 'watchlist_remove',
  'pane_list', 'pane_set_layout', 'pane_focus', 'pane_set_symbol', 'layout_switch',
]);
const registered = new Set();
const server = new McpServer({ name: 'iantiai-tradingview-desktop', version: '1.1.0' }, {
  instructions: 'Local TradingView Desktop bridge for Pine development and chart verification. Preserve existing editor contents before writing or creating scripts. Never publish scripts or place trades. A successful MCP connection does not validate indicator calculations. Compilation and saving may send script source to TradingView through the signed-in session. Desktop must be started with loopback CDP; this server does not launch or kill it.',
});
const filtered = {
  tool(name, ...args) {
    if (!allowed.has(name)) return undefined;
    registered.add(name);
    return server.tool(name, ...args);
  },
};
for (const [file, fn] of [
  ['health', 'registerHealthTools'], ['chart', 'registerChartTools'],
  ['pine', 'registerPineTools'], ['data', 'registerDataTools'],
  ['capture', 'registerCaptureTools'], ['indicators', 'registerIndicatorTools'],
  ['tab', 'registerTabTools'], ['ui', 'registerUiTools'],
  ['watchlist', 'registerWatchlistTools'], ['pane', 'registerPaneTools'],
]) {
  const module = await load(`tools/${file}.js`);
  if (typeof module[fn] !== 'function') throw new Error(`Unsupported upstream module: ${file}/${fn}`);
  module[fn](filtered);
}
for (const name of allowed) {
  if (!registered.has(name)) throw new Error(`Missing allowlisted upstream tool: ${name}`);
}
const { jsonResult } = await load('tools/_format.js');
const chart = await load('core/chart.js');
const ui = await load('core/ui.js');
server.tool('tv_health_check', 'Read-only check of the local TradingView chart connection; no update check or app restart.', {}, async () => {
  try {
    const state = await chart.getState();
    return jsonResult({ ...state, cdp_connected: true, endpoint: '127.0.0.1:9222', limited_adapter: true });
  } catch (error) {
    return jsonResult({ success: false, error: error.message, hint: 'Save and close TradingView, then run START_TRADINGVIEW_MCP.ps1. No automatic forced restart.' }, true);
  }
});
server.tool('pine_editor_open', 'Open the Pine editor only; no trading or broker panel access.', {}, async () => {
  try { return jsonResult(await ui.openPanel({ panel: 'pine-editor', action: 'open' })); }
  catch (error) { return jsonResult({ success: false, error: error.message }, true); }
});
console.error(`IANTIAI TradingView MCP: ${registered.size + 2} tools; loopback only; no trading, arbitrary UI evaluation, forced launch or auto-update tools.`);
await server.connect(new StdioServerTransport());

