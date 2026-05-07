# EnhancedAnalyticsPanel v2.20 → v3.00: Review, Bug Fixes & Enhancements

## Summary

Full code review of `EnhancedAnalyticsPanel.mq5` (v2.20). Found **11 bugs** (3 critical, 4 moderate, 4 minor) and added **9 enhancements**. The upgraded v3.00 ships all fixes and new features while remaining backward-compatible with existing input settings.

---

## Bugs Fixed

### Critical

| # | Bug | Location | Impact | Fix |
|---|-----|----------|--------|-----|
| 1 | **Session time overlap** | `GetSessionName()` | Hours 7–8 matched both ASIAN (0–8) and LONDON (7–12). ASIAN always won due to check order, so LONDON effectively started at 8, not 7. | Reordered checks: overlap session (NY/LON 13–17) first, then non-overlapping ranges (LONDON 8–13, NY 17–21, ASIAN 0–8). |
| 2 | **RSI filter blocks confirmatory signals** | `PerformAnalysis()` RSI filter section | When RSI < Oversold, the filter blocked BUY signals—but oversold RSI actually *supports* buying. Same for overbought RSI blocking SELL signals. The filter was penalizing signals that had extra confirmation. | Changed to only block *contrarian* moves: RSI > Overbought blocks BUY (not SELL); RSI < Oversold blocks SELL (not BUY). |
| 3 | **Identical pip display branches** | `UpdateDashboard()` pip calculation | Both branches of the ternary operator produced the same output (`slPips / 10`). JPY/2-digit pairs need a different divisor (1.0 instead of 10.0) for correct pip display. | Added proper digit-based divisor: `pipDivisor = 1.0` for 2- or 3-digit symbols, `10.0` for 5-digit symbols. |

### Moderate

| # | Bug | Location | Impact | Fix |
|---|-----|----------|--------|-----|
| 4 | **BB filter ignores VOL CHOP regime** | `PerformAnalysis()` BB filter | Only checked for `"RANGING"` regime, but `"VOL CHOP"` is also a non-trending state where BB extreme signals should be filtered. | Added `"VOL CHOP"` to the non-trending check: `bool isNonTrending = (state.regime == "RANGING" \|\| state.regime == "VOL CHOP")`. |
| 5 | **Approximated entry price** | `CalculateTradeSetup()` | Used `price + spreadValue/2` as an approximation for Ask, and `price - spreadValue/2` for Bid. MT5 provides actual Ask/Bid via `SymbolInfoDouble()`. | Now uses `SymbolInfoDouble(NULL, SYMBOL_ASK)` for BUY entries and `SYMBOL_BID` for SELL entries, with the close price as a fallback. |
| 6 | **Signal alerts fire on strength changes** | `OnCalculate()` alert section | Alert triggered on *any* signal string change, including "STRONG BUY" → "BUY" which is just a strength fluctuation, not a meaningful directional shift. | Added `GetSignalDirection()` helper that extracts "BUY"/"SELL"/"" from the signal string. Alerts now only fire when the *directional component* changes. |
| 7 | **Missing `ChartRedraw()`** | `OnCalculate()` end | After updating all UI objects, no `ChartRedraw()` was called. Updates were only visible on the next natural chart repaint, causing perceived lag. | Added `ChartRedraw(0)` after `UpdateDashboard()`. |

### Minor

| # | Bug | Location | Impact | Fix |
|---|-----|----------|--------|-----|
| 8 | **`GetTickCount()` uint overflow** | `OnCalculate()` flash/throttle logic | `GetTickCount()` returns `uint` which wraps around every ~49.7 days. Subtraction like `currentTick - crossFlashStartTick` can produce incorrect results at the boundary. | Created `TickElapsed(startTick, durationMs)` helper with overflow guard: treats any elapsed value > 0x80000000 as "elapsed". |
| 9 | **Volume average uses only 2 bars** | `AnalyzeVolume()` | Averaging only 2 previous bars made volume spike detection extremely noisy. A single anomalous bar could swing the ratio wildly. | Changed to 10-bar average (`VOLUME_AVG_BARS = 10`). Copies `VOLUME_AVG_BARS + 1` bars and loops over indices 1..N. |
| 10 | **`IsFontAvailable()` always returns true** | `IsFontAvailable()` / `InitFonts()` | MT5 silently falls back to a default font, so the test object approach can never detect unavailability. The preference loop always picked the first font. | Removed `IsFontAvailable()` and `InitFonts()`. Fonts are now set directly to known-good defaults ("Segoe UI" / "Segoe UI Semibold") which MT5 handles gracefully if unavailable. |
| 11 | **MACD histogram not used in signal logic** | `PerformAnalysis()` | MACD histogram was calculated and displayed on the dashboard but never influenced signal generation. | Added MACD histogram direction as a signal filter (see Enhancement #3 below). |

---

## Enhancements Added

### 1. MACD Histogram Direction Filter
**Input:** `Inp_UseMACDFilter` (default: `true`)

Downgrades signal strength when the MACD histogram contradicts the EMA-based signal direction:
- BUY signal + negative MACD histogram → downgraded to WEAK BUY
- SELL signal + positive MACD histogram → downgraded to WEAK SELL

### 2. Volume Confirmation Filter
**Input:** `Inp_UseVolumeFilter` (default: `true`)

Requires minimum volume participation (ratio ≥ 0.5x average) for NORMAL/STRONG signals. Low-volume signals are downgraded to WEAK, reducing false signals during illiquid periods.

### 3. ATR-Based Spread Filter
**Inputs:** `Inp_UseSpreadATRFilter` (default: `true`), `Inp_SpreadATRRatio` (default: `0.3`)

Rejects signals when the current spread exceeds 30% of ATR. This prevents entries where transaction costs eat too much of the expected move.

### 4. Bollinger Band Squeeze Detection
Detects when BB width (relative to middle band) falls below 0.5%, indicating low volatility compression and potential upcoming breakout. Displayed in the BB status field as "SQUEEZE", "SQUEEZE UP", or "SQUEEZE DN".

### 5. Squeeze Alert System
**Input:** `Inp_AlertOnSqueeze` (default: `false`)

Optional alert when a BB squeeze is detected. Uses 5x the normal cooldown to avoid alert spam during extended squeeze periods.

### 6. Signal Confidence Score (0–100%)
New composite metric displayed in the panel footer. Scoring breakdown:

| Factor | Points |
|--------|--------|
| EMA alignment (base) | +20 |
| H4 trend confirmation | +20 |
| ADX very strong (>35) | +15 |
| ADX strong (>25) | +10 |
| MTF alignment meets minimum | +15 |
| Full MTF alignment (4/4) | +5 (bonus) |
| MACD histogram alignment | +10 |
| Normal volume (1.0–2.0x) | +10 |
| RSI in favorable zone | +5 |

### 7. Improved Volume Averaging
Changed from 2-bar to 10-bar moving average for volume ratio calculation, significantly reducing noise in spike detection.

### 8. Actual Ask/Bid for Trade Setups
Entry prices now use real-time Ask (for BUY) and Bid (for SELL) from `SymbolInfoDouble()` instead of the spread-midpoint approximation. Provides more accurate SL/TP levels.

### 9. Signal Alert Includes Confidence
Alert messages now include the confidence percentage, giving traders an at-a-glance quality assessment of each signal.

---

## New Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Inp_UseVolumeFilter` | bool | true | Require volume ≥ 0.5x avg for strong signals |
| `Inp_UseMACDFilter` | bool | true | MACD histogram must align with signal direction |
| `Inp_UseSpreadATRFilter` | bool | true | Block signals when spread/ATR ratio is too high |
| `Inp_SpreadATRRatio` | double | 0.3 | Maximum allowed spread-to-ATR ratio |
| `Inp_AlertOnSqueeze` | bool | false | Alert on BB squeeze detection |

---

## Migration Notes

- All existing input parameters retain their defaults; upgrading from v2.20 requires no reconfiguration.
- The version bumps from 2.20 → 3.00 to reflect the scope of changes.
- New filters default to enabled (`true`) for immediate benefit; disable individually if they are too conservative for your strategy.
- The `IsFontAvailable()` / `InitFonts()` functions have been removed. If you had custom font logic depending on these, note that fonts now default to "Segoe UI" / "Segoe UI Semibold".
