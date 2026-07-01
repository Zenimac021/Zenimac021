//+------------------------------------------------------------------+
//| Smart XAU Pro EA.mq5                                             |
//| Version: 1.42 (M15 SCALPING - HIGH VOLATILITY OPTIMIZED)        |
//| Tuned for: Gold XAU/USD M15 Timeframe Scalping                  |
//| Features: Tight stops, Fast EMAs, ATR-responsive, Volume Filter |
//+------------------------------------------------------------------+
#property copyright "© 2025"
#property version   "1.42"
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define MAGIC 2025121542  // 2025-12-15-42 (XAU EA v1.42 M15 Scalping)
#define PANEL_PREFIX "XAU_PANEL_"

// --- Inputs ---
input group "--- UI Settings ---"
input int panelX = 10;
input int panelY = 200;

input group "--- Smart Automation ---"
input bool defaultAutoTrade = true;
input bool enableTrendFilter = true;
input double minADXStrength = 20.0;  // SCALP: Reduced from 25 for faster entries
input double minVolumeIncrease = 1.15; // Slightly relaxed volume filter for scalping
input long minVolumeTicks = 150;     // Increased tick volume threshold

input group "--- Risk Management ---"
enum LOT_MODE { FIXED_LOT, RISK_PERCENT };
input LOT_MODE lotMode = FIXED_LOT;
input double fixedLot = 0.05;  // SCALP: Reduced from 0.1 for tighter risk
input double riskPercent = 0.1; // SCALP: Reduced from 0.2 for conservative scaling
input double maxDailyLossPercent = 2.0; // SCALP: Tighter daily loss limit
input int maxConsecutiveLosses = 4;     // Allow more tries in scalping mode

input group "--- Strategy Parameters (M15 OPTIMIZED) ---"
input int fastEMA = 5;        // SCALP: Faster from 7 for quick crossovers
input int slowEMA = 13;       // SCALP: Faster from 21 for tighter bands
input int fixedSLPips = 80;   // SCALP: Tight stop from 500
input int fixedTPPips = 120;  // SCALP: Quick profit target from 1000

input group "--- ATR Dynamic Settings ---"
input bool useATR_SL = true;
input bool useATR_TS = true;
input int atrPeriod = 10;      // SCALP: Shorter period for M15
input double atrSL_Mult = 0.8; // SCALP: Tighter multiplier from 1.2
input double atrTS_Mult = 1.0; // SCALP: Reduced trailing from 1.8

input group "--- Break Even Settings ---"
input bool useBreakEven = true;
input int beTriggerPips = 50;  // SCALP: Reduced from 150 for faster BE
input int beOffsetPips = 15;   // SCALP: Smaller offset from 50

input group "--- Scalping Specific ---"
input bool enableScalpFilters = true;  // Enable volatility & momentum checks
input double maxSpreadPoints = 3.0;    // Skip if spread > 3 points
input int minRSIDistance = 10;         // RSI overbought/oversold threshold
input bool useM5Confirmation = true;   // Confirm M15 signals on M5
input int maxHoldBars = 5;             // Close after N bars if not in profit

input group "--- Debug Settings ---"
input bool enableDetailedLogging = false;

// Global State
bool Global_AutoTrade = true;
int barsSinceEntry = 0;

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
    
public:
    RiskManager() : m_maxDL(2.0), m_startEq(0), m_lastDay(0), m_maxConsecLosses(4), m_lastDealsChecked(0), 
                    cachedEquity(0), lastEquityUpdate(0) {}
    
    void Init(double dl, int maxLosses) {
        m_maxDL = dl;
        m_maxConsecLosses = maxLosses;
        m_startEq = GetCachedEquity();
        m_lastDay = iTime(_Symbol, PERIOD_D1, 0);
    }

    double GetCachedEquity() {
        datetime currentTime = TimeCurrent();
        if(currentTime - lastEquityUpdate > 10) {
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
    int hRSI;                  // NEW: RSI for overbought/oversold
    datetime h1EMAUpdateTime;
    bool m_trendFilterEnabled;
    
public:
    TradeManager() : h1EMAHandle(INVALID_HANDLE), h1EMAUpdateTime(0), m_trendFilterEnabled(enableTrendFilter),
                     hRSI(INVALID_HANDLE) {
        m_sym.Name(_Symbol);
        m_trade.SetExpertMagicNumber(MAGIC);

        hADX = iADX(_Symbol, PERIOD_CURRENT, 14);
        if(hADX == INVALID_HANDLE) {
            Print("ERROR: Failed to create ADX indicator for symbol: ", _Symbol);
        }
        
        hEMA_F = iMA(_Symbol, PERIOD_CURRENT, fastEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_F == INVALID_HANDLE) {
            Print("ERROR: Failed to create Fast EMA indicator for symbol: ", _Symbol);
        }
        
        hEMA_S = iMA(_Symbol, PERIOD_CURRENT, slowEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_S == INVALID_HANDLE) {
            Print("ERROR: Failed to create Slow EMA indicator for symbol: ", _Symbol);
        }
        
        hVol = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
        if(hVol == INVALID_HANDLE) {
            Print("WARNING: Volume indicator not available for symbol: ", _Symbol);
        }
        
        hATR = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
        if(hATR == INVALID_HANDLE) {
            Print("ERROR: Failed to create ATR indicator for symbol: ", _Symbol);
        }

        // NEW: RSI for momentum confirmation
        hRSI = iRSI(_Symbol, PERIOD_CURRENT, 14);
        if(hRSI == INVALID_HANDLE) {
            Print("WARNING: RSI indicator could not be created");
        }

        if(m_trendFilterEnabled) {
            h1EMAHandle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
            if(h1EMAHandle == INVALID_HANDLE) {
                Print("WARNING: H1 EMA indicator could not be created");
                m_trendFilterEnabled = false;
            }
        }

        if(IsReady()) {
            Print("INFO: All indicators initialized successfully for symbol: ", _Symbol);
        }
    }

    ~TradeManager() {
        if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
        if(hEMA_F != INVALID_HANDLE) IndicatorRelease(hEMA_F);
        if(hEMA_S != INVALID_HANDLE) IndicatorRelease(hEMA_S);
        if(hVol != INVALID_HANDLE) IndicatorRelease(hVol);
        if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
        if(h1EMAHandle != INVALID_HANDLE) IndicatorRelease(h1EMAHandle);
        if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
    }

    bool IsReady() {
        return (hADX != INVALID_HANDLE && hEMA_F != INVALID_HANDLE &&
                hEMA_S != INVALID_HANDLE && hATR != INVALID_HANDLE);
    }

    int GetSignal() {
        if(hEMA_F == INVALID_HANDLE || hEMA_S == INVALID_HANDLE || hADX == INVALID_HANDLE)
            return -1;

        double f[], s[], adx[];
        ArrayResize(f, 2);
        ArrayResize(s, 2);
        ArrayResize(adx, 1);
        
        int copied_f = CopyBuffer(hEMA_F, 0, 1, 2, f);
        int copied_s = CopyBuffer(hEMA_S, 0, 1, 2, s);
        
        if(copied_f < 2 || copied_s < 2) {
            if(enableDetailedLogging) Print("DEBUG: Failed to copy EMA buffers");
            return -1;
        }

        int copied_adx = CopyBuffer(hADX, 0, 1, 1, adx);
        if(copied_adx <= 0) {
            if(enableDetailedLogging) Print("DEBUG: Failed to copy ADX buffer");
            return -1;
        }

        if(adx[0] < minADXStrength) return -1;

        // SCALP: BUY signal - fast EMA crosses above slow EMA
        if(f[0] > s[0] && f[1] <= s[1] && CheckFilters(0)) return 0;
        // SCALP: SELL signal - fast EMA crosses below slow EMA
        if(f[0] < s[0] && f[1] >= s[1] && CheckFilters(1)) return 1;
        return -1;
    }

    double GetATRValue() {
        if(hATR == INVALID_HANDLE) {
            if(enableDetailedLogging) Print("DEBUG: ATR handle invalid");
            return 0.0;
        }

        double atr[];
        ArrayResize(atr, 1);
        int copied = CopyBuffer(hATR, 0, 1, 1, atr);
        
        if(copied <= 0 || atr[0] <= 0) {
            return 0.0;
        }

        return atr[0];
    }

    double GetRSI() {
        if(hRSI == INVALID_HANDLE) return -1;

        double rsi[];
        ArrayResize(rsi, 1);
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
            
            if(spread > maxSpreadPoints) {
                if(enableDetailedLogging) Print("DEBUG: Spread too wide: ", spread);
                return false;
            }
        }

        // NEW: RSI momentum check - avoid extreme conditions
        if(enableScalpFilters && hRSI != INVALID_HANDLE) {
            double rsi = GetRSI();
            if(rsi < 0) return false;
            
            if(dir == 0 && rsi > (100 - minRSIDistance)) return false;  // Don't buy if overbought
            if(dir == 1 && rsi < minRSIDistance) return false;          // Don't sell if oversold
        }

        if(m_trendFilterEnabled && h1EMAHandle != INVALID_HANDLE) {
            double h1CloseArray[];
            if(CopyClose(_Symbol, PERIOD_H1, 1, 1, h1CloseArray) < 1) {
                return false;
            }
            double h1Close = h1CloseArray[0];
            
            double h1EMAArray[];
            if(CopyBuffer(h1EMAHandle, 0, 1, 1, h1EMAArray) < 1) {
                return false;
            }
            double h1EMA = h1EMAArray[0];
            
            if(dir == 0 && h1Close < h1EMA) return false;
            if(dir == 1 && h1Close > h1EMA) return false;
        }
        
        if(hVol != INVALID_HANDLE) {
            double v[];
            ArrayResize(v, 2);
            int copied = CopyBuffer(hVol, 0, 1, 2, v);
            
            if(copied >= 2) {
                if(v[1] <= 0 || v[0] < minVolumeTicks) return false;
                if(v[0] < v[1] * minVolumeIncrease) return false;
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
        // SCALP: Use tighter ATR multiplier for scalping
        double slDistance = useATR_SL && atrValue > 0 ? atrValue * atrSL_Mult : fixedSLPips * _Point;
        double tpDistance = fixedTPPips * _Point;

        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double maxReasonableATR = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (digits == 3 || digits == 5 ? 800 : 80); // SCALP: Reduced caps
        
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
                    Sleep(500);  // SCALP: Reduced wait
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
        barsSinceEntry++;

        for(int i = 0; i < totalPositions; i++) {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

            long positionType = PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);

            // NEW: Force close after N bars without profit
            if(barsSinceEntry >= maxHoldBars) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit <= 0) {
                    if(m_trade.PositionClose(ticket)) {
                        Print("TIMEOUT: Closed unprofitable position after ", maxHoldBars, " bars");
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

            // ATR Trailing Stop logic
            if(useATR_TS && atrValue > 0) {
                double tsDistance = atrValue * atrTS_Mult;
                
                int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                double maxReasonableTS = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (digits == 3 || digits == 5 ? 400 : 40);
                
                if(tsDistance > maxReasonableTS) {
                    tsDistance = maxReasonableTS;
                }
                
                double newSL = 0;
                long stopsLevel = 0;
                if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel)) continue;

                if(positionType == POSITION_TYPE_BUY) {
                    newSL = currentPrice - tsDistance;
                    if(newSL > currentSL && newSL < currentPrice && MathAbs(currentPrice - newSL) >= stopsLevel * _Point) {
                        if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                            if(enableDetailedLogging) Print("DEBUG: BUY TS updated to ", newSL);
                        }
                    }
                } else {
                    newSL = currentPrice + tsDistance;
                    if(newSL < currentSL || currentSL == 0) {
                        if(newSL > currentPrice && MathAbs(newSL - currentPrice) >= stopsLevel * _Point) {
                            if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                                if(enableDetailedLogging) Print("DEBUG: SELL TS updated to ", newSL);
                            }
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
};

//+------------------------------------------------------------------+
//| UI Management Class                                              |
//+------------------------------------------------------------------+
class UIManager {
public:
    void Create(int x, int y) {
        ObjectsDeleteAll(0, PANEL_PREFIX);
        CreateRect("BG", x, y, 200, 280, C'35,35,35');
        CreateRect("HDR", x, y, 200, 25, C'60,60,60');
        
        CreateLabel("TITLE", x + 50, y + 5, "Smart XAU Pro v1.42 M15", 10, clrWhite);
        
        string autoTxt = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color autoClr = Global_AutoTrade ? C'0,150,0' : C'100,100,100';
        
        CreateBtn("AUTO", x + 10, y + 35, 180, 30, autoTxt, autoClr);
        CreateBtn("BUY", x + 10, y + 75, 85, 30, "BUY", C'0,130,0');
        CreateBtn("SELL", x + 105, y + 75, 85, 30, "SELL", C'180,0,0');
        CreateBtn("CLOSEPROFIT", x + 10, y + 115, 180, 30, "CLOSE PROFIT", C'0,138,0');
        CreateBtn("PARTIAL", x + 10, y + 155, 180, 30, "PARTIAL 50%", C'255,165,0');
        CreateBtn("CLOSEALL", x + 10, y + 195, 180, 30, "CLOSE ALL", C'150,0,0');
        
        CreateRect("STATS_BG", x + 10, y + 235, 180, 35, C'25,25,25');
        CreateLabel("STATS", x + 15, y + 240, "Positions: -- | Profit: --", 9, clrYellow);
    }

    void UpdateAutoBtn() {
        string t = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color c = Global_AutoTrade ? C'0,150,0' : C'100,100,100';
        ObjectSetString(0, PANEL_PREFIX + "AUTO", OBJPROP_TEXT, t);
        ObjectSetInteger(0, PANEL_PREFIX + "AUTO", OBJPROP_BGCOLOR, c);
    }

    void UpdateStats(int positions, double profit) {
        string statsText = StringFormat("Pos: %d | Profit: %.2f", positions, profit);
        ObjectSetString(0, PANEL_PREFIX + "STATS", OBJPROP_TEXT, statsText);
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
    RM.Init(maxDailyLossPercent, maxConsecutiveLosses);
    TM = new TradeManager();
    UI.Create(panelX, panelY);
    Print("===== Smart XAU Pro EA v1.42 M15 SCALPING STARTED =====");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int r) {
    ObjectsDeleteAll(0, PANEL_PREFIX);
    delete TM;
    Print("===== Smart XAU Pro EA v1.42 M15 SCALPING STOPPED =====");
}

void OnTick() {
    if(TM != NULL && TM.IsReady()) {
        TM.ManagePositions();

        if(Global_AutoTrade) {
            static datetime lastBar;
            if(iTime(_Symbol, PERIOD_CURRENT, 0) != lastBar) {
                int sig = TM.GetSignal();
                if(sig != -1 && RM.IsAllowed()) {
                    TM.Execute(sig);
                }
                lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
            }
        }

        UI.UpdateStats(TM.GetActivePositions(), TM.GetTotalProfit());
    }
    
    if(!Global_AutoTrade) {
        static datetime lastSleep = 0;
        datetime currentTime = TimeCurrent();
        if(currentTime - lastSleep > 2) {
            Sleep(10);
            lastSleep = currentTime;
        }
    }
}

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp) {
    if(id == CHARTEVENT_OBJECT_CLICK && TM != NULL && TM.IsReady()) {
        string cmd = StringSubstr(sp, StringLen(PANEL_PREFIX));
        if(cmd == "AUTO") { Global_AutoTrade = !Global_AutoTrade; UI.UpdateAutoBtn(); }
        if(cmd == "BUY" && RM.IsAllowed()) TM.Execute(0);
        if(cmd == "SELL" && RM.IsAllowed()) TM.Execute(1);
        if(cmd == "CLOSEPROFIT") TM.CloseProfitable();
        if(cmd == "PARTIAL") TM.PartialClose50();
        if(cmd == "CLOSEALL") TM.CloseAll();
        ObjectSetInteger(0, sp, OBJPROP_STATE, false);
        ChartRedraw();
    }
}
