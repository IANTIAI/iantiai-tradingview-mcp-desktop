# User guide

## Everyday use

After the one-time installation and AI-client setup, double-click Start, open your configured Claude Desktop or Codex desktop app, and speak or type your request. Voice input depends on your client or OS dictation; the dashboard does not record audio.

Describe your indicator idea in plain language. The AI can read chart context, preserve your existing Pine source, write a new version, compile it, inspect errors and refine it with you. This keeps development and feedback close together and supports quick iteration. Verify calculations before relying on the result.

ChatGPT can help with ideas and code review, but this source package does not include a direct ChatGPT connector. See the README's client references for connection options.

Double-click `START_IANTIAI_TRADINGVIEW.vbs`. TradingView starts automatically. **Start TradingView** is a fallback if you close the TradingView app while keeping the dashboard open. **Logs** opens the current session's diagnostic folder. No MCP shell is required.

The footer shows only the website link: `https://iantiai.com/`. Social and repository links belong on the website.

Closing the dashboard stops its monitor and any waiting starter. TradingView remains open. Your AI client's independently started MCP connection is managed by that client.

## Understanding status

| Display | Meaning |
| --- | --- |
| TradingView: running | A TradingView process was found. This alone does not prove MCP access. |
| MCP server: active — 58 tools | The monitor successfully connected and retrieved the exposed tool list. |
| Chart connection: connected | The read-only chart health check succeeded. |
| ACTIVE - ready for MCP | The tool-list and chart checks are successful and recent. |
| WAITING - connecting | The connection is still starting, unavailable or stale. Check the status message and Logs. |

## Read data from TradingView

1. Open the chart and confirm its symbol and timeframe with `chart_get_state`.
2. Use `data_get_ohlcv` for candles. The current schema supports a `count` parameter (up to 500) and `summary` for compact statistics.
3. Use `data_get_study_values` for currently available plotted indicator values.
4. Use `data_get_indicator` with a study entity ID obtained from the chart state to inspect inputs and study details.
5. Inspect Pine objects with `data_get_pine_lines`, `data_get_pine_labels`, `data_get_pine_tables` or `data_get_pine_boxes`. A `study_filter` can target an indicator by name.

The tools read what is available in the open TradingView context. They do not promise unlimited historical exports, tick-by-tick data, broker data or every value from an indicator. Check the returned availability, timestamps and schema before interpreting results.

Optional command-line examples, run from the repository folder:

```powershell
node .\mcp-call.mjs chart_get_state
node .\mcp-call.mjs data_get_study_values
node .\mcp-call.mjs data_get_ohlcv '{"count":100,"summary":true}'
node .\mcp-call.mjs data_get_pine_tables '{"study_filter":"My Indicator"}'
```

For JSON quoting on Windows, use PowerShell 7 or issue calls through your AI client. Older Windows PowerShell may require escaping the embedded quotes when passing JSON to native executables.

## Develop a Pine Script indicator

1. Read the current chart state and existing editor source with `pine_get_source`. Back up the source before any replacement.
2. State the desired formula, inputs, timeframe handling and expected output.
3. Use `pine_new` only after preserving the current editor contents, or open an existing script with `pine_open`.
4. Apply the source with `pine_set_source`.
5. Run `pine_analyze` or `pine_check` for preliminary checks. They do not replace TradingView compilation.
6. Compile with `pine_compile` or `pine_smart_compile`; inspect `pine_get_errors` and `pine_get_console`.
7. Verify plotted values and Pine objects against known examples and the expected formula. Include session boundaries, higher-timeframe data and repainting cases where relevant.
8. Use `pine_save` for private saving when requested. It does not publish the script publicly.

A successful compile checks syntax and compiler acceptance. It is not evidence of a profitable strategy or a correct calculation.

## Troubleshooting

**TradingView is running but the chart is disconnected:** Save work and close TradingView normally. The starter will relaunch it with loopback CDP. Then open a chart and let it load.

**Port 9222 is occupied:** The starter refuses to continue if the port is not a verified TradingView loopback listener. Check the other application using the port; do not expose the connection through a firewall rule or port forwarding.

**Dependencies cannot be found:** Run `scripts/setup.ps1` from the repository. Do not move only the launcher file: `app`, assets, the bridge files and `.vendor` are required.

**Pine editor source is not available:** Open the Pine editor and wait for it to finish loading. Try `pine_editor_open` before reading. Avoid replacing a script to diagnose a read failure.

**MSIX installation does not expose CDP:** After saving and closing TradingView, the existing starter supports the optional `-UseLocalPackageCopy` argument. This copies the installed app package into `.vendor/tradingview-desktop`; no account profile is copied. It may use substantial disk space.

**Nothing opens after launching VBS:** The machine may restrict Windows Script Host, or Node.js may be missing. For diagnostics, run `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\app\TradingView-Dashboard.ps1` in PowerShell and read the reported error.

## Tool catalogue

## Added in version 1.1

| Area | New functions | Notes |
| --- | --- | --- |
| Strategy Tester | `data_get_strategy_results`, `data_get_trades`, `data_get_equity` | Reads backtest results, simulated trades and equity. Results and trade reads may open the tester and unhide a strategy so TradingView can calculate reports. These are not broker transactions. |
| Quotes and depth | `quote_get`, `depth_get` | A quote for a different symbol may temporarily switch the chart and restore it. DOM availability depends on the current chart, panel and data access. |
| Watchlists | `watchlist_get`, `watchlist_add`, `watchlist_add_bulk`, `watchlist_remove` | The add/remove functions modify the active watchlist. Use only for the changes requested by the user. |
| Multiple charts | `pane_list`, `pane_set_layout`, `pane_focus`, `pane_set_symbol` | Lists panes and controls the chart grid, active pane and per-pane symbols. Available layouts may depend on the TradingView plan. |
| Saved layouts | `layout_switch` | Switches to an existing saved layout. Preserve pending layout changes first. |

The version 1.1 handshake and offline tests passed for all 58 exposed tool registrations. Initial live checks encountered timeouts; individual new functions and mutations have not yet been verified against the running application.

Example prompts:

> Read the current Strategy Tester performance and equity curve. State which strategy and chart context the results refer to, and do not change the script.

> Read my active watchlist. After I confirm the symbols, add them to this watchlist.

> List the current chart panes. Set up a two-chart layout with the symbols I provide, preserving any unsaved layout changes first.

All exposed functions and their descriptions are listed in [TOOLS.md](TOOLS.md). Exact parameters are available in [tools.json](tools.json).


