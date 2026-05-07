# Gold Trend Scalper

Professional MQL5 tools for trading Gold (XAUUSD) on scalping timeframes, including a signal indicator and an AI-assisted Expert Advisor dashboard.

## Features

- **Multi-Confirmation Signals**: Combines EMA crossovers, MACD momentum, and ADX trend strength
- **Session Filters**: Trade only during London, New York, or Asian sessions
- **Spread Filter**: Avoid signals during high-spread periods
- **SL/TP Levels**: Automatic calculation using fixed points or ATR-based methods
- **Full Alert System**: Sound, push notifications, and email alerts
- **Information Panel**: Real-time display of trend, ADX, session, and spread status
- **Gold Dashboard EA**: AI-assisted Expert Advisor with dashboard panels, optional OpenAI analysis, spread/risk gates, normalized order volume, and safer auto-trading defaults

## Signal Logic

### Buy Conditions
- Fast EMA crosses above Slow EMA
- MACD histogram positive with bullish crossover
- ADX above minimum threshold (trending market)
- Active trading session
- Acceptable spread level

### Sell Conditions
- Fast EMA crosses below Slow EMA
- MACD histogram negative with bearish crossover
- ADX above minimum threshold (trending market)
- Active trading session
- Acceptable spread level

## Installation

1. Copy [`GoldTrendScalper.mq5`](MQL5/Indicators/GoldTrendScalper.mq5) to your MT5 `Data Folder/MQL5/Indicators/`
2. Optional: copy [`GoldDashboardEA.mq5`](MQL5/Experts/GoldDashboardEA.mq5) to your MT5 `Data Folder/MQL5/Experts/`
3. Compile in MetaEditor (press F7)
4. Drag and drop onto a XAUUSD chart

See the full [Installation Guide](docs/INSTALLATION.md) for detailed instructions.

## Recommended Settings

| Timeframe | Fast EMA | Slow EMA | ADX Min | Max Spread |
|-----------|----------|----------|---------|------------|
| M1 | 5 | 13 | 18 | 20 pts |
| M5 | 8 | 21 | 20 | 30 pts |
| M15 | 10 | 25 | 22 | 40 pts |

## Parameters

### Moving Average
- Fast EMA Period (default: 8)
- Slow EMA Period (default: 21)

### MACD
- Fast Period (12), Slow Period (26), Signal (9)

### ADX
- Period (14), Minimum Level (20)

### Risk Management
- Fixed or ATR-based SL/TP calculation
- Configurable multipliers

See the full [User Guide](docs/USER_GUIDE.md) for all parameters and usage details.

## Trading Sessions (GMT)

| Session | Hours | Recommendation |
|---------|-------|----------------|
| Asian | 00:00 - 08:00 | Lower volatility |
| London | 08:00 - 16:00 | Best for scalping |
| New York | 13:00 - 21:00 | High volatility |

## Requirements

- MetaTrader 5 platform
- XAUUSD (Gold) trading pair
- Internet connection for alerts

## Disclaimer

This indicator is a trading tool and does not guarantee profits. Always use proper risk management. Past performance does not indicate future results.

## License

MIT License - See LICENSE file for details.
