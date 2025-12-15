# Gold Trend Scalper - User Guide

## Overview

Gold Trend Scalper is a professional MQL5 signal indicator designed specifically for trading Gold (XAUUSD) on scalping timeframes (M1, M5, M15). It uses a multi-confirmation trend-following strategy combining EMA crossovers, MACD momentum, and ADX trend strength.

## Signal Logic

### Buy Signal Conditions
A BUY signal is generated when ALL of the following conditions are met:

1. **EMA Crossover**: Fast EMA (8) crosses above Slow EMA (21)
2. **MACD Bullish**: MACD histogram is positive AND MACD line is above signal line
3. **ADX Strong**: ADX value is above the minimum threshold (default: 20)
4. **Session Active**: Current time is within an enabled trading session
5. **Spread Acceptable**: Current spread is below the maximum threshold

### Sell Signal Conditions
A SELL signal is generated when ALL of the following conditions are met:

1. **EMA Crossover**: Fast EMA (8) crosses below Slow EMA (21)
2. **MACD Bearish**: MACD histogram is negative AND MACD line is below signal line
3. **ADX Strong**: ADX value is above the minimum threshold (default: 20)
4. **Session Active**: Current time is within an enabled trading session
5. **Spread Acceptable**: Current spread is below the maximum threshold

## Input Parameters

### Moving Average Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| Fast EMA Period | 8 | Period for the fast exponential moving average |
| Slow EMA Period | 21 | Period for the slow exponential moving average |
| Applied Price | Close | Price type used for MA calculation |

### MACD Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| MACD Fast | 12 | Fast EMA period for MACD |
| MACD Slow | 26 | Slow EMA period for MACD |
| MACD Signal | 9 | Signal line period for MACD |

### ADX Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| ADX Period | 14 | Period for ADX calculation |
| ADX Min Level | 20 | Minimum ADX value for signal generation |

### Alert Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| Enable Sound Alert | true | Play sound when signal occurs |
| Enable Push Alert | true | Send push notification to mobile |
| Enable Email Alert | false | Send email when signal occurs |
| Alert Sound | alert.wav | Sound file to play for alerts |

### Session Filter

| Parameter | Default | Description |
|-----------|---------|-------------|
| Enable Session Filter | true | Filter signals by trading session |
| Trade Asian Session | false | Allow signals during 00:00-08:00 GMT |
| Trade London Session | true | Allow signals during 08:00-16:00 GMT |
| Trade New York Session | true | Allow signals during 13:00-21:00 GMT |

### Spread Filter

| Parameter | Default | Description |
|-----------|---------|-------------|
| Enable Spread Filter | true | Filter signals by spread level |
| Max Spread Points | 30 | Maximum allowed spread in points |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| Show SL/TP | true | Display stop-loss and take-profit lines |
| SL/TP Mode | ATR-Based | Calculation method (Fixed or ATR-Based) |
| Fixed SL Points | 100 | Stop-loss in points (if Fixed mode) |
| Fixed TP Points | 150 | Take-profit in points (if Fixed mode) |
| ATR Period | 14 | ATR period for calculations |
| ATR SL Multiplier | 1.5 | ATR multiplier for stop-loss |
| ATR TP Multiplier | 2.0 | ATR multiplier for take-profit |

### Visual Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| Buy Arrow Color | Lime | Color for buy signal arrows |
| Sell Arrow Color | Red | Color for sell signal arrows |
| Arrow Size | 3 | Size of signal arrows (1-5) |
| Show Info Panel | true | Display information panel on chart |
| Panel Background | Black | Background color of info panel |
| Panel Text Color | White | Text color of info panel |
| Panel X Offset | 20 | Horizontal position of panel |
| Panel Y Offset | 30 | Vertical position of panel |

## Information Panel

The info panel displays real-time trading information:

```
┌────────────────────────────────┐
│   GOLD TREND SCALPER v1.0      │
├────────────────────────────────┤
│ Trend:      ▲ BULLISH          │  <- Current trend direction
│ ADX:        28.5 (Strong)      │  <- ADX value and strength
├────────────────────────────────┤
│ Session:    LONDON (Active)    │  <- Current trading session
│ Spread:     12 pts (OK)        │  <- Current spread status
├────────────────────────────────┤
│ ATR:        15.50              │  <- Current ATR value
│ Status:     READY              │  <- Signal generation status
└────────────────────────────────┘
```

### Status Indicators

- **READY**: All filters passed, signals will be generated
- **WAITING**: Session or spread filter blocking signals

### ADX Strength Levels

- **Very Strong** (40+): Gold color - Excellent trend
- **Strong** (25-40): Green color - Good trend
- **Moderate** (20-25): Yellow color - Acceptable trend
- **Weak** (<20): Gray color - No signals generated

## Trading Sessions

The indicator recognizes three major trading sessions (GMT times):

| Session | Hours (GMT) | Characteristics |
|---------|-------------|-----------------|
| Asian | 00:00 - 08:00 | Lower volatility, ranging markets |
| London | 08:00 - 16:00 | High liquidity, trending moves |
| New York | 13:00 - 21:00 | High volatility, news events |
| London/NY Overlap | 13:00 - 16:00 | Highest liquidity period |

**Recommendation**: For Gold scalping, the London and New York sessions are typically best due to higher volatility and cleaner trends.

## SL/TP Calculation Methods

### Fixed Points Mode
- Uses predetermined pip values
- Best for consistent position sizing
- Default: 100 points SL, 150 points TP (1:1.5 risk-reward)

### ATR-Based Mode (Recommended)
- Adapts to current market volatility
- SL = ATR x SL Multiplier (e.g., ATR of 15 x 1.5 = 22.5 points)
- TP = ATR x TP Multiplier (e.g., ATR of 15 x 2.0 = 30 points)
- Better for changing market conditions

## Best Practices

### Optimal Settings for Gold Scalping

**M1 Timeframe** (Ultra-short):
- Fast EMA: 5
- Slow EMA: 13
- ADX Min Level: 18
- Max Spread: 20 points

**M5 Timeframe** (Standard scalping):
- Fast EMA: 8
- Slow EMA: 21
- ADX Min Level: 20
- Max Spread: 30 points

**M15 Timeframe** (Conservative):
- Fast EMA: 10
- Slow EMA: 25
- ADX Min Level: 22
- Max Spread: 40 points

### Risk Management Tips

1. **Never risk more than 1-2% per trade**
2. **Use the SL/TP levels provided by the indicator**
3. **Avoid trading during major news events** (NFP, FOMC, etc.)
4. **Respect the spread filter** - high spreads indicate low liquidity
5. **Trade with the trend** - only take signals in the direction of higher timeframe trend

### Combining with Other Analysis

- Use higher timeframe (H1/H4) for overall trend direction
- Identify key support/resistance levels
- Be cautious near round numbers (1900, 1950, 2000, etc.)
- Check economic calendar for scheduled news

## Alert Message Format

When a signal is generated, you receive alerts in this format:

```
XAUUSD BUY Signal @ 1985.50
SL: 1983.00 | TP: 1990.00
ADX: 28.5 | Session: LONDON
```

## Frequently Asked Questions

**Q: Why am I not seeing any signals?**
A: Check: (1) ADX might be below threshold, (2) Session filter might be blocking, (3) Spread might be too high, (4) No EMA crossover has occurred.

**Q: Can I use this for other instruments?**
A: While designed for Gold, it can work on other trending instruments. Adjust parameters based on the instrument's volatility.

**Q: What is the best timeframe?**
A: M5 is recommended for most traders. M1 requires very quick execution, while M15 gives more reliable but fewer signals.

**Q: How do I reduce false signals?**
A: Increase ADX minimum level, use higher timeframe confirmation, and only trade during active sessions.

**Q: Why are SL/TP lines not showing?**
A: Enable "Show SL/TP" in settings. Lines appear only after a new signal is generated.

## Disclaimer

This indicator is a tool to assist in trading decisions and does not guarantee profits. Always practice proper risk management and never trade with money you cannot afford to lose. Past performance does not indicate future results. The developer is not responsible for any trading losses.
