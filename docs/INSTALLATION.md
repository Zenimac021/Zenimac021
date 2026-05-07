# Gold Trend Scalper - Installation Guide

## System Requirements

- MetaTrader 5 (MT5) trading platform
- Windows, macOS, or Linux operating system
- Minimum 4GB RAM recommended
- Active internet connection for alerts

## Installation Steps

### Method 1: Manual Installation

1. **Download the MQL5 File**
   - Download `GoldTrendScalper.mq5` for the indicator
   - Optional: download `GoldDashboardEA.mq5` for the Expert Advisor dashboard

2. **Locate Your MT5 Data Folder**
   - Open MetaTrader 5
   - Click **File** > **Open Data Folder**
   - Navigate to `MQL5/Indicators/` for the indicator or `MQL5/Experts/` for the EA

3. **Copy the MQL5 File**
   - Copy `GoldTrendScalper.mq5` to the `MQL5/Indicators/` folder
   - Copy `GoldDashboardEA.mq5` to the `MQL5/Experts/` folder if you want the EA dashboard

4. **Compile the MQL5 File**
   - In MT5, open **Navigator** (Ctrl+N)
   - Right-click on **Indicators** or **Expert Advisors** and select **Refresh**
   - Double-click on `GoldTrendScalper` or `GoldDashboardEA` to open in MetaEditor
   - Press **F7** or click **Compile** button
   - Ensure there are no errors (0 errors, 0 warnings)

5. **Add to Chart**
   - Open a XAUUSD (Gold) chart
   - In Navigator, find `GoldTrendScalper` under Indicators or `GoldDashboardEA` under Expert Advisors
   - Drag and drop onto the chart, or double-click to apply
   - For the EA, keep `InpEnableTrading=false` until you have reviewed settings and enabled MT5 AutoTrading intentionally

### Expert Advisor Safety Notes

- `GoldDashboardEA.mq5` defaults to `InpEnableTrading=false`.
- Set your OpenAI API key in the EA inputs if enabling live AI analysis.
- Add `https://api.openai.com` under **Tools** > **Options** > **Expert Advisors** > **Allow WebRequest for listed URL**.
- Review lot size, spread limit, max positions, daily loss, and drawdown settings before enabling live trading.

### Method 2: Direct Installation via MetaEditor

1. **Open MetaEditor**
   - In MT5, press **F4** or click **Tools** > **MetaQuotes Language Editor**

2. **Create New MQL5 File**
   - Click **File** > **New** > **Custom Indicator** or **Expert Advisor**
   - Name it `GoldTrendScalper` or `GoldDashboardEA`

3. **Replace Code**
   - Delete the template code
   - Copy and paste the entire code from `GoldTrendScalper.mq5` or `GoldDashboardEA.mq5`

4. **Compile and Use**
   - Press **F7** to compile
   - Return to MT5 (F5) and apply the indicator or EA to your chart

## Post-Installation Setup

### Enable Push Notifications (Optional)

1. Go to **Tools** > **Options** > **Notifications**
2. Check **Enable Push Notifications**
3. Enter your MetaQuotes ID from MT5 mobile app
4. Click **Test** to verify connection

### Enable Email Alerts (Optional)

1. Go to **Tools** > **Options** > **Email**
2. Configure your SMTP server settings:
   - **SMTP server**: smtp.gmail.com:465 (for Gmail)
   - **SMTP login**: your email address
   - **SMTP password**: your app password
   - **From**: your email address
   - **To**: recipient email address
3. Check **Enable** and click **Test**

### Recommended Chart Settings

- **Symbol**: XAUUSD (Gold)
- **Timeframe**: M1, M5, or M15 for scalping
- **Chart Type**: Candlestick
- **Auto Scroll**: Enabled
- **Chart Shift**: Enabled (for better signal visibility)

## Troubleshooting

### Indicator Not Appearing in Navigator

1. Ensure the file is in the correct folder
2. Right-click Indicators in Navigator and select **Refresh**
3. Restart MetaTrader 5

### Compilation Errors

1. Ensure you have the complete code (no truncation)
2. Check MT5 is up to date
3. Verify MetaEditor is using the correct syntax mode

### Alerts Not Working

1. **Sound Alerts**: Check volume settings and alert file exists
2. **Push Notifications**: Verify MetaQuotes ID is correct
3. **Email Alerts**: Check SMTP settings and firewall

### Signals Not Appearing

1. Ensure you have enough historical data loaded
2. Check if session filter is blocking (time settings)
3. Verify spread is below the maximum threshold
4. ADX might be below the minimum level (weak trend)

## Updating

1. Replace the old `.mq5` file with the new version
2. Recompile in MetaEditor (F7)
3. Remove and re-add the indicator or EA to charts

## Uninstallation

1. Remove the indicator or EA from all charts
2. Delete `GoldTrendScalper.mq5` from `MQL5/Indicators/` and/or `GoldDashboardEA.mq5` from `MQL5/Experts/`
3. Delete matching `.ex5` compiled files if present

## Support

For issues and feature requests, please open an issue on the GitHub repository.
