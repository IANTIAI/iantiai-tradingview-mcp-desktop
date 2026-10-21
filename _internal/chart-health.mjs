// Read-only chart check. Release stale CDP clients after a reload or tab change.
export async function chartHealth(connection, chart) {
  try {
    const state = await chart.getState();
    return { ...state, cdp_connected: true, endpoint: '127.0.0.1:9222', limited_adapter: true };
  } catch (error) {
    await connection.disconnect().catch(() => {});
    const loading = /_activeChartWidgetWV|TradingViewApi|No TradingView chart target/.test(error.message);
    return { success: false, cdp_connected: false,
      phase: loading ? 'chart_loading' : 'reconnecting',
      error: loading ? 'TradingView is open but its chart is not ready. Open a chart; reconnection is automatic.' : error.message };
  }
}
