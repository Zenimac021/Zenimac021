# RoNz Auto SL n TP — Expert Advisor

A gold-optimized Expert Advisor that manages SL/TP, breakeven, lock-profit, and trailing stop on existing positions. Drop it on any chart and let it manage open trades — it does not open trades on its own (except optional test trades in the Strategy Tester).

Source: [`MQL5/Experts/RoNzAutoSLTP.mq5`](../MQL5/Experts/RoNzAutoSLTP.mq5)

---

## Highlights vs. v3.0

### Critical fixes
- **Breakeven / Lock-Profit / Trailing no longer get reverted every tick.** v3.0's `ProcessServerMode` recomputed `priceOpen − StopLoss` on every tick and overwrote any SL the other modules had already moved. v3.1 only places SL/TP when they are missing.
- **`ProcessServerMode` no longer wipes a manual SL or TP** when only one of `StopLoss` / `TakeProfit` is configured. Sentinel `0` is treated as "leave alone", not "remove".
- **Gold Adaptive trailing actually fires.** v3.0's ATR scaling divided by an extra `/ 100`, so the volatility multiplier almost never triggered. Thresholds now operate on raw ATR points.
- **`OrderTest` no longer stalls when a foreign position is open.** It now tracks the EA's own test positions only, instead of any open position on the account.

### High-impact fixes
- Cache cleanup runs in **both** tick mode and timer mode (was timer-only).
- `IsValidStopLevel` reads a live tick before validating, so long timer intervals don't reject otherwise-valid stops.
- `IsRetriableTradeRetcode` now also retries on `TIMEOUT`, `CONNECTION`, and `TOO_MANY_REQUESTS`.
- `ProcessClientMode` honors `IncludeSpreadInSL` for symmetry with server mode.
- `OrderTest` uses live `MqlTick` and broker minimum volume; sends with market price.

### Enhancements
- **All-Gold Detection.** `IsGoldSymbol` now recognises any of `XAU`, `GOLD`, `GLD` (case-insensitive) regardless of broker prefix/suffix or punctuation. Examples that work out of the box:
  - `XAUUSD`, `XAUUSD.m`, `XAUUSD-pro`, `XAU/USD`, `xau_usd`
  - `GOLD`, `GOLD.cash`, `Gold-Pro`, `_GOLD_`
  - `GLD`, `GLD.us`
- New input `GoldSymbolKeywords` (default `XAU,GOLD,GLD`) lets you add more keywords without recompiling.
- New input `GoldSymbolOverrides` lets you whitelist one-off broker-specific names that don't match any keyword.
- New input `EnableGoldAdjustments` toggles the volatility multiplier off entirely (useful for A/B tests).
- New input `IncludeSpreadInTP` (default `false`) so server/client modes can be configured symmetrically.
- New input `MaxDrawdownPct` (`0` = disabled). When equity drops by this fraction below the EA's startup balance, all managed positions are closed at market.
- Centralised gold multiplier through one helper (`GetAdjustedLevels`) — every module uses the same numbers per iteration.
- Stricter input validation: rejects `ProfitLock >= LockProfitAfter`, zero `BreakevenTrigger` when breakeven is enabled, etc.
- `EnableTest` defaults to `false` so the EA cannot accidentally open test trades on a live account when the timer is disabled.

---

## Inputs (overview)

| Group | Input | Default | Notes |
|---|---|---|---|
| SL & TP | `TakeProfit` | 8000 pts | `0` = no TP |
| | `StopLoss` | 5000 pts | `0` = no SL |
| | `SLnTPMode` | `SERVER` | `CLIENT` keeps SL/TP virtual until hit |
| | `IncludeSpreadInSL` | `true` | |
| | `IncludeSpreadInTP` | `false` | New |
| Lock Profit | `LockProfitEnable` | `LP_ENABLE` | |
| | `LockProfitAfter` | 45 pts | |
| | `ProfitLock` | 25 pts | Must be `<` `LockProfitAfter` |
| Trailing | `TrailingStopMethod` | `TS_GOLD_ADAPTIVE` | |
| | `TrailingStop` | 50 pts | |
| | `TrailingStep` | 35 pts | |
| Breakeven | `EnableBreakeven` | `true` | |
| | `BreakevenTrigger` | 25 pts | Must be `> 0` when enabled |
| Gold | `EnableGoldAdjustments` | `true` | New |
| | `GoldSymbolKeywords` | `XAU,GOLD,GLD` | New (case-insensitive, CSV) |
| | `GoldSymbolOverrides` | `""` | New (CSV of explicit symbol names) |
| Risk | `MaxDrawdownPct` | `0.0` | New. `0` = disabled |
| General | `ExpertMagicNumber` | 18745 | |
| | `Slippage` | 15 pts | |
| | `ChartSymbolSelection` | `CURRENT_CHART_SYMBOL` | |
| | `EnableTest` | `false` | New default; only fires inside the Strategy Tester |
| | `LogLevel` | `LOG_OPERATIONS` | `LOG_VERBOSE` is helpful for tuning |
| | `ProcessingInterval` | 1000 ms | `0` falls back to `OnTick` |
| | `MaxSpreadPoints` | 500 pts | `0` = disabled |

---

## Installation

1. Copy [`RoNzAutoSLTP.mq5`](../MQL5/Experts/RoNzAutoSLTP.mq5) to your MT5 `Data Folder/MQL5/Experts/`.
2. In MetaEditor, open the file and press **F7** to compile.
3. Drag the EA onto any chart for a symbol whose positions you want managed.
4. In the inputs dialog, leave defaults for XAUUSD or tune per the table above.
5. Make sure **AutoTrading** is enabled in the MT5 toolbar.

The EA does not open trades by itself — pair it with your discretionary entries or another expert/indicator that opens positions.

---

## Tuning notes

* **Multi-symbol mode (`ALL_OPEN_ORDERS`)**: with `ExpertMagicNumber = 0`, every position on the account is managed regardless of magic. With any other magic, only that magic is managed.
* **Drawdown guard**: starts measuring from the balance captured in `OnInit`. If you reload the EA, the baseline is reset.
* **Verbose logging**: set `LogLevel = LOG_VERBOSE` in the Strategy Tester to see exactly which SL/TP changes were skipped (and why).
