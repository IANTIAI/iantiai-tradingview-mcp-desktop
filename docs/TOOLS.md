# MCP tool reference

This list is exported from the limited adapter using a real MCP handshake. The current release exposes **58 tools**. These are callable functions, not separate applications.

`ACTIVE` means the MCP handshake and chart health check succeeded. It does not validate an indicator's calculations.

## Connection and discovery

| Tool | What it does |
| --- | --- |
| `tv_discover` | Report which known TradingView API paths are available and their methods |
| `tv_ui_state` | Get current UI state: which panels are open, what buttons are visible/enabled/disabled |
| `tv_health_check` | Read-only check of the local TradingView chart connection; no update check or app restart. |

## Charts and symbols

| Tool | What it does |
| --- | --- |
| `chart_get_state` | Get current chart state (symbol, timeframe, chart type, indicators) |
| `chart_set_symbol` | Change the chart symbol |
| `chart_set_timeframe` | Change the chart timeframe/resolution |
| `chart_set_type` | Change chart type |
| `chart_manage_indicator` | Add or remove an indicator/study on the chart |
| `chart_get_visible_range` | Get the visible date range (unix timestamps) and bars range on the chart |
| `chart_set_visible_range` | Zoom the chart to a specific date range (unix timestamps) |
| `chart_scroll_to_date` | Jump the chart view to center on a specific date |
| `symbol_info` | Get detailed metadata about the current symbol (name, exchange, type, description) |
| `symbol_search` | Search for symbols by name or keyword |
| `quote_get` | Get real-time quote data for a symbol (price, OHLC, volume). If symbol is provided and differs from the current chart, the chart is briefly switched to fetch the quote and then restored — adds ~1-2s and serializes parallel calls. |
| `depth_get` | Get order book / DOM (Depth of Market) data from the chart |

## Pine Script development

| Tool | What it does |
| --- | --- |
| `pine_get_source` | Get current Pine Script source code from the editor |
| `pine_set_source` | Set Pine Script source code in the editor |
| `pine_compile` | Compile / add the current Pine Script to the chart |
| `pine_get_errors` | Get Pine Script compilation errors from Monaco markers |
| `pine_save` | Save the current Pine Script (Ctrl+S) |
| `pine_get_console` | Read Pine Script console/log output (compile messages, log.info(), errors) |
| `pine_smart_compile` | Intelligent compile: detects button, compiles, checks errors, reports study changes |
| `pine_new` | Create a new blank Pine Script |
| `pine_open` | Open a saved Pine Script by name |
| `pine_list_scripts` | List saved Pine Scripts |
| `pine_analyze` | Run static analysis on Pine Script code WITHOUT compiling — catches array out-of-bounds, unguarded array.first()/last(), bad loop bounds, and implicit bool casts. Works offline, no TradingView connection needed. |
| `pine_check` | Compile Pine Script via TradingView's server API without needing the chart open. Returns compilation errors/warnings. Useful for validating code before injecting into the chart. |
| `pine_editor_open` | Open the Pine editor only; no trading or broker panel access. |

## Chart and indicator data

| Tool | What it does |
| --- | --- |
| `data_get_ohlcv` | Get OHLCV bar data from the chart. Use summary=true for compact stats instead of all bars (saves context). |
| `data_get_indicator` | Get indicator/study info and input values |
| `data_get_strategy_results` | Get strategy performance metrics from Strategy Tester. Auto-opens the panel and auto-unhides a hidden strategy (TradingView never computes reports for hidden strategies); result includes unhidden_strategies when that happened. |
| `data_get_trades` | Get trade list from Strategy Tester. Auto-opens the panel and auto-unhides a hidden strategy. |
| `data_get_equity` | Get equity curve data from Strategy Tester |
| `data_get_pine_lines` | Read horizontal price levels drawn by Pine Script indicators (line.new). Returns deduplicated price levels per study. Use study_filter to target a specific indicator. |
| `data_get_pine_labels` | Read text labels drawn by Pine Script indicators (label.new). Returns text and price pairs. Use study_filter to target a specific indicator. |
| `data_get_pine_tables` | Read table data drawn by Pine Script indicators (table.new). Returns formatted text rows per table. Use study_filter to target a specific indicator. |
| `data_get_pine_boxes` | Read box/zone boundaries drawn by Pine Script indicators (box.new). Returns deduplicated {high, low} price zones. Use study_filter to target a specific indicator. |
| `data_get_study_values` | Get current indicator values from the data window for all visible studies (RSI, MACD, Bollinger Bands, EMAs, custom indicators with plot()). |

## Indicators

| Tool | What it does |
| --- | --- |
| `indicator_set_inputs` | Change indicator/study input values (e.g., length, source, period) |
| `indicator_toggle_visibility` | Show or hide an indicator/study on the chart |
| `indicator_search` | Search TradingView's Indicators dialog for indicators, strategies, and community/public scripts by keyword. Returns matching titles grouped by section (Technicals, Community, My scripts, etc.). |
| `indicator_add` | Search the Indicators dialog and add a result to the chart by name. Works for strategies and community scripts, not just built-ins. Returns the new study entity_id. |

## Watchlists and chart panes

| Tool | What it does |
| --- | --- |
| `watchlist_get` | Get all symbols from the current TradingView watchlist with last price, change, and change% |
| `watchlist_add` | Add a symbol to the TradingView watchlist |
| `watchlist_add_bulk` | Add multiple symbols to the TradingView watchlist |
| `watchlist_remove` | Remove one or more symbols from the active TradingView watchlist |
| `pane_list` | List all chart panes in the current layout with their symbols and active state |
| `pane_set_layout` | Change the chart grid layout (e.g., single, 2x2, 2h, 3v) |
| `pane_focus` | Focus a specific chart pane by index (0-based) |
| `pane_set_symbol` | Set the symbol on a specific pane by index |

## Tabs, layouts and capture

| Tool | What it does |
| --- | --- |
| `capture_screenshot` | Take a screenshot of the TradingView chart |
| `tab_list` | List all open TradingView chart tabs |
| `tab_new` | Open a new chart tab. Optionally pick what to load in it: layout "new" creates a named blank layout, or pass a saved layout name to open it. |
| `layout_new` | Create a new named blank chart layout (opens in a new tab) |
| `tab_switch` | Switch to a chart tab by index |
| `layout_list` | List saved chart layouts |
| `layout_switch` | Switch to a saved chart layout by name or ID |
| `ui_find_element` | Find UI elements by text, aria-label, or CSS selector and return their positions |

## Parameters

See [tools.json](tools.json) for the exact parameter names, required fields, enum values, descriptions and defaults. It is exported from this release rather than inferred from upstream documentation.

## Boundaries

The adapter excludes trade execution, alerts, replay, arbitrary JavaScript evaluation, generic clicks and keystrokes, forced app restarts, and automatic updates. Saving a Pine script is private saving, not public publication. Preserve the current editor contents before writing or creating scripts.
