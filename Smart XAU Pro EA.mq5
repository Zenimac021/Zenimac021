//+------------------------------------------------------------------+
//| Smart XAU Pro EA.mq5                                             |
//| Version: 1.40 (OPTIMIZED FOR GOLD VOLATILITY + ATR TS + BE)     |
//| Enhanced with ATR Dynamic SL/TS and Break-Even for Gold         |
//+------------------------------------------------------------------+
#property copyright "© 2025"
#property version   "1.40"
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

#define MAGIC 2025121502  // 2025-12-15-02 (XAU EA v1.40 with ATR & BE)
#define PANEL_PREFIX "XAU_PANEL_"

// --- Inputs ---
input group "--- UI Settings ---"
input int panelX = 10;
input int panelY = 200;

input group "--- Smart Automation ---"
input bool defaultAutoTrade = true;
input bool enableTrendFilter = true;
input double minADXStrength = 25.0;
input double minVolumeIncrease = 1.1; // Minimum volume increase ratio (1.1 = 10% increase)
input long minVolumeTicks = 100;     // Minimum volume in ticks 

input group "--- Risk Management ---"
enum LOT_MODE { FIXED_LOT, RISK_PERCENT };
input LOT_MODE lotMode = FIXED_LOT;
input double fixedLot = 0.1;
input double riskPercent = 0.2; // Reduced risk for Gold volatility 
input double maxDailyLossPercent = 3.0; 
input int maxConsecutiveLosses = 3;

input group "--- Strategy Parameters ---"
input int fastEMA = 7 ;
input int slowEMA = 21;
input int fixedSLPips = 500;  // Fixed SL in pips (60 pips for Gold volatility)
input int fixedTPPips = 1000; // Fixed TP in pips (120 pips for Gold volatility)

input group "--- ATR Dynamic Settings ---"
input bool useATR_SL = true;       // Use ATR for Stop Loss
input bool useATR_TS = true;       // Use ATR for Trailing Stop
input int atrPeriod = 14;          // ATR Period
input double atrSL_Mult = 1.2;     // ATR Multiplier for SL (1.2 = 1.2x ATR for Gold)
input double atrTS_Mult = 1.8;     // ATR Multiplier for TS (1.8 = 1.8x ATR for Gold)

input group "--- Break Even Settings ---"
input bool useBreakEven = true;    // Use Break Even
input int beTriggerPips = 150;     // Break Even Trigger (pips from entry for Gold)
input int beOffsetPips = 50;       // Break Even Offset (pips above/below entry for Gold)

// Global State
bool Global_AutoTrade = true;

//+------------------------------------------------------------------+
//| Risk Management Class                                            |
//+------------------------------------------------------------------+
class RiskManager {
private:
    double m_maxDL, m_startEq;
    datetime m_lastDay;
    int m_maxConsecLosses;
    int m_lastDealsChecked;
    
    // Cache for account info to reduce API calls
    double cachedEquity;
    datetime lastEquityUpdate;
    
public:
    RiskManager() : m_maxDL(3.0), m_startEq(0), m_lastDay(0), m_maxConsecLosses(3), m_lastDealsChecked(0), 
                    cachedEquity(0), lastEquityUpdate(0) {}
    void Init(double dl, int maxLosses) {
        m_maxDL = dl;
        m_maxConsecLosses = maxLosses;
        m_startEq = GetCachedEquity();
        m_lastDay = iTime(_Symbol, PERIOD_D1, 0);
    }

    // Cached equity getter to reduce API calls
    double GetCachedEquity() {
        datetime currentTime = TimeCurrent();
        // Update cache every 10 seconds to reduce API calls
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
        int checkCount = MathMin(totalDeals, 20); // Check last 20 deals max

        for(int i = totalDeals - 1; i >= MathMax(0, totalDeals - checkCount); i--) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0) continue;

            long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            if(magic != MAGIC) continue; // Only count our EA's deals

            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit <= 0) {
                consecutiveLosses++;
            } else {
                break; // Stop at first profit
            }
        }

        m_lastDealsChecked = totalDeals;
        return consecutiveLosses;
    }

    bool IsAllowed() {
        // Check daily loss limit
        datetime currentTime = TimeCurrent();
        if(iTime(_Symbol, PERIOD_D1, 0) > m_lastDay) {
            m_startEq = GetCachedEquity();
            m_lastDay = iTime(_Symbol, PERIOD_D1, 0);
        }
        double currentEquity = GetCachedEquity();
        double dd = (m_startEq - currentEquity) / m_startEq * 100.0;
        if(dd >= m_maxDL) return false;

        // Check consecutive losses
        if(GetConsecutiveLosses() >= m_maxConsecLosses) return false;

        return true;
    }
};

//+------------------------------------------------------------------+
//| Trade Management Class                                           |
//+------------------------------------------------------------------+
class TradeManager {
private:
    CTrade m_trade;
    CSymbolInfo m_sym;
    int hADX, hEMA_F, hEMA_S, hVol, hATR;
public:
    TradeManager() {
        m_sym.Name(_Symbol);
        m_trade.SetExpertMagicNumber(MAGIC);

        // Initialize indicators with error checking
        hADX = iADX(_Symbol, PERIOD_CURRENT, 14);
        if(hADX == INVALID_HANDLE) {
            Print("Error: Failed to create ADX indicator for symbol: ", _Symbol, " Error: ", GetLastError());
        }
        
        hEMA_F = iMA(_Symbol, PERIOD_CURRENT, fastEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_F == INVALID_HANDLE) {
            Print("Error: Failed to create Fast EMA indicator for symbol: ", _Symbol, " Error: ", GetLastError());
        }
        
        hEMA_S = iMA(_Symbol, PERIOD_CURRENT, slowEMA, 0, MODE_EMA, PRICE_CLOSE);
        if(hEMA_S == INVALID_HANDLE) {
            Print("Error: Failed to create Slow EMA indicator for symbol: ", _Symbol, " Error: ", GetLastError());
        }
        
        hVol = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
        if(hVol == INVALID_HANDLE) {
            Print("Error: Failed to create Volume indicator for symbol: ", _Symbol, " Error: ", GetLastError());
        }
        
        hATR = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
        if(hATR == INVALID_HANDLE) {
            Print("Error: Failed to create ATR indicator for symbol: ", _Symbol, " Error: ", GetLastError());
        }

        if(IsReady()) {
            Print("All indicators initialized successfully for symbol: ", _Symbol);
        } else {
            Print("Warning: Some indicators failed to initialize. EA may not function properly.");
        }
    }

    ~TradeManager() {
        // Clean up indicators
        if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
        if(hEMA_F != INVALID_HANDLE) IndicatorRelease(hEMA_F);
        if(hEMA_S != INVALID_HANDLE) IndicatorRelease(hEMA_S);
        if(hVol != INVALID_HANDLE) IndicatorRelease(hVol);
        if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
    }

    bool IsReady() {
        return (hADX != INVALID_HANDLE && hEMA_F != INVALID_HANDLE &&
                hEMA_S != INVALID_HANDLE && hVol != INVALID_HANDLE && hATR != INVALID_HANDLE);
    }

    int GetSignal() {
        // Check for valid indicator handles first
        if(hEMA_F == INVALID_HANDLE || hEMA_S == INVALID_HANDLE || hADX == INVALID_HANDLE || hVol == INVALID_HANDLE || hATR == INVALID_HANDLE)
            return -1;

        double f[], s[], adx[], plusDI[], minusDI[];
        
        // Resize arrays to ensure they can hold the required data
        ArrayResize(f, 2);
        ArrayResize(s, 2);
        ArrayResize(adx, 1);
        ArrayResize(plusDI, 1);
        ArrayResize(minusDI, 1);
        
        // Copy indicator buffers with error checking
        int copied_f = CopyBuffer(hEMA_F, 0, 1, 2, f);
        int copied_s = CopyBuffer(hEMA_S, 0, 1, 2, s);
        
        if(copied_f < 2 || copied_s < 2) {
            Print("Error: Failed to copy EMA buffers. Copied EMA_F: ", copied_f, ", Copied EMA_S: ", copied_s);
            return -1;
        }

        // Copy ADX buffers with error checking
        int copied_adx = CopyBuffer(hADX, 0, 1, 1, adx);
        int copied_plusDI = CopyBuffer(hADX, 1, 1, 1, plusDI);
        int copied_minusDI = CopyBuffer(hADX, 2, 1, 1, minusDI);
        
        if(copied_adx <= 0 || copied_plusDI <= 0 || copied_minusDI <= 0) {
            Print("Error: Failed to copy ADX buffers. ADX: ", copied_adx, ", +DI: ", copied_plusDI, ", -DI: ", copied_minusDI);
            return -1;
        }

        if(adx[0] < minADXStrength) return -1; // Trend not strong enough

        // Use more robust crossover detection with additional validation
        if(f[0] > s[0] && f[1] <= s[1] && CheckFilters(0)) return 0; // Buy
        if(f[0] < s[0] && f[1] >= s[1] && CheckFilters(1)) return 1; // Sell
        return -1;
    }

    double GetATRValue() {
        if(hATR == INVALID_HANDLE) {
            Print("Warning: ATR indicator handle is invalid");
            return 0.0;
        }

        double atr[];
        ArrayResize(atr, 1);
        int copied = CopyBuffer(hATR, 0, 1, 1, atr);
        
        if(copied <= 0) {
            Print("Warning: Could not copy ATR buffer (copied: ", copied, ")");
            return 0.0;
        }

        if(atr[0] <= 0) {
            Print("Warning: ATR value is invalid: ", atr[0]);
            return 0.0;
        }

        return atr[0];
    }

    bool CheckFilters(int dir) {
        if(enableTrendFilter) {
            // Get H1 close price
            double h1CloseArray[];
            if(CopyClose(_Symbol, PERIOD_H1, 1, 1, h1CloseArray) < 1) {
                Print("Error: Could not get H1 close price");
                return false; // Skip signal if we can't get H1 data
            }
            double h1Close = h1CloseArray[0];
            
            // Create and get H1 EMA
            int h1EMAHandle = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
            if(h1EMAHandle == INVALID_HANDLE) {
                Print("Error: Could not create H1 EMA indicator");
                return false;
            }
            
            double h1EMAArray[];
            if(CopyBuffer(h1EMAHandle, 0, 1, 1, h1EMAArray) < 1) {
                Print("Error: Could not get H1 EMA value");
                IndicatorRelease(h1EMAHandle);
                return false;
            }
            double h1EMA = h1EMAArray[0];
            
            // Release the temporary indicator handle
            IndicatorRelease(h1EMAHandle);
            
            if(dir == 0 && h1Close < h1EMA) return false;
            if(dir == 1 && h1Close > h1EMA) return false;
        }
        
        // Improved volume validation with configurable thresholds
        double v[];
        ArrayResize(v, 2);
        int copied = CopyBuffer(hVol, 0, 1, 2, v);
        
        if(copied < 2) {
            // If volume data is not available, skip volume filter check
            // This makes the EA more robust when volume data isn't available for certain symbols
            Print("Warning: Could not copy volume data, skipping volume filter (copied: ", copied, ")");
            return true;
        }
        
        if(v[1] <= 0 || v[0] < minVolumeTicks) return false; // Invalid or too low volume
        if(v[0] < v[1] * minVolumeIncrease) return false; // Volume not increasing enough
        
        return true;
    }

    void Execute(int dir) {
        if(!m_sym.RefreshRates()) {
            Print("Error: Failed to refresh symbol rates");
            return;
        }

        double lot = (lotMode == FIXED_LOT) ? fixedLot : CalculateRiskLot();
        if(lot <= 0) {
            Print("Error: Invalid lot size calculated: ", lot);
            return;
        }

        // Validate lot size against symbol specifications
        double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double lotsMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotsStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        if(lot < lotsMin) {
            lot = lotsMin;
            Print("Warning: Lot size adjusted to minimum: ", lot);
        } else if(lot > lotsMax) {
            lot = lotsMax;
            Print("Warning: Lot size adjusted to maximum: ", lot);
        }
        
        // Normalize lot size to step
        if(lotsStep > 0) {
            lot = MathFloor(lot/lotsStep) * lotsStep;
        }

        double price = (dir == 0) ? m_sym.Ask() : m_sym.Bid();

        // Use ATR for dynamic SL if enabled, otherwise use fixed SL
        double atrValue = GetATRValue();
        double slDistance = useATR_SL && atrValue > 0 ? atrValue * atrSL_Mult : fixedSLPips * _Point;
        double tpDistance = fixedTPPips * _Point;

        // Validate that ATR value is reasonable
        if(useATR_SL && atrValue > 0) {
            // Limit ATR-based stops to prevent extremely wide stops
            double maxReasonableATR = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 1000; // Adjust as needed
            if(slDistance > maxReasonableATR) {
                slDistance = maxReasonableATR;
                Print("Warning: ATR-based SL limited to prevent excessively wide stop loss");
            }
        }

        double sl = (dir == 0) ? price - slDistance : price + slDistance;
        double tp = (dir == 0) ? price + tpDistance : price - tpDistance;

        // Validate SL/TP levels against market limits
        long stopsLevelLong = 0;
        if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevelLong)) {
            Print("Error: Could not get stops level for symbol: ", _Symbol);
            return;
        }
        double stopsLevel = stopsLevelLong * _Point;
        double slDistPoints = slDistance / _Point;
        double tpDistPoints = tpDistance / _Point;
        
        if(slDistPoints < stopsLevel || tpDistPoints < stopsLevel) {
            Print("Error: SL/TP too close to price. Required min: ", stopsLevel/_Point, " pips, SL: ", slDistPoints, " pips, TP: ", tpDistPoints, " pips");
            return;
        }

        // Validate that SL and TP are in correct direction
        if(dir == 0) { // Buy order
            if(sl >= price || tp <= price) {
                Print("Error: Invalid SL/TP for buy order. Price: ", price, " SL: ", sl, " TP: ", tp);
                return;
            }
        } else { // Sell order
            if(sl <= price || tp >= price) {
                Print("Error: Invalid SL/TP for sell order. Price: ", price, " SL: ", sl, " TP: ", tp);
                return;
            }
        }

        bool tradeSuccess = false;
        int attempts = 0;
        int maxAttempts = 3; // Retry up to 3 times if trade fails
        
        while(attempts < maxAttempts && !tradeSuccess) {
            if(dir == 0) {
                tradeSuccess = m_trade.Buy(lot, _Symbol, price, sl, tp);
            } else {
                tradeSuccess = m_trade.Sell(lot, _Symbol, price, sl, tp);
            }

            if(!tradeSuccess) {
                uint error = m_trade.ResultRetcode();
                Print("Trade execution attempt ", attempts + 1, " failed. Error: ", error, " (", m_trade.ResultRetcodeDescription(), ")");
                
                if(error == TRADE_RETCODE_MARKET_CLOSED || error == TRADE_RETCODE_REQUOTE) {
                    Sleep(1000); // Wait 1 second before retry
                    if(!m_sym.RefreshRates()) {
                        Print("Error: Failed to refresh symbol rates after failed trade");
                        break;
                    }
                    attempts++;
                } else {
                    // Different error, don't retry
                    break;
                }
            }
        }

        if(tradeSuccess) {
            Print("Trade executed successfully: ", (dir == 0 ? "BUY" : "SELL"), " ", lot, " lots at ", price,
                  " SL: ", slDistance/_Point, " pips", useATR_SL && atrValue > 0 ? " (ATR)" : " (Fixed)",
                  " TP: ", tpDistance/_Point, " pips");
        } else {
            Print("Trade execution ultimately failed after ", maxAttempts, " attempts.");
        }
    }

    void ManagePositions() {
        double atrValue = GetATRValue();
        int totalPositions = PositionsTotal();

        for(int i = 0; i < totalPositions; i++) {
            if(!PositionSelectByTicket(PositionGetTicket(i))) {
                continue; // Skip if we can't select the position
            }
            
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0 || PositionGetInteger(POSITION_MAGIC) != MAGIC) continue;

            long positionType = PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);

            // Break-even logic
            if(useBreakEven) {
                double profitInPips = (positionType == POSITION_TYPE_BUY) ?
                    (currentPrice - openPrice) / _Point : (openPrice - currentPrice) / _Point;

                if(profitInPips >= beTriggerPips) {
                    double beLevel = (positionType == POSITION_TYPE_BUY) ?
                        openPrice + beOffsetPips * _Point : openPrice - beOffsetPips * _Point;

                    // Ensure break-even level is valid and improves current SL
                    if((positionType == POSITION_TYPE_BUY && (currentSL < beLevel || currentSL == 0) && beLevel < currentPrice) ||
                       (positionType == POSITION_TYPE_SELL && (currentSL > beLevel || currentSL == 0) && beLevel > currentPrice)) {

                        // Validate that the new SL level meets minimum distance requirements
                        long stopsLevelBE = 0;
                        if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevelBE)) {
                            double minStopLevel = stopsLevelBE * _Point;
                            if(MathAbs(currentPrice - beLevel) >= minStopLevel) {
                                if(m_trade.PositionModify(ticket, beLevel, currentTP)) {
                                    Print("Break-even activated for position ", ticket, " at ", beLevel);
                                } else {
                                    Print("Failed to activate break-even for position ", ticket, ". Error: ", m_trade.ResultRetcodeDescription());
                                }
                            }
                        }
                    }
                }
            }

            // ATR Trailing Stop logic
            if(useATR_TS && atrValue > 0) {
                double tsDistance = atrValue * atrTS_Mult;
                
                // Limit trailing stop distance to prevent excessive trailing
                double maxReasonableTS = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 500; // Adjust as needed
                if(tsDistance > maxReasonableTS) {
                    tsDistance = maxReasonableTS;
                }
                
                double newSL = 0;

                if(positionType == POSITION_TYPE_BUY) {
                    newSL = currentPrice - tsDistance;
                    // Only update SL if it's an improvement (higher for long positions)
                    if(newSL > currentSL && newSL < currentPrice) { // Ensure SL is below current price
                        // Validate minimum distance from current price
                        long stopsLevel = 0;
                        if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel)) {
                            if(MathAbs(currentPrice - newSL) >= stopsLevel * _Point) {
                                if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                                    Print("ATR Trailing Stop updated for BUY position ", ticket, " to ", newSL);
                                } else {
                                    Print("Failed to update trailing stop for BUY position ", ticket, ". Error: ", m_trade.ResultRetcodeDescription());
                                }
                            }
                        }
                    }
                } else { // SELL position
                    newSL = currentPrice + tsDistance;
                    // Only update SL if it's an improvement (lower for short positions)
                    if(newSL < currentSL && newSL > currentPrice) { // Ensure SL is above current price
                        // Validate minimum distance from current price
                        long stopsLevel2 = 0;
                        if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel2)) {
                            if(MathAbs(newSL - currentPrice) >= stopsLevel2 * _Point) {
                                if(m_trade.PositionModify(ticket, newSL, currentTP)) {
                                    Print("ATR Trailing Stop updated for SELL position ", ticket, " to ", newSL);
                                } else {
                                    Print("Failed to update trailing stop for SELL position ", ticket, ". Error: ", m_trade.ResultRetcodeDescription());
                                }
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
            Print("Error: Invalid account equity: ", equity);
            return fixedLot;
        }

        double riskAmount = equity * (riskPercent/100.0);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        if(tickValue <= 0) {
            Print("Error: Invalid tick value: ", tickValue);
            // Calculate tick value manually if symbol info fails
            tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            if(tickValue <= 0) {
                // Estimate tick value as a fallback
                int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                tickValue = _Point * (digits == 5 ? 10 : 1);
            }
            if(tickValue <= 0) {
                Print("Error: Could not determine tick value, using fixed lot");
                return fixedLot;
            }
        }

        // Use ATR for risk calculation if enabled
        double atrValue = GetATRValue();
        double slPoints = (useATR_SL && atrValue > 0) ? atrValue * atrSL_Mult : fixedSLPips * _Point;
        
        if(slPoints <= 0) {
            Print("Error: Invalid stop loss points: ", slPoints);
            return fixedLot;
        }

        double slValue = slPoints * tickValue;

        if(slValue <= 0) {
            Print("Error: Invalid stop loss value: ", slValue);
            return fixedLot;
        }

        double lot = riskAmount / slValue;
        double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double lotsMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

        // Ensure minimum lot size is positive
        if(lotsMin <= 0) {
            lotsMin = 0.01; // Default minimum lot size
        }

        lot = NormalizeDouble(MathMax(lotsMin, MathMin(lot, lotsMax)), 2);

        if(lot <= 0) {
            Print("Error: Calculated lot size is invalid: ", lot, ". Equity: ", equity, ", Risk Amount: ", riskAmount, ", SL Value: ", slValue);
            return fixedLot;
        }

        return lot;
    }

    void CloseAll() {
        int closed = 0;
        for(int i=PositionsTotal()-1; i>=0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC)==MAGIC) {
                if(m_trade.PositionClose(ticket)) {
                    closed++;
                } else {
                    Print("Error closing position ", ticket, ": ", GetLastError());
                }
            }
        }
        if(closed > 0) Print("Closed ", closed, " positions");
    }
    
    void CloseProfitable() {
        int closed = 0;
        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit > 0) {
                    if(m_trade.PositionClose(ticket)) {
                        closed++;
                    } else {
                        Print("Error closing profitable position ", ticket, ": ", GetLastError());
                    }
                }
            }
        }
        if(closed > 0) Print("Closed ", closed, " profitable positions");
    }
    
    void PartialClose50() {
        int partialClosed = 0;
        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MAGIC) {
                // FIX: Only partial close if position is profitable
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit <= 0) continue;

                double positionVolume = PositionGetDouble(POSITION_VOLUME);
                double closeVolume = positionVolume * 0.5;
                double lotsMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

                if(closeVolume >= lotsMin) {
                    if(m_trade.PositionClosePartial(ticket, closeVolume)) {
                        partialClosed++;
                        Print("Partial close 50% of profitable position ", ticket);
                    } else {
                        Print("Error partial closing position ", ticket, ": ", GetLastError());
                    }
                }
            }
        }
        if(partialClosed > 0) Print("Partial closed ", partialClosed, " positions");
    }
};

//+------------------------------------------------------------------+
//| UI Management Class                                              |
//+------------------------------------------------------------------+
class UIManager {
public:
    void Create(int x, int y) {
        ObjectsDeleteAll(0, PANEL_PREFIX);
        CreateRect("BG", x, y, 180, 240, C'35,35,35');
        CreateRect("HDR", x, y, 180, 25, C'60,60,60');
        
        // Add title text
        CreateLabel("TITLE", x+45, y+5, "Smart XAU Pro", 12, clrWhite);
        
        string autoTxt = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color autoClr = Global_AutoTrade ? C'0,150,0' : C'100,100,100';
        
        CreateBtn("AUTO", x+10, y+35, 160, 30, autoTxt, autoClr);
        CreateBtn("BUY", x+10, y+75, 75, 30, "BUY", C'0,130,0');
        CreateBtn("SELL", x+95, y+75, 75, 30, "SELL", C'180,0,0');
        CreateBtn("CLOSEPROFIT", x+10, y+115, 160, 30, "CLOSE PROFIT", C'0,138,0');
        CreateBtn("PARTIAL", x+10, y+155, 160, 30, "PARTIAL 50%", C'255,165,0');
        CreateBtn("CLOSEALL", x+10, y+195, 160, 30, "CLOSE ALL", C'150,0,0');
    }

    void UpdateAutoBtn() {
        string t = Global_AutoTrade ? "AUTO: ON" : "AUTO: OFF";
        color c = Global_AutoTrade ? C'0,150,0' : C'100,100,100';
        ObjectSetString(0, PANEL_PREFIX+"AUTO", OBJPROP_TEXT, t);
        ObjectSetInteger(0, PANEL_PREFIX+"AUTO", OBJPROP_BGCOLOR, c);
    }

private:
    void CreateRect(string n, int x, int y, int w, int h, color c) {
        string name = PANEL_PREFIX+n;
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
        string name = PANEL_PREFIX+n;
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
        string name = PANEL_PREFIX+n;
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
    return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { ObjectsDeleteAll(0, PANEL_PREFIX); delete TM; }

void OnTick() {
    if(TM != NULL && TM.IsReady()) {
        // Manage existing positions (BE and TS)
        TM.ManagePositions();

        // Check for new signals only on new bars
        if(Global_AutoTrade) {
            static datetime lastBar;
            if(iTime(_Symbol, PERIOD_CURRENT, 0) != lastBar) {
                int sig = TM.GetSignal();
                if(sig != -1 && RM.IsAllowed()) TM.Execute(sig);
                lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
            }
        }
    }
    
    // Small sleep to reduce CPU usage when not actively trading
    // This is especially useful when autotrading is disabled
    if(!Global_AutoTrade) {
        static datetime lastSleep = 0;
        datetime currentTime = TimeCurrent();
        // Only sleep every few seconds when auto-trading is off to reduce CPU usage
        if(currentTime - lastSleep > 2) {
            Sleep(10); // Sleep for 10ms to reduce CPU usage
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
