//+------------------------------------------------------------------+
//|                                             Indicator Arrows.mq5 |
//|                        Enhanced Edition v3.2 Clean               |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Enhanced Edition v3.2"
#property link      "https://www.mql5.com"
#property version   "3.20"
#property description "Clean Strategy: EMA200 + BB + RSI + MACD + VOLUME"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot 1: Buy Arrows
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  2
#property indicator_style1  STYLE_SOLID

//--- Plot 2: Sell Arrows
#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrMagenta
#property indicator_width2  2
#property indicator_style2  STYLE_SOLID

//+------------------------------------------------------------------+
//| Enumerations (Streamlined to 5 indicators)                        |
//+------------------------------------------------------------------+
enum ENUM_MY_INDICATOR
  {
   MY_IND_MA           = 0,  // Moving Average
   MY_IND_MACD         = 1,  // MACD
   MY_IND_RSI          = 2,  // RSI
   MY_IND_BANDS        = 3,  // Bollinger Bands
   MY_IND_VOLUME       = 4,  // Volume
   MY_IND_NONE         = 99  // No Indicator
  };

enum ENUM_SIGNAL_MODE
  {
   MODE_REQUIRE_ALL    = 0,  // Require ALL indicators to agree
   MODE_REQUIRE_PRIMARY = 1, // Primary only, others as filter
   MODE_MAJORITY_VOTE  = 2  // Majority vote (>50% agree)
  };

enum ENUM_ARROW_STYLE
  {
   ARROW_UP_DOWN      = 0,  // Up/Down Arrows (233/234)
   ARROW_THUMB_UP_DOWN = 1, // Thumbs Up/Down (67/68)
   ARROW_TRIANGLE     = 2,  // Triangles (228/226)
   ARROW_DIAMOND      = 3,  // Diamonds (252/251)
   ARROW_CUSTOM       = 5   // Custom Codes
  };

enum ENUM_SIGNAL
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

//+------------------------------------------------------------------+
//| Input Parameters                                                   |
//+------------------------------------------------------------------+
input group "═════════ INDICATOR 1 (Primary Trigger) ═════════"
input ENUM_MY_INDICATOR  Ind1_Type         = MY_IND_MACD;    // Indicator Type (MACD)
input ENUM_TIMEFRAMES    Ind1_TimeFrame    = PERIOD_H1;      // Timeframe
input bool               Ind1_Enabled      = true;           // Enable

input group "═════════ INDICATOR 2 (Pullback Zone) ═════════"
input ENUM_MY_INDICATOR  Ind2_Type         = MY_IND_BANDS;   // Indicator Type (Bollinger Bands)
input ENUM_TIMEFRAMES    Ind2_TimeFrame    = PERIOD_H1;      // Timeframe
input bool               Ind2_Enabled      = true;           // Enable

input group "═════════ INDICATOR 3 (Exhaustion Filter) ═════════"
input ENUM_MY_INDICATOR  Ind3_Type         = MY_IND_RSI;     // Indicator Type (RSI)
input ENUM_TIMEFRAMES    Ind3_TimeFrame    = PERIOD_H1;      // Timeframe
input bool               Ind3_Enabled      = true;           // Enable

input group "═════════ INDICATOR 4 (Spare/Extra Conf) ═════════"
input ENUM_MY_INDICATOR  Ind4_Type         = MY_IND_MA;      // Indicator Type (MA 50)
input ENUM_TIMEFRAMES    Ind4_TimeFrame    = PERIOD_H1;      // Timeframe
input bool               Ind4_Enabled      = true;           // Enable

input group "═════════ INDICATOR 5 (Volume Confirmation) ═════════"
input ENUM_MY_INDICATOR  Ind5_Type         = MY_IND_VOLUME;  // Indicator Type (Volume)
input ENUM_TIMEFRAMES    Ind5_TimeFrame    = PERIOD_H1;      // Timeframe
input bool               Ind5_Enabled      = true;           // Enable

input group "═════════ SIGNAL LOGIC ═════════"
input ENUM_SIGNAL_MODE   SignalMode        = MODE_REQUIRE_PRIMARY; // Signal Mode 
input int                MinAgreeingIndicators = 3;           // Min agreeing indicators (1-5)
input bool               AllowReEntry      = false;           // Allow re-entry in same direction
input int                MinBarsBetween    = 2;               // Min bars between signals

input group "═════════ TREND FILTER (EMA 200) ═════════"
input bool               UseTrendFilter    = true;            // Use EMA 200 Trend Filter
input ENUM_TIMEFRAMES    TrendTimeFrame    = PERIOD_H4;       // Trend Timeframe
input int                TrendMAPeriod     = 200;             // Trend MA Period (200)
input ENUM_MA_METHOD     TrendMAMethod     = MODE_EMA;        // Trend MA Method (EMA)

input group "═════════ ARROW SETTINGS ═════════"
input ENUM_ARROW_STYLE   ArrowStyle        = ARROW_UP_DOWN;   
input int                ArrowSize         = 2;                
input color              BuyArrowColor     = clrLimeGreen;     
input color              SellArrowColor    = clrMagenta;       
input int                CustomBuyCode     = 233;              
input int                CustomSellCode    = 234;              
input double             ArrowOffsetATR    = 0.5;             
input int                ATRPeriod         = 14;               

input group "═════════ RISK-REWARD SETTINGS ═════════"
input bool               ShowRiskReward    = true;               
input double             StopLossATRMultiplier = 1.5;         
input double             TakeProfitMultiplier = 3.0;          

input group "═════════ SCALPING FILTERS ═════════"
input bool               FilterSpread      = true;            
input double             MaxSpreadPips     = 30.0;             
input bool               FilterVolatility  = true;            
input double             MinATRPips        = 5.0;              

input group "═════════ VISUAL SETTINGS ═════════"
input bool               ShowDashboard     = true;             
input bool               ShowSpread        = true;             
input bool               ShowATR           = true;             

input group "═════════ ALERTS ═════════"
input bool               EnableAlerts      = true;             
input bool               AlertPopup        = true;             
input bool               AlertSound        = true;             
input string             SoundFile         = "alert2.wav";     

input group "═════════ MACD PARAMETERS ═════════"
input int                MACD_Fast         = 12;         
input int                MACD_Slow         = 26;
input int                MACD_Signal       = 9;
input ENUM_APPLIED_PRICE MACD_Price        = PRICE_CLOSE;

input group "═════════ RSI PARAMETERS ═════════"
input int                RSI_Period        = 14;           
input ENUM_APPLIED_PRICE RSI_Price         = PRICE_CLOSE;
input double             RSI_OversoldLevel = 35.0;        // Optimized for trend pullbacks
input double             RSI_OverboughtLevel = 65.0;       

input group "═════════ BOLLINGER BANDS PARAMETERS ═════════"
input int                BB_Period         = 20;
input double             BB_Deviation      = 2.0;         
input ENUM_APPLIED_PRICE BB_Price          = PRICE_CLOSE;

input group "═════════ VOLUME PARAMETERS ═════════"
input int                VOL_Period        = 20;          // Volume SMA Period
input ENUM_APPLIED_VOLUME VOL_VolumeType   = VOLUME_TICK; // Volume Type
input double             VOL_Multiplier    = 1.2;         // Trigger if Vol > SMA * Mult

input group "═════════ MA PARAMETERS ═════════"
input int                MA_Period         = 50;          
input ENUM_MA_METHOD     MA_Method         = MODE_EMA;
input ENUM_APPLIED_PRICE MA_Price          = PRICE_CLOSE;

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
double BuyBuffer[];
double SellBuffer[];
double BuySignalLineBuffer[];
double SellSignalLineBuffer[];

long    g_chartID;
int     g_digits;
double  g_pipValue;
double  g_point;

int     g_atrHandle = INVALID_HANDLE;
int     g_trendMAHandle = INVALID_HANDLE;

ENUM_SIGNAL g_lastSignal = SIGNAL_NONE;
int     g_barsSinceBuy = 999;
int     g_barsSinceSell = 999;
datetime g_cachedTrendBarTime = 0;
ENUM_SIGNAL g_cachedTrendDirection = SIGNAL_NONE;

string  g_objPrefix = "IndArrows_";

struct SIndicatorConfig
  {
   ENUM_MY_INDICATOR type;
   ENUM_TIMEFRAMES   timeframe;
   bool              enabled;
   int               handle;
   string            name;
   ENUM_SIGNAL       signal;
  };

SIndicatorConfig g_ind[5];

//+------------------------------------------------------------------+
//| Utility helpers                                                    |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES ResolveTimeframe(ENUM_TIMEFRAMES tf) { return (tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : tf; }
double PriceToPips(double priceDelta) { return (g_pipValue <= 0.0) ? 0.0 : priceDelta / g_pipValue; }

int GetBarShift(ENUM_TIMEFRAMES tf, datetime barTime, int minNeeded = 0)
  {
   ENUM_TIMEFRAMES resolvedTf = ResolveTimeframe(tf);
   int shift = iBarShift(_Symbol, resolvedTf, barTime, false);
   if(shift < 0 || shift + minNeeded >= Bars(_Symbol, resolvedTf)) return -1;
   return shift;
  }

bool CopyIndicatorValues(int handle, int bufferNum, ENUM_TIMEFRAMES tf, datetime barTime, int count, double &values[])
  {
   if(count <= 0) return false;
   int shift = GetBarShift(tf, barTime, count - 1);
   if(shift < 0) return false;
   ArrayResize(values, count);
   ArraySetAsSeries(values, true);
   return (CopyBuffer(handle, bufferNum, shift, count, values) == count);
  }

int GetBuyArrowCode() { return (ArrowStyle == ARROW_CUSTOM) ? CustomBuyCode : 233; }
int GetSellArrowCode() { return (ArrowStyle == ARROW_CUSTOM) ? CustomSellCode : 234; }

void InitIndicatorConfig(int index, ENUM_MY_INDICATOR type, ENUM_TIMEFRAMES tf, bool enabled)
  {
   g_ind[index].type = type; g_ind[index].timeframe = tf; g_ind[index].enabled = enabled;
   g_ind[index].handle = INVALID_HANDLE; g_ind[index].signal = SIGNAL_NONE; g_ind[index].name = "";
  }

//+------------------------------------------------------------------+
//| Create indicator handle (Streamlined)                              |
//+------------------------------------------------------------------+
int CreateIndicatorHandle(ENUM_MY_INDICATOR type, ENUM_TIMEFRAMES tf)
  {
   switch(type)
     {
      case MY_IND_MA:         return iMA(_Symbol, tf, MA_Period, 0, MA_Method, MA_Price);
      case MY_IND_MACD:       return iMACD(_Symbol, tf, MACD_Fast, MACD_Slow, MACD_Signal, MACD_Price);
      case MY_IND_RSI:        return iRSI(_Symbol, tf, RSI_Period, RSI_Price);
      case MY_IND_BANDS:      return iBands(_Symbol, tf, BB_Period, 0, BB_Deviation, BB_Price);
      case MY_IND_VOLUME:     return iVolumes(_Symbol, tf, VOL_VolumeType);
      default:                return INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Get indicator display name (Streamlined)                           |
//+------------------------------------------------------------------+
string GetIndicatorName(ENUM_MY_INDICATOR type, ENUM_TIMEFRAMES tf)
  {
   string tfName = (tf == PERIOD_CURRENT) ? "" : StringSubstr(EnumToString(tf), 7) + " ";
   switch(type)
     {
      case MY_IND_MA:         return StringFormat("MA%s(%d)", tfName, MA_Period);
      case MY_IND_MACD:       return StringFormat("MACD%s(%d,%d,%d)", tfName, MACD_Fast, MACD_Slow, MACD_Signal);
      case MY_IND_RSI:        return StringFormat("RSI%s(%d)", tfName, RSI_Period);
      case MY_IND_BANDS:      return StringFormat("BB%s(%d,%.1f)", tfName, BB_Period, BB_Deviation);
      case MY_IND_VOLUME:     return StringFormat("Vol%s(SMA%d,%.1fx)", tfName, VOL_Period, VOL_Multiplier);
      default:                return "None";
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_chartID = ChartID(); g_digits = _Digits; g_point = _Point;
   g_pipValue = (g_digits == 3 || g_digits == 5) ? g_point * 10.0 : g_point;
   
   if(MACD_Fast >= MACD_Slow) return INIT_PARAMETERS_INCORRECT;
   if(Ind1_Type == MY_IND_NONE || !Ind1_Enabled) return INIT_PARAMETERS_INCORRECT;
   
   InitIndicatorConfig(0, Ind1_Type, Ind1_TimeFrame, Ind1_Enabled);
   InitIndicatorConfig(1, Ind2_Type, Ind2_TimeFrame, Ind2_Enabled);
   InitIndicatorConfig(2, Ind3_Type, Ind3_TimeFrame, Ind3_Enabled);
   InitIndicatorConfig(3, Ind4_Type, Ind4_TimeFrame, Ind4_Enabled);
   InitIndicatorConfig(4, Ind5_Type, Ind5_TimeFrame, Ind5_Enabled);
   
   g_atrHandle = iATR(_Symbol, _Period, ATRPeriod);
   if(UseTrendFilter) g_trendMAHandle = iMA(_Symbol, TrendTimeFrame, TrendMAPeriod, 0, TrendMAMethod, PRICE_CLOSE);
   
   for(int i = 0; i < 5; i++)
     {
      if(g_ind[i].type != MY_IND_NONE && g_ind[i].enabled)
        {
         g_ind[i].handle = CreateIndicatorHandle(g_ind[i].type, g_ind[i].timeframe);
         g_ind[i].name = GetIndicatorName(g_ind[i].type, g_ind[i].timeframe);
         if(g_ind[i].handle == INVALID_HANDLE) return INIT_FAILED;
        }
     }
   
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BuySignalLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SellSignalLineBuffer, INDICATOR_DATA);
   
   ArraySetAsSeries(BuyBuffer, true); ArraySetAsSeries(SellBuffer, true);
   ArraySetAsSeries(BuySignalLineBuffer, true); ArraySetAsSeries(SellSignalLineBuffer, true);
   
   PlotIndexSetInteger(0, PLOT_ARROW, GetBuyArrowCode()); PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(1, PLOT_ARROW, GetSellArrowCode()); PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(2, PLOT_SHOW_DATA, false); PlotIndexSetInteger(3, PLOT_SHOW_DATA, false);
   
   if(ShowDashboard) { CreateDashboard(); EventSetTimer(1); }
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Dashboard & GUI Functions                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   int x = 10, y = 80, lineHeight = 18, boxHeight = 60;
   ObjectCreate(g_chartID, g_objPrefix + "Box", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_XDISTANCE, 5);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_YDISTANCE, y - 20);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_XSIZE, 220);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_BGCOLOR, C'20,20,30');
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_BORDER_COLOR, C'60,60,80');
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_BACK, false);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_HIDDEN, true);
   
   CreateLabel(g_objPrefix + "Title", "EMA+BB+RSI+MACD+Vol", x + 5, y - 15, clrWhite, "Arial Bold", 8); y += lineHeight;
   if(ShowSpread) { CreateLabel(g_objPrefix + "Spread", "Spread: ---", x, y, clrGold, "Arial Bold", 9); y += lineHeight; boxHeight += lineHeight; }
   if(ShowATR) { CreateLabel(g_objPrefix + "ATR", "ATR: ---", x, y, clrCyan, "Arial Bold", 9); y += lineHeight; boxHeight += lineHeight; }
   
   for(int i = 0; i < 5; i++)
     {
      if(g_ind[i].type != MY_IND_NONE)
        {
         CreateLabel(StringFormat("%sInd%d", g_objPrefix, i), StringFormat("%d: %s", i + 1, g_ind[i].name), x, y, clrSilver, "Arial", 8);
         y += lineHeight - 2; boxHeight += lineHeight - 2;
        }
     }
   if(UseTrendFilter) { CreateLabel(g_objPrefix + "Trend", "Trend(EMA200): ---", x, y, clrOrange, "Arial Bold", 9); y += lineHeight; boxHeight += lineHeight; }
   CreateLabel(g_objPrefix + "Signal", "Signal: ---", x, y, clrSilver, "Arial Bold", 10); y += lineHeight; boxHeight += lineHeight;
   ObjectSetInteger(g_chartID, g_objPrefix + "Box", OBJPROP_YSIZE, boxHeight + 5);
  }

void CreateLabel(string name, string text, int x, int y, color clr, string font, int size)
  {
   ObjectCreate(g_chartID, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(g_chartID, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(g_chartID, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(g_chartID, name, OBJPROP_TEXT, text); ObjectSetString(g_chartID, name, OBJPROP_FONT, font);
   ObjectSetInteger(g_chartID, name, OBJPROP_FONTSIZE, size); ObjectSetInteger(g_chartID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(g_chartID, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(g_chartID, name, OBJPROP_SELECTABLE, false); ObjectSetInteger(g_chartID, name, OBJPROP_HIDDEN, true);
  }

void UpdateLabel(string name, string text, color clr = clrNONE)
  {
   if(ObjectFind(g_chartID, name) == -1) return;
   ObjectSetString(g_chartID, name, OBJPROP_TEXT, text);
   if(clr != clrNONE) ObjectSetInteger(g_chartID, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Core Signal Logic (Streamlined)                                    |
//+------------------------------------------------------------------+
ENUM_SIGNAL CalculateIndicatorSignal(int indIdx, datetime barTime)
  {
   if(g_ind[indIdx].handle == INVALID_HANDLE) return SIGNAL_NONE;
   double val1[], val2[];
   ENUM_TIMEFRAMES tf = g_ind[indIdx].timeframe;
   
   if(!CopyIndicatorValues(g_ind[indIdx].handle, 0, tf, barTime, 3, val1)) return SIGNAL_NONE;

   switch(g_ind[indIdx].type)
     {
      case MY_IND_MACD:
         if(!CopyIndicatorValues(g_ind[indIdx].handle, 1, tf, barTime, 3, val2)) return SIGNAL_NONE;
         if(val1[2] <= val2[2] && val1[1] > val2[1]) return SIGNAL_BUY;
         if(val1[2] >= val2[2] && val1[1] < val2[1]) return SIGNAL_SELL;
         break;
         
      case MY_IND_BANDS:
         if(!CopyIndicatorValues(g_ind[indIdx].handle, 2, tf, barTime, 3, val2)) return SIGNAL_NONE; // Lower band
         {
            double closeP[]; ArraySetAsSeries(closeP, true);
            if(CopyClose(_Symbol, ResolveTimeframe(tf), iBarShift(_Symbol, ResolveTimeframe(tf), barTime), 3, closeP) != 3) return SIGNAL_NONE;
            if(closeP[2] > val2[2] && closeP[1] <= val2[1]) return SIGNAL_BUY;  // Touched lower band
            if(!CopyIndicatorValues(g_ind[indIdx].handle, 1, tf, barTime, 3, val2)) return SIGNAL_NONE; // Upper band
            if(closeP[2] < val2[2] && closeP[1] >= val2[1]) return SIGNAL_SELL; // Touched upper band
         }
         break;
         
      case MY_IND_RSI:
         if(val1[2] <= RSI_OversoldLevel && val1[1] > RSI_OversoldLevel) return SIGNAL_BUY;
         if(val1[2] >= RSI_OverboughtLevel && val1[1] < RSI_OverboughtLevel) return SIGNAL_SELL;
         break;
         
      case MY_IND_VOLUME:
         {
            double smaVol = 0; 
            int period = MathMin(VOL_Period, 50);
            double volArr[];
            if(CopyIndicatorValues(g_ind[indIdx].handle, 0, tf, barTime, period + 2, volArr) != period + 2) return SIGNAL_NONE;
            for(int i=2; i<period+2; i++) smaVol += volArr[i];
            smaVol /= period;
            
            double closeP[], openP[]; ArraySetAsSeries(closeP, true); ArraySetAsSeries(openP, true);
            int shift = iBarShift(_Symbol, ResolveTimeframe(tf), barTime);
            if(CopyClose(_Symbol, ResolveTimeframe(tf), shift, 3, closeP) != 3) return SIGNAL_NONE;
            if(CopyOpen(_Symbol, ResolveTimeframe(tf), shift, 3, openP) != 3) return SIGNAL_NONE;
            
            if(val1[1] > smaVol * VOL_Multiplier) // High volume spike
              {
               if(closeP[1] > openP[1]) return SIGNAL_BUY;
               if(closeP[1] < openP[1]) return SIGNAL_SELL;
              }
         }
         break;
         
      case MY_IND_MA:
         {
            double closeP[]; ArraySetAsSeries(closeP, true);
            if(CopyClose(_Symbol, ResolveTimeframe(tf), iBarShift(_Symbol, ResolveTimeframe(tf), barTime), 3, closeP) != 3) return SIGNAL_NONE;
            if(closeP[2] < val1[2] && closeP[1] > val1[1]) return SIGNAL_BUY;
            if(closeP[2] > val1[2] && closeP[1] < val1[1]) return SIGNAL_SELL;
         }
         break;
     }
   return SIGNAL_NONE;
  }

ENUM_SIGNAL CalculateIndicatorBias(int indIdx, datetime barTime)
  {
   if(g_ind[indIdx].handle == INVALID_HANDLE) return SIGNAL_NONE;
   double val1[], val2[];
   if(!CopyIndicatorValues(g_ind[indIdx].handle, 0, g_ind[indIdx].timeframe, barTime, 2, val1)) return SIGNAL_NONE;
   
   switch(g_ind[indIdx].type)
     {
      case MY_IND_MACD:
         if(!CopyIndicatorValues(g_ind[indIdx].handle, 1, g_ind[indIdx].timeframe, barTime, 2, val2)) return SIGNAL_NONE;
         if(val1[1] > val2[1]) return SIGNAL_BUY; if(val1[1] < val2[1]) return SIGNAL_SELL;
         break;
      case MY_IND_BANDS:
         { 
            double closeP[]; ArraySetAsSeries(closeP, true);
            if(CopyClose(_Symbol, ResolveTimeframe(g_ind[indIdx].timeframe), iBarShift(_Symbol, ResolveTimeframe(g_ind[indIdx].timeframe), barTime), 2, closeP) != 2) return SIGNAL_NONE;
            if(closeP[1] > val1[1]) return SIGNAL_BUY; if(closeP[1] < val1[1]) return SIGNAL_SELL;
         }
         break;
      case MY_IND_RSI:
         if(val1[1] > 50) return SIGNAL_BUY; if(val1[1] < 50) return SIGNAL_SELL;
         break;
      case MY_IND_VOLUME:
         return CalculateIndicatorSignal(indIdx, barTime); // Volume bias is directional based on candle
      case MY_IND_MA:
         { 
            double closeP[]; ArraySetAsSeries(closeP, true);
            if(CopyClose(_Symbol, ResolveTimeframe(g_ind[indIdx].timeframe), iBarShift(_Symbol, ResolveTimeframe(g_ind[indIdx].timeframe), barTime), 2, closeP) != 2) return SIGNAL_NONE;
            if(closeP[1] > val1[1]) return SIGNAL_BUY; if(closeP[1] < val1[1]) return SIGNAL_SELL;
         }
         break;
     }
   return SIGNAL_NONE;
  }

ENUM_SIGNAL GetTrendDirection(datetime barTime)
  {
   if(!UseTrendFilter || g_trendMAHandle == INVALID_HANDLE) return SIGNAL_NONE;
   if(barTime == g_cachedTrendBarTime) return g_cachedTrendDirection;
   
   double maVal[];
   if(CopyIndicatorValues(g_trendMAHandle, 0, TrendTimeFrame, barTime, 2, maVal) != 2) return SIGNAL_NONE;
   
   double closeP[]; ArraySetAsSeries(closeP, true);
   if(CopyClose(_Symbol, ResolveTimeframe(TrendTimeFrame), iBarShift(_Symbol, ResolveTimeframe(TrendTimeFrame), barTime), 2, closeP) != 2) return SIGNAL_NONE;
   
   g_cachedTrendBarTime = barTime;
   if(closeP[1] > maVal[1]) g_cachedTrendDirection = SIGNAL_BUY;
   else if(closeP[1] < maVal[1]) g_cachedTrendDirection = SIGNAL_SELL;
   else g_cachedTrendDirection = SIGNAL_NONE;
   
   return g_cachedTrendDirection;
  }

double GetATR(int shift)
  {
   double atrVal[];
   if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, shift, 1, atrVal) == 1) return atrVal[0];
   return 0.0;
  }

bool PassesScalpingFilters(datetime barTime, int dataBar, bool isCurrentBar, string &reason)
  {
   reason = "";
   MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) return false;
   
   if(FilterSpread && PriceToPips(tick.ask - tick.bid) > MaxSpreadPips) { reason = "High Spread"; return false; }
   if(FilterVolatility && PriceToPips(GetATR(dataBar + 1)) < MinATRPips) { reason = "Low Volatility"; return false; }
   return true;
  }

void DrawRiskReward(datetime time, double price, ENUM_SIGNAL dir, double atr)
  {
   if(!ShowRiskReward || atr == 0) return;
   string prefix = g_objPrefix + "RR_" + TimeToString(time);
   double sl = (dir == SIGNAL_BUY) ? price - (atr * StopLossATRMultiplier) : price + (atr * StopLossATRMultiplier);
   double tp = (dir == SIGNAL_BUY) ? price + (atr * TakeProfitMultiplier) : price - (atr * TakeProfitMultiplier);
   
   ObjectCreate(g_chartID, prefix + "_SL", OBJ_HLINE, 0, time, sl);
   ObjectSetInteger(g_chartID, prefix + "_SL", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(g_chartID, prefix + "_SL", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(g_chartID, prefix + "_SL", OBJPROP_HIDDEN, true);
   
   ObjectCreate(g_chartID, prefix + "_TP", OBJ_HLINE, 0, time, tp);
   ObjectSetInteger(g_chartID, prefix + "_TP", OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(g_chartID, prefix + "_TP", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(g_chartID, prefix + "_TP", OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(rates_total < 100) return 0;
   ArraySetAsSeries(time, true); ArraySetAsSeries(open, true); ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);

   MqlTick tick; bool hasTick = SymbolInfoTick(_Symbol, tick);
   if(hasTick && ShowSpread) UpdateLabel(g_objPrefix + "Spread", StringFormat("Spread: %.1f", PriceToPips(tick.ask - tick.bid)));
   if(ShowATR) UpdateLabel(g_objPrefix + "ATR", StringFormat("ATR(%d): %.1f pips", ATRPeriod, PriceToPips(GetATR(1))));

   int limit = (prev_calculated == 0) ? MathMin(rates_total - 5, 2000) : MathMax(prev_calculated - 2, 1);
   
   ENUM_SIGNAL currentSignal = SIGNAL_NONE;
   int currentStrength = 0;
   bool filtersPassed = true; string filterReason = "";
   
   for(int i = limit; i >= 1 && !IsStopped(); i--)
     {
      BuyBuffer[i] = EMPTY_VALUE; SellBuffer[i] = EMPTY_VALUE;
      BuySignalLineBuffer[i] = EMPTY_VALUE; SellSignalLineBuffer[i] = EMPTY_VALUE;
      
      int enabledCount = 0, buyTriggerCount = 0, sellTriggerCount = 0, buyBiasCount = 0, sellBiasCount = 0;
      ENUM_SIGNAL triggers[5]; ENUM_SIGNAL biases[5];
      
      for(int indIdx = 0; indIdx < 5; indIdx++)
        {
         triggers[indIdx] = SIGNAL_NONE; biases[indIdx] = SIGNAL_NONE; g_ind[indIdx].signal = SIGNAL_NONE;
         if(g_ind[indIdx].type == MY_IND_NONE || !g_ind[indIdx].enabled) continue;
         enabledCount++;
         
         triggers[indIdx] = CalculateIndicatorSignal(indIdx, time[i]);
         biases[indIdx] = CalculateIndicatorBias(indIdx, time[i]);
         if(biases[indIdx] == SIGNAL_NONE && triggers[indIdx] != SIGNAL_NONE) biases[indIdx] = triggers[indIdx];
         g_ind[indIdx].signal = biases[indIdx];
         
         if(triggers[indIdx] == SIGNAL_BUY) buyTriggerCount++; else if(triggers[indIdx] == SIGNAL_SELL) sellTriggerCount++;
         if(biases[indIdx] == SIGNAL_BUY) buyBiasCount++; else if(biases[indIdx] == SIGNAL_SELL) sellBiasCount++;
        }
       
       if(enabledCount == 0) continue;
       ENUM_SIGNAL finalSignal = SIGNAL_NONE; int signalStrength = 0;
       
       switch(SignalMode)
         {
          case MODE_REQUIRE_PRIMARY:
             if(triggers[0] == SIGNAL_BUY && sellBiasCount == 0 && buyBiasCount >= enabledCount / 2.0) finalSignal = SIGNAL_BUY;
             else if(triggers[0] == SIGNAL_SELL && buyBiasCount == 0 && sellBiasCount >= enabledCount / 2.0) finalSignal = SIGNAL_SELL;
             break;
          case MODE_REQUIRE_ALL:
             if(triggers[0] == SIGNAL_BUY && buyBiasCount == enabledCount) finalSignal = SIGNAL_BUY;
             else if(triggers[0] == SIGNAL_SELL && sellBiasCount == enabledCount) finalSignal = SIGNAL_SELL;
             break;
          case MODE_MAJORITY_VOTE:
             if(buyTriggerCount > sellTriggerCount && buyBiasCount >= MathMax(1, enabledCount / 2)) finalSignal = SIGNAL_BUY;
             else if(sellTriggerCount > buyTriggerCount && sellBiasCount >= MathMax(1, enabledCount / 2)) finalSignal = SIGNAL_SELL;
             break;
         }
       
       if(finalSignal != SIGNAL_NONE)
         {
          int agreeingCount = (finalSignal == SIGNAL_BUY) ? buyBiasCount : sellBiasCount;
          if(agreeingCount < MinAgreeingIndicators) finalSignal = SIGNAL_NONE;
         }
       
       if(UseTrendFilter && finalSignal != SIGNAL_NONE)
         {
          ENUM_SIGNAL trendDir = GetTrendDirection(time[i]);
          if(finalSignal != trendDir) finalSignal = SIGNAL_NONE;
         }
       
       if(finalSignal != SIGNAL_NONE)
         {
          string fReason = "";
          if(!PassesScalpingFilters(time[i], i, (i == 1), fReason))
            {
             finalSignal = SIGNAL_NONE;
             if(i == 1) { filtersPassed = false; filterReason = fReason; }
            }
         }
       
       if(i == 1) { g_barsSinceBuy++; g_barsSinceSell++; }
       if(finalSignal != SIGNAL_NONE && MinBarsBetween > 0)
         {
          if(finalSignal == SIGNAL_BUY && g_barsSinceBuy <= MinBarsBetween) finalSignal = SIGNAL_NONE;
          if(finalSignal == SIGNAL_SELL && g_barsSinceSell <= MinBarsBetween) finalSignal = SIGNAL_NONE;
         }
       if(!AllowReEntry && finalSignal != SIGNAL_NONE && finalSignal == g_lastSignal) finalSignal = SIGNAL_NONE;
       
       if(finalSignal != SIGNAL_NONE)
         {
          int agreeingCount = (finalSignal == SIGNAL_BUY) ? buyBiasCount : sellBiasCount;
          signalStrength = (enabledCount > 0) ? (int)MathRound((double)agreeingCount * 100.0 / (double)enabledCount) : 0;
         }
         
      double atr = GetATR(i + 1); double offset = atr * ArrowOffsetATR;
      
      if(finalSignal == SIGNAL_BUY)
        {
         BuyBuffer[i] = low[i] - offset;
         if(i == 1) { g_barsSinceBuy = 0; DrawRiskReward(time[1], low[1], SIGNAL_BUY, atr); }
        }
      else if(finalSignal == SIGNAL_SELL)
        {
         SellBuffer[i] = high[i] + offset;
         if(i == 1) { g_barsSinceSell = 0; DrawRiskReward(time[1], high[1], SIGNAL_SELL, atr); }
        }
       
       if(i == 1)
         {
          g_lastSignal = finalSignal; currentSignal = finalSignal; currentStrength = signalStrength;
         }
     }
   
   if(ShowDashboard)
     {
      for(int indIdx = 0; indIdx < 5; indIdx++)
        {
         if(g_ind[indIdx].type == MY_IND_NONE) continue;
         string labelName = StringFormat("%sInd%d", g_objPrefix, indIdx);
         if(!g_ind[indIdx].enabled) { UpdateLabel(labelName, StringFormat("%d: Disabled", indIdx + 1), clrGray); continue; }
         string sigText = "— NONE"; color sigColor = clrGray;
         if(g_ind[indIdx].signal == SIGNAL_BUY) { sigText = "▲ BUY"; sigColor = clrLimeGreen; }
         else if(g_ind[indIdx].signal == SIGNAL_SELL) { sigText = "▼ SELL"; sigColor = clrMagenta; }
         UpdateLabel(labelName, StringFormat("%d: %s [%s]", indIdx + 1, g_ind[indIdx].name, sigText), sigColor);
        }
      
      if(UseTrendFilter)
        {
         string trendText = "Trend: NEUTRAL"; color trendColor = clrOrange;
         ENUM_SIGNAL td = GetTrendDirection(time[0]);
         if(td == SIGNAL_BUY) { trendText = "Trend: UP ▲ (EMA200)"; trendColor = clrLimeGreen; }
         else if(td == SIGNAL_SELL) { trendText = "Trend: DOWN ▼ (EMA200)"; trendColor = clrFireBrick; }
         UpdateLabel(g_objPrefix + "Trend", trendText, trendColor);
        }
      
      string sigText = "Signal: ---"; color sigColor = clrSilver;
      if(!filtersPassed) { sigText = StringFormat("Signal: FILTERED (%s)", filterReason); sigColor = clrGray; }
      else if(currentSignal == SIGNAL_BUY) { sigText = StringFormat("Signal: BUY ▲ (%d%%)", currentStrength); sigColor = clrLimeGreen; }
      else if(currentSignal == SIGNAL_SELL) { sigText = StringFormat("Signal: SELL ▼ (%d%%)", currentStrength); sigColor = clrFireBrick; }
      UpdateLabel(g_objPrefix + "Signal", sigText, sigColor);
     }
   
   return rates_total;
  }

//+------------------------------------------------------------------+
//| Timer & Deinit Functions                                           |
//+------------------------------------------------------------------+
void OnTimer() { /* Dashboard handled in OnCalculate to prevent flicker */ }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectDelete(g_chartID, g_objPrefix + "Box");
   ObjectDelete(g_chartID, g_objPrefix + "Title");
   ObjectDelete(g_chartID, g_objPrefix + "Spread");
   ObjectDelete(g_chartID, g_objPrefix + "ATR");
   ObjectDelete(g_chartID, g_objPrefix + "Trend");
   ObjectDelete(g_chartID, g_objPrefix + "Signal");
   for(int i=0; i<5; i++) ObjectDelete(g_chartID, StringFormat("%sInd%d", g_objPrefix, i));
   
   int obj_total = ObjectsTotal(g_chartID);
   for(int i = obj_total - 1; i >= 0; i--)
     {
      string name = ObjectName(g_chartID, i);
      if(StringFind(name, g_objPrefix + "RR_") >= 0) ObjectDelete(g_chartID, name);
     }
   ChartRedraw(g_chartID);
  }
//+------------------------------------------------------------------+