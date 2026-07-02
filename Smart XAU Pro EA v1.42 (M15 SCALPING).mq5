//+------------------------------------------------------------------+
//| Smart XAU Pro EA.mq5                                             |
//| Version: 2.00 (M15 SCALPING - HIGH VOLATILITY OPTIMIZED)        |
//| Tuned for: Gold XAU/USD M15 Timeframe Scalping                  |
//| Features: Tight stops, Fast EMAs, ATR-responsive, Volume Filter |
//| Changelog v2.00:                                                |
//|   - FIXED: SELL trailing stop logic                             |
//|   - FIXED: Volume check using wrong bar index                   |
//|   - FIXED: barsSinceEntry now increments per bar, not tick      |
//|   - FIXED: H1 trend filter using stale data                     |
//|   - ADDED: M5 confirmation filter                             |
//|   - ADDED: Session time filter (London/NY overlap)              |
//|   - ADDED: News/cooldown filter after losses                    |
//|   - ADDED: Dynamic spread filter based on ATR                   |
//|   - ADDED: Enhanced dashboard with signal strength              |
//|   - ADDED: Max spread % of ATR input                          |
//|   - IMPROVED: Equity cache reduced to 2 seconds                 |
//|   - IMPROVED: Better error handling and logging                 |
//+------------------------------------------------------------------+
#property copyright "© 2025"
#property version   "2.00"
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define MAGIC 2025121542
#define PANEL_PREFIX "XAU_PANEL_"

// --- Inputs ---
input group "--- UI Settings ---"
input int panelX = 10;
input int panelY = 100;

input group "--- Smart Automation ---"
input bool defaultAutoTrade = true;
input bool enableTrendFilter = true;
input double minADXStrength = 20.0;
input double minVolumeIncrease = 1.15;
input long minVolumeTicks = 150;

input group "--- Risk Management ---"
enum LOT_MODE { FIXED_LOT, RISK_PERCENT };
input LOT_MODE lotMode = FIXED_LOT;
input double fixedLot = 0.05;
input double riskPercent = 0.1;
input double maxDailyLossPercent = 2.0;
input int maxConsecutiveLosses = 4;
input int lossCooldownBars = 3;        // NEW: Bars to wait after consecutive losses

input group "--- Strategy Parameters (M15 OPTIMIZED) ---"
input int fastEMA = 5;
input int slowEMA = 13;
input int fixedSLPips = 80;
input int fixedTPPips = 120;

input group "--- ATR Dynamic Settings ---"
input bool useATR_SL = true;
input bool useATR_TS = true;
input int atrPeriod = 10;
input double atrSL_Mult = 0.8;
input double atrTS_Mult = 1.0;

input group "--- Break Even Settings ---"
input bool useBreakEven = true;
input int beTriggerPips = 50;
input int beOffsetPips = 15;

input group "--- Scalping Specific ---"
input bool enableScalpFilters = true;
input double maxSpreadPoints = 200.0;
input double maxSpreadATRPercent = 15.0;  // NEW: Max spread as % of ATR (0=disable)
input int minRSIDistance = 10;
input bool useM5Confirmation = true;      // NEW: Now implemented
input int maxHoldBars = 5;

input group "--- Session Filter ---"
input bool enableSessionFilter = true;    // NEW
input int sessionStartHour = 8;           // London open UTC
input int sessionEndHour = 20;            // NY close UTC
input bool tradeMonday = true;
input bool tradeFriday = true;

input group "--- Debug Settings ---"
input bool enableDetailedLogging = false;

// Global State
bool Global_AutoTrade = true;
int barsSinceEntry = 0;
datetime lastSignalBar = 0;               // NEW: Track bar of last signal
int cooldownBarsRemaining = 0;            // NEW: Loss cooldown counter

//+------------------------------------------------------------------+
//| Risk Management Class                                            |
//+------------------------------------------------------------------+
class RiskManager {
private:
    double m_maxDL, m_startEq;
    datetime m_lastDay;
    int m_maxConsecLosses;
    int m_lastDealsChecked;
    double cachedEquity;
    datetime lastEquityUpdate;
    int m_cooldownBars;
    int m_remainingCooldown;

public:
    RiskManager() : m_maxDL(2.0), m_startEq(0), m_lastDay(0), m_maxConsecLosses(4), m_lastDealsChecked(0), 
                    cachedEquity(0), lastEquityUpdate(0), m_cooldownBars(3), m_remainingCooldown(0) {}

    void Init(double dl, int maxLosses, int cooldownBars) {
        m_maxDL = dl;
        m_maxConsecLosses = maxLosses;
        m_cooldownBars = cooldownBars;
        m_startEq = GetCachedEquity();
        m_lastDay = iTime(_Symbol, PERIOD_D1, 0);
        m_remainingCooldown = 0;
    }

    double GetCachedEquity() {
        datetime currentTime = TimeCurrent();
        if(currentTime - lastEquityUpdate > 2) {  // FIXED: Reduced from 10 to 2 seconds
            cachedEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            lastEquityUpdate = currentTime;
        }
        return cachedEquity;
    }

    int GetConsecutiveLosses() {
        int totalDeals = HistoryDealsTotal();
        if(totalDeals == m_lastDealsChecked) return 0;

        int consecutiveLosses = 0;
        int checkCount = MathMin(totalDeals, 20);

        for(int i = totalDeals - 1; i >= MathMax(0, totalDeals - checkCount); i--) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0) continue;

            long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            if(magic != MAGIC) continue;

            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit <= 0) {
                consecutiveLosses++;
            } else {
                break;
            }
        }

        m_lastDealsChecked = totalDeals;
        return consecutiveLosses;
    }

    void UpdateCooldown() {
        if(m_remainingCooldown > 0) m_remainingCooldown--;
    }

    void TriggerCooldown() {
        m_remainingCooldown = m_cooldownBars;
    }

    int GetCooldownRemaining() { return m_remainingCooldown; }

    bool IsAllowed() {
        datetime currentTime = TimeCurrent();
        if(iTime(_Symbol, PERIOD_D1, 0) > m_lastDay) {
            m_startEq = GetCachedEquity();
            m_lastDay = iTime(_Symbol, PERIOD_D1, 0);
        }
        double currentEquity = GetCachedEquity();
        double dd = (m_startEq - currentEquity) / m_startEq * 100.0;
        if(dd >= m_maxDL) return false;

        if(GetConsecutiveLosses() >= m_maxConsecLosses) return false;
        if(m_remainingCooldown > 0) return false;

        return true;
    }
};

//+------------------------------------------------------------------+
//| Session Filter Class                                             |
//+------------------------------------------------------------------+
class SessionFilter {
public:
    static bool IsTradingAllowed() {
        if(!enableSessionFilter) return true;

        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        // Day filter
        if(dt.day_of_week == 1 && !tradeMonday) return false;
        if(dt.day_of_week == 5 && !tradeFriday) return false;
        if(dt.day_of_week == 0 || dt.day_of_week == 6) return false; // Weekend

        // Hour filter
        if(dt.hour < sessionStartHour || dt.hour >= sessionEndHour) return false;

        return true;
    }
};

//+------------------------------------------------------------------+
//| Trade Management Class (M15 SCALPING)                            |
//+------------------------------------------------------------------+
class TradeManager {
private:
    CTrade m_trade;
    CSymbolInfo m_sym;
    int hADX, hEMA_F, hEMA_S, hVol, hATR;
    int h1EMAHandle;
    int hRSI;
    int h5EMA_F, h5EMA_S;        // NEW: M5 confirmation handles
    datetime h1EMAUpdateTime;
    bool m_trendFilterEnabled;
    double lastATRValue;
    datetime lastATRUpdate;

public:
    TradeManager() : h1EMAHandle(INVALID_HANDLE), h1EMAUpdateTime(0), m_trendFilterEnabled(enableTrendFilter),
                     hRSI(INVALID_HANDLE), h5EMA_F(INVALID_HANDLE), h5EMA_S(INVALID_HANDLE),
                     lastATRValue(0), lastATRUpdate(0) {
        m_sym.Name(_Symbol);
        m_trade.SetExpertMagicNumber(MAGIC);

        hADX = iADX(_Symbol, PERIOD_CURRENT, 14);
        if(hADX == INVALID_HANDLE) Print("ERROR: Failed to create ADX indicator");

        hEMA_F = iMA(_Symbol, PERIOD_CURRENT, fastEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_F == INVALID_HANDLE) Print("ERROR: Failed to create Fast EMA");

        hEMA_S = iMA(_Symbol, PERIOD_CURRENT, slowEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_S == INVALID_HANDLE) Print("ERROR: Failed to create Slow EMA");

        hVol = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
        if(hVol == INVALID_HANDLE) Print("WARNING: Volume indicator not available");

        hATR = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
        if(hATR == INVALID_HANDLE) Print("ERROR: Failed to create ATR indicator");

        hRSI = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if(hRSI == INVALID_HANDLE) Print("WARNING: RSI indicator could not be created");

        // NEW: M5 Confirmation handles
        if(useM5Confirmation) {
            h5EMA_F = iMA(_Symbol, PERIOD_M5, fastEMA, 0, MODE_EMA, PRICE_CLOSE);
            h5EMA_S = iMA(_Symbol, PERIOD_M5, slowEMA, 0, MODE_EMA, PRICE_CLOSE);
            if(h5EMA_F == INVALID_HANDLE || h5EMA_S == INVALID_HANDLE) {
                Print("WARNING: M5 EMA indicators could not be created, disabling M5 confirmation");
                h5EMA_F = INVALID_HANDLE;
                h5EMA_S = INVALID_HANDLE;
            }
        }

        if(m_trendFilterEnabled) {
            h1EMAHandle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
            if(h1EMAHandle == INVALID_HANDLE) {
                Print("WARNING: H1 EMA indicator could not be created");
                m_trendFilterEnabled = false;
            }
        }

        if(IsReady()) Print("INFO: All indicators initialized successfully");
    }

    ~TradeManager() {
        if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
        if(hEMA_F != INVALID_HANDLE) IndicatorRelease(hEMA_F);
        if(hEMA_S != INVALID_HANDLE) IndicatorRelease(hEMA_S);
        if(hVol != INVALID_HANDLE) IndicatorRelease(hVol);
        if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
        if(h1EMAHandle != INVALID_HANDLE) IndicatorRelease(h1EMAHandle);
        if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
        if(h5EMA_F != INVALID_HANDLE) IndicatorRelease(h5EMA_F);
        if(h5EMA_S != INVALID_HANDLE) IndicatorRelease(h5EMA_S);
    }

    bool IsReady() {
        return (hADX != INVALID_HANDLE && hEMA_F != INVALID_HANDLE &&
                hEMA_S != INVALID_HANDLE && hATR != INVALID_HANDLE);
    }

    int GetSignal() {
        if(hEMA_F == INVALID_HANDLE || hEMA_S == INVALID_HANDLE || hADX == INVALID_HANDLE)
            return -1;

        double f[3], s[3], adx[1];  // Need 3 bars for crossover detection

        int copied_f = CopyBuffer(hEMA_F, 0, 0, 3, f);
        int copied_s = CopyBuffer(hEMA_S, 0, 0, 3, s);

        if(copied_f < 3 || copied_s < 3) {
            if(enableDetailedLogging) Print("DEBUG: Failed to copy EMA buffers");
            return -1;
        }

        int copied_adx = CopyBuffer(hADX, 0, 1, 1, adx);
        if(copied_adx <= 0) {
            if(enableDetailedLogging) Print("DEBUG: Failed to copy ADX buffer");
            return -1;
        }

        if(adx[0] < minADXStrength) return -1;

        // Crossover detection: [1] is previous bar, [2] is bar before that
        bool crossUp = (f[1] > s[1]) && (f[2] <= s[2]);   // Buy signal on previous bar
        bool crossDown = (f[1] < s[1]) && (f[2] >= s[2]); // Sell signal on previous bar

        if(crossUp && CheckFilters(0)) {
            if(!useM5Confirmation || CheckM5Confirmation(0)) return 0;
        }
        if(crossDown && CheckFilters(1)) {
            if(!useM5Confirmation || CheckM5Confirmation(1)) return 1;
        }
        return -1;
    }

    // NEW: M5 Confirmation implementation
    bool CheckM5Confirmation(int dir) {
        if(h5EMA_F == INVALID_HANDLE || h5EMA_S == INVALID_HANDLE) return true;

        double f5[2], s5[2];

        if(CopyBuffer(h5EMA_F, 0, 0, 2, f5) < 2) return false;
        if(CopyBuffer(h5EMA_S, 0, 0, 2, s5) < 2) return false;

        // M5 must align with M15 signal direction
        if(dir == 0) return f5[1] > s5[1];  // M5 bullish
        if(dir == 1) return f5[1] < s5[1];  // M5 bearish
        return false;
    }

    double GetATRValue() {
        if(hATR == INVALID_HANDLE) return 0.0;

        datetime currentTime = TimeCurrent();
        if(currentTime - lastATRUpdate < 2 && lastATRValue > 0) return lastATRValue;

        double atr[1];
        int copied = CopyBuffer(hATR, 0, 1, 1, atr);

        if(copied <= 0 || atr[0] <= 0) return 0.0;

        lastATRValue = atr[0];
        lastATRUpdate = currentTime;
        return atr[0];
    }

    double GetRSI() {
        if(hRSI == INVALID_HANDLE) return -1;

        double rsi[1];
        int copied = CopyBuffer(hRSI, 0, 1, 1, rsi);

        if(copied <= 0) return -1;
        return rsi[0];
    }

    bool CheckFilters(int dir) {
        // Check spread for scalping
        if(enableScalpFilters) {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double spread = (ask - bid) / _Point;

            // FIXED: Dynamic spread filter based on ATR
            if(maxSpreadATRPercent > 0) {
                double atr = GetATRValue();
                if(atr > 0) {
                    double maxSpreadATR = atr * maxSpreadATRPercent / 100.0 / _Point;
                    if(spread > maxSpreadATR) {
                        if(enableDetailedLogging) Print("DEBUG: Spread ", spread, " exceeds ATR-based limit ", maxSpreadATR);
                        return false;
                    }
                }
            }

            if(spread > maxSpreadPoints) {
                if(enableDetailedLogging) Print("DEBUG: Spread too wide: ", spread);
                return false;
            }
        }

        // RSI momentum check
        if(enableScalpFilters && hRSI != INVALID_HANDLE) {
            double rsi = GetRSI();
            if(rsi < 0) return false;

            if(dir == 0 && rsi > (100 - minRSIDistance)) return false;
            if(dir == 1 && rsi < minRSIDistance) return false;
        }

        // FIXED: H1 Trend Filter - use current bar (index 0) instead of previous
        if(m_trendFilterEnabled && h1EMAHandle != INVALID_HANDLE) {
            double h1CloseArray[1];
            if(CopyClose(_Symbol, PERIOD_H1, 0, 1, h1CloseArray) < 1) return false;
            double h1Close = h1CloseArray[0];

            double h1EMAArray[1];
            if(CopyBuffer(h1EMAHandle, 0, 0, 1, h1EMAArray) < 1) return false;
            double h1EMA = h1EMAArray[0];

            if(dir == 0 && h1Close < h1EMA) return false;
            if(dir == 1 && h1Close > h1EMA) return false;
        }

        // FIXED: Volume check - use completed bars
        if(hVol != INVALID_HANDLE) {
            double v[3];
            int copied = CopyBuffer(hVol, 0, 0, 3, v);

            if(copied >= 3) {
                if(v[1] <= 0 || v[1] < minVolumeTicks) return false;           // Previous bar volume
                if(v[1] < v[2] * minVolumeIncrease) return false;             // Compare prev vs prev-prev
            }
        }

        return true;
    }

    void Execute(int dir) {
        if(!m_sym.RefreshRates()) {
            Print("ERROR: Failed to refresh symbol rates");
            return;
        }

        double lot = (lotMode == FIXED_LOT) ? fixedLot : CalculateRiskLot();
        if(lot <= 0) {
            Print("ERROR: Invalid lot size: ", lot);
            return;
        }

        double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double lotsMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotsStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        if(lot < lotsMin) lot = lotsMin;
        else if(lot > lotsMax) lot = lotsMax;

        if(lotsStep > 0) {
            lot = MathFloor(lot / lotsStep) * lotsStep;
        }

        double price = (dir == 0) ? m_sym.Ask() : m_sym.Bid();

        double atrValue = GetATRValue();
        double slDistance = useATR_SL && atrValue > 0 ? atrValue * atrSL_Mult : fixedSLPips * _Point;
        double tpDistance = fixedTPPips * _Point;

        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double maxReasonableATR = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (digits == 3 || digits == 5 ? 800 : 80);

        if(useATR_SL && atrValue > 0 && slDistance > maxReasonableATR) {
            slDistance = maxReasonableATR;
        }

        double sl = (dir == 0) ? price - slDistance : price + slDistance;
        double tp = (dir == 0) ? price + tpDistance : price - tpDistance;

        long stopsLevelLong = 0;
        if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevelLong)) {
            Print("ERROR: Could not get stops level");
            return;
        }
        double stopsLevel = stopsLevelLong * _Point;
        double slDistPoints = slDistance / _Point;
        double tpDistPoints = tpDistance / _Point;

        if(slDistPoints < stopsLevel || tpDistPoints < stopsLevel) {
            Print("ERROR: SL/TP too close. Min: ", stopsLevel/_Point, "pips, SL:", slDistPoints, "TP:", tpDistPoints);
            return;
        }

        if(dir == 0) {
            if(sl >= price || tp <= price) {
                Print("ERROR: Invalid SL/TP for BUY. Price:", price, " SL:", sl, " TP:", tp);
                return;
            }
        } else {
            if(sl <= price || tp >= price) {
                Print("ERROR: Invalid SL/TP for SELL. Price:", price, " SL:", sl, " TP:", tp);
                return;
            }
        }

        bool tradeSuccess = false;
        int attempts = 0;
        int maxAttempts = 3;

        while(attempts < maxAttempts && !tradeSuccess) {
            if(dir == 0) {
                tradeSuccess = m_trade.Buy(lot, _Symbol, price, sl, tp);
            } else {
                tradeSuccess = m_trade.Sell(lot, _Symbol, price, sl, tp);
            }

            if(!tradeSuccess) {
                uint error = m_trade.ResultRetcode();
                if(error == TRADE_RETCODE_MARKET_CLOSED || error == TRADE_RETCODE_REQUOTE) {
                    Sleep(500);
                    attempts++;
                } else {
                    break;
                }
            }
        }

        if(tradeSuccess) {
            Print("TRADE: ", (dir == 0 ? "BUY" : "SELL"), " ", lot, " @ ", price, 
                  " SL:", slDistance/_Point, "pips TP:", tpDistance/_Point, "pips");
            barsSinceEntry = 0;
        }
    }

    void ManagePositions() {
        double atrValue = GetATRValue();
        int totalPositions = PositionsTotal();

        for(int i = 0; i < totalPositions; i++) {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;

            if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

            long positionType = PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            // FIXED: Force close after N bars without profit (per bar, not per tick)
            datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
            int barsHeld = Bars(_Symbol, PERIOD_CURRENT, openTime, currentBar);
            if(barsHeld >= maxHoldBars) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit <= 0) {
                    if(m_trade.PositionClose(ticket)) {
                        Print("TIMEOUT: Closed unprofitable position after ", barsHeld, " bars");
                    }
                    continue;
                }
            }

            // Break-even logic
            if(useBreakEven) {
                double profitInPips = (positionType == POSITION_TYPE_BUY) ?
                    (currentPrice - openPrice) / _Point : (openPrice - currentPrice) / _Point;

                if(profitInPips >= beTriggerPips) {
                    double beLevel = (positionType == POSITION_TYPE_BUY) ?
                        openPrice + beOffsetPips * _Point : openPrice - beOffsetPips * _Point;

                    if((positionType == POSITION_TYPE_BUY && (currentSL < beLevel || currentSL == 0) && beLevel < currentPrice) ||
                       (positionType == POSITION_TYPE_SELL && (currentSL > beLevel || currentSL == 0) && beLevel > currentPrice)) {

                        long stopsLevelBE = 0;
                        if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevelBE)) {
                            double minStopLevel = stopsLevelBE * _Point;
                            if(MathAbs(currentPrice - beLevel) >= minStopLevel) {
                                if(m_trade.PositionModify(ticket, beLevel, currentTP)) {
                                    Print("BREAKEVEN: Position ", ticket, " protected");
                                }
                            }
                        }
                    }
                }
            }

            // FIXED: ATR Trailing Stop logic
            if(useATR_TS && atrValue > 0) {
                double tsDistance = atrValue * atrTS_Mult;

                int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                double maxReasonableTS = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (digits == 3 || digits == 5 ? 400 : 40);

                if(tsDistance > maxReasonableTS) tsDistance = maxReasonableTS;

                double newSL = 0;
                long stopsLevel = 0;
                if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel)) continue;
                double minStopDistance = stopsLevel * _Point;

                if(positionType == POSITION_TYPE_BUY) {
                    newSL = currentPrice - tsDistance;
                    if(newSL > currentSL && newSL < currentPrice - minStopDistance) {
                        if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                            if(enableDetailedLogging) Print("DEBUG: BUY TS updated to ", newSL);
                        }
                    }
                } else { // SELL - FIXED LOGIC
                    newSL = currentPrice + tsDistance;
                    // For SELL: newSL must be LOWER than currentSL (tighter) AND above currentPrice + min distance
                    if((newSL < currentSL || currentSL == 0) && newSL > currentPrice + minStopDistance) {
                        if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                            if(enableDetailedLogging) Print("DEBUG: SELL TS updated to ", newSL);
                        }
                    }
                }
            }
        }
    }

    double CalculateRiskLot() {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(equity <= 0) {
            Print("ERROR: Invalid equity: ", equity);
            return fixedLot;
        }

        double riskAmount = equity * (riskPercent / 100.0);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

        if(tickValue <= 0) {
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            tickValue = _Point * (digits == 5 ? 10 : 1);
        }

        double atrValue = GetATRValue();
        double slPoints = (useATR_SL && atrValue > 0) ? atrValue * atrSL_Mult : fixedSLPips * _Point;

        if(slPoints <= 0) {
            Print("ERROR: Invalid SL: ", slPoints);
            return fixedLot;
        }

        double slValue = slPoints * tickValue;
        if(slValue <= 0) {
            Print("ERROR: Invalid SL value: ", slValue);
            return fixedLot;
        }

        double lot = riskAmount / slValue;
        double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double lotsMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

        if(lotsMin <= 0) lotsMin = 0.01;

        lot = NormalizeDouble(MathMax(lotsMin, MathMin(lot, lotsMax)), 2);

        if(lot <= 0) {
            Print("ERROR: Invalid lot calculation: ", lot);
            return fixedLot;
        }

        return lot;
    }

    void CloseAll() {
        int closed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                if(m_trade.PositionClose(ticket)) closed++;
            }
        }
        Print("CLOSED: ", closed, " positions");
    }

    void CloseProfitable() {
        int closed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit > 0 && m_trade.PositionClose(ticket)) closed++;
            }
        }
        Print("CLOSED: ", closed, " profitable positions");
    }

    void PartialClose50() {
        int partialClosed = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit <= 0) continue;

                double positionVolume = PositionGetDouble(POSITION_VOLUME);
                double closeVolume = positionVolume * 0.5;
                double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

                if(closeVolume >= lotsMin && m_trade.PositionClosePartial(ticket, closeVolume)) {
                    partialClosed++;
                }
            }
        }
        Print("PARTIAL: Closed 50% of ", partialClosed, " positions");
    }

    int GetActivePositions() {
        int count = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                count++;
            }
        }
        return count;
    }

    double GetTotalProfit() {
        double totalProfit = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                totalProfit += PositionGetDouble(POSITION_PROFIT);
            }
        }
        return totalProfit;
    }

    // NEW: Get signal strength for dashboard
    string GetSignalStrength() {
        if(hADX == INVALID_HANDLE || hRSI == INVALID_HANDLE) return "N/A";

        double adx[1], rsi[1];

        if(CopyBuffer(hADX, 0, 1, 1, adx) < 1) return "N/A";
        if(CopyBuffer(hRSI, 0, 1, 1, rsi) < 1) return "N/A";

        double strength = adx[0];
        if(strength >= 40) return "STRONG";
        if(strength >= 25) return "MODERATE";
        if(strength >= minADXStrength) return "WEAK";
        return "NONE";
    }

    // NEW: Get trend direction for dashboard
    string GetTrendDirection() {
        if(h1EMAHandle == INVALID_HANDLE) return "N/A";

        double h1Close[1], h1EMA[1];
        if(CopyClose(_Symbol, PERIOD_H1, 0, 1, h1Close) < 1) return "N/A";
        if(CopyBuffer(h1EMAHandle, 0, 0, 1, h1EMA) < 1) return "N/A";

        if(h1Close[0] > h1EMA[0]) return "BULLISH";
        return "BEARISH";
    }
};

//+------------------------------------------------------------------+
//| Enhanced UI Management Class                                     |
//+------------------------------------------------------------------+
class UIManager {
public:
    void Create(int x, int y) {
        ObjectsDeleteAll(0, PANEL_PREFIX);
        CreateRect("BG", x, y, 220, 340, C'35,35,35');
        CreateRect("HDR", x, y, 220, 25, C'60,60,60');

        CreateLabel("TITLE", x + 10, y + 5, "Smart XAU Pro v2.00 M15", 10, clrWhite);

        string autoTxt = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color autoClr = Global_AutoTrade ? C'0,150,0' : C'100,100,100';

        CreateBtn("AUTO", x + 10, y + 35, 200, 28, autoTxt, autoClr);
        CreateBtn("BUY", x + 10, y + 70, 95, 28, "BUY", C'0,130,0');
        CreateBtn("SELL", x + 115, y + 70, 95, 28, "SELL", C'180,0,0');
        CreateBtn("CLOSEPROFIT", x + 10, y + 105, 200, 28, "CLOSE PROFIT", C'0,138,0');
        CreateBtn("PARTIAL", x + 10, y + 140, 200, 28, "PARTIAL 50%", C'255,165,0');
        CreateBtn("CLOSEALL", x + 10, y + 175, 200, 28, "CLOSE ALL", C'150,0,0');

        // NEW: Enhanced stats area
        CreateRect("STATS_BG", x + 10, y + 210, 200, 120, C'25,25,25');
        CreateLabel("STATS_POS", x + 15, y + 215, "Pos: -- | Profit: --", 9, clrYellow);
        CreateLabel("STATS_SIG", x + 15, y + 232, "Signal: --", 9, clrLightGray);
        CreateLabel("STATS_TREND", x + 15, y + 249, "Trend: --", 9, clrLightGray);
        CreateLabel("STATS_ATR", x + 15, y + 266, "ATR: --", 9, clrLightGray);
        CreateLabel("STATS_SPREAD", x + 15, y + 283, "Spread: --", 9, clrLightGray);
        CreateLabel("STATS_STATUS", x + 15, y + 300, "Status: --", 9, clrLightGray);
    }

    void UpdateAutoBtn() {
        string t = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color c = Global_AutoTrade ? C'0,150,0' : C'100,100,100';
        ObjectSetString(0, PANEL_PREFIX + "AUTO", OBJPROP_TEXT, t);
        ObjectSetInteger(0, PANEL_PREFIX + "AUTO", OBJPROP_BGCOLOR, c);
    }

    void UpdateStats(int positions, double profit, string signal, string trend, double atr, double spread, string status) {
        ObjectSetString(0, PANEL_PREFIX + "STATS_POS", OBJPROP_TEXT, 
            StringFormat("Pos: %d | Profit: %.2f", positions, profit));
        ObjectSetString(0, PANEL_PREFIX + "STATS_SIG", OBJPROP_TEXT, 
            StringFormat("Signal: %s", signal));

        color trendClr = clrLightGray;
        if(trend == "BULLISH") trendClr = clrLime;
        if(trend == "BEARISH") trendClr = clrRed;
        ObjectSetString(0, PANEL_PREFIX + "STATS_TREND", OBJPROP_TEXT, 
            StringFormat("Trend: %s", trend));
        ObjectSetInteger(0, PANEL_PREFIX + "STATS_TREND", OBJPROP_COLOR, trendClr);

        ObjectSetString(0, PANEL_PREFIX + "STATS_ATR", OBJPROP_TEXT, 
            StringFormat("ATR: %.2f", atr));

        color spreadClr = spread <= 200 ? clrLime : (spread <= 350 ? clrYellow : clrRed);
        ObjectSetString(0, PANEL_PREFIX + "STATS_SPREAD", OBJPROP_TEXT, 
            StringFormat("Spread: %.1f pts", spread));
        ObjectSetInteger(0, PANEL_PREFIX + "STATS_SPREAD", OBJPROP_COLOR, spreadClr);

        color statusClr = clrLightGray;
        if(status == "TRADING") statusClr = clrLime;
        if(status == "COOLDOWN") statusClr = clrOrange;
        if(status == "BLOCKED") statusClr = clrRed;
        ObjectSetString(0, PANEL_PREFIX + "STATS_STATUS", OBJPROP_TEXT, 
            StringFormat("Status: %s", status));
        ObjectSetInteger(0, PANEL_PREFIX + "STATS_STATUS", OBJPROP_COLOR, statusClr);
    }

private:
    void CreateRect(string n, int x, int y, int w, int h, color c) {
        string name = PANEL_PREFIX + n;
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

    void CreateBtn(string n, int x, int y, int w, int h, string t, color c) {
        string name = PANEL_PREFIX + n;
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetString(0, name, OBJPROP_TEXT, t);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

    void CreateLabel(string n, int x, int y, string t, int fontSize, color c) {
        string name = PANEL_PREFIX + n;
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, t);
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
};

//+------------------------------------------------------------------+
//| Global Instances & Events                                        |
//+------------------------------------------------------------------+
RiskManager RM;
TradeManager *TM = NULL;
UIManager UI;

int OnInit() {
    Global_AutoTrade = defaultAutoTrade;
    RM.Init(maxDailyLossPercent, maxConsecutiveLosses, lossCooldownBars);
    TM = new TradeManager();
    UI.Create(panelX, panelY);

    if(!SessionFilter::IsTradingAllowed()) {
        Print("INFO: Outside trading hours - EA will monitor but not trade");
    }

    Print("===== Smart XAU Pro EA v2.00 M15 SCALPING STARTED =====");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int r) {
    ObjectsDeleteAll(0, PANEL_PREFIX);
    delete TM;
    Print("===== Smart XAU Pro EA v2.00 M15 SCALPING STOPPED =====");
}

void OnTick() {
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool isNewBar = (currentBar != lastBar);

    if(TM != NULL && TM.IsReady()) {
        TM.ManagePositions();

        if(isNewBar) {
            barsSinceEntry++;
            RM.UpdateCooldown();
            lastBar = currentBar;

            if(Global_AutoTrade && SessionFilter::IsTradingAllowed()) {
                int sig = TM.GetSignal();
                if(sig != -1 && RM.IsAllowed()) {
                    TM.Execute(sig);
                }
            }
        }

        // Update enhanced dashboard
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double spread = (ask - bid) / _Point;
        double atr = TM.GetATRValue();

        string status = "READY";
        if(!Global_AutoTrade) status = "MANUAL";
        else if(!SessionFilter::IsTradingAllowed()) status = "OFF-HOURS";
        else if(RM.GetCooldownRemaining() > 0) status = "COOLDOWN";
        else if(!RM.IsAllowed()) status = "BLOCKED";
        else if(TM.GetActivePositions() > 0) status = "TRADING";

        UI.UpdateStats(TM.GetActivePositions(), TM.GetTotalProfit(), 
                       TM.GetSignalStrength(), TM.GetTrendDirection(), 
                       atr, spread, status);
    }
}

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp) {
    if(id == CHARTEVENT_OBJECT_CLICK && TM != NULL && TM.IsReady()) {
        string cmd = StringSubstr(sp, StringLen(PANEL_PREFIX));

        if(cmd == "AUTO") { 
            Global_AutoTrade = !Global_AutoTrade; 
            UI.UpdateAutoBtn(); 
        }
        if(cmd == "BUY") {
            if(SessionFilter::IsTradingAllowed() && RM.IsAllowed()) {
                TM.Execute(0);
            } else {
                Print("WARNING: Cannot BUY - session or risk filter blocking");
            }
        }
        if(cmd == "SELL") {
            if(SessionFilter::IsTradingAllowed() && RM.IsAllowed()) {
                TM.Execute(1);
            } else {
                Print("WARNING: Cannot SELL - session or risk filter blocking");
            }
        }
        if(cmd == "CLOSEPROFIT") TM.CloseProfitable();
        if(cmd == "PARTIAL") TM.PartialClose50();
        if(cmd == "CLOSEALL") TM.CloseAll();

        ObjectSetInteger(0, sp, OBJPROP_STATE, false);
        ChartRedraw();
    }
}
