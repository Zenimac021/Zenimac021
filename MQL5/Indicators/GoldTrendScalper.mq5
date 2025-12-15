//+------------------------------------------------------------------+
//|                                            GoldTrendScalper.mq5 |
//|                                    Copyright 2024, Zenimac021   |
//|                         https://github.com/Zenimac021/Zenimac021 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Zenimac021"
#property link      "https://github.com/Zenimac021/Zenimac021"
#property version   "1.00"
#property description "Professional Gold (XAUUSD) Trend Scalping Signal Indicator"
#property description "Uses EMA Crossover + MACD + ADX for trend confirmation"
#property description "Includes session filters, spread filter, and SL/TP levels"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

//--- Plot Buy Signals
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot Sell Signals
#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- Enumerations
enum ENUM_SLTP_MODE
{
   MODE_FIXED = 0,    // Fixed Points
   MODE_ATR   = 1     // ATR-Based
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Moving Average Settings
input group "=== Moving Average Settings ==="
input int                FastEMA_Period    = 8;           // Fast EMA Period
input int                SlowEMA_Period    = 21;          // Slow EMA Period
input ENUM_APPLIED_PRICE MA_Price          = PRICE_CLOSE; // Applied Price

//--- MACD Settings
input group "=== MACD Settings ==="
input int                MACD_Fast         = 12;          // MACD Fast EMA
input int                MACD_Slow         = 26;          // MACD Slow EMA
input int                MACD_Signal       = 9;           // MACD Signal Period

//--- ADX Settings
input group "=== ADX Settings ==="
input int                ADX_Period        = 14;          // ADX Period
input int                ADX_MinLevel      = 20;          // Minimum ADX for Signal

//--- Alert Settings
input group "=== Alert Settings ==="
input bool               EnableSoundAlert  = true;        // Enable Sound Alerts
input bool               EnablePushAlert   = true;        // Enable Push Notifications
input bool               EnableEmailAlert  = false;       // Enable Email Alerts
input string             AlertSound        = "alert.wav"; // Alert Sound File

//--- Session Filter Settings
input group "=== Session Filter ==="
input bool               EnableSessionFilter = true;      // Enable Session Filter
input bool               TradeAsianSession   = false;     // Trade Asian Session (00:00-08:00)
input bool               TradeLondonSession  = true;      // Trade London Session (08:00-16:00)
input bool               TradeNewYorkSession = true;      // Trade New York Session (13:00-21:00)

//--- Spread Filter Settings
input group "=== Spread Filter ==="
input bool               EnableSpreadFilter = true;       // Enable Spread Filter
input int                MaxSpreadPoints    = 30;         // Maximum Spread in Points

//--- Risk Management Settings
input group "=== Risk Management ==="
input bool               ShowSLTP          = true;        // Show SL/TP Levels
input ENUM_SLTP_MODE     SL_TP_Mode        = MODE_ATR;    // SL/TP Calculation Mode
input int                FixedSL_Points    = 100;         // Fixed SL in Points
input int                FixedTP_Points    = 150;         // Fixed TP in Points
input int                ATR_Period        = 14;          // ATR Period
input double             ATR_SL_Multi      = 1.5;         // ATR Multiplier for SL
input double             ATR_TP_Multi      = 2.0;         // ATR Multiplier for TP

//--- Visual Settings
input group "=== Visual Settings ==="
input color              BuyArrowColor     = clrLime;     // Buy Arrow Color
input color              SellArrowColor    = clrRed;      // Sell Arrow Color
input int                ArrowSize         = 3;           // Arrow Size (1-5)
input bool               ShowInfoPanel     = true;        // Show Information Panel
input color              PanelBgColor      = clrBlack;    // Panel Background Color
input color              PanelTextColor    = clrWhite;    // Panel Text Color
input int                PanelXOffset      = 20;          // Panel X Position
input int                PanelYOffset      = 30;          // Panel Y Position

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
double BuySignalBuffer[];
double SellSignalBuffer[];
double FastEMA_Buffer[];
double SlowEMA_Buffer[];

int FastEMA_Handle;
int SlowEMA_Handle;
int MACD_Handle;
int ADX_Handle;
int ATR_Handle;

datetime LastAlertTime = 0;
int LastAlertBar = -1;
string IndicatorName = "GoldTrendScalper";
string PanelPrefix = "GTS_Panel_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate input parameters
   if(FastEMA_Period >= SlowEMA_Period)
   {
      Alert("Error: Fast EMA period must be less than Slow EMA period!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(FastEMA_Period < 1 || SlowEMA_Period < 1 || ADX_Period < 1)
   {
      Alert("Error: Period values must be greater than 0!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Set up indicator buffers
   SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, FastEMA_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, SlowEMA_Buffer, INDICATOR_CALCULATIONS);
   
   //--- Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Up arrow for buy
   PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Down arrow for sell
   
   //--- Set arrow colors
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, BuyArrowColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, SellArrowColor);
   
   //--- Set arrow sizes
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, ArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, ArrowSize);
   
   //--- Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create indicator handles
   FastEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, FastEMA_Period, 0, MODE_EMA, MA_Price);
   SlowEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA_Period, 0, MODE_EMA, MA_Price);
   MACD_Handle = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, MA_Price);
   ADX_Handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   //--- Check handles
   if(FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE ||
      MACD_Handle == INVALID_HANDLE || ADX_Handle == INVALID_HANDLE ||
      ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles!");
      return(INIT_FAILED);
   }
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName + " (" + 
                      IntegerToString(FastEMA_Period) + "/" + 
                      IntegerToString(SlowEMA_Period) + ")");
   
   //--- Create info panel
   if(ShowInfoPanel)
      CreateInfoPanel();
   
   Print(IndicatorName + " initialized successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(FastEMA_Handle != INVALID_HANDLE) IndicatorRelease(FastEMA_Handle);
   if(SlowEMA_Handle != INVALID_HANDLE) IndicatorRelease(SlowEMA_Handle);
   if(MACD_Handle != INVALID_HANDLE) IndicatorRelease(MACD_Handle);
   if(ADX_Handle != INVALID_HANDLE) IndicatorRelease(ADX_Handle);
   if(ATR_Handle != INVALID_HANDLE) IndicatorRelease(ATR_Handle);
   
   //--- Delete chart objects
   DeleteInfoPanel();
   DeleteSLTPLines();
   
   Print(IndicatorName + " removed from chart.");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check for minimum bars
   int minBars = MathMax(SlowEMA_Period, MathMax(MACD_Slow + MACD_Signal, ADX_Period)) + 10;
   if(rates_total < minBars)
      return(0);
   
   //--- Copy indicator data
   double fastEMA[], slowEMA[];
   double macdMain[], macdSignal[], macdHist[];
   double adxValue[], plusDI[], minusDI[];
   double atrValue[];
   
   //--- Calculate starting position
   int start;
   if(prev_calculated == 0)
   {
      start = minBars;
      ArrayInitialize(BuySignalBuffer, EMPTY_VALUE);
      ArrayInitialize(SellSignalBuffer, EMPTY_VALUE);
   }
   else
   {
      start = prev_calculated - 1;
   }
   
   //--- Copy EMA data
   if(CopyBuffer(FastEMA_Handle, 0, 0, rates_total, fastEMA) <= 0) return(0);
   if(CopyBuffer(SlowEMA_Handle, 0, 0, rates_total, slowEMA) <= 0) return(0);
   
   //--- Copy MACD data
   if(CopyBuffer(MACD_Handle, 0, 0, rates_total, macdMain) <= 0) return(0);
   if(CopyBuffer(MACD_Handle, 1, 0, rates_total, macdSignal) <= 0) return(0);
   
   //--- Copy ADX data
   if(CopyBuffer(ADX_Handle, 0, 0, rates_total, adxValue) <= 0) return(0);
   if(CopyBuffer(ADX_Handle, 1, 0, rates_total, plusDI) <= 0) return(0);
   if(CopyBuffer(ADX_Handle, 2, 0, rates_total, minusDI) <= 0) return(0);
   
   //--- Copy ATR data
   if(CopyBuffer(ATR_Handle, 0, 0, rates_total, atrValue) <= 0) return(0);
   
   //--- Store EMA values for external access
   ArrayCopy(FastEMA_Buffer, fastEMA);
   ArrayCopy(SlowEMA_Buffer, slowEMA);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;
      
      //--- Skip if not enough data
      if(i < 2) continue;
      
      //--- Calculate MACD histogram
      double macdHistCurrent = macdMain[i] - macdSignal[i];
      double macdHistPrev = macdMain[i-1] - macdSignal[i-1];
      
      //--- Check for EMA crossover
      bool emaCrossUp = (fastEMA[i] > slowEMA[i]) && (fastEMA[i-1] <= slowEMA[i-1]);
      bool emaCrossDown = (fastEMA[i] < slowEMA[i]) && (fastEMA[i-1] >= slowEMA[i-1]);
      
      //--- Check MACD conditions
      bool macdBullish = (macdHistCurrent > 0) && (macdMain[i] > macdSignal[i]);
      bool macdBearish = (macdHistCurrent < 0) && (macdMain[i] < macdSignal[i]);
      
      //--- Check ADX condition
      bool adxStrong = adxValue[i] >= ADX_MinLevel;
      
      //--- Check filters
      bool sessionOK = CheckSession(time[i]);
      bool spreadOK = CheckSpread();
      
      //--- Generate BUY signal
      if(emaCrossUp && macdBullish && adxStrong && sessionOK && spreadOK)
      {
         BuySignalBuffer[i] = low[i] - (atrValue[i] * 0.5);  // Place arrow below candle
         
         //--- Send alerts only for the latest bar
         if(i == rates_total - 1 && LastAlertBar != rates_total)
         {
            double slPrice, tpPrice;
            CalculateSLTP(close[i], true, atrValue[i], slPrice, tpPrice);
            SendSignalAlert("BUY", close[i], slPrice, tpPrice, adxValue[i]);
            
            if(ShowSLTP)
               DrawSLTPLines(slPrice, tpPrice, true);
            
            LastAlertBar = rates_total;
         }
      }
      
      //--- Generate SELL signal
      if(emaCrossDown && macdBearish && adxStrong && sessionOK && spreadOK)
      {
         SellSignalBuffer[i] = high[i] + (atrValue[i] * 0.5);  // Place arrow above candle
         
         //--- Send alerts only for the latest bar
         if(i == rates_total - 1 && LastAlertBar != rates_total)
         {
            double slPrice, tpPrice;
            CalculateSLTP(close[i], false, atrValue[i], slPrice, tpPrice);
            SendSignalAlert("SELL", close[i], slPrice, tpPrice, adxValue[i]);
            
            if(ShowSLTP)
               DrawSLTPLines(slPrice, tpPrice, false);
            
            LastAlertBar = rates_total;
         }
      }
   }
   
   //--- Update info panel
   if(ShowInfoPanel)
   {
      int lastIdx = rates_total - 1;
      string trend = (fastEMA[lastIdx] > slowEMA[lastIdx]) ? "BULLISH" : "BEARISH";
      string session = GetCurrentSession();
      int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      UpdateInfoPanel(trend, adxValue[lastIdx], session, currentSpread, atrValue[lastIdx]);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading session          |
//+------------------------------------------------------------------+
bool CheckSession(datetime barTime)
{
   if(!EnableSessionFilter)
      return true;
   
   MqlDateTime dt;
   TimeToStruct(barTime, dt);
   int hour = dt.hour;
   
   //--- Asian Session: 00:00 - 08:00 GMT
   if(TradeAsianSession && hour >= 0 && hour < 8)
      return true;
   
   //--- London Session: 08:00 - 16:00 GMT
   if(TradeLondonSession && hour >= 8 && hour < 16)
      return true;
   
   //--- New York Session: 13:00 - 21:00 GMT
   if(TradeNewYorkSession && hour >= 13 && hour < 21)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current spread is acceptable                             |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   if(!EnableSpreadFilter)
      return true;
   
   int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (currentSpread <= MaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Get current session name                                          |
//+------------------------------------------------------------------+
string GetCurrentSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   if(hour >= 13 && hour < 16)
      return "LONDON/NY";
   else if(hour >= 8 && hour < 16)
      return "LONDON";
   else if(hour >= 13 && hour < 21)
      return "NEW YORK";
   else if(hour >= 0 && hour < 8)
      return "ASIAN";
   else
      return "OFF-HOURS";
}

//+------------------------------------------------------------------+
//| Calculate SL and TP levels                                        |
//+------------------------------------------------------------------+
void CalculateSLTP(double entryPrice, bool isBuy, double atr, double &sl, double &tp)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(SL_TP_Mode == MODE_FIXED)
   {
      if(isBuy)
      {
         sl = entryPrice - (FixedSL_Points * point);
         tp = entryPrice + (FixedTP_Points * point);
      }
      else
      {
         sl = entryPrice + (FixedSL_Points * point);
         tp = entryPrice - (FixedTP_Points * point);
      }
   }
   else // MODE_ATR
   {
      if(isBuy)
      {
         sl = entryPrice - (atr * ATR_SL_Multi);
         tp = entryPrice + (atr * ATR_TP_Multi);
      }
      else
      {
         sl = entryPrice + (atr * ATR_SL_Multi);
         tp = entryPrice - (atr * ATR_TP_Multi);
      }
   }
}

//+------------------------------------------------------------------+
//| Send signal alerts                                                |
//+------------------------------------------------------------------+
void SendSignalAlert(string signalType, double price, double sl, double tp, double adx)
{
   //--- Prevent duplicate alerts
   datetime currentTime = TimeCurrent();
   if(currentTime - LastAlertTime < 60) // 60 second cooldown
      return;
   
   LastAlertTime = currentTime;
   
   //--- Format alert message
   string message = StringFormat("%s %s Signal @ %.2f\nSL: %.2f | TP: %.2f\nADX: %.1f | Session: %s",
                                 _Symbol, signalType, price, sl, tp, adx, GetCurrentSession());
   
   //--- Sound Alert
   if(EnableSoundAlert)
   {
      PlaySound(AlertSound);
   }
   
   //--- Popup Alert
   Alert(message);
   
   //--- Push Notification
   if(EnablePushAlert)
   {
      string pushMsg = StringFormat("%s %s @ %.2f | SL: %.2f | TP: %.2f",
                                    _Symbol, signalType, price, sl, tp);
      SendNotification(pushMsg);
   }
   
   //--- Email Alert
   if(EnableEmailAlert)
   {
      string subject = StringFormat("%s %s Signal - %s", _Symbol, signalType, IndicatorName);
      SendMail(subject, message);
   }
   
   Print(IndicatorName + ": " + message);
}

//+------------------------------------------------------------------+
//| Create information panel                                          |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   int x = PanelXOffset;
   int y = PanelYOffset;
   int width = 200;
   int height = 180;
   
   //--- Create background rectangle
   ObjectCreate(0, PanelPrefix + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_BGCOLOR, PanelBgColor);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_BACK, false);
   ObjectSetInteger(0, PanelPrefix + "BG", OBJPROP_SELECTABLE, false);
   
   //--- Create title label
   CreateLabel(PanelPrefix + "Title", x + 10, y + 5, "GOLD TREND SCALPER v1.0", clrGold, 10, true);
   
   //--- Create separator line
   CreateLabel(PanelPrefix + "Sep1", x + 10, y + 25, "------------------------", clrGray, 8, false);
   
   //--- Create info labels
   CreateLabel(PanelPrefix + "TrendLabel", x + 10, y + 40, "Trend:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "TrendValue", x + 80, y + 40, "---", PanelTextColor, 9, true);
   
   CreateLabel(PanelPrefix + "ADXLabel", x + 10, y + 58, "ADX:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "ADXValue", x + 80, y + 58, "---", PanelTextColor, 9, false);
   
   CreateLabel(PanelPrefix + "Sep2", x + 10, y + 75, "------------------------", clrGray, 8, false);
   
   CreateLabel(PanelPrefix + "SessionLabel", x + 10, y + 90, "Session:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "SessionValue", x + 80, y + 90, "---", PanelTextColor, 9, false);
   
   CreateLabel(PanelPrefix + "SpreadLabel", x + 10, y + 108, "Spread:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "SpreadValue", x + 80, y + 108, "---", PanelTextColor, 9, false);
   
   CreateLabel(PanelPrefix + "Sep3", x + 10, y + 125, "------------------------", clrGray, 8, false);
   
   CreateLabel(PanelPrefix + "ATRLabel", x + 10, y + 140, "ATR:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "ATRValue", x + 80, y + 140, "---", PanelTextColor, 9, false);
   
   CreateLabel(PanelPrefix + "StatusLabel", x + 10, y + 158, "Status:", PanelTextColor, 9, false);
   CreateLabel(PanelPrefix + "StatusValue", x + 80, y + 158, "READY", clrLime, 9, true);
}

//+------------------------------------------------------------------+
//| Create a text label                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Update information panel                                          |
//+------------------------------------------------------------------+
void UpdateInfoPanel(string trend, double adx, string session, int spread, double atr)
{
   //--- Update trend
   color trendColor = (trend == "BULLISH") ? clrLime : clrRed;
   string trendSymbol = (trend == "BULLISH") ? "▲ " : "▼ ";
   ObjectSetString(0, PanelPrefix + "TrendValue", OBJPROP_TEXT, trendSymbol + trend);
   ObjectSetInteger(0, PanelPrefix + "TrendValue", OBJPROP_COLOR, trendColor);
   
   //--- Update ADX
   string adxStrength = "";
   color adxColor = PanelTextColor;
   if(adx >= 40) { adxStrength = " (Very Strong)"; adxColor = clrGold; }
   else if(adx >= 25) { adxStrength = " (Strong)"; adxColor = clrLime; }
   else if(adx >= ADX_MinLevel) { adxStrength = " (Moderate)"; adxColor = clrYellow; }
   else { adxStrength = " (Weak)"; adxColor = clrGray; }
   
   ObjectSetString(0, PanelPrefix + "ADXValue", OBJPROP_TEXT, DoubleToString(adx, 1) + adxStrength);
   ObjectSetInteger(0, PanelPrefix + "ADXValue", OBJPROP_COLOR, adxColor);
   
   //--- Update session
   bool sessionActive = CheckSession(TimeCurrent());
   color sessionColor = sessionActive ? clrLime : clrGray;
   string sessionStatus = sessionActive ? " (Active)" : " (Inactive)";
   ObjectSetString(0, PanelPrefix + "SessionValue", OBJPROP_TEXT, session + sessionStatus);
   ObjectSetInteger(0, PanelPrefix + "SessionValue", OBJPROP_COLOR, sessionColor);
   
   //--- Update spread
   bool spreadOK = CheckSpread();
   color spreadColor = spreadOK ? clrLime : clrRed;
   string spreadStatus = spreadOK ? " (OK)" : " (HIGH)";
   ObjectSetString(0, PanelPrefix + "SpreadValue", OBJPROP_TEXT, IntegerToString(spread) + " pts" + spreadStatus);
   ObjectSetInteger(0, PanelPrefix + "SpreadValue", OBJPROP_COLOR, spreadColor);
   
   //--- Update ATR
   ObjectSetString(0, PanelPrefix + "ATRValue", OBJPROP_TEXT, DoubleToString(atr, _Digits));
   
   //--- Update status
   bool ready = sessionActive && spreadOK;
   ObjectSetString(0, PanelPrefix + "StatusValue", OBJPROP_TEXT, ready ? "READY" : "WAITING");
   ObjectSetInteger(0, PanelPrefix + "StatusValue", OBJPROP_COLOR, ready ? clrLime : clrYellow);
}

//+------------------------------------------------------------------+
//| Delete information panel                                          |
//+------------------------------------------------------------------+
void DeleteInfoPanel()
{
   ObjectsDeleteAll(0, PanelPrefix);
}

//+------------------------------------------------------------------+
//| Draw SL and TP lines on chart                                     |
//+------------------------------------------------------------------+
void DrawSLTPLines(double sl, double tp, bool isBuy)
{
   //--- Delete old lines
   DeleteSLTPLines();
   
   string slName = IndicatorName + "_SL";
   string tpName = IndicatorName + "_TP";
   
   //--- Create SL line
   ObjectCreate(0, slName, OBJ_HLINE, 0, 0, sl);
   ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, slName, OBJPROP_TEXT, "SL: " + DoubleToString(sl, _Digits));
   ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
   
   //--- Create TP line
   ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, tp);
   ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, tpName, OBJPROP_TEXT, "TP: " + DoubleToString(tp, _Digits));
   ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Delete SL/TP lines                                                |
//+------------------------------------------------------------------+
void DeleteSLTPLines()
{
   ObjectDelete(0, IndicatorName + "_SL");
   ObjectDelete(0, IndicatorName + "_TP");
}

//+------------------------------------------------------------------+
//| ChartEvent function - handle chart events                         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Handle chart resize event
   if(id == CHARTEVENT_CHART_CHANGE && ShowInfoPanel)
   {
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+
