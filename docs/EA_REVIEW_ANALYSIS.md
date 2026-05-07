# Advanced SMC Institutional EA - Code Review & Enhancement Report

## Overview

Full review, debugging, and enhancement of the `Advanced_SMC_Institutional_EA.mq5` Expert Advisor. The EA wraps the `Advanced_SMC_Institutional_Signals` custom indicator and automates trade execution with risk management.

---

## Bugs Fixed

### 1. ProcessClosedDeals Iteration Order (Critical)

**Problem:** The loop iterated newest-to-oldest (`for(int i = deals - 1; i >= 0; i--)`) while using `g_lastProcessedDeal` as a watermark. When the first (newest) deal was processed, its ticket ID was stored in `g_lastProcessedDeal`. All older deals with lower ticket IDs were then skipped by the `dealTicket <= g_lastProcessedDeal` check — meaning they were **never processed**. This caused missed loss/win tracking, incorrect daily stats, and broken daily risk lock.

**Fix:** Reversed the loop to iterate oldest-to-newest (`for(int i = 0; i < deals; i++)`), ensuring every deal is processed sequentially and the watermark advances correctly.

### 2. Fixed-Size Partial Ticket Array (Moderate)

**Problem:** `ulong g_partialTickets[32]` was a fixed 32-element array. After 32 partial takes without clearing, `MarkPartialTaken` silently stopped recording — subsequent positions would get **duplicate partial closes** because `HasPartialTaken` returned false.

**Fix:** Converted to a dynamic array using `ArrayResize()`. The array grows as needed and shrinks when tickets are cleared.

### 3. Trailing Stop Fires Before Break-Even (Moderate)

**Problem:** The trailing stop logic had no coordination with break-even. The trailing stop could move the stop loss before break-even was ever triggered, defeating the purpose of the break-even feature. If a user expected "break-even first, then trail," the EA would trail immediately.

**Fix:** Added `g_breakEvenHit` flag. Trailing stop now only activates after break-even has been confirmed. The flag resets on position close and new entry.

### 4. No Algo Trading Permission Check (Moderate)

**Problem:** The EA attempted to place trades without verifying that algorithmic trading was enabled at the terminal, account, and MQL program levels. This led to silent trade failures with unhelpful error messages.

**Fix:** Added `IsAlgoTradingAllowed()` function that checks `TERMINAL_TRADE_ALLOWED`, `MQL_TRADE_ALLOWED`, `ACCOUNT_TRADE_ALLOWED`, and `ACCOUNT_TRADE_EXPERT`. Called in both `OnInit` (warning) and `ExecuteSignal` (skip with reason).

### 5. No Trade Result Verification (Minor)

**Problem:** After `g_trade.Buy()` or `g_trade.Sell()`, only `GetLastError()` was checked. The actual trade server retcode (requote, no money, invalid stops, etc.) was ignored, making debugging difficult.

**Fix:** Added `RetcodeDescription()` function that translates 20+ trade retcodes to human-readable strings. Both `ExecuteSignal` and `CloseManagedPosition` now log the specific retcode on failure. Successful trades also verify the retcode is `DONE`/`DONE_PARTIAL`/`PLACED`.

### 6. g_entryBarTime Not Reset on Position Close (Minor)

**Problem:** When a position was closed by SL/TP (not by the EA's explicit close logic), `g_entryBarTime` retained the stale value from the previous trade. While not causing crashes (since `GetManagedPosition` returns false when flat), this left dirty state for the next trade cycle.

**Fix:** `g_entryBarTime` is now reset to 0 in `CloseManagedPosition()` and `ProcessClosedDeals()`.

### 7. Dead Preset Enum (Minor)

**Problem:** `ENUM_SMC_PRESET` was declared with 7 values but never implemented — no code read it or applied presets. Users saw the enum in the settings but it did nothing.

**Fix:** Fully implemented the preset system (see Enhancements below).

---

## Enhancements Added

### 1. Preset System

Implemented all 7 presets with tuned parameters:

| Preset | Risk % | SL Buffer | TP RR | Partial RR | BE RR | Trail ATR | Max Bars | Spike Mult |
|--------|--------|-----------|-------|------------|-------|-----------|----------|------------|
| Custom | user | user | user | user | user | user | user | user |
| Aggressive | 2.00 | 0.15 | 2.50 | 0.80 | 0.80 | 0.80 | 16 | 3.00 |
| Balanced | 1.00 | 0.25 | 1.80 | 1.00 | 1.00 | 1.00 | 24 | 2.50 |
| Conservative | 0.50 | 0.40 | 1.50 | 1.20 | 1.20 | 1.20 | 36 | 2.00 |
| Gold Scalping | 1.50 | 0.20 | 2.00 | 0.80 | 0.80 | 0.70 | 12 | 2.00 |
| Forex Intraday | 1.00 | 0.30 | 2.00 | 1.00 | 1.00 | 1.00 | 30 | 2.50 |
| Indices Momentum | 1.25 | 0.35 | 2.50 | 1.00 | 1.00 | 1.20 | 20 | 3.00 |

Preset selection is a simple dropdown. "Custom" uses all manual input values. Any other preset overrides the relevant runtime parameters while preserving non-preset inputs.

### 2. Entry Cooldown

New input `InpEntryCooldownBars` (default: 2). After a position closes, the EA waits N bars before allowing a new entry. Prevents rapid re-entry into choppy markets after a stop-out. Cooldown counter decrements on each new bar and is displayed on the panel.

### 3. Friday Close Protection

New inputs:
- `InpUseFridayClose` (default: false) — enable/disable
- `InpFridayCloseHour` (default: 20) — server hour to close

When enabled, any open position is automatically closed on Friday at the specified hour, and no new entries are allowed during the Friday close window. Prevents weekend gap risk.

### 4. Max Drawdown Protection

New input `InpMaxDrawdownPercent` (default: 10.0, 0=disabled). Tracks peak account balance and computes current drawdown. If drawdown exceeds the threshold, `g_dailyLockActive` is set to true, preventing new entries. Drawdown percentage and peak balance are displayed on the panel.

### 5. Enhanced Panel

The panel now shows:
- **Preset name** — which preset is active
- **Cooldown counter** — bars remaining before new entries allowed
- **Drawdown info** — current DD% and peak balance
- **Version bump** — "Advanced SMC EA v2" title

### 6. Detailed Initialization Logging

`OnInit` now prints the active preset, effective risk percentage, and TP risk-reward ratio on startup for easier diagnostics.

---

## Code Quality Improvements

- Version bumped from `1.00` to `2.00`
- Runtime preset variables (`rt_*`) cleanly separate input values from effective values
- All trade operations include retcode logging
- Dynamic array for partial ticket tracking eliminates silent overflow
- Consistent state reset (`g_breakEvenHit`, `g_entryBarTime`, `g_cooldownBarsRemaining`) across all close paths
- CSV log failure now prints the error code instead of silently failing
