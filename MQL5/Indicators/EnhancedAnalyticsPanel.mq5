//+------------------------------------------------------------------+
//|                                       EnhancedAnalyticsPanel.mq5 |
//|                   Professional AlgoTrade Pro Dashboard for MT5   |
//+------------------------------------------------------------------+
#property copyright "AlgoTrade Pro"
#property link      "https://algotradepro.com"
#property version   "3.00"
#property description "Professional multi-timeframe trading dashboard with enhanced signal generation"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- PROFESSIONAL UI COLORS
#define CLR_BG          C'15,23,42'
#define CLR_PANEL       C'30,41,59'
#define CLR_BORDER      C'51,65,85'
#define CLR_TEXT_MAIN   C'241,245,249'
#define CLR_TEXT_SUB    C'148,163,184'
#define CLR_TEXT_DIM    C'100,116,139'
#define CLR_ACCENT      C'99,102,241'
#define CLR_BUY         C'16,185,129'
#define CLR_SELL        C'244,63,94'
#define CLR_NEUTRAL     C'71,85,105'
#define CLR_WARNING     C'251,146,60'
#define CLR_DANGER      C'239,68,68'
#define CLR_FLASH       C'255,255,255'
#define CLR_BUY_DIM     C'64,160,110'
#define CLR_SELL_DIM    C'190,70,90'

//--- INPUTS
input group "=== Indicator Settings ==="
input int      Inp_RSI_Period    = 7;      // Scalping: Faster RSI
input int      Inp_EMA_Fast      = 5;      // Scalping: Faster EMA
input int      Inp_EMA_Slow      = 13;     // Scalping: Slower EMA
input int      Inp_ATR_Period    = 14;
input int      Inp_ADX_Period    = 14;
input double   Inp_Vol_Threshold = 0.0015;
input int      Inp_BB_Period     = 20;
input double   Inp_BB_Deviation  = 2.0;

input group "=== Signal Logic ==="
input bool     Inp_UseRSIFilter  = true;
input int      Inp_RSI_Overbought= 75;     // Scalping: Tighter extreme levels
input int      Inp_RSI_Oversold  = 25;     // Scalping: Tighter extreme levels
input bool     Inp_UseBBSignal   = true;
input bool     Inp_RequireAlignment = true;      // Scalping: Require higher TF confirmation
input int      Inp_MinAlignment  = 2;            // Scalping: Only need 2 TFs (e.g. M15, H1)
input bool     Inp_UseVolumeFilter = true;       // Use volume confirmation for signals
input bool     Inp_UseMACDFilter   = true;       // Use MACD histogram direction filter
input bool     Inp_UseSpreadATRFilter = true;    // Reject signals when spread > 30% of ATR
input double   Inp_SpreadATRRatio = 0.3;         // Max spread-to-ATR ratio

input group "=== Trade Setup ==="
input double   Inp_SL_Multiplier = 1.5;    // Scalping: Tighter SL
input double   Inp_TP1_Multiplier= 1.5;    // Scalping: 1:1 RR for TP1
input double   Inp_TP2_Multiplier= 3.0;    // Scalping: 1:2 RR for TP2
input double   Inp_TP2_Strong_Mult= 4.5;   // Scalping: 1:3 RR for Strong Signals
input double   Inp_RiskPercent   = 1.0;

input group "=== Alert Settings ==="
input bool     Inp_EnableAlerts  = true;
input bool     Inp_AlertOnCross  = true;
input bool     Inp_AlertOnBBTouch= false;
input bool     Inp_AlertOnSqueeze= false;   // Alert on BB squeeze detection
input bool     Inp_PushAlerts    = false;
input bool     Inp_EmailAlerts   = false;
input int      Inp_AlertCooldown = 60;

input group "=== Display Settings ==="
input bool     Inp_ShowArrows    = true;
input int      Inp_Panel_X       = 10;
input int      Inp_Panel_Y       = 30;
input bool     Inp_PanelDrag     = true;
input int      Inp_FontSize      = 0;
input bool     Inp_ShowRiskCalc  = true;
input bool     Inp_CompactMode   = false;
input int      Inp_TimezoneOffset= 0;

//--- ENUMS
enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_NONE = 0,
   SIGNAL_WEAK = 1,
   SIGNAL_NORMAL = 2,
   SIGNAL_STRONG = 3
};

enum ENUM_BB_POSITION
{
   BB_MIDDLE = 0,
   BB_UPPER_TOUCH = 1,
   BB_LOWER_TOUCH = -1,
   BB_OUTSIDE_UPPER = 2,
   BB_OUTSIDE_LOWER = -2
};

//--- HANDLES
int hRSI, hMACD, hEMAFast, hEMASlow, hATR, hBollinger, hADX;
int hHT_EMAFast, hHT_EMASlow;
int hVolume;
int hM15_EMAFast, hM15_EMASlow;
int hH1_EMAFast, hH1_EMASlow;
int hD1_EMAFast, hD1_EMASlow;

//--- BUFFERS
double bSignalBuy[];
double bSignalSell[];
double bRSI[], bMacdMain[], bMacdSig[], bEmaFast[], bEmaSlow[], bATR[];
double bUpperBB[], bLowerBB[], bMiddleBB[], bADX[];
double bHT_EmaFast[], bHT_EmaSlow[];
double bVolume[];
double bM15_EMAFast[], bM15_EMASlow[];
double bH1_EMAFast[], bH1_EMASlow[];
double bD1_EMAFast[], bD1_EMASlow[];

//--- ANALYSIS STATE STRUCTURE
struct AnalysisState
{
   string   regime;
   color    regimeColor;
   bool     isVolatile;
   
   string   signal;
   color    signalBg;
   string   signalSub;
   ENUM_SIGNAL_STRENGTH signalStrength;
   
   double   rsi;
   double   adx;
   double   macdHist;
   
   string   maCross;
   color    maCrossColor;
   bool     justCrossed;
   bool     crossFlashActive;
   
   double   spread;
   string   spreadStatus;
   color    spreadColor;
   
   string   volumeStatus;
   color    volumeColor;
   double   volumeRatio;
   
   string   m15Trend;
   string   h1Trend;
   string   h4Trend;
   string   d1Trend;
   string   trendAlignment;
   color    trendAlignmentColor;
   int      alignedCount;
   bool     alignmentMeetsMin;
   
   double   entry;
   double   sl;
   double   tp1;
   double   tp2;
   double   riskRewardRatio;
   bool     hasSetup;
   
   ENUM_BB_POSITION bbPosition;
   string   bbStatus;
   color    bbColor;
   bool     bbSqueeze;
   
   double   slPips;
   double   riskAmount;
   double   lotSize;
   bool     riskCalcValid;
   
   bool     rsiFilterPass;
   bool     bbFilterPass;
   bool     volumeFilterPass;
   bool     macdFilterPass;
   bool     spreadATRFilterPass;
   
   int      signalConfidence;
   
   string   symbol;
   string   timeframe;
   string   session;
   string   signalReason;
};

//--- ALERT STATE
string lastSignal = "";
string lastSignalDirection = "";
string prevClosedSignal = "";
datetime lastCandleTime = 0;
string lastCrossSignal = "";
string lastBBSignal = "";
datetime lastAlertTime = 0;
datetime lastCrossAlertTime = 0;
datetime lastBBAlertTime = 0;
datetime lastSqueezeAlertTime = 0;

//--- UI OBJECT CONSTANTS
#define UI_REGIME_VAL     "RegimeVal"
#define UI_SIGNAL_BG      "SignalBg"
#define UI_SIGNAL_VAL     "SignalVal"
#define UI_SIGNAL_SUB     "SignalSub"
#define UI_RSI_VAL        "RSIVal"
#define UI_ADX_VAL        "ADXVal"
#define UI_MACD_VAL       "MACDVal"
#define UI_ENTRY_VAL      "EntryVal"
#define UI_SL_VAL         "SLVal"
#define UI_TP1_VAL        "TP1Val"
#define UI_TP2_VAL        "TP2Val"
#define UI_RR_VAL         "RRVal"
#define UI_MACROSS_VAL    "MACrossVal"
#define UI_SPREAD_VAL     "SpreadVal"
#define UI_VOLUME_VAL     "VolumeVal"
#define UI_MTF_VAL        "MTFVal"
#define UI_SYMBOL_VAL     "SymbolVal"
#define UI_SESSION_VAL    "SessionVal"
#define UI_ALIGN_VAL      "AlignVal"
#define UI_BB_VAL         "BBVal"
#define UI_RISK_VAL       "RiskVal"
#define UI_LOT_VAL        "LotVal"
#define UI_SLPIPS_VAL     "SLPipsVal"
#define UI_REASON_VAL     "ReasonVal"
#define UI_CONFIDENCE_VAL "ConfidenceVal"

//--- GLOBALS
string prefix = "ATP_";
int panelX = 10;
int panelY = 30;
int panelWidth = 300;
int panelHeight = 0;
uint lastUIUpdateTick = 0;
const uint UI_UPDATE_INTERVAL_MS = 200;
uint lastMTFUpdateTick = 0;
const uint MTF_UPDATE_INTERVAL_MS = 2000;
bool mtfDataReady = false;
bool isDragging = false;
int dragOffsetX = 0;
int dragOffsetY = 0;
uint crossFlashStartTick = 0;
const uint CROSS_FLASH_DURATION_MS = 1500;

// Volume averaging
const int VOLUME_AVG_BARS = 10;

// MTF Constants
string MTF_BULL = "▲";
string MTF_BEAR = "▼";
string MTF_NEUTRAL = "◆";

// Fonts
string FONT_MAIN = "Segoe UI";
string FONT_BOLD = "Segoe UI Semibold";

//+------------------------------------------------------------------+
//| Tick-count elapsed helper (overflow-safe)                        |
//+------------------------------------------------------------------+
bool TickElapsed(uint startTick, uint durationMs)
{
   uint now = GetTickCount();
   uint elapsed = now - startTick;
   if(elapsed > 0x80000000)
      return true;
   return elapsed >= durationMs;
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   panelX = Inp_Panel_X;
   panelY = Inp_Panel_Y;
   
   if(Inp_RSI_Period < 2 || Inp_EMA_Fast < 2 || Inp_EMA_Slow < 2 || 
      Inp_ATR_Period < 1 || Inp_ADX_Period < 1 || Inp_BB_Period < 2)
   {
      Print("ERROR: Invalid input parameters - periods must be >= 2");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(Inp_EMA_Fast >= Inp_EMA_Slow)
   {
      Print("ERROR: Fast EMA period must be less than Slow EMA period");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(Inp_SL_Multiplier <= 0 || Inp_TP1_Multiplier <= 0 || Inp_TP2_Multiplier <= 0)
   {
      Print("ERROR: ATR multipliers must be positive");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(Inp_RSI_Oversold >= Inp_RSI_Overbought)
   {
      Print("ERROR: RSI Oversold must be less than Overbought");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(Inp_MinAlignment < 1 || Inp_MinAlignment > 4)
   {
      Print("WARNING: MinAlignment clamped to 1-4 range");
   }
   
   if(!InitIndicators())
      return(INIT_FAILED);
      
   SetIndexBuffer(0, bSignalBuy, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 10);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(0, PLOT_LABEL, "Buy Signal");
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, CLR_BUY);
   
   SetIndexBuffer(1, bSignalSell, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(1, PLOT_LABEL, "Sell Signal");
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, CLR_SELL);
   
   CreateProfessionalPanel();
   
   if(Inp_PanelDrag)
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   Print("Enhanced Analytics Panel v3.00 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize all indicator handles with proper cleanup             |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   hRSI = INVALID_HANDLE;
   hMACD = INVALID_HANDLE;
   hEMAFast = INVALID_HANDLE;
   hEMASlow = INVALID_HANDLE;
   hATR = INVALID_HANDLE;
   hBollinger = INVALID_HANDLE;
   hADX = INVALID_HANDLE;
   hVolume = INVALID_HANDLE;
   hHT_EMAFast = INVALID_HANDLE;
   hHT_EMASlow = INVALID_HANDLE;
   hM15_EMAFast = INVALID_HANDLE;
   hM15_EMASlow = INVALID_HANDLE;
   hH1_EMAFast = INVALID_HANDLE;
   hH1_EMASlow = INVALID_HANDLE;
   hD1_EMAFast = INVALID_HANDLE;
   hD1_EMASlow = INVALID_HANDLE;
   
   hRSI = iRSI(NULL, 0, Inp_RSI_Period, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE) { Print("ERROR: Failed to create RSI handle"); return false; }
   
   hMACD = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE);
   if(hMACD == INVALID_HANDLE) { Print("ERROR: Failed to create MACD handle"); return false; }
   
   hEMAFast = iMA(NULL, 0, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMAFast == INVALID_HANDLE) { Print("ERROR: Failed to create EMA Fast handle"); return false; }
   
   hEMASlow = iMA(NULL, 0, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   if(hEMASlow == INVALID_HANDLE) { Print("ERROR: Failed to create EMA Slow handle"); return false; }
   
   hATR = iATR(NULL, 0, Inp_ATR_Period);
   if(hATR == INVALID_HANDLE) { Print("ERROR: Failed to create ATR handle"); return false; }
   
   hBollinger = iBands(NULL, 0, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE);
   if(hBollinger == INVALID_HANDLE) { Print("ERROR: Failed to create Bollinger handle"); return false; }
   
   hADX = iADX(NULL, 0, Inp_ADX_Period);
   if(hADX == INVALID_HANDLE) { Print("ERROR: Failed to create ADX handle"); return false; }
   
   hVolume = iVolumes(NULL, 0, VOLUME_REAL);
   if(hVolume == INVALID_HANDLE)
   {
      hVolume = iVolumes(NULL, 0, VOLUME_TICK);
      if(hVolume == INVALID_HANDLE) { Print("ERROR: Failed to create Volume handle"); return false; }
   }
   
   ENUM_TIMEFRAMES currentTF = Period();
   
   if(currentTF != PERIOD_H4)
   {
      hHT_EMAFast = iMA(NULL, PERIOD_H4, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hHT_EMASlow = iMA(NULL, PERIOD_H4, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      if(hHT_EMAFast == INVALID_HANDLE || hHT_EMASlow == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create H4 EMA handles - H4 signals disabled");
         hHT_EMAFast = INVALID_HANDLE;
         hHT_EMASlow = INVALID_HANDLE;
      }
   }
   else
   {
      hHT_EMAFast = hEMAFast;
      hHT_EMASlow = hEMASlow;
   }
   
   if(currentTF != PERIOD_M15)
   {
      hM15_EMAFast = iMA(NULL, PERIOD_M15, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hM15_EMASlow = iMA(NULL, PERIOD_M15, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      if(hM15_EMAFast == INVALID_HANDLE || hM15_EMASlow == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create M15 EMA handles");
         hM15_EMAFast = INVALID_HANDLE;
         hM15_EMASlow = INVALID_HANDLE;
      }
   }
   else
   {
      hM15_EMAFast = hEMAFast;
      hM15_EMASlow = hEMASlow;
   }
   
   if(currentTF != PERIOD_H1)
   {
      hH1_EMAFast = iMA(NULL, PERIOD_H1, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hH1_EMASlow = iMA(NULL, PERIOD_H1, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      if(hH1_EMAFast == INVALID_HANDLE || hH1_EMASlow == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create H1 EMA handles");
         hH1_EMAFast = INVALID_HANDLE;
         hH1_EMASlow = INVALID_HANDLE;
      }
   }
   else
   {
      hH1_EMAFast = hEMAFast;
      hH1_EMASlow = hEMASlow;
   }
   
   if(currentTF != PERIOD_D1)
   {
      hD1_EMAFast = iMA(NULL, PERIOD_D1, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hD1_EMASlow = iMA(NULL, PERIOD_D1, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      if(hD1_EMAFast == INVALID_HANDLE || hD1_EMASlow == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create D1 EMA handles");
         hD1_EMAFast = INVALID_HANDLE;
         hD1_EMASlow = INVALID_HANDLE;
      }
   }
   else
   {
      hD1_EMAFast = hEMAFast;
      hD1_EMASlow = hEMASlow;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, prefix);
   
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hEMAFast != INVALID_HANDLE) IndicatorRelease(hEMAFast);
   if(hEMASlow != INVALID_HANDLE) IndicatorRelease(hEMASlow);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hBollinger != INVALID_HANDLE) IndicatorRelease(hBollinger);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hVolume != INVALID_HANDLE) IndicatorRelease(hVolume);
   
   ENUM_TIMEFRAMES currentTF = Period();
   if(hHT_EMAFast != INVALID_HANDLE && currentTF != PERIOD_H4) IndicatorRelease(hHT_EMAFast);
   if(hHT_EMASlow != INVALID_HANDLE && currentTF != PERIOD_H4) IndicatorRelease(hHT_EMASlow);
   if(hM15_EMAFast != INVALID_HANDLE && currentTF != PERIOD_M15) IndicatorRelease(hM15_EMAFast);
   if(hM15_EMASlow != INVALID_HANDLE && currentTF != PERIOD_M15) IndicatorRelease(hM15_EMASlow);
   if(hH1_EMAFast != INVALID_HANDLE && currentTF != PERIOD_H1) IndicatorRelease(hH1_EMAFast);
   if(hH1_EMASlow != INVALID_HANDLE && currentTF != PERIOD_H1) IndicatorRelease(hH1_EMASlow);
   if(hD1_EMAFast != INVALID_HANDLE && currentTF != PERIOD_D1) IndicatorRelease(hD1_EMAFast);
   if(hD1_EMASlow != INVALID_HANDLE && currentTF != PERIOD_D1) IndicatorRelease(hD1_EMASlow);
   
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   
   if(reason == REASON_RECOMPILE)
      Print("Panel recompiled successfully");
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!Inp_PanelDrag) return;
   
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;
      bool mouseClick = (int)StringToInteger(sparam) == 1;
      
      bool overHeader = (mouseX >= panelX && mouseX <= panelX + panelWidth &&
                         mouseY >= panelY && mouseY <= panelY + 44);
      
      if(mouseClick && overHeader)
      {
         isDragging = true;
         dragOffsetX = mouseX - panelX;
         dragOffsetY = mouseY - panelY;
      }
      else if(!mouseClick)
      {
         isDragging = false;
      }
      
      if(isDragging)
      {
         int newX = mouseX - dragOffsetX;
         int newY = mouseY - dragOffsetY;
         
         int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
         int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
         
         newX = MathMax(0, MathMin(newX, chartWidth - panelWidth));
         newY = MathMax(0, MathMin(newY, chartHeight - 100));
         
         MovePanel(newX, newY);
      }
   }
}

//+------------------------------------------------------------------+
//| Move panel to new position                                       |
//+------------------------------------------------------------------+
void MovePanel(int newX, int newY)
{
   int dx = newX - panelX;
   int dy = newY - panelY;
   
   if(dx == 0 && dy == 0) return;
   
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
      {
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 
                          (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) + dx);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 
                          (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) + dy);
      }
   }
   
   panelX = newX;
   panelY = newY;
}

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
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
   if(rates_total < 100) return 0;
   
   uint currentTick = GetTickCount();
   bool isWarmup = (prev_calculated == 0);
   
   if(!isWarmup && !TickElapsed(lastUIUpdateTick, UI_UPDATE_INTERVAL_MS))
      return rates_total;
      
   if(lastCandleTime != time[rates_total - 1])
   {
      prevClosedSignal = lastSignal;
      lastCandleTime = time[rates_total - 1];
   }
   
   ArraySetAsSeries(bRSI, true);
   ArraySetAsSeries(bMacdMain, true);
   ArraySetAsSeries(bMacdSig, true);
   ArraySetAsSeries(bEmaFast, true);
   ArraySetAsSeries(bEmaSlow, true);
   ArraySetAsSeries(bATR, true);
   ArraySetAsSeries(bUpperBB, true);
   ArraySetAsSeries(bLowerBB, true);
   ArraySetAsSeries(bMiddleBB, true);
   ArraySetAsSeries(bADX, true);
   ArraySetAsSeries(bHT_EmaFast, true);
   ArraySetAsSeries(bHT_EmaSlow, true);
   ArraySetAsSeries(bVolume, true);
   
   if(CopyBuffer(hRSI, 0, 0, 1, bRSI) <= 0) return rates_total;
   if(CopyBuffer(hADX, 0, 0, 1, bADX) <= 0) return rates_total;
   if(CopyBuffer(hEMAFast, 0, 0, 2, bEmaFast) < 2) return rates_total;
   if(CopyBuffer(hEMASlow, 0, 0, 2, bEmaSlow) < 2) return rates_total;
   if(CopyBuffer(hATR, 0, 0, 1, bATR) <= 0) return rates_total;
   if(CopyBuffer(hBollinger, 0, 0, 1, bMiddleBB) <= 0) return rates_total;
   if(CopyBuffer(hBollinger, 1, 0, 1, bUpperBB) <= 0) return rates_total;
   if(CopyBuffer(hBollinger, 2, 0, 1, bLowerBB) <= 0) return rates_total;
   if(CopyBuffer(hMACD, 0, 0, 1, bMacdMain) <= 0) return rates_total;
   if(CopyBuffer(hMACD, 1, 0, 1, bMacdSig) <= 0) return rates_total;
   int volCopied = (int)CopyBuffer(hVolume, 0, 0, VOLUME_AVG_BARS + 1, bVolume);
   if(volCopied < 3) return rates_total;
   
   bool h4DataValid = false;
   if(hHT_EMAFast != INVALID_HANDLE && hHT_EMASlow != INVALID_HANDLE)
   {
      if(CopyBuffer(hHT_EMAFast, 0, 0, 1, bHT_EmaFast) > 0 && 
         CopyBuffer(hHT_EMASlow, 0, 0, 1, bHT_EmaSlow) > 0 &&
         ArraySize(bHT_EmaFast) > 0 && ArraySize(bHT_EmaSlow) > 0)
      {
         h4DataValid = true;
      }
   }
   
   bool needMTFUpdate = isWarmup || !mtfDataReady || 
                        TickElapsed(lastMTFUpdateTick, MTF_UPDATE_INTERVAL_MS);
   
   if(needMTFUpdate)
   {
      ArraySetAsSeries(bM15_EMAFast, true);
      ArraySetAsSeries(bM15_EMASlow, true);
      ArraySetAsSeries(bH1_EMAFast, true);
      ArraySetAsSeries(bH1_EMASlow, true);
      ArraySetAsSeries(bD1_EMAFast, true);
      ArraySetAsSeries(bD1_EMASlow, true);
      
      bool m15Ok = false, h1Ok = false, d1Ok = false;
      
      if(hM15_EMAFast != INVALID_HANDLE && hM15_EMASlow != INVALID_HANDLE)
      {
         m15Ok = (CopyBuffer(hM15_EMAFast, 0, 0, 1, bM15_EMAFast) > 0 &&
                  CopyBuffer(hM15_EMASlow, 0, 0, 1, bM15_EMASlow) > 0 &&
                  ArraySize(bM15_EMAFast) > 0 && ArraySize(bM15_EMASlow) > 0);
      }
      
      if(hH1_EMAFast != INVALID_HANDLE && hH1_EMASlow != INVALID_HANDLE)
      {
         h1Ok = (CopyBuffer(hH1_EMAFast, 0, 0, 1, bH1_EMAFast) > 0 &&
                 CopyBuffer(hH1_EMASlow, 0, 0, 1, bH1_EMASlow) > 0 &&
                 ArraySize(bH1_EMAFast) > 0 && ArraySize(bH1_EMASlow) > 0);
      }
      
      if(hD1_EMAFast != INVALID_HANDLE && hD1_EMASlow != INVALID_HANDLE)
      {
         d1Ok = (CopyBuffer(hD1_EMAFast, 0, 0, 1, bD1_EMAFast) > 0 &&
                 CopyBuffer(hD1_EMASlow, 0, 0, 1, bD1_EMASlow) > 0 &&
                 ArraySize(bD1_EMAFast) > 0 && ArraySize(bD1_EMASlow) > 0);
      }
      
      if(m15Ok && h1Ok && d1Ok)
      {
         mtfDataReady = true;
         lastMTFUpdateTick = currentTick;
      }
   }
   
   double currentPrice = close[rates_total - 1];
   AnalysisState state;
   ZeroMemory(state);
   
   PerformAnalysis(currentPrice, state, h4DataValid);
   
   if(state.justCrossed)
   {
      crossFlashStartTick = currentTick;
   }
   state.crossFlashActive = !TickElapsed(crossFlashStartTick, CROSS_FLASH_DURATION_MS);
   
   // Alerts: only fire on directional changes, not strength changes
   if(Inp_EnableAlerts)
   {
      datetime now = TimeCurrent();
      string currentDirection = GetSignalDirection(state.signal);
      
      if(currentDirection != "" && lastSignalDirection != "" && 
         currentDirection != lastSignalDirection && state.signalStrength >= SIGNAL_NORMAL)
      {
         if(now - lastAlertTime >= Inp_AlertCooldown)
         {
            SendSignalAlert(state);
            lastAlertTime = now;
         }
      }
      
      if(Inp_AlertOnCross && state.justCrossed)
      {
         if(now - lastCrossAlertTime >= Inp_AlertCooldown)
         {
            SendCrossAlert(state);
            lastCrossAlertTime = now;
         }
      }
      
      if(Inp_AlertOnBBTouch && 
         (state.bbPosition == BB_UPPER_TOUCH || state.bbPosition == BB_LOWER_TOUCH ||
          state.bbPosition == BB_OUTSIDE_UPPER || state.bbPosition == BB_OUTSIDE_LOWER))
      {
         string bbSignal = (state.bbPosition > 0) ? "BB_UPPER" : "BB_LOWER";
         if(lastBBSignal != bbSignal && now - lastBBAlertTime >= Inp_AlertCooldown)
         {
            SendBBAlert(state);
            lastBBAlertTime = now;
         }
         lastBBSignal = bbSignal;
      }
      
      if(Inp_AlertOnSqueeze && state.bbSqueeze)
      {
         if(now - lastSqueezeAlertTime >= Inp_AlertCooldown * 5)
         {
            SendSqueezeAlert(state);
            lastSqueezeAlertTime = now;
         }
      }
   }
   
   bSignalBuy[rates_total - 1] = 0.0;
   bSignalSell[rates_total - 1] = 0.0;
   
   if(Inp_ShowArrows && state.signalStrength >= SIGNAL_NORMAL)
   {
      bool isBuy = StringFind(state.signal, "BUY") >= 0;
      bool isSell = StringFind(state.signal, "SELL") >= 0;
      
      bool prevIsBuy = StringFind(prevClosedSignal, "BUY") >= 0;
      bool prevIsSell = StringFind(prevClosedSignal, "SELL") >= 0;
      
      double atrDist = (ArraySize(bATR) > 0) ? bATR[0] * 0.5 : 10 * SymbolInfoDouble(NULL, SYMBOL_POINT);
      
      if(isBuy && !prevIsBuy)
         bSignalBuy[rates_total - 1] = low[rates_total - 1] - atrDist;
         
      if(isSell && !prevIsSell)
         bSignalSell[rates_total - 1] = high[rates_total - 1] + atrDist;
   }
   
   lastSignal = state.signal;
   lastSignalDirection = GetSignalDirection(state.signal);
   
   UpdateDashboard(state);
   lastUIUpdateTick = currentTick;
   
   ChartRedraw(0);
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Extract directional component from signal string                 |
//+------------------------------------------------------------------+
string GetSignalDirection(const string signal)
{
   if(StringFind(signal, "BUY") >= 0) return "BUY";
   if(StringFind(signal, "SELL") >= 0) return "SELL";
   return "";
}

//+------------------------------------------------------------------+
//| Get Trend Direction                                              |
//+------------------------------------------------------------------+
string GetTrendDirection(double fastEMA, double slowEMA)
{
   if(fastEMA == 0 || slowEMA == 0) return MTF_NEUTRAL;
   
   double diff = fastEMA - slowEMA;
   double threshold = MathMax(fastEMA, slowEMA) * 0.0001;
   
   if(diff > threshold) return MTF_BULL;
   if(diff < -threshold) return MTF_BEAR;
   return MTF_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Analyze Volume (improved: 10-bar average)                        |
//+------------------------------------------------------------------+
void AnalyzeVolume(const double &vol[], string &status, color &clr, double &ratio)
{
   int volSize = ArraySize(vol);
   if(volSize < 3)
   {
      status = "N/A";
      clr = CLR_TEXT_DIM;
      ratio = 0;
      return;
   }
   
   double volCurrent = vol[0];
   
   int avgBars = MathMin(VOLUME_AVG_BARS, volSize - 1);
   double volSum = 0;
   for(int i = 1; i <= avgBars; i++)
      volSum += vol[i];
   
   if(volSum < 0.001 || avgBars <= 0)
   {
      status = "N/A";
      clr = CLR_TEXT_DIM;
      ratio = 0;
      return;
   }
   
   double volAvg = volSum / (double)avgBars;
   ratio = volCurrent / volAvg;
   
   if(ratio > 2.0)
   {
      status = "EXTREME";
      clr = CLR_DANGER;
   }
   else if(ratio > 1.5)
   {
      status = "SPIKE";
      clr = CLR_WARNING;
   }
   else if(ratio > 1.2)
   {
      status = "HIGH";
      clr = CLR_BUY;
   }
   else if(ratio < 0.5)
   {
      status = "LOW";
      clr = CLR_TEXT_DIM;
   }
   else
   {
      status = "NORMAL";
      clr = CLR_TEXT_MAIN;
   }
}

//+------------------------------------------------------------------+
//| Get Session Name (fixed: no overlapping ranges)                  |
//+------------------------------------------------------------------+
string GetSessionName()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour + Inp_TimezoneOffset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;
   
   if(hour >= 13 && hour < 17) return "NY/LON";
   if(hour >= 8 && hour < 13) return "LONDON";
   if(hour >= 17 && hour < 21) return "NEW YORK";
   if(hour >= 0 && hour < 8) return "ASIAN";
   return "OFF-HOURS";
}

//+------------------------------------------------------------------+
//| Analyze Spread                                                   |
//+------------------------------------------------------------------+
void AnalyzeSpread(double &spreadPts, string &status, color &clr)
{
   long spreadPoints = SymbolInfoInteger(NULL, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(NULL, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(NULL, SYMBOL_DIGITS);
   
   spreadPts = spreadPoints * point;
   
   string sym = Symbol();
   int tightThresh, normalThresh, wideThresh;
   
   if(StringFind(sym, "JPY") >= 0)
   {
      tightThresh = 15; normalThresh = 30; wideThresh = 60;
   }
   else if(digits == 5 || digits == 3)
   {
      tightThresh = 10; normalThresh = 20; wideThresh = 40;
   }
   else if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      tightThresh = 30; normalThresh = 60; wideThresh = 100;
   }
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      tightThresh = 5; normalThresh = 10; wideThresh = 20;
   }
   else if(digits <= 2)
   {
      tightThresh = 5; normalThresh = 15; wideThresh = 30;
   }
   else
   {
      tightThresh = 2; normalThresh = 5; wideThresh = 10;
   }
   
   if(spreadPoints <= tightThresh) { status = "TIGHT"; clr = CLR_BUY; }
   else if(spreadPoints <= normalThresh) { status = "NORMAL"; clr = CLR_TEXT_MAIN; }
   else if(spreadPoints <= wideThresh) { status = "WIDE"; clr = CLR_WARNING; }
   else { status = "HIGH"; clr = CLR_DANGER; }
}

//+------------------------------------------------------------------+
//| Analyze Bollinger Band Position                                 |
//+------------------------------------------------------------------+
void AnalyzeBBPosition(double price, double upper, double lower, double middle,
                       ENUM_BB_POSITION &pos, string &status, color &clr, bool &squeeze)
{
   pos = BB_MIDDLE;
   status = "MIDDLE";
   clr = CLR_TEXT_MAIN;
   squeeze = false;
   
   double bbWidth = upper - lower;
   if(bbWidth <= 0) return;
   
   double relativeWidth = bbWidth / middle;
   if(relativeWidth < 0.005)
   {
      squeeze = true;
   }
   
   double tolerance = bbWidth * 0.02;
   
   if(price >= upper + tolerance)
   {
      pos = BB_OUTSIDE_UPPER;
      status = squeeze ? "SQUEEZE UP" : "ABOVE UPPER";
      clr = CLR_DANGER;
   }
   else if(price >= upper - tolerance)
   {
      pos = BB_UPPER_TOUCH;
      status = "AT UPPER";
      clr = CLR_WARNING;
   }
   else if(price <= lower - tolerance)
   {
      pos = BB_OUTSIDE_LOWER;
      status = squeeze ? "SQUEEZE DN" : "BELOW LOWER";
      clr = CLR_BUY;
   }
   else if(price <= lower + tolerance)
   {
      pos = BB_LOWER_TOUCH;
      status = "AT LOWER";
      clr = CLR_BUY_DIM;
   }
   else if(price > middle)
   {
      pos = BB_MIDDLE;
      status = squeeze ? "SQUEEZE" : "UPPER HALF";
      clr = CLR_BUY_DIM;
   }
   else
   {
      pos = BB_MIDDLE;
      status = squeeze ? "SQUEEZE" : "LOWER HALF";
      clr = CLR_SELL_DIM;
   }
}

//+------------------------------------------------------------------+
//| Calculate Trend Alignment                                        |
//+------------------------------------------------------------------+
void CalculateTrendAlignment(
   const string m15, const string h1, const string h4, const string d1,
   string &alignment, color &clr, int &alignedCount, bool &meetsMin, int minAlign)
{
   int bullCount = 0, bearCount = 0;
   
   if(m15 == MTF_BULL) bullCount++; else if(m15 == MTF_BEAR) bearCount++;
   if(h1 == MTF_BULL) bullCount++; else if(h1 == MTF_BEAR) bearCount++;
   if(h4 == MTF_BULL) bullCount++; else if(h4 == MTF_BEAR) bearCount++;
   if(d1 == MTF_BULL) bullCount++; else if(d1 == MTF_BEAR) bearCount++;
   
   alignedCount = MathMax(bullCount, bearCount);
   meetsMin = (alignedCount >= minAlign);
   
   if(bullCount == 4) {
      alignment = "ALL BULL";
      clr = CLR_BUY;
   } else if(bearCount == 4) {
      alignment = "ALL BEAR";
      clr = CLR_SELL;
   } else if(bullCount >= 3) {
      alignment = "STRONG BULL";
      clr = CLR_BUY;
   } else if(bearCount >= 3) {
      alignment = "STRONG BEAR";
      clr = CLR_SELL;
   } else if(bullCount > bearCount) {
      alignment = "BULL BIAS";
      clr = CLR_BUY_DIM;
   } else if(bearCount > bullCount) {
      alignment = "BEAR BIAS";
      clr = CLR_SELL_DIM;
   } else {
      alignment = "MIXED";
      clr = CLR_NEUTRAL;
   }
   
   if(!meetsMin && minAlign > 0)
   {
      clr = CLR_TEXT_DIM;
   }
}

//+------------------------------------------------------------------+
//| Calculate Risk                                                   |
//+------------------------------------------------------------------+
void CalculateRisk(double sl, double entry, double atr, double riskPct,
                   double &slPips, double &riskAmt, double &lots, bool &valid)
{
   slPips = 0;
   riskAmt = 0;
   lots = 0;
   valid = false;
   
   double point = SymbolInfoDouble(NULL, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(NULL, SYMBOL_DIGITS);
   double tickValue = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(NULL, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(NULL, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(NULL, SYMBOL_VOLUME_STEP);
   
   if(point <= 0 || tickValue <= 0 || tickSize <= 0 || minLot <= 0)
   {
      return;
   }
   
   slPips = MathAbs(entry - sl) / point;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) balance = 10000;
   riskAmt = balance * (riskPct / 100.0);
   
   if(slPips <= 0) return;
   
   double ticksInSL = slPips * (point / tickSize);
   if(ticksInSL <= 0) return;
   
   lots = riskAmt / (ticksInSL * tickValue);
   
   lots = MathFloor(lots / lotStep) * lotStep;
   
   lots = MathMax(minLot, MathMin(lots, maxLot));
   
   valid = true;
}

//+------------------------------------------------------------------+
//| Calculate Trade Setup (uses actual Ask/Bid)                      |
//+------------------------------------------------------------------+
void CalculateTradeSetup(
   const string signal, const double price, const double atr, 
   const ENUM_SIGNAL_STRENGTH strength,
   double &entry, double &sl, double &tp1, double &tp2, double &rrRatio, bool &hasSetup)
{
   sl = 0; tp1 = 0; tp2 = 0; rrRatio = 0;
   hasSetup = false;
   
   if(atr <= 0 || price <= 0) return;
   
   double tp2Mult = (strength == SIGNAL_STRONG) ? Inp_TP2_Strong_Mult : Inp_TP2_Multiplier;
   
   if(StringFind(signal, "BUY") >= 0)
   {
      entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
      if(entry <= 0) entry = price;
      sl = NormalizeDouble(entry - (atr * Inp_SL_Multiplier), _Digits);
      tp1 = NormalizeDouble(entry + (atr * Inp_TP1_Multiplier), _Digits);
      tp2 = NormalizeDouble(entry + (atr * tp2Mult), _Digits);
      hasSetup = true;
   }
   else if(StringFind(signal, "SELL") >= 0)
   {
      entry = SymbolInfoDouble(NULL, SYMBOL_BID);
      if(entry <= 0) entry = price;
      sl = NormalizeDouble(entry + (atr * Inp_SL_Multiplier), _Digits);
      tp1 = NormalizeDouble(entry - (atr * Inp_TP1_Multiplier), _Digits);
      tp2 = NormalizeDouble(entry - (atr * tp2Mult), _Digits);
      hasSetup = true;
   }
   
   if(hasSetup && Inp_SL_Multiplier > 0)
      rrRatio = tp2Mult / Inp_SL_Multiplier;
}

//+------------------------------------------------------------------+
//| Calculate Signal Confidence (0-100)                              |
//+------------------------------------------------------------------+
int CalculateConfidence(const AnalysisState &state, bool htBullish, bool htBearish, 
                        bool strongTrend, bool veryStrongTrend)
{
   int conf = 0;
   bool isBuy = StringFind(state.signal, "BUY") >= 0;
   bool isSell = StringFind(state.signal, "SELL") >= 0;
   if(!isBuy && !isSell) return 0;
   
   // EMA alignment: +20
   conf += 20;
   
   // H4 confirmation: +20
   if((isBuy && htBullish) || (isSell && htBearish))
      conf += 20;
   
   // ADX strength: +15 (strong) or +10 (moderate)
   if(veryStrongTrend) conf += 15;
   else if(strongTrend) conf += 10;
   
   // MTF alignment: +15 for meeting min, +5 extra for full alignment
   if(state.alignmentMeetsMin)
   {
      conf += 15;
      if(state.alignedCount >= 4) conf += 5;
   }
   
   // MACD histogram alignment: +10
   if((isBuy && state.macdHist > 0) || (isSell && state.macdHist < 0))
      conf += 10;
   
   // Volume confirmation: +10
   if(state.volumeRatio >= 1.0 && state.volumeRatio <= 2.0)
      conf += 10;
   
   // RSI in favorable zone: +5
   if(isBuy && state.rsi < 60) conf += 5;
   else if(isSell && state.rsi > 40) conf += 5;
   
   return MathMin(100, conf);
}

//+------------------------------------------------------------------+
//| Main Analysis Logic                                              |
//+------------------------------------------------------------------+
void PerformAnalysis(double price, AnalysisState &state, bool h4DataValid)
{
   state.symbol = Symbol();
   state.timeframe = GetTimeframeName(Period());
   state.session = GetSessionName();
   
   if(ArraySize(bRSI) < 1 || ArraySize(bADX) < 1 || ArraySize(bEmaFast) < 2 || 
      ArraySize(bEmaSlow) < 2 || ArraySize(bATR) < 1 || ArraySize(bUpperBB) < 1 || 
      ArraySize(bLowerBB) < 1 || ArraySize(bMacdMain) < 1 || ArraySize(bMacdSig) < 1)
   {
      state.signal = "LOADING";
      state.signalBg = CLR_NEUTRAL;
      state.regime = "INITIALIZING";
      state.regimeColor = CLR_TEXT_DIM;
      return;
   }
   
   double rsi = bRSI[0];
   double adx = bADX[0];
   double macdHist = bMacdMain[0] - bMacdSig[0];
   
   state.rsi = rsi;
   state.adx = adx;
   state.macdHist = macdHist;
   
   // 1. Regime Detection
   double bbWidth = (price > 0) ? (bUpperBB[0] - bLowerBB[0]) / price : 0;
   state.isVolatile = bbWidth > Inp_Vol_Threshold;
   
   bool emaBull = bEmaFast[0] > bEmaSlow[0];
   bool priceAboveFast = price > bEmaFast[0];
   bool priceBelowFast = price < bEmaFast[0];
   
   if(state.isVolatile)
   {
      if(emaBull && priceAboveFast)
         state.regime = "VOL BULL";
      else if(!emaBull && priceBelowFast)
         state.regime = "VOL BEAR";
      else
         state.regime = "VOL CHOP";
      state.regimeColor = CLR_WARNING;
   }
   else
   {
      if(emaBull && priceAboveFast)
      {
         state.regime = "UPTREND";
         state.regimeColor = CLR_BUY;
      }
      else if(!emaBull && priceBelowFast)
      {
         state.regime = "DOWNTREND";
         state.regimeColor = CLR_SELL;
      }
      else
      {
         state.regime = "RANGING";
         state.regimeColor = CLR_NEUTRAL;
      }
   }
   
   // 2. BB Position Analysis (with squeeze detection)
   AnalyzeBBPosition(price, bUpperBB[0], bLowerBB[0], 
                     (ArraySize(bMiddleBB) > 0) ? bMiddleBB[0] : (bUpperBB[0] + bLowerBB[0]) / 2,
                     state.bbPosition, state.bbStatus, state.bbColor, state.bbSqueeze);
   
   // 3. RSI Filter (fixed: only block contrarian signals)
   state.rsiFilterPass = true;
   string rsiFilterReason = "";
   
   if(Inp_UseRSIFilter)
   {
      if(rsi > Inp_RSI_Overbought && emaBull)
      {
         state.rsiFilterPass = false;
         rsiFilterReason = "RSI OB";
      }
      else if(rsi < Inp_RSI_Oversold && !emaBull)
      {
         state.rsiFilterPass = false;
         rsiFilterReason = "RSI OS";
      }
   }
   
   // 4. BB Filter (fixed: also checks VOL CHOP regime)
   state.bbFilterPass = true;
   string bbFilterReason = "";
   
   if(Inp_UseBBSignal)
   {
      bool isNonTrending = (state.regime == "RANGING" || state.regime == "VOL CHOP");
      if(state.bbPosition == BB_OUTSIDE_UPPER && isNonTrending)
      {
         state.bbFilterPass = false;
         bbFilterReason = "BB EXT";
      }
      else if(state.bbPosition == BB_OUTSIDE_LOWER && isNonTrending)
      {
         state.bbFilterPass = false;
         bbFilterReason = "BB EXT";
      }
   }
   
   // 5. MACD Histogram Filter
   state.macdFilterPass = true;
   string macdFilterReason = "";
   
   if(Inp_UseMACDFilter)
   {
      if(emaBull && macdHist < 0)
      {
         state.macdFilterPass = false;
         macdFilterReason = "MACD-";
      }
      else if(!emaBull && macdHist > 0)
      {
         state.macdFilterPass = false;
         macdFilterReason = "MACD+";
      }
   }
   
   // 6. Volume Filter
   state.volumeFilterPass = true;
   AnalyzeVolume(bVolume, state.volumeStatus, state.volumeColor, state.volumeRatio);
   
   if(Inp_UseVolumeFilter)
   {
      if(state.volumeRatio < 0.5)
         state.volumeFilterPass = false;
   }
   
   // 7. Spread-to-ATR Filter
   state.spreadATRFilterPass = true;
   AnalyzeSpread(state.spread, state.spreadStatus, state.spreadColor);
   
   if(Inp_UseSpreadATRFilter && ArraySize(bATR) > 0 && bATR[0] > 0)
   {
      double spreadRatio = state.spread / bATR[0];
      if(spreadRatio > Inp_SpreadATRRatio)
      {
         state.spreadATRFilterPass = false;
      }
   }
   
   // 8. H4 Trend Assessment
   bool htBullish = false, htBearish = false;
   if(h4DataValid)
   {
      htBullish = bHT_EmaFast[0] > bHT_EmaSlow[0];
      htBearish = bHT_EmaFast[0] < bHT_EmaSlow[0];
   }
   
   // 9. Multi-Timeframe Analysis
   state.h4Trend = h4DataValid ? GetTrendDirection(bHT_EmaFast[0], bHT_EmaSlow[0]) : MTF_NEUTRAL;
   
   if(mtfDataReady)
   {
      state.m15Trend = GetTrendDirection(bM15_EMAFast[0], bM15_EMASlow[0]);
      state.h1Trend = GetTrendDirection(bH1_EMAFast[0], bH1_EMASlow[0]);
      state.d1Trend = GetTrendDirection(bD1_EMAFast[0], bD1_EMASlow[0]);
      
      int minAlign = MathMax(1, MathMin(4, Inp_MinAlignment));
      CalculateTrendAlignment(
         state.m15Trend, state.h1Trend, state.h4Trend, state.d1Trend,
         state.trendAlignment, state.trendAlignmentColor, state.alignedCount,
         state.alignmentMeetsMin, minAlign
      );
   }
   else
   {
      state.m15Trend = MTF_NEUTRAL;
      state.h1Trend = MTF_NEUTRAL;
      state.d1Trend = MTF_NEUTRAL;
      state.trendAlignment = "LOADING...";
      state.trendAlignmentColor = CLR_TEXT_DIM;
      state.alignedCount = 0;
      state.alignmentMeetsMin = false;
   }
   
   // 10. Signal Generation
   bool strongTrend = adx > 25;
   bool veryStrongTrend = adx > 35;
   
   state.signal = "NEUTRAL";
   state.signalBg = CLR_NEUTRAL;
   state.signalStrength = SIGNAL_NONE;
   state.signalReason = "";
   
   bool alignmentOk = !Inp_RequireAlignment || state.alignmentMeetsMin;
   
   if(emaBull && alignmentOk)
   {
      string reason = "EMA Bull";
      
      if(htBullish && veryStrongTrend)
      {
         state.signal = "STRONG BUY";
         state.signalBg = CLR_BUY;
         state.signalStrength = SIGNAL_STRONG;
         reason += "+H4+ADX";
      }
      else if(htBullish && strongTrend)
      {
         state.signal = "BUY";
         state.signalBg = CLR_BUY;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+H4+Trend";
      }
      else if(htBullish)
      {
         state.signal = "BUY";
         state.signalBg = CLR_BUY_DIM;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+H4";
      }
      else if(strongTrend)
      {
         state.signal = "BUY";
         state.signalBg = CLR_BUY_DIM;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+Trend";
      }
      else
      {
         state.signal = "WEAK BUY";
         state.signalBg = CLR_BUY_DIM;
         state.signalStrength = SIGNAL_WEAK;
      }
      
      // Apply RSI filter
      if(!state.rsiFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signal = "WEAK BUY";
         state.signalStrength = SIGNAL_WEAK;
         state.signalBg = CLR_WARNING;
         reason = rsiFilterReason + " warning";
      }
      
      // Apply BB filter
      if(!state.bbFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signal = "CAUTION";
         state.signalStrength = SIGNAL_WEAK;
         state.signalBg = CLR_WARNING;
         reason = bbFilterReason + " warning";
      }
      
      // Apply MACD filter
      if(!state.macdFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK BUY";
         state.signalBg = CLR_WARNING;
         reason += " " + macdFilterReason;
      }
      
      // Apply volume filter
      if(!state.volumeFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK BUY";
         reason += " LowVol";
      }
      
      // Apply spread/ATR filter
      if(!state.spreadATRFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK BUY";
         state.signalBg = CLR_WARNING;
         reason += " HighSpread";
      }
      
      state.signalReason = reason;
   }
   else if(!emaBull && alignmentOk)
   {
      string reason = "EMA Bear";
      
      if(htBearish && veryStrongTrend)
      {
         state.signal = "STRONG SELL";
         state.signalBg = CLR_SELL;
         state.signalStrength = SIGNAL_STRONG;
         reason += "+H4+ADX";
      }
      else if(htBearish && strongTrend)
      {
         state.signal = "SELL";
         state.signalBg = CLR_SELL;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+H4+Trend";
      }
      else if(htBearish)
      {
         state.signal = "SELL";
         state.signalBg = CLR_SELL_DIM;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+H4";
      }
      else if(strongTrend)
      {
         state.signal = "SELL";
         state.signalBg = CLR_SELL_DIM;
         state.signalStrength = SIGNAL_NORMAL;
         reason += "+Trend";
      }
      else
      {
         state.signal = "WEAK SELL";
         state.signalBg = CLR_SELL_DIM;
         state.signalStrength = SIGNAL_WEAK;
      }
      
      // Apply RSI filter
      if(!state.rsiFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signal = "WEAK SELL";
         state.signalStrength = SIGNAL_WEAK;
         state.signalBg = CLR_WARNING;
         reason = rsiFilterReason + " warning";
      }
      
      // Apply BB filter
      if(!state.bbFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signal = "CAUTION";
         state.signalStrength = SIGNAL_WEAK;
         state.signalBg = CLR_WARNING;
         reason = bbFilterReason + " warning";
      }
      
      // Apply MACD filter
      if(!state.macdFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK SELL";
         state.signalBg = CLR_WARNING;
         reason += " " + macdFilterReason;
      }
      
      // Apply volume filter
      if(!state.volumeFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK SELL";
         reason += " LowVol";
      }
      
      // Apply spread/ATR filter
      if(!state.spreadATRFilterPass && state.signalStrength >= SIGNAL_NORMAL)
      {
         state.signalStrength = SIGNAL_WEAK;
         state.signal = "WEAK SELL";
         state.signalBg = CLR_WARNING;
         reason += " HighSpread";
      }
      
      state.signalReason = reason;
   }
   else if(!alignmentOk)
   {
      state.signal = "NO ALIGN";
      state.signalBg = CLR_TEXT_DIM;
      state.signalStrength = SIGNAL_NONE;
      state.signalReason = "MTF alignment required";
   }
   
   // Signal subtitle
   string htTrendStr = (!htBullish && !htBearish) ? "FLAT" : (htBullish ? "BULL" : "BEAR");
   if(!h4DataValid) htTrendStr = "N/A";
   state.signalSub = "H4: " + htTrendStr + " | ADX: " + (veryStrongTrend ? "V.STRONG" : (strongTrend ? "STRONG" : "WEAK"));
   
   // 11. MA Cross Detection
   bool crossUp = (bEmaFast[1] <= bEmaSlow[1] && bEmaFast[0] > bEmaSlow[0]);
   bool crossDown = (bEmaFast[1] >= bEmaSlow[1] && bEmaFast[0] < bEmaSlow[0]);
   state.justCrossed = crossUp || crossDown;
   
   if(crossUp)
   {
      state.maCross = "▲ CROSS UP";
      state.maCrossColor = CLR_BUY;
   }
   else if(crossDown)
   {
      state.maCross = "▼ CROSS DN";
      state.maCrossColor = CLR_SELL;
   }
   else if(emaBull)
   {
      state.maCross = "▲ BULLISH";
      state.maCrossColor = CLR_BUY_DIM;
   }
   else
   {
      state.maCross = "▼ BEARISH";
      state.maCrossColor = CLR_SELL_DIM;
   }
   
   // 12. Trade Setup (uses actual Ask/Bid)
   state.entry = price;
   CalculateTradeSetup(
      state.signal, price, bATR[0], state.signalStrength,
      state.entry, state.sl, state.tp1, state.tp2, state.riskRewardRatio, state.hasSetup
   );
   
   // 13. Risk Calculation
   if(state.hasSetup && Inp_ShowRiskCalc)
   {
      CalculateRisk(state.sl, state.entry, bATR[0], Inp_RiskPercent,
                    state.slPips, state.riskAmount, state.lotSize, state.riskCalcValid);
   }
   
   // 14. Confidence Score
   state.signalConfidence = CalculateConfidence(state, htBullish, htBearish, strongTrend, veryStrongTrend);
}

//+------------------------------------------------------------------+
//| Get Timeframe Name                                               |
//+------------------------------------------------------------------+
string GetTimeframeName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default: return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| Get adjusted font size                                           |
//+------------------------------------------------------------------+
int GetFontSize(int baseSize)
{
   int adjusted = baseSize + Inp_FontSize;
   return MathMax(6, MathMin(adjusted, 20));
}

//+------------------------------------------------------------------+
//| UI UPDATE                                                        |
//+------------------------------------------------------------------+
void UpdateDashboard(const AnalysisState &state)
{
   UpdateText(UI_SYMBOL_VAL, state.symbol + " | " + state.timeframe, CLR_TEXT_SUB);
   UpdateText(UI_SESSION_VAL, state.session, CLR_ACCENT);
   
   UpdateText(UI_REGIME_VAL, state.regime, state.regimeColor);
   
   UpdateRectColor(UI_SIGNAL_BG, state.signalBg);
   UpdateText(UI_SIGNAL_VAL, state.signal, CLR_TEXT_MAIN);
   UpdateText(UI_SIGNAL_SUB, state.signalSub, C'220,220,220');
   
   // Technical Grid
   color rsiColor = CLR_TEXT_MAIN;
   if(state.rsi > Inp_RSI_Overbought) rsiColor = CLR_DANGER;
   else if(state.rsi > Inp_RSI_Overbought - 10) rsiColor = CLR_WARNING;
   else if(state.rsi < Inp_RSI_Oversold) rsiColor = CLR_BUY;
   else if(state.rsi < Inp_RSI_Oversold + 10) rsiColor = CLR_BUY_DIM;
   UpdateText(UI_RSI_VAL, DoubleToString(state.rsi, 1), rsiColor);
   
   color adxColor = (state.adx > 35) ? CLR_BUY : (state.adx > 25) ? CLR_BUY_DIM : CLR_TEXT_DIM;
   UpdateText(UI_ADX_VAL, DoubleToString(state.adx, 1), adxColor);
   
   color macdColor = (state.macdHist > 0) ? CLR_BUY : (state.macdHist < 0) ? CLR_SELL : CLR_NEUTRAL;
   UpdateText(UI_MACD_VAL, DoubleToString(state.macdHist, 5), macdColor);
   
   color crossColor = state.crossFlashActive ? CLR_FLASH : state.maCrossColor;
   UpdateText(UI_MACROSS_VAL, state.maCross, crossColor);
   
   UpdateText(UI_SPREAD_VAL, 
              DoubleToString(state.spread, _Digits) + " (" + state.spreadStatus + ")", 
              state.spreadColor);
   
   UpdateText(UI_VOLUME_VAL, 
              state.volumeStatus + " (" + DoubleToString(state.volumeRatio, 1) + "x)", 
              state.volumeColor);
   
   UpdateText(UI_BB_VAL, state.bbStatus, state.bbColor);
   
   string mtfDisplay = state.m15Trend + " " + state.h1Trend + " " + state.h4Trend + " " + state.d1Trend;
   UpdateText(UI_MTF_VAL, mtfDisplay, state.trendAlignmentColor);
   
   UpdateText(UI_ALIGN_VAL, state.trendAlignment, state.trendAlignmentColor);
   
   // Trade Setup
   if(state.hasSetup)
   {
      UpdateText(UI_ENTRY_VAL, DoubleToString(state.entry, _Digits), CLR_TEXT_MAIN);
      UpdateText(UI_SL_VAL, DoubleToString(state.sl, _Digits), CLR_SELL);
      UpdateText(UI_TP1_VAL, DoubleToString(state.tp1, _Digits), CLR_BUY);
      UpdateText(UI_TP2_VAL, DoubleToString(state.tp2, _Digits), CLR_BUY);
      
      color rrColor = (state.riskRewardRatio >= 3.0) ? CLR_BUY : 
                      (state.riskRewardRatio >= 2.0) ? CLR_ACCENT : CLR_TEXT_MAIN;
      UpdateText(UI_RR_VAL, "1:" + DoubleToString(state.riskRewardRatio, 1), rrColor);
      
      if(Inp_ShowRiskCalc && state.riskCalcValid)
      {
         double pipDivisor = 10.0;
         int digits = (int)SymbolInfoInteger(NULL, SYMBOL_DIGITS);
         if(digits == 3 || digits == 2)
            pipDivisor = 1.0;
         
         string pipsStr = DoubleToString(state.slPips / pipDivisor, 1);
         UpdateText(UI_SLPIPS_VAL, pipsStr + " pips", CLR_TEXT_SUB);
         UpdateText(UI_RISK_VAL, DoubleToString(state.riskAmount, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY), CLR_WARNING);
         UpdateText(UI_LOT_VAL, DoubleToString(state.lotSize, 2) + " lots", CLR_ACCENT);
      }
   }
   else
   {
      UpdateText(UI_ENTRY_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_SL_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_TP1_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_TP2_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_RR_VAL, "--", CLR_TEXT_DIM);
      UpdateText(UI_SLPIPS_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_RISK_VAL, "---", CLR_TEXT_DIM);
      UpdateText(UI_LOT_VAL, "---", CLR_TEXT_DIM);
   }
   
   // Signal reason
   UpdateText(UI_REASON_VAL, state.signalReason, CLR_TEXT_DIM);
   
   // Confidence display
   color confColor = CLR_TEXT_DIM;
   if(state.signalConfidence >= 75) confColor = CLR_BUY;
   else if(state.signalConfidence >= 50) confColor = CLR_ACCENT;
   else if(state.signalConfidence >= 25) confColor = CLR_WARNING;
   UpdateText(UI_CONFIDENCE_VAL, IntegerToString(state.signalConfidence) + "%", confColor);
}

//+------------------------------------------------------------------+
//| UI CREATION                                                      |
//+------------------------------------------------------------------+
void CreateProfessionalPanel()
{
   int w = panelWidth;
   int h = Inp_CompactMode ? 510 : 620;
   panelHeight = h;
   int x = panelX;
   int y = panelY;
   
   // 1. Main Container
   CreateRect("MainShadow", x-1, y-1, w+2, h+2, CLR_BORDER);
   CreateRect("MainBg", x, y, w, h, CLR_BG);
   
   // 2. Header Bar
   CreateRect("HeaderBg", x, y, w, 44, CLR_PANEL);
   CreateText("AppTitle", "◆ ALGO PRO", x+15, y+8, CLR_TEXT_MAIN, GetFontSize(10), true);
   CreateText(UI_SYMBOL_VAL, Symbol() + " | " + GetTimeframeName(Period()), x+15, y+26, CLR_TEXT_SUB, GetFontSize(7));
   CreateText("AppVer", "v3.0", x+w-50, y+8, CLR_TEXT_DIM, GetFontSize(7), false, ANCHOR_RIGHT_UPPER);
   CreateText(UI_SESSION_VAL, "SESSION", x+w-15, y+26, CLR_ACCENT, GetFontSize(7), true, ANCHOR_RIGHT_UPPER);
   if(Inp_PanelDrag)
      CreateText("DragHint", "⋮⋮", x+w-40, y+8, CLR_TEXT_DIM, GetFontSize(10), false, ANCHOR_RIGHT_UPPER);
   
   y += 52;
   
   // 3. Market Regime
   CreateText("RegimeLbl", "REGIME", x+15, y, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_REGIME_VAL, "ANALYZING...", x+w-15, y, CLR_TEXT_MAIN, GetFontSize(8), true, ANCHOR_RIGHT_UPPER);
   CreateRect("SepRegime", x+15, y+14, w-30, 1, CLR_BORDER);
   
   y += 22;
   
   // 4. Signal Panel
   CreateRect(UI_SIGNAL_BG, x+15, y, w-30, 55, CLR_NEUTRAL);
   CreateText("SignalLbl", "PRIMARY SIGNAL", x+30, y+6, C'200,200,200', GetFontSize(7));
   CreateText(UI_SIGNAL_VAL, "WAITING", x+30, y+18, CLR_TEXT_MAIN, GetFontSize(14), true);
   CreateText(UI_SIGNAL_SUB, "---", x+w-30, y+36, C'210,210,210', GetFontSize(7), false, ANCHOR_RIGHT_UPPER);
   
   y += 68;
   
   // 5. Technical Grid
   CreateRect("GridBg", x+15, y, w-30, 78, CLR_PANEL);
   
   int col1 = x + 28;
   int col2 = x + 155;
   int row1 = y + 12;
   int row2 = y + 44;
   
   CreateText("RSILbl", "RSI (" + IntegerToString(Inp_RSI_Period) + ")", col1, row1, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_RSI_VAL, "--", col1, row1+13, CLR_TEXT_MAIN, GetFontSize(9), true);
   
   CreateText("ADXLbl", "ADX TREND", col2, row1, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_ADX_VAL, "--", col2, row1+13, CLR_TEXT_MAIN, GetFontSize(9), true);
   
   CreateText("MACDLbl", "MACD HIST", col1, row2, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_MACD_VAL, "--", col1, row2+13, CLR_TEXT_MAIN, GetFontSize(9), true);
   
   CreateText("MACrossLbl", "MA CROSS", col2, row2, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_MACROSS_VAL, "WAITING", col2, row2+13, CLR_TEXT_MAIN, GetFontSize(8), true);
   
   y += 88;
   
   // 6. Info Grid (Spread, Volume, BB)
   CreateRect("InfoBg", x+15, y, w-30, 60, CLR_PANEL);
   
   int iy = y + 10;
   int ix1 = x + 28;
   
   CreateText("SpreadLbl", "SPREAD", ix1, iy, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_SPREAD_VAL, "--", ix1 + 50, iy, CLR_TEXT_MAIN, GetFontSize(8), true);
   
   CreateText("VolumeLbl", "VOLUME", x+155, iy, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_VOLUME_VAL, "--", x+205, iy, CLR_TEXT_MAIN, GetFontSize(8), true);
   
   iy += 20;
   CreateRect("SepInfo1", x+25, iy-2, w-50, 1, CLR_BG);
   
   iy += 6;
   CreateText("BBLbl", "BB POSITION", ix1, iy, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_BB_VAL, "--", ix1 + 75, iy, CLR_TEXT_MAIN, GetFontSize(8), true);
   
   y += 70;
   
   // 7. MTF Section
   CreateRect("MTFBg", x+15, y, w-30, 58, CLR_PANEL);
   
   iy = y + 10;
   CreateText("MTFLbl", "MTF ALIGNMENT (M15 · H1 · H4 · D1)", ix1, iy, CLR_TEXT_SUB, GetFontSize(7));
   iy += 14;
   CreateText(UI_MTF_VAL, "◆ ◆ ◆ ◆", ix1, iy, CLR_TEXT_DIM, GetFontSize(11), false);
   iy += 18;
   CreateText("AlignLbl", "CONSENSUS:", ix1, iy, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_ALIGN_VAL, "LOADING...", ix1 + 75, iy, CLR_TEXT_DIM, GetFontSize(8), true);
   
   y += 68;
   
   // 8. Trade Setup
   CreateText("SetupHdr", "TRADE SETUP (ATR " + IntegerToString(Inp_ATR_Period) + ")", x+15, y, CLR_TEXT_SUB, GetFontSize(7));
   y += 14;
   CreateRect("SetupBg", x+15, y, w-30, Inp_ShowRiskCalc ? 175 : 145, CLR_PANEL);
   
   int ly = y + 12;
   int lx = x + 28;
   int vx = x + w - 28;
   
   CreateText("EntryLbl", "ENTRY", lx, ly, CLR_TEXT_MAIN, GetFontSize(7));
   CreateText(UI_ENTRY_VAL, "---", vx, ly, CLR_TEXT_MAIN, GetFontSize(9), true, ANCHOR_RIGHT_UPPER);
   ly += 22;
   CreateRect("Sep1", lx, ly-3, w-56, 1, CLR_BG);
   
   CreateText("SLLbl", "STOP LOSS", lx, ly, CLR_SELL, GetFontSize(7));
   CreateText(UI_SL_VAL, "---", vx, ly, CLR_SELL, GetFontSize(9), true, ANCHOR_RIGHT_UPPER);
   ly += 22;
   CreateRect("Sep2", lx, ly-3, w-56, 1, CLR_BG);
   
   CreateText("TP1Lbl", "TARGET 1", lx, ly, CLR_BUY, GetFontSize(7));
   CreateText(UI_TP1_VAL, "---", vx, ly, CLR_BUY, GetFontSize(9), true, ANCHOR_RIGHT_UPPER);
   ly += 22;
   CreateRect("Sep3", lx, ly-3, w-56, 1, CLR_BG);
   
   CreateText("TP2Lbl", "TARGET 2", lx, ly, CLR_BUY, GetFontSize(7));
   CreateText(UI_TP2_VAL, "---", vx, ly, CLR_BUY, GetFontSize(9), true, ANCHOR_RIGHT_UPPER);
   ly += 22;
   CreateRect("Sep4", lx, ly-3, w-56, 1, CLR_BG);
   
   CreateText("RRLbl", "RISK : REWARD", lx, ly, CLR_TEXT_SUB, GetFontSize(7));
   CreateText(UI_RR_VAL, "--", vx, ly, CLR_ACCENT, GetFontSize(10), true, ANCHOR_RIGHT_UPPER);
   
   if(Inp_ShowRiskCalc)
   {
      ly += 24;
      CreateRect("Sep5", lx, ly-3, w-56, 1, CLR_BORDER);
      ly += 4;
      
      CreateText("RiskLbl", "RISK (" + DoubleToString(Inp_RiskPercent, 1) + "%)", lx, ly, CLR_TEXT_SUB, GetFontSize(7));
      CreateText(UI_RISK_VAL, "---", vx, ly, CLR_WARNING, GetFontSize(8), true, ANCHOR_RIGHT_UPPER);
      ly += 18;
      
      CreateText("LotLbl", "LOT SIZE", lx, ly, CLR_TEXT_SUB, GetFontSize(7));
      CreateText(UI_LOT_VAL, "---", vx, ly, CLR_ACCENT, GetFontSize(8), true, ANCHOR_RIGHT_UPPER);
      ly += 18;
      
      CreateText("SLPipsLbl", "SL DISTANCE", lx, ly, CLR_TEXT_SUB, GetFontSize(7));
      CreateText(UI_SLPIPS_VAL, "---", vx, ly, CLR_TEXT_SUB, GetFontSize(8), true, ANCHOR_RIGHT_UPPER);
   }
   
   y += (Inp_ShowRiskCalc ? 185 : 155);
   
   // 9. Confidence & Signal Reason (footer)
   if(!Inp_CompactMode)
   {
      CreateText("ConfLbl", "CONFIDENCE:", x+15, y, CLR_TEXT_DIM, GetFontSize(7));
      CreateText(UI_CONFIDENCE_VAL, "0%", x+85, y, CLR_TEXT_DIM, GetFontSize(8), true);
      
      y += 16;
      CreateText("ReasonLbl", "REASON:", x+15, y, CLR_TEXT_DIM, GetFontSize(7));
      CreateText(UI_REASON_VAL, "---", x+65, y, CLR_TEXT_DIM, GetFontSize(7));
   }
}

//+------------------------------------------------------------------+
//| UI HELPERS                                                       |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg)
{
   string obj = prefix + name;
   ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
}

void CreateText(string name, string text, int x, int y, color clr, int size=8, 
                bool bold=false, ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER)
{
   string obj = prefix + name;
   ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, bold ? FONT_BOLD : FONT_MAIN);
   ObjectSetInteger(0, obj, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
}

void UpdateText(string name, string text, color clr)
{
   string obj = prefix + name;
   if(ObjectFind(0, obj) >= 0)
   {
      ObjectSetString(0, obj, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   }
}

void UpdateRectColor(string name, color bg)
{
   string obj = prefix + name;
   if(ObjectFind(0, obj) >= 0)
      ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
}

//+------------------------------------------------------------------+
//| ALERT SYSTEM                                                     |
//+------------------------------------------------------------------+
void SendSignalAlert(const AnalysisState &state)
{
   string message = StringFormat("%s [%s]: %s -> %s | Regime: %s | Confidence: %d%% | %s", 
                                  state.symbol, state.timeframe, lastSignal, 
                                  state.signal, state.regime, state.signalConfidence,
                                  state.signalReason);
   
   Alert(message);
   PlaySound("alert.wav");
   
   if(Inp_PushAlerts)
      SendNotification(message);
   
   if(Inp_EmailAlerts)
      SendMail("AlgoPro Signal: " + state.symbol, message);
   
   Print("SIGNAL ALERT: ", message);
}

void SendCrossAlert(const AnalysisState &state)
{
   string message = StringFormat("%s [%s]: MA CROSS %s | %s", 
                                  state.symbol, state.timeframe,
                                  state.maCross, state.regime);
   
   Alert(message);
   PlaySound("alert2.wav");
   
   if(Inp_PushAlerts)
      SendNotification(message);
   
   Print("CROSS ALERT: ", message);
}

void SendBBAlert(const AnalysisState &state)
{
   string message = StringFormat("%s [%s]: %s | Regime: %s", 
                                  state.symbol, state.timeframe,
                                  state.bbStatus, state.regime);
   
   Alert(message);
   PlaySound("alert.wav");
   
   if(Inp_PushAlerts)
      SendNotification(message);
   
   Print("BB ALERT: ", message);
}

void SendSqueezeAlert(const AnalysisState &state)
{
   string message = StringFormat("%s [%s]: BB SQUEEZE detected | Regime: %s | Potential breakout", 
                                  state.symbol, state.timeframe, state.regime);
   
   Alert(message);
   PlaySound("alert2.wav");
   
   if(Inp_PushAlerts)
      SendNotification(message);
   
   Print("SQUEEZE ALERT: ", message);
}
//+------------------------------------------------------------------+
