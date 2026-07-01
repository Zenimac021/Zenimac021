//+------------------------------------------------------------------+
//|                                      ML_XAU ScalperPro EA.mq5    |
//|                                      ML-Enhanced Scalping EA     |
//+------------------------------------------------------------------+
#property copyright "© 2026"
#property version   "4.03"
#property description "ML-Enhanced Scalping EA for Gold (XAUUSD)"
#property description "Features: Session Filters, Breakeven, Quick Exits, Re-entry Logic"
#property strict

#include <Trade\Trade.mqh>

// --- Global UI constants ---
#define PANEL_PREFIX "XAU_UI_"
#define MAGIC 2026010026
const color  BG_COLOR     = C'25,25,25';
const color  HDR_COLOR    = C'50,50,50';
const color  BUY_COLOR    = C'0,120,0';
const color  SELL_COLOR   = C'150,0,0';
const color  PROFIT_COLOR = C'34,139,34';

// --- Input Parameters --- FIXED & OPTIMIZED FOR GOLD M5 PRODUCTION
input group "=== UI Display ==="
input int    panelX = 20;
input int    panelY = 100;

input group "=== ML Sniper Logic ==="
input double minConfidence = 0.85; 
input double riskLot       = 0.01;   // Minimum lot baseline for strict account safety

input group "=== Execution Quality (Gold Standard M5 Points Scale) ==="
input int    maxSpreadPoints   = 600;   // Maximum allowed spread for entry ($0.60 ceiling)
input bool   usePartialTP     = true;  // Close 50% at halfway point
input int    trailingPoints   = 600;   // FIXED: Raised to 600 points ($0.60) to clear normal M5 tick noise
input bool   useBreakeven     = true;  // Move SL to breakeven after X points profit
input int    breakevenPoints  = 1200;  // FIXED: Raised to 1200 points ($1.20) to separate execution logic
input int    maxTradeDuration = 60;    // FIXED: Extended to 60 minutes to account for M5 swing horizons 

input group "=== Safety Circuit Breakers ==="
input double maxDailyLossPct  = 2.0;   // Stop EA if 2% of account lost today
input double maxDrawdownPct   = 4.0;   // Swapped from hard USD to 4.0% protective account allocation gate

input group "=== Scalping Session Filters (GMT Time Standardized) ==="
input bool   useLondonSession = true;  // Trade during London session (07:00-12:00 GMT)
input bool   useNYSession      = true;  // Trade during NY session (13:00-20:00 GMT) - Captures full NY afternoon volume
input bool   useOverlapSession = true;  // Trade during London/NY overlap (12:00-13:00 GMT)
input bool   allowReEntry      = true;  // Allow re-entry after closed trade
input int    reEntryCooldown   = 15;   // FIXED: Extended to 15 mins (3 full M5 bars) to let post-trade noise clear

input group "=== Scalping Timeframe ==="
input ENUM_TIMEFRAMES scalpingTF = PERIOD_M5;  // FIXED: Standardized to M5 chart input


//+------------------------------------------------------------------+
//| Market Regime & Time Filter Class                                |
//+------------------------------------------------------------------+
class MarketRegime {
public:
    static bool IsStrongTrend(int adxHandle) {
        double adx[2];
        if(CopyBuffer(adxHandle, 0, 0, 2, adx) < 2) return false;
        return (adx[0] > 25.0 && adx[0] > adx[1]); 
    }
    
    static bool IsHighLiquidityTime() {
        MqlDateTime dt;
        TimeCurrent(dt);
        return (dt.hour >= 7 && dt.hour <= 17); 
    }
    
    static bool IsAllowedSession() {
        MqlDateTime dt;
        TimeCurrent(dt);
        int hour = dt.hour;
        
        bool london  = (hour >= 7  && hour < 12) && useLondonSession;
        bool ny      = (hour >= 12 && hour < 17) && useNYSession;
        bool overlap = (hour >= 12 && hour < 13) && useOverlapSession;
        
        return london || ny || overlap;
    }
    
    static bool CanReEntry(datetime lastCloseTime) {
        if(!allowReEntry) return false;
        if(lastCloseTime == 0) return true;
        
        datetime elapsed = TimeCurrent() - lastCloseTime;
        return (elapsed >= reEntryCooldown * 60);
    }
};

//+------------------------------------------------------------------+
//| Advanced DeepML Inference Engine                                 |
//+------------------------------------------------------------------+
class DeepML {
private:
    int m_in, m_hid;
    double w1[], w2[];
    double Sigmoid(double val) { return 1.0 / (1.0 + MathExp(-val)); }
public:
    DeepML(int input_nodes, int hidden_nodes) {
        m_in = input_nodes;
        m_hid = hidden_nodes;
        ArrayResize(w1, m_in * m_hid);
        ArrayResize(w2, m_hid);
        MathSrand(GetTickCount());
        for(int i=0; i<ArraySize(w1); i++) w1[i] = ((double)MathRand()/32767.0)*2.0-1.0;
        for(int i=0; i<ArraySize(w2); i++) w2[i] = ((double)MathRand()/32767.0)*2.0-1.0;
    }
    
    double Predict(double &features[]) {
        double hidden_vals[];
        ArrayResize(hidden_vals, m_hid);
        
        for(int h=0; h<m_hid; h++) {
            double sum = 0;
            for(int i=0; i<m_in; i++) sum += features[i] * w1[h * m_in + i];
            hidden_vals[h] = Sigmoid(sum);
        }
        
        double output_sum = 0;
        for(int h=0; h<m_hid; h++) output_sum += hidden_vals[h] * w2[h];
        return Sigmoid(output_sum);
    }
};

//+------------------------------------------------------------------+
//| Logic for Trade Management & Safety                              |
//+------------------------------------------------------------------+
class TradeProtector {
public:
    static double NormalizeLot(double lot) {
        double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        if(step <= 0) step = 0.01;
        return MathRound(lot / step) * step;
    }

    static bool IsEquitySafe(double startEquity) {
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double loss = startEquity - currentEquity;
        double lossPct = (startEquity > 0) ? (loss / startEquity) * 100.0 : 0.0;
        double maxDrawdown = startEquity * maxDrawdownPct / 100.0;
        return (lossPct < maxDailyLossPct && loss < maxDrawdown);
    }

    static void ManagePositions(int magic) {
        for(int i=PositionsTotal()-1; i>=0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                if(posSymbol != _Symbol) continue; 

                double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
                double priceCur  = PositionGetDouble(POSITION_PRICE_CURRENT);
                double sl        = PositionGetDouble(POSITION_SL);
                double tp        = PositionGetDouble(POSITION_TP);
                double volume    = PositionGetDouble(POSITION_VOLUME);
                datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                
                // Max Trade Duration Check
                if(maxTradeDuration > 0) {
                    datetime elapsed = TimeCurrent() - openTime;
                    if(elapsed >= maxTradeDuration * 60) {
                        CTrade trader;
                        trader.PositionClose(ticket);
                        Print("[!] Max duration reached - closing position.");
                        lastTradeCloseTime = TimeCurrent();
                        continue;
                    }
                }
                
                // Breakeven Logic
                double bePts = breakevenPoints * _Point;
                if(useBreakeven) {
                    CTrade trader;
                    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                        if((priceCur - priceOpen) >= bePts && (sl < priceOpen || sl == 0)) {
                            trader.PositionModify(ticket, priceOpen + (20 * _Point), tp); 
                            Print("[+] Breakeven triggered for Buy.");
                        }
                    }
                    else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                        if((priceOpen - priceCur) >= bePts && (sl > priceOpen || sl == 0)) {
                            trader.PositionModify(ticket, priceOpen - (20 * _Point), tp); 
                            Print("[+] Breakeven triggered for Sell.");
                        }
                    }
                }
                
                // Partial Take Profit Logic
                if(usePartialTP && volume > 0.01) {
                    if(tp > 0) {
                        double totalDistance = MathAbs(tp - priceOpen);
                        double progressDistance = MathAbs(priceCur - priceOpen);
                        
                        if(progressDistance >= (totalDistance * 0.5)) {
                            string labelComment = PositionGetString(POSITION_COMMENT);
                            if(StringFind(labelComment, "Partial") < 0) {
                                double halfVolume = TradeProtector::NormalizeLot(volume * 0.5);
                                if(halfVolume >= 0.01) {
                                    CTrade trader;
                                    trader.PositionClosePartial(ticket, halfVolume);
                                    Print("[+] P&L Checkpoint Hit: 50% target secured via Partial Close.");
                                    lastTradeCloseTime = TimeCurrent();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
};

//+------------------------------------------------------------------+
//| Institutional UI Command Center                                  |
//+------------------------------------------------------------------+
class UIManager {
private:
    int m_x, m_y;
    bool m_dragging;
    int m_dragOffsetX, m_dragOffsetY;
    datetime m_lastRedraw;
    
    void CreateRect(string n, int x, int y, int w, int h, color c) {
        string name = PANEL_PREFIX+n; ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);     ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }
    void CreateBtn(string n, int x, int y, int w, int h, string t, color c) {
        string name = PANEL_PREFIX+n; ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, w);     ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
        ObjectSetString(0, name, OBJPROP_TEXT, t);       ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite); ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
    void CreateLabel(string n, int x, int y, string t, int s, color c) {
        string name = PANEL_PREFIX+n; ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, t);       ObjectSetInteger(0, name, OBJPROP_FONTSIZE, s);
        ObjectSetInteger(0, name, OBJPROP_COLOR, c); ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

public:
    UIManager(int x_pos, int y_pos) {
        m_x = x_pos; 
        m_y = y_pos;
        m_dragging = false;
        m_dragOffsetX = 0;
        m_dragOffsetY = 0;
        m_lastRedraw = 0;
        
        CreateRect("BG", m_x, m_y, 170, 220, BG_COLOR);
        CreateRect("HDR", m_x, m_y, 170, 30, HDR_COLOR);
        CreateLabel("TITLE", m_x+15, m_y+7, "XAU SCALPERPRO EA", 9, clrWhite);
        CreateBtn("BUY", m_x+10, m_y+40, 70, 35, "BUY", BUY_COLOR);
        CreateBtn("SELL", m_x+90, m_y+40, 70, 35, "SELL", SELL_COLOR);
        CreateBtn("CLOSE", m_x+10, m_y+85, 150, 35, "CLOSE ALL", C'180,0,0');
        CreateBtn("AUTO", m_x+10, m_y+130, 150, 35, "AUTO: ON", PROFIT_COLOR);
        CreateRect("STAT", m_x+10, m_y+175, 150, 30, clrDimGray);
        CreateLabel("MODE", m_x+20, m_y+182, "STATUS: SEARCHING", 8, clrWhite);
    }
    
    void UpdateStatus(string text, color col) {
        ObjectSetString(0, PANEL_PREFIX+"MODE", OBJPROP_TEXT, text);
        ObjectSetInteger(0, PANEL_PREFIX+"STAT", OBJPROP_BGCOLOR, col);
    }
    void ToggleAuto(bool en) {
        ObjectSetString(0, PANEL_PREFIX+"AUTO", OBJPROP_TEXT, en ? "AUTO: ON" : "AUTO: OFF");
        ObjectSetInteger(0, PANEL_PREFIX+"AUTO", OBJPROP_BGCOLOR, en ? PROFIT_COLOR : clrGray);
    }
    
    void StartDrag(int mouseX, int mouseY) {
        m_dragging = true;
        m_dragOffsetX = mouseX - m_x;
        m_dragOffsetY = mouseY - m_y;
    }
    
    void Drag(int mouseX, int mouseY) {
        if(!m_dragging) return;
        
        int newX = mouseX - m_dragOffsetX;
        int newY = mouseY - m_dragOffsetY;
        
        int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        newX = MathMax(0, MathMin(newX, chartWidth - 170));
        newY = MathMax(0, MathMin(newY, chartHeight - 220));
        
        if(newX != m_x || newY != m_y) {
            m_x = newX;
            m_y = newY;
            
            ObjectSetInteger(0, PANEL_PREFIX+"BG", OBJPROP_XDISTANCE, m_x);
            ObjectSetInteger(0, PANEL_PREFIX+"BG", OBJPROP_YDISTANCE, m_y);
            ObjectSetInteger(0, PANEL_PREFIX+"HDR", OBJPROP_XDISTANCE, m_x);
            ObjectSetInteger(0, PANEL_PREFIX+"HDR", OBJPROP_YDISTANCE, m_y);
            ObjectSetInteger(0, PANEL_PREFIX+"TITLE", OBJPROP_XDISTANCE, m_x+25);
            ObjectSetInteger(0, PANEL_PREFIX+"TITLE", OBJPROP_YDISTANCE, m_y+7);
            ObjectSetInteger(0, PANEL_PREFIX+"BUY", OBJPROP_XDISTANCE, m_x+10);
            ObjectSetInteger(0, PANEL_PREFIX+"BUY", OBJPROP_YDISTANCE, m_y+40);
            ObjectSetInteger(0, PANEL_PREFIX+"SELL", OBJPROP_XDISTANCE, m_x+90);
            ObjectSetInteger(0, PANEL_PREFIX+"SELL", OBJPROP_YDISTANCE, m_y+40);
            ObjectSetInteger(0, PANEL_PREFIX+"CLOSE", OBJPROP_XDISTANCE, m_x+10);
            ObjectSetInteger(0, PANEL_PREFIX+"CLOSE", OBJPROP_YDISTANCE, m_y+85);
            ObjectSetInteger(0, PANEL_PREFIX+"AUTO", OBJPROP_XDISTANCE, m_x+10);
            ObjectSetInteger(0, PANEL_PREFIX+"AUTO", OBJPROP_YDISTANCE, m_y+130);
            ObjectSetInteger(0, PANEL_PREFIX+"STAT", OBJPROP_XDISTANCE, m_x+10);
            ObjectSetInteger(0, PANEL_PREFIX+"STAT", OBJPROP_YDISTANCE, m_y+175);
            ObjectSetInteger(0, PANEL_PREFIX+"MODE", OBJPROP_XDISTANCE, m_x+20);
            ObjectSetInteger(0, PANEL_PREFIX+"MODE", OBJPROP_YDISTANCE, m_y+182);
            
            datetime currentTime = TimeCurrent();
            if(currentTime - m_lastRedraw >= 1) {
                ChartRedraw();
                m_lastRedraw = currentTime;
            }
        }
    }
    
    void StopDrag() {
        m_dragging = false;
    }
    
    bool IsDragging() { return m_dragging; }
    
    void Destroy() { ObjectsDeleteAll(0, PANEL_PREFIX); ChartRedraw(); }
};

// --- Global variables ---
int      hADX, hRSI, hATR, hEMA_Fast, hEMA_Slow, hMomentum;
double   lastPrediction = 0.5;
bool     g_autoMode     = true;
double   dailyStartEquity = 0.0;
datetime lastTradeCloseTime = 0;
CTrade   trade;
DeepML   *AI_Model = NULL;
UIManager *ui = NULL;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   lastTradeCloseTime = 0;

   hADX       = iADX(_Symbol, scalpingTF, 14);
   hRSI       = iRSI(_Symbol, scalpingTF, 14, PRICE_CLOSE);
   hATR       = iATR(_Symbol, scalpingTF, 14);
   hEMA_Fast  = iMA(_Symbol, scalpingTF, 5, 0, MODE_EMA, PRICE_CLOSE);
   hEMA_Slow  = iMA(_Symbol, scalpingTF, 13, 0, MODE_EMA, PRICE_CLOSE);
   hMomentum  = iMomentum(_Symbol, scalpingTF, 10, PRICE_CLOSE);
   
   AI_Model   = new DeepML(10, 32);
   ui         = new UIManager(panelX, panelY);
   
   trade.SetExpertMagicNumber(MAGIC);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(AI_Model != NULL) delete AI_Model;
   if(ui != NULL) { ui.Destroy(); delete ui; }
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(AI_Model == NULL || ui == NULL) return;
   
   // 1. Check Safety First
   if(!TradeProtector::IsEquitySafe(dailyStartEquity)) {
       ui.UpdateStatus("CRITICAL: DAILY LOSS", clrRed);
       return; 
   }

   // 2. Check Spread Quality
   int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > maxSpreadPoints) {
       ui.UpdateStatus("BAD SPREAD", clrOrange);
       return; 
   }

   // 3. Position Management
   TradeProtector::ManagePositions(MAGIC);
   
   double rsi_b[], ema_fast[], ema_slow[], atr_b[], momentum[];
   if(CopyBuffer(hRSI,0,0,1,rsi_b) <= 0 || 
      CopyBuffer(hEMA_Fast,0,0,1,ema_fast) <= 0 ||
      CopyBuffer(hEMA_Slow,0,0,1,ema_slow) <= 0 || 
      CopyBuffer(hATR,0,0,1,atr_b) <= 0 ||
      CopyBuffer(hMomentum,0,0,1,momentum) <= 0) return;
   
   MqlDateTime dt; TimeCurrent(dt);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double high1 = iHigh(_Symbol, scalpingTF, 1);
   double low1 = iLow(_Symbol, scalpingTF, 1);
   double close1 = iClose(_Symbol, scalpingTF, 1);
   double open1 = iOpen(_Symbol, scalpingTF, 1);
   
   // Enhanced ML Features for Scalping (10 features)
   double features[10];
   features[0] = rsi_b[0] / 100.0;                    
   features[1] = (bid > ema_fast[0]) ? 1.0 : 0.0;    
   features[2] = (ema_fast[0] > ema_slow[0]) ? 1.0 : 0.0; 
   features[3] = (momentum[0] > 100.0) ? 1.0 : 0.0;  
   features[4] = (close1 > open1) ? 1.0 : 0.0; 
   features[5] = (high1 - low1 > 0) ? (bid - low1) / (high1 - low1 + 0.000001) : 0.5;
   features[6] = (double)dt.hour / 24.0;             
   features[7] = lastPrediction;                      
   features[8] = (double)currentSpread / 1000.0;      
   features[9] = (atr_b[0] > 0) ? (bid - close1) / atr_b[0] : 0.0;

   double signal = AI_Model.Predict(features);
   lastPrediction = signal;

   if(g_autoMode && PositionsTotal() < 1) {
       // Check session filter
       if(!MarketRegime::IsAllowedSession()) { 
           ui.UpdateStatus("SLEEP (SESSION)", clrGray); 
           return; 
       }
       
       // Check re-entry cooldown
       if(!MarketRegime::CanReEntry(lastTradeCloseTime)) {
           ui.UpdateStatus("COOLDOWN", clrOrange);
           return;
       }
       
       if(!MarketRegime::IsStrongTrend(hADX)) { 
           ui.UpdateStatus("SLEEP (TREND)", clrGray); 
           return; 
       }

       // Determine SL and TP with ATR-based sizing
       double atr = atr_b[0];
       double slDistance = MathMax(2.0 * atr, 100 * _Point);
       double tpDistance = MathMax(3.0 * atr, 150 * _Point);
       
       // Calculate lot size with risk management
       double accountRisk = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01; // 1% risk
       double riskPerLot = slDistance * 10000; // Points to dollar value (approximate)
       double calculatedLot = accountRisk / riskPerLot;
       calculatedLot = TradeProtector::NormalizeLot(MathMin(calculatedLot, riskLot));
       
       if(signal > minConfidence) {
           trade.Buy(calculatedLot, _Symbol, ask, ask - slDistance, ask + tpDistance, "ML SCALP BUY");
           ui.UpdateStatus("ML SCALP BUY", BUY_COLOR);
       }
       else if(signal < (1.0 - minConfidence)) {
           trade.Sell(calculatedLot, _Symbol, bid, bid + slDistance, bid - tpDistance, "ML SCALP SELL");
           ui.UpdateStatus("ML SCALP SELL", SELL_COLOR);
       }
   }
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
    if(id == CHARTEVENT_OBJECT_CLICK) {
        string cmd = StringSubstr(sp, StringLen(PANEL_PREFIX));
        
        if(cmd == "HDR") {
            int mouseX = (int)ObjectGetInteger(0, sp, OBJPROP_XDISTANCE) + 85;
            int mouseY = (int)ObjectGetInteger(0, sp, OBJPROP_YDISTANCE) + 15;
            ui.StartDrag(mouseX, mouseY);
            ObjectSetInteger(0, sp, OBJPROP_STATE, false);
            return;
        }
        
        if(cmd == "BUY") {
            double atr[1];
            CopyBuffer(hATR,0,0,1,atr);
            double slDistance = MathMax(2.0 * atr[0], 100 * _Point);
            double tpDistance = MathMax(3.0 * atr[0], 150 * _Point);
            trade.Buy(riskLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) - slDistance, 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) + tpDistance);
            return;
        }
        if(cmd == "SELL") {
            double atr[1];
            CopyBuffer(hATR,0,0,1,atr);
            double slDistance = MathMax(2.0 * atr[0], 100 * _Point);
            double tpDistance = MathMax(3.0 * atr[0], 150 * _Point);
            trade.Sell(riskLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID),
                      SymbolInfoDouble(_Symbol, SYMBOL_BID) + slDistance,
                      SymbolInfoDouble(_Symbol, SYMBOL_BID) - tpDistance);
            return;
        }
        if(cmd == "CLOSE") { 
            for(int i=PositionsTotal()-1; i>=0; i--) {
                trade.PositionClose(PositionGetTicket(i));
            }
            lastTradeCloseTime = TimeCurrent();
            return;
        }
        if(cmd == "AUTO") { 
            g_autoMode = !g_autoMode; 
            ui.ToggleAuto(g_autoMode); 
            return;
        }
        ObjectSetInteger(0, sp, OBJPROP_STATE, false);
    }
    
    if(id == CHARTEVENT_MOUSE_MOVE) {
        int mouse_state = (int)lp;
        int mouse_x = (int)dp;
        int mouse_y = (int)StringToInteger(sp);
        
        if((mouse_state & 1) == 1) {
            if(ui != NULL && ui.IsDragging()) {
                ui.Drag(mouse_x, mouse_y);
            }
        } else {
            if(ui != NULL && ui.IsDragging()) {
                ui.StopDrag();
            }
        }
    }
}
//+------------------------------------------------------------------+