//+------------------------------------------------------------------+
//|                                      InstitutionalDashboard.mq5  |
//|                        Advanced Institutional Analytics Dashboard|
//+------------------------------------------------------------------+
#property copyright "Institutional Analytics"
#property link      ""
#property version   "3.20" // Enhanced: Volume analysis, liquidity levels, MTF analysis, bug fixes
#property description "Institutional Analytics Dashboard with volume profile, liquidity zones & MTF"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- OPTIMIZATION CONSTANTS ---
#define OPT_UPDATE_INTERVAL_SECONDS  0      // Update dashboard every tick for scalping
#define UI_UPDATE_THROTTLE_MS        200    // Minimum ms between UI updates
#define OPT_EPSILON                  0.0000001  // Small value for float comparisons

//--- Include optimization library
#include <DashboardOptimization.mqh>

//--- COLORS ---
#define DASH_CLR_WHITE   C'255,255,255'
#define DASH_CLR_NONE    clrNONE

//--- INPUTS ---
input group "═══ Risk Management ═══"
input double   Inp_RiskPercent   = 0.5;       // Risk Per Trade (%) - Lower for scalping
input int      Inp_ATR_Period    = 12;        // ATR Period for Stop Loss - Faster response
input double   Inp_ATR_Multiplier= 1.0;       // ATR Multiplier for SL - Tighter stops
input double   Inp_RR_Ratio      = 1.5;       // TakeProfit/StopLoss Ratio - Quick profits

input group "═══ Trend & Momentum ═══"
input int      Inp_RSI_Period    = 7;         // RSI Period - More sensitive
input int      Inp_ADX_Period    = 14;        // ADX Period - Faster trend detection
input int      Inp_EMA_Fast      = 13;         // Fast EMA - Fibonacci, more responsive
input int      Inp_EMA_Slow      = 34;        // Slow EMA - Fibonacci, scalping optimized
input int      Inp_MACD_Fast     = 12;         // MACD Fast Period - Scalping settings
input int      Inp_MACD_Slow     = 26;        // MACD Slow Period - Scalping settings
input int      Inp_MACD_Signal   = 9;         // MACD Signal Period - Faster signals

input group "═══ Volatility Analysis ═══"
input int      Inp_BB_Period     = 20;        // Bollinger Bands Period - More responsive
input double   Inp_BB_Deviation  = 2.0;       // Bollinger Bands Deviation

input group "═══ Volume Analysis ═══"
input bool     Inp_ShowVolume    = true;      // Show Volume Profile (NEW)
input int      Inp_VolumePeriod  = 20;        // Volume Lookback Period (NEW)
input double   Inp_VolumeThreshold = 1.5;     // High Volume Threshold (x Average) (NEW)

input group "═══ Liquidity Zones ═══"
input bool     Inp_ShowLiquidity = true;      // Show Liquidity Zones (NEW)
input int      Inp_LookbackBars  = 50;        // Swing High/Low Lookback (NEW)

input group "═══ Multi-Timeframe ═══"
input bool     Inp_ShowMTF       = true;      // Show MTF Trend Analysis (NEW)
input ENUM_TIMEFRAMES Inp_MTF1   = PERIOD_H1; // Higher Timeframe 1 (NEW)
input ENUM_TIMEFRAMES Inp_MTF2   = PERIOD_H4; // Higher Timeframe 2 (NEW)

input group "═══ Correlation Matrix ═══"
input string            Inp_Corr_Symbol1  = "XAUUSD";   // Correlation Symbol 1
input string            Inp_Corr_Symbol2  = "EURUSD";   // Correlation Symbol 2
input string            Inp_Corr_Symbol3  = "US30";     // Correlation Symbol 3
input int               Inp_Corr_Period   = 13;         // Correlation Period - Fibonacci, shorter
input ENUM_TIMEFRAMES   Inp_Corr_TF       = PERIOD_H1;  // Correlation Timeframe (H1+ recommended)

input group "═══ Session & Spread ═══"
input bool     Inp_ShowSessions  = true;      // Show Market Sessions
input bool     Inp_ShowSpread    = true;      // Show Current Spread
input double   Inp_MaxSpreadAlert= 0.0;       // Max Spread Alert (0=disabled, in points)

input group "═══ Scalping Execution Filters ═══"
input bool     Inp_UseADXFilter       = true;  // Block weak-trend entries
input double   Inp_MinSignalADX       = 18.0;  // Minimum ADX for entries
input bool     Inp_UseSpreadFilter    = true;  // Block entries on wide spreads
input int      Inp_MaxSignalSpread    = 300;    // Maximum spread for entries (points)
input bool     Inp_UseLiquidityFilter = true;  // Penalize entries into nearby opposing liquidity
input double   Inp_LiquidityBufferATR = 0.35;  // Distance buffer in ATR units
input int      Inp_LiquidityPenalty   = 20;    // Quality penalty near opposing liquidity

input group "═══ Visual Settings ═══"
input bool     Inp_ShowPivots    = true;      // Show Pivot Lines on Chart
input int      Inp_PanelX        = 20;        // Panel X Coordinate
input int      Inp_PanelY        = 40;        // Panel Y Coordinate
input color    Inp_BgColor       = C'31,41,55'; // Panel Background (gray-850)
input color    Inp_PanelColor    = C'17,24,39'; // Inner Panels (gray-900)
input color    Inp_TextColor     = C'243,244,246'; // Text Color

//--- HANDLES ---
int hRSI, hMACD, hADX, hATR, hEMAFast, hEMASlow, hBollinger;
int hEMAFast_H1, hEMASlow_H1;    // MTF H1 handles
int hEMAFast_H4, hEMASlow_H4;    // MTF H4 handles

//--- BUFFERS ---
double bRSI[], bMacdMain[], bMacdSig[], bADX[], bATR[], bEmaFast[], bEmaSlow[], bUpperBB[], bLowerBB[];
double bEmaFast_H1[], bEmaSlow_H1[];  // MTF H1 buffers
double bEmaFast_H4[], bEmaSlow_H4[];  // MTF H4 buffers

//--- GLOBALS ---
string prefix = "PRO_DASH_";
//--- Optimization Globals ---
datetime g_corr_time  = 0;
datetime g_pivot_time = 0;
datetime g_liquidity_time = 0;  // NEW: Liquidity update timer
double   g_corr1      = 0.0, g_corr2 = 0.0, g_corr3 = 0.0;
string   g_rsym1      = ""; // Resolved Symbol 1
string   g_rsym2      = ""; // Resolved Symbol 2
string   g_rsym3      = ""; // Resolved Symbol 3

//--- NEW: Liquidity Zone Structures ---
struct LiquidityZone
{
   double price;
   double strength;  // 0-100
   int    type;      // 1 = Resistance, -1 = Support
   datetime time;
};

LiquidityZone g_liquidityZones[];
int           g_liquidityCount = 0;

//--- NEW: Volume Analysis Globals ---
double g_avgVolume = 0.0;
double g_lastVolume = 0.0;
bool   g_highVolume = false;
double g_volumeRatio = 0.0;

//--- NEW: MTF Trend States ---
enum ENUM_TREND_STATE
{
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_NEUTRAL
};

ENUM_TREND_STATE g_trend_H1  = TREND_NEUTRAL;
ENUM_TREND_STATE g_trend_H4  = TREND_NEUTRAL;
datetime         g_lastSpreadAlertBar = 0;
double           g_nearestSupport = 0.0;
double           g_nearestResistance = 0.0;
bool             g_adxFilterPassed = true;
bool             g_spreadFilterPassed = true;
bool             g_liquidityFilterPassed = true;


//+------------------------------------------------------------------+
//| Forward Declarations                                             |
//+------------------------------------------------------------------+
color GetCorrColor(double val);
string ResolveSymbol(string inputSym);
bool   GetSymbolReturns(string symbol, int period, double &returns[]);
double CalculateCorrelation(const double &returnsA[], string symB, int period);
double CalculatePositionSize(double riskPercent, double atrValue, double multiplier);
void CreateInterface();
void UpdateUI(string signal, color sigColor, int quality, double adx, double lots, double sl, double tp,
              string s1, double c1, string s2, double c2, string s3, double c3);
void CreateRect(string name, int x, int y, int w, int h, color bg, color border);
void CreateLabel(string name, string text, int x, int y, color col, int size=10, bool bold=false);
void DrawHLine(string name, double price, color col, ENUM_LINE_STYLE style);
void UpdateCorrelationLabels(string s1, double c1, string s2, double c2, string s3, double c3);
string FormatCorrelationValue(double value);
string GetActiveSession();
int GetCurrentSpread();

//--- NEW Functions ---
void DetectLiquidityZones(int lookback);
void AnalyzeVolume(int period, double threshold);
void AnalyzeMTFTrends();
string TrendStateToString(ENUM_TREND_STATE state);
color TrendStateToColor(ENUM_TREND_STATE state);
int CalculateDynamicPanelHeight();
void ClearLiquidityObjects();
void SortLiquidityZonesByStrength();
void UpdateNearestLiquidityLevels(double currentPrice);
string FormatPriceValue(double price);


//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate input parameters (using library functions)
   int result;
   result = ValidatePeriod(Inp_RSI_Period, "RSI Period");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidatePeriod(Inp_ADX_Period, "ADX Period");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidatePeriod(Inp_EMA_Fast, "Fast EMA");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidatePeriod(Inp_EMA_Slow, "Slow EMA");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidatePeriod(Inp_ATR_Period, "ATR Period");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidatePeriod(Inp_BB_Period, "BB Period");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateDeviation(Inp_BB_Deviation, "BB Deviation");
   if(result != INIT_SUCCEEDED) return result;

   // Validate EMA relationship
   ValidateMAPeriods(Inp_EMA_Fast, Inp_EMA_Slow, "Fast EMA", "Slow EMA");

   // Validate Correlation Period
   result = ValidatePeriod(Inp_Corr_Period, "Correlation Period", 5, 500);
   if(result != INIT_SUCCEEDED) return result;

   // Validate risk parameters
   if(Inp_RiskPercent <= 0 || Inp_RiskPercent > 10)
   {
      Print("WARNING: Risk percent (", Inp_RiskPercent, "%) outside recommended range 0.1-10%");
   }

   if(Inp_ATR_Multiplier <= 0)
   {
      Print("ERROR: ATR Multiplier must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Inp_RR_Ratio <= 0)
   {
      Print("ERROR: Risk/Reward Ratio must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Inp_MinSignalADX < 0)
   {
      Print("ERROR: Min Signal ADX must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Inp_MaxSignalSpread < 0)
   {
      Print("ERROR: Max Signal Spread must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Inp_LiquidityBufferATR < 0)
   {
      Print("ERROR: Liquidity Buffer ATR must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Inp_LiquidityPenalty < 0)
   {
      Print("ERROR: Liquidity Penalty must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Validate MACD period relationship (fast must be less than slow)
   if(Inp_MACD_Fast >= Inp_MACD_Slow)
   {
      PrintFormat("WARNING: MACD Fast Period (%d) should be less than Slow Period (%d)",
                  Inp_MACD_Fast, Inp_MACD_Slow);
      // Don't fail initialization, just warn
   }

   if(Inp_MACD_Signal <= 0 || Inp_MACD_Signal >= Inp_MACD_Fast)
   {
      PrintFormat("WARNING: MACD Signal Period (%d) should be positive and less than Fast Period (%d)",
                  Inp_MACD_Signal, Inp_MACD_Fast);
   }

   // Validate Volume parameters (NEW)
   if(Inp_VolumePeriod < 5 || Inp_VolumePeriod > 100)
   {
      PrintFormat("WARNING: Volume Period (%d) outside recommended range 5-100", Inp_VolumePeriod);
   }

   // Validate Liquidity lookback (NEW)
   if(Inp_LookbackBars < 10 || Inp_LookbackBars > 200)
   {
      PrintFormat("WARNING: Liquidity Lookback (%d) outside recommended range 10-200", Inp_LookbackBars);
   }

   // Initialize indicator handles
   hRSI       = iRSI(NULL, 0, Inp_RSI_Period, PRICE_CLOSE);
   hMACD      = iMACD(NULL, 0, Inp_MACD_Fast, Inp_MACD_Slow, Inp_MACD_Signal, PRICE_CLOSE);
   hADX       = iADX(NULL, 0, Inp_ADX_Period);
   hATR       = iATR(NULL, 0, Inp_ATR_Period);
   hEMAFast   = iMA(NULL, 0, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hEMASlow   = iMA(NULL, 0, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hBollinger = iBands(NULL, 0, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE);

   // NEW: MTF handles
   if(Inp_ShowMTF)
   {
      hEMAFast_H1 = iMA(Symbol(), Inp_MTF1, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hEMASlow_H1 = iMA(Symbol(), Inp_MTF1, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      hEMAFast_H4 = iMA(Symbol(), Inp_MTF2, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      hEMASlow_H4 = iMA(Symbol(), Inp_MTF2, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   }

   // Validate handles (using library function)
   result = ValidateHandle(hRSI, "RSI");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hMACD, "MACD");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hADX, "ADX");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hATR, "ATR");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hEMAFast, "Fast EMA");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hEMASlow, "Slow EMA");
   if(result != INIT_SUCCEEDED) return result;

   result = ValidateHandle(hBollinger, "Bollinger Bands");
   if(result != INIT_SUCCEEDED) return result;

   // Validate MTF handles (NEW)
   if(Inp_ShowMTF)
   {
      result = ValidateHandle(hEMAFast_H1, "MTF H1 Fast EMA");
      if(result != INIT_SUCCEEDED) return result;
      
      result = ValidateHandle(hEMASlow_H1, "MTF H1 Slow EMA");
      if(result != INIT_SUCCEEDED) return result;
      
      result = ValidateHandle(hEMAFast_H4, "MTF H4 Fast EMA");
      if(result != INIT_SUCCEEDED) return result;
      
      result = ValidateHandle(hEMASlow_H4, "MTF H4 Slow EMA");
      if(result != INIT_SUCCEEDED) return result;
   }

   // Clean up old objects just in case
   DeleteObjectsByPrefix(prefix);

   // Resolve symbols once at initialization
   g_rsym1 = ResolveSymbol(Inp_Corr_Symbol1);
   g_rsym2 = ResolveSymbol(Inp_Corr_Symbol2);
   g_rsym3 = ResolveSymbol(Inp_Corr_Symbol3);

   // Initialize liquidity zones array (NEW)
   ArrayResize(g_liquidityZones, MathMax(20, Inp_LookbackBars * 2));

   // Create user interface
   CreateInterface();

   Print("Institutional Dashboard v3.20 initialized successfully");
   Print("[NEW] Volume Analysis: ", Inp_ShowVolume ? "Enabled" : "Disabled");
   Print("[NEW] Liquidity Zones: ", Inp_ShowLiquidity ? "Enabled" : "Disabled");
   Print("[NEW] MTF Analysis: ", Inp_ShowMTF ? "Enabled" : "Disabled");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(prefix);

   // Release handles using library function
   int handles[] = {hRSI, hMACD, hADX, hATR, hEMAFast, hEMASlow, hBollinger};
   ReleaseHandles(handles);

   // Release MTF handles (NEW)
   if(Inp_ShowMTF)
   {
      int mtf_handles[] = {hEMAFast_H1, hEMASlow_H1, hEMAFast_H4, hEMASlow_H4};
      ReleaseHandles(mtf_handles);
   }

   Print("Institutional Dashboard deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main Iteration Function                                          |
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
   // Check if we have enough data
   if(rates_total < MathMax(Inp_EMA_Slow, Inp_Corr_Period) + 10) return 0;

   //--- OPTIMIZATION: Update throttling (library function)
   if(!ShouldUpdateDashboard(OPT_UPDATE_INTERVAL_SECONDS))
      return(rates_total);

   // Use last closed bar [1] for stable signals that don't repaint during the current bar.
   int data_shift = 1;

   //--- Copy indicator buffers with enhanced error handling
   // If copy fails, we return rates_total to skip this tick but keep the indicator running.
   if(!SafeCopyBuffer(hRSI, 0, data_shift, 1, bRSI, "RSI")) return rates_total;
   if(!SafeCopyBuffer(hMACD, 0, data_shift, 1, bMacdMain, "MACD Main")) return rates_total;
   if(!SafeCopyBuffer(hMACD, 1, data_shift, 1, bMacdSig, "MACD Signal")) return rates_total;
   if(!SafeCopyBuffer(hADX, 0, data_shift, 1, bADX, "ADX")) return rates_total;
   if(!SafeCopyBuffer(hATR, 0, data_shift, 1, bATR, "ATR")) return rates_total;
   if(!SafeCopyBuffer(hEMAFast, 0, data_shift, 1, bEmaFast, "Fast EMA")) return rates_total;
   if(!SafeCopyBuffer(hEMASlow, 0, data_shift, 1, bEmaSlow, "Slow EMA")) return rates_total;
   if(!SafeCopyBuffer(hBollinger, 1, data_shift, 1, bUpperBB, "BB Upper")) return rates_total;
   if(!SafeCopyBuffer(hBollinger, 2, data_shift, 1, bLowerBB, "BB Lower")) return rates_total;

   // Copy MTF buffers (NEW)
   if(Inp_ShowMTF)
   {
      if(!SafeCopyBuffer(hEMAFast_H1, 0, data_shift, 1, bEmaFast_H1, "MTF H1 Fast")) return rates_total;
      if(!SafeCopyBuffer(hEMASlow_H1, 0, data_shift, 1, bEmaSlow_H1, "MTF H1 Slow")) return rates_total;
      if(!SafeCopyBuffer(hEMAFast_H4, 0, data_shift, 1, bEmaFast_H4, "MTF H4 Fast")) return rates_total;
      if(!SafeCopyBuffer(hEMASlow_H4, 0, data_shift, 1, bEmaSlow_H4, "MTF H4 Slow")) return rates_total;
   }

   // MQL5 passes the OnCalculate price/time arrays in FORWARD order by default
   // (index 0 = oldest bar, index rates_total-1 = newest/current bar).
   // ArraySetAsSeries() is explicitly forbidden on these const parameters.
   // Use forward-index arithmetic: newest-closed bar = rates_total-1-data_shift.
   double currentPrice = close[rates_total - 1 - data_shift];

   //=== SIGNAL GENERATION ===
   string signal = "NEUTRAL";
   color signalColor = C'107,114,128';
   int signalDirection = 0; // 1=BUY, -1=SELL, 0=NEUTRAL

   // EMA directional bias
   if(bEmaFast[0] > bEmaSlow[0])
      signalDirection = 1;
   else if(bEmaFast[0] < bEmaSlow[0])
      signalDirection = -1;

   //=== SIGNAL QUALITY (Weighted Algorithm) - FIXED: Prevent negative values ===
   double adx = bADX[0];
   double rsi = bRSI[0];
   double macdDelta = MathAbs(bMacdMain[0] - bMacdSig[0]);
   double emaDistance = MathAbs(bEmaFast[0] - bEmaSlow[0]);
   double atr = bATR[0];

   // Base quality of 20 - ensures some signal even in weak conditions
   int quality = 20;

   // ADX Trend Strength (weight: 35%) - Most important for trend confirmation
   if(adx > 15) quality += 10;
   if(adx > 20) quality += 10;
   if(adx > 30) quality += 10;
   if(adx > 40) quality += 5; // Bonus for very strong trend

   // MACD Momentum (weight: 25%) - Secondary confirmation
   // Normalize by ATR to make threshold work across different instruments
   double atrPriceRatio = (atr > 0) ? (macdDelta / atr) : 0;
   if(atrPriceRatio > 0.1) quality += 5;
   if(atrPriceRatio > 0.3) quality += 10;
   if(atrPriceRatio > 0.5) quality += 10;

   // EMA Spread (weight: 15%) - Measures trend conviction
   double emaSpreadRatio = (currentPrice > OPT_EPSILON) ? (emaDistance / currentPrice) : 0;
   if(emaSpreadRatio > 0.0001) quality += 5;
   if(emaSpreadRatio > 0.0005) quality += 5;
   if(emaSpreadRatio > 0.001) quality += 5;

   // RSI Neutrality Penalty (weight: 25%) - Overbought/oversold warning
   // Use a narrower neutral band (35-65) for better entries
   // FIXED: Reduced penalty to prevent negative quality
   double rsiNeutralDistance = MathAbs(rsi - 50);
   if(rsiNeutralDistance > 20) quality -= 5; // RSI > 70 or < 30
   if(rsiNeutralDistance > 30) quality -= 5; // RSI > 80 or < 20
   if(rsiNeutralDistance > 40) quality -= 5;  // RSI > 90 or < 10

   // NEW: Volume confirmation bonus
   if(Inp_ShowVolume && g_highVolume)
   {
      quality += 10; // High volume confirms signal
   }

   // NEW: MTF alignment bonus
   if(Inp_ShowMTF)
   {
      if(g_trend_H1 == TREND_BULLISH && signalDirection == 1) quality += 10;
      if(g_trend_H4 == TREND_BULLISH && signalDirection == 1) quality += 10;
      if(g_trend_H1 == TREND_BEARISH && signalDirection == -1) quality += 10;
      if(g_trend_H4 == TREND_BEARISH && signalDirection == -1) quality += 10;
   }

   // Scalp execution filters: wide spread, weak ADX, and opposing liquidity.
   int currentSpread = GetCurrentSpread();
   g_spreadFilterPassed = (!Inp_UseSpreadFilter || currentSpread <= Inp_MaxSignalSpread);
   g_adxFilterPassed = (!Inp_UseADXFilter || adx >= Inp_MinSignalADX);
   g_liquidityFilterPassed = true;

   if(Inp_UseLiquidityFilter && signalDirection != 0 && atr > OPT_EPSILON)
   {
      double liquidityBuffer = atr * Inp_LiquidityBufferATR;
      if(signalDirection == 1 && g_nearestResistance > 0.0 &&
         (g_nearestResistance - currentPrice) <= liquidityBuffer)
      {
         quality -= Inp_LiquidityPenalty;
         g_liquidityFilterPassed = false;
      }
      else if(signalDirection == -1 && g_nearestSupport > 0.0 &&
              (currentPrice - g_nearestSupport) <= liquidityBuffer)
      {
         quality -= Inp_LiquidityPenalty;
         g_liquidityFilterPassed = false;
      }
   }

   // Clamp quality to 0-100 range (prevents negative values)
   quality = MathMax(0, MathMin(100, quality));

   bool canTrade = (signalDirection != 0 && g_spreadFilterPassed && g_adxFilterPassed);
   if(canTrade)
   {
      if(signalDirection == 1)
      {
         signal = "BUY";
         signalColor = C'16,185,129';
      }
      else
      {
         signal = "SELL";
         signalColor = C'239,68,68';
      }

      if(quality < 45) signal = "WEAK " + signal;
      else if(quality > 75) signal = "STRONG " + signal;
   }
   else
   {
      signal = "NEUTRAL";
      signalColor = C'107,114,128';
   }

   //=== POSITION SIZING ===
   double slDist = atr * Inp_ATR_Multiplier;
   double entry = currentPrice;
   double slPrice = 0.0;
   double tpPrice = 0.0;
   double lotSize = 0.0;

   if(canTrade)
   {
      if(signalDirection == 1)
      {
         slPrice = entry - slDist;
         tpPrice = entry + (slDist * Inp_RR_Ratio);
      }
      else
      {
         slPrice = entry + slDist;
         tpPrice = entry - (slDist * Inp_RR_Ratio);
      }

      lotSize = CalculatePositionSize(Inp_RiskPercent, atr, Inp_ATR_Multiplier);
   }

   //=== PIVOT POINTS (Calculate once per day for performance) ===
   // FIXED: Use proper timezone handling with TimeCurrent() for server time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);  // FIXED: Use server time, not bar time
   datetime currentDayStart = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(Inp_ShowPivots && g_pivot_time != currentDayStart)
   {
      g_pivot_time = currentDayStart; // Update time first to prevent re-entry on failure

      double hHigh[1], hLow[1], hClose[1];
      // FIXED: Use index 1 for yesterday's data (correct)
      if(CopyHigh(NULL, PERIOD_D1, 1, 1, hHigh) > 0 &&
         CopyLow(NULL, PERIOD_D1, 1, 1, hLow) > 0 &&
         CopyClose(NULL, PERIOD_D1, 1, 1, hClose) > 0)
      {
         // Validate pivot data
         if(hHigh[0] > 0 && hLow[0] > 0 && hClose[0] > 0 &&
            hHigh[0] != EMPTY_VALUE && hLow[0] != EMPTY_VALUE && hClose[0] != EMPTY_VALUE)
         {
            double pp = (hHigh[0] + hLow[0] + hClose[0]) / 3.0;
            double r1 = (2 * pp) - hLow[0];
            double s1 = (2 * pp) - hHigh[0];

            DrawHLine("P_PP", pp, C'251,191,36', STYLE_DASH); // Yellow
            DrawHLine("P_R1", r1, C'239,68,68', STYLE_DOT);   // Red
            DrawHLine("P_S1", s1, C'16,185,129', STYLE_DOT);  // Green
         }
      }
   }

   //=== CORRELATION CALCULATIONS (Optimized - only on new bar) ===
   datetime currentBarTime = time[rates_total-1];

   // use global g_corr_time (declared earlier) instead of an extra static
   // variable; this also keeps the global variable from being unused.
   if(g_corr_time != currentBarTime)
   {
      g_corr_time = currentBarTime;

      double baseReturns[];
      if(GetSymbolReturns(Symbol(), Inp_Corr_Period, baseReturns))
      {
         g_corr1 = CalculateCorrelation(baseReturns, g_rsym1, Inp_Corr_Period);
         g_corr2 = CalculateCorrelation(baseReturns, g_rsym2, Inp_Corr_Period);
         g_corr3 = CalculateCorrelation(baseReturns, g_rsym3, Inp_Corr_Period);
      }
      else
      {
         g_corr1 = 0.0; g_corr2 = 0.0; g_corr3 = 0.0;
      }
   }

   //=== NEW: VOLUME ANALYSIS ===
   if(Inp_ShowVolume)
   {
      AnalyzeVolume(Inp_VolumePeriod, Inp_VolumeThreshold);
   }

   //=== NEW: LIQUIDITY ZONES DETECTION ===
   if(Inp_ShowLiquidity)
   {
      datetime liquidityBarTime = time[rates_total - 1 - data_shift];
      if(g_liquidity_time != liquidityBarTime)
      {
         g_liquidity_time = liquidityBarTime;
         DetectLiquidityZones(Inp_LookbackBars);
      }
   }
   else
   {
      g_nearestSupport = 0.0;
      g_nearestResistance = 0.0;
      g_liquidityCount = 0;
      ClearLiquidityObjects();
   }

   //=== NEW: MTF TREND ANALYSIS ===
   if(Inp_ShowMTF)
   {
      AnalyzeMTFTrends();
   }

   //=== SPREAD ALERT ===
   datetime closedBarTime = time[rates_total - 1 - data_shift];
   if(Inp_MaxSpreadAlert > 0 && currentSpread > Inp_MaxSpreadAlert && g_lastSpreadAlertBar != closedBarTime)
   {
      Alert("High spread detected: ", currentSpread, " points (threshold: ", Inp_MaxSpreadAlert, ")");
      g_lastSpreadAlertBar = closedBarTime;
   }

   //=== UPDATE USER INTERFACE (Throttled for performance) ===
   static uint lastUIUpdate = 0;
   if(GetTickCount() - lastUIUpdate >= UI_UPDATE_THROTTLE_MS)
   {
      UpdateUI(signal, signalColor, quality, adx, lotSize, slPrice, tpPrice,
               g_rsym1 != "" ? g_rsym1 : Inp_Corr_Symbol1, g_corr1,
               g_rsym2 != "" ? g_rsym2 : Inp_Corr_Symbol2, g_corr2,
               g_rsym3 != "" ? g_rsym3 : Inp_Corr_Symbol3, g_corr3);
      
      ChartRedraw(0);
      lastUIUpdate = GetTickCount();
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| NEW: Detect Liquidity Zones (Swing Highs/Lows)                   |
//+------------------------------------------------------------------+
void DetectLiquidityZones(int lookback)
{
   double high[], low[];
   int barsNeeded = lookback + 2;

   if(ArraySize(g_liquidityZones) < (lookback * 2))
      ArrayResize(g_liquidityZones, MathMax(20, lookback * 2));

   if(CopyHigh(NULL, 0, 1, barsNeeded, high) < barsNeeded)
   {
      g_liquidityCount = 0;
      g_nearestSupport = 0.0;
      g_nearestResistance = 0.0;
      ClearLiquidityObjects();
      return;
   }
   if(CopyLow(NULL, 0, 1, barsNeeded, low) < barsNeeded)
   {
      g_liquidityCount = 0;
      g_nearestSupport = 0.0;
      g_nearestResistance = 0.0;
      ClearLiquidityObjects();
      return;
   }

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   g_liquidityCount = 0;
   double minGap = MathMax(SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10.0, OPT_EPSILON);

   // Detect swing highs (resistance)
   for(int i = 1; i < lookback - 1; i++)
   {
      if(high[i] > high[i-1] && high[i] > high[i+1])
      {
         bool isDuplicate = false;
         for(int j = 0; j < g_liquidityCount; j++)
         {
            if(g_liquidityZones[j].type == 1 && MathAbs(g_liquidityZones[j].price - high[i]) <= minGap)
            {
               if(g_liquidityZones[j].strength < (100.0 - (i * (100.0 / lookback))))
                  g_liquidityZones[j].strength = 100.0 - (i * (100.0 / lookback));
               isDuplicate = true;
               break;
            }
         }

         if(!isDuplicate && g_liquidityCount < ArraySize(g_liquidityZones))
         {
            g_liquidityZones[g_liquidityCount].price = high[i];
            g_liquidityZones[g_liquidityCount].strength = 100.0 - (i * (100.0 / lookback));
            g_liquidityZones[g_liquidityCount].type = 1;  // Resistance
            g_liquidityZones[g_liquidityCount].time = TimeCurrent();
            g_liquidityCount++;
         }
      }
   }

   // Detect swing lows (support)
   for(int i = 1; i < lookback - 1; i++)
   {
      if(low[i] < low[i-1] && low[i] < low[i+1])
      {
         bool isDuplicate = false;
         for(int j = 0; j < g_liquidityCount; j++)
         {
            if(g_liquidityZones[j].type == -1 && MathAbs(g_liquidityZones[j].price - low[i]) <= minGap)
            {
               if(g_liquidityZones[j].strength < (100.0 - (i * (100.0 / lookback))))
                  g_liquidityZones[j].strength = 100.0 - (i * (100.0 / lookback));
               isDuplicate = true;
               break;
            }
         }

         if(!isDuplicate && g_liquidityCount < ArraySize(g_liquidityZones))
         {
            g_liquidityZones[g_liquidityCount].price = low[i];
            g_liquidityZones[g_liquidityCount].strength = 100.0 - (i * (100.0 / lookback));
            g_liquidityZones[g_liquidityCount].type = -1;  // Support
            g_liquidityZones[g_liquidityCount].time = TimeCurrent();
            g_liquidityCount++;
         }
      }
   }

   SortLiquidityZonesByStrength();
   UpdateNearestLiquidityLevels(SymbolInfoDouble(Symbol(), SYMBOL_BID));
   ClearLiquidityObjects();

   int supportDrawn = 0;
   int resistanceDrawn = 0;
   for(int i = 0; i < g_liquidityCount; i++)
   {
      if(g_liquidityZones[i].type == -1 && supportDrawn >= 3)
         continue;
      if(g_liquidityZones[i].type == 1 && resistanceDrawn >= 3)
         continue;

      string name = StringFormat("Liq_%s_%d",
                                 g_liquidityZones[i].type == 1 ? "RES" : "SUP",
                                 g_liquidityZones[i].type == 1 ? resistanceDrawn : supportDrawn);
      color zoneColor = (g_liquidityZones[i].type == 1) ? C'239,68,68' : C'16,185,129';
      DrawHLine(name, g_liquidityZones[i].price, zoneColor, STYLE_DOT);

      if(g_liquidityZones[i].type == 1)
         resistanceDrawn++;
      else
         supportDrawn++;

      if(supportDrawn >= 3 && resistanceDrawn >= 3)
         break;
   }
}

//+------------------------------------------------------------------+
//| NEW: Analyze Volume Profile                                      |
//+------------------------------------------------------------------+
void AnalyzeVolume(int period, double threshold)
{
   long volumeData[];
   if(CopyTickVolume(NULL, 0, 1, period, volumeData) < period)
   {
      g_avgVolume = 0.0;
      g_lastVolume = 0.0;
      g_volumeRatio = 0.0;
      g_highVolume = false;
      return;
   }
   
   ArraySetAsSeries(volumeData, true);
   
   // Calculate average volume
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      sum += (double)volumeData[i];
   }
   g_avgVolume = sum / period;
   g_lastVolume = (double)volumeData[0];
   g_volumeRatio = (g_avgVolume > OPT_EPSILON) ? (g_lastVolume / g_avgVolume) : 0.0;
   
   // Check for high volume
   g_highVolume = (g_volumeRatio > threshold);
}

//+------------------------------------------------------------------+
//| NEW: Analyze Multi-Timeframe Trends                              |
//+------------------------------------------------------------------+
void AnalyzeMTFTrends()
{
   // H1 Trend
   if(bEmaFast_H1[0] > bEmaSlow_H1[0])
      g_trend_H1 = TREND_BULLISH;
   else if(bEmaFast_H1[0] < bEmaSlow_H1[0])
      g_trend_H1 = TREND_BEARISH;
   else
      g_trend_H1 = TREND_NEUTRAL;

   // H4 Trend
   if(bEmaFast_H4[0] > bEmaSlow_H4[0])
      g_trend_H4 = TREND_BULLISH;
   else if(bEmaFast_H4[0] < bEmaSlow_H4[0])
      g_trend_H4 = TREND_BEARISH;
   else
      g_trend_H4 = TREND_NEUTRAL;
}

//+------------------------------------------------------------------+
//| NEW: Trend State to String                                       |
//+------------------------------------------------------------------+
string TrendStateToString(ENUM_TREND_STATE state)
{
   switch(state)
   {
      case TREND_BULLISH:  return "BULL";
      case TREND_BEARISH:  return "BEAR";
      default:             return "NEUTRAL";
   }
}

//+------------------------------------------------------------------+
//| NEW: Trend State to Color                                        |
//+------------------------------------------------------------------+
color TrendStateToColor(ENUM_TREND_STATE state)
{
   switch(state)
   {
      case TREND_BULLISH:  return C'16,185,129';   // Green
      case TREND_BEARISH:  return C'239,68,68';    // Red
      default:             return C'156,163,175';  // Gray
   }
}

//+------------------------------------------------------------------+
//| NEW: Calculate Dynamic Panel Height                              |
//+------------------------------------------------------------------+
int CalculateDynamicPanelHeight()
{
   int height = 480;  // Base height
   
   if(Inp_ShowSessions) height += 25;
   if(Inp_ShowSpread) height += 25;
   if(Inp_UseADXFilter || Inp_UseSpreadFilter || Inp_UseLiquidityFilter) height += 25;
   if(Inp_ShowVolume) height += 30;
   if(Inp_ShowLiquidity) height += 45;
   if(Inp_ShowMTF) height += 50;
   
   return height;
}

//+------------------------------------------------------------------+
//| NEW: Remove previous liquidity lines                             |
//+------------------------------------------------------------------+
void ClearLiquidityObjects()
{
   for(int i = 0; i < 3; i++)
   {
      ObjectDelete(0, prefix + StringFormat("Liq_SUP_%d", i));
      ObjectDelete(0, prefix + StringFormat("Liq_RES_%d", i));
   }
}

//+------------------------------------------------------------------+
//| NEW: Sort liquidity zones from strongest to weakest              |
//+------------------------------------------------------------------+
void SortLiquidityZonesByStrength()
{
   for(int i = 0; i < g_liquidityCount - 1; i++)
   {
      for(int j = i + 1; j < g_liquidityCount; j++)
      {
         if(g_liquidityZones[j].strength > g_liquidityZones[i].strength)
         {
            LiquidityZone tmp = g_liquidityZones[i];
            g_liquidityZones[i] = g_liquidityZones[j];
            g_liquidityZones[j] = tmp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| NEW: Track nearest support and resistance                        |
//+------------------------------------------------------------------+
void UpdateNearestLiquidityLevels(double currentPrice)
{
   g_nearestSupport = 0.0;
   g_nearestResistance = 0.0;

   for(int i = 0; i < g_liquidityCount; i++)
   {
      double levelPrice = g_liquidityZones[i].price;
      if(g_liquidityZones[i].type == -1 && levelPrice <= currentPrice)
      {
         if(g_nearestSupport <= 0.0 || levelPrice > g_nearestSupport)
            g_nearestSupport = levelPrice;
      }

      if(g_liquidityZones[i].type == 1 && levelPrice >= currentPrice)
      {
         if(g_nearestResistance <= 0.0 || levelPrice < g_nearestResistance)
            g_nearestResistance = levelPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| NEW: Format dashboard prices                                     |
//+------------------------------------------------------------------+
string FormatPriceValue(double price)
{
   if(price <= 0.0)
      return "---";

   return DoubleToString(price, _Digits);
}

//+------------------------------------------------------------------+
//| Helper: Resolve Symbol Name ( Handle Suffixes)                    |
//+------------------------------------------------------------------+
string ResolveSymbol(string inputSym)
{
   if(inputSym == "" || inputSym == "None") return "";

   // 1. Direct match check
   if(SymbolInfoInteger(inputSym, SYMBOL_VISIBLE)) return inputSym;
   if(SymbolSelect(inputSym, true)) return inputSym;

   string chartSym = Symbol();
   string trySym = "";

   // 2. Check if current chart symbol contains the requested symbol as prefix
   if(StringFind(chartSym, inputSym) == 0) {
      string suffix = StringSubstr(chartSym, StringLen(inputSym));
      trySym = inputSym + suffix;
      if(SymbolSelect(trySym, true)) return trySym;
   }

   // 3. Try standard suffix extraction (common length 6 for pairs).
   // Use >= 6 to also handle exact-6-char base symbols (e.g. EURUSD) that
   // may carry a broker suffix when the chart symbol is longer.
   if(StringLen(chartSym) >= 6) {
      string suffix = StringSubstr(chartSym, 6);
      trySym = inputSym + suffix;
      if(SymbolSelect(trySym, true)) return trySym;
   }

   // Not found
   Print("Warning: Could not resolve symbol: ", inputSym);
   return "";
}

//+------------------------------------------------------------------+
//| Get Returns for a Symbol                                         |
//+------------------------------------------------------------------+
bool GetSymbolReturns(string symbol, int period, double &returns[])
{
   if(symbol == "" || symbol == "None" || period <= 0) return false;

   // Ensure symbol is selected in Market Watch
   long isSelected = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT, isSelected) || isSelected == 0) {
       if(!SymbolSelect(symbol, true)) {
          PrintFormat("Warning: Could not select symbol %s", symbol);
          return false;
       }
   }

   double closes[];
   int barsNeeded = period + 1;
   if(barsNeeded < 2) barsNeeded = 2; // Minimum 2 bars needed

   // Copy from bar 1 (last closed bar) to avoid repainting
   // Use the dedicated correlation timeframe so that correlation remains
   // meaningful regardless of the chart's current timeframe (e.g. M1).
   int copied = CopyClose(symbol, Inp_Corr_TF, 1, barsNeeded, closes);
   if(copied < barsNeeded) {
      PrintFormat("Warning: Could not copy %d bars for %s (got %d)", barsNeeded, symbol, copied);
      return false;
   }

   // Validate copied data - check for NULL/EMPTY_VALUE/invalid prices
   for(int i = 0; i < copied; i++) {
      if(closes[i] == EMPTY_VALUE || closes[i] <= 0 || closes[i] != closes[i]) { // NaN check
         PrintFormat("Warning: Invalid close price at bar %d for %s", i, symbol);
         return false;
      }
   }

   ArraySetAsSeries(closes, true);
   ArrayResize(returns, period);

   for(int i = 0; i < period; i++) {
      double prev = closes[i+1];
      double curr = closes[i];

      // Prevent division by zero and handle invalid values
      if(MathAbs(prev) > OPT_EPSILON && prev != EMPTY_VALUE && curr != EMPTY_VALUE &&
         prev == prev && curr == curr) // Additional NaN check
         returns[i] = (curr - prev) / prev;
      else
         returns[i] = 0;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Correlation against base returns                       |
//+------------------------------------------------------------------+
double CalculateCorrelation(const double &returnsA[], string symB, int period)
{
   if(symB == "" || symB == "None") return 0.0;
   if(symB == Symbol()) return 1.0;

   // Get returns for symB
   double returnsB[];
   if(!GetSymbolReturns(symB, period, returnsB)) return 0.0;

   // Calculate Pearson Correlation Coefficient
   double sumA = 0, sumB = 0, sumAB = 0, sumASq = 0, sumBSq = 0;

   for(int i = 0; i < period; i++) {
      double rA = returnsA[i];
      double rB = returnsB[i];

      sumA   += rA;
      sumB   += rB;
      sumAB  += rA * rB;
      sumASq += rA * rA;
      sumBSq += rB * rB;
   }

   double varA = (period * sumASq) - (sumA * sumA);
   double varB = (period * sumBSq) - (sumB * sumB);

   // Ensure variances are non-negative (handle precision issues)
   if(varA < 0) varA = 0;
   if(varB < 0) varB = 0;

   double denominator = MathSqrt(varA * varB);

   if(denominator < OPT_EPSILON) return 0.0;

   double correlation = ((period * sumAB) - (sumA * sumB)) / denominator;

   // Clamp correlation
   return MathMax(-1.0, MathMin(1.0, correlation));
}

//+------------------------------------------------------------------+
//| Calculate Position Size based on risk management                 |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double atrValue, double multiplier)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance <= 0) return 0.01;

   double riskAmount = accountBalance * (riskPercent / 100.0);
   double slDistance = atrValue * multiplier;

   if(slDistance <= 0) return 0.01;

   double tickSize  = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   // SYMBOL_TRADE_TICK_VALUE is returned in the account currency by the broker.
   // Use SYMBOL_TRADE_TICK_VALUE_PROFIT for profit calculation consistency if available.
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE_PROFIT);

   if(tickSize <= 0 || tickValue <= 0) {
      PrintFormat("Warning: Could not get Tick Size/Value for %s. Position size calculation may be inaccurate.", Symbol());
      // Return minimum lot size as a safe default
      return SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   }

   double pointsRisk = slDistance / tickSize;
   double lotSize = riskAmount / (pointsRisk * tickValue);

   // Normalize to volume step
   double volStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(volStep > 0)
   {
      lotSize = MathFloor(lotSize / volStep) * volStep;
      // Determine digits from step
      int digits = 0;
      if(volStep < 0.1) digits = 2;
      else if(volStep < 1.0) digits = 1;
      lotSize = NormalizeDouble(lotSize, digits);
   }
   else
   {
      lotSize = NormalizeDouble(lotSize, 2);
   }

   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   return lotSize;
}

//+------------------------------------------------------------------+
//| Get Active Market Session                                        |
//+------------------------------------------------------------------+
string GetActiveSession()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   int hour = dt.hour;
   int dayOfWeek = dt.day_of_week;

   // Weekend check
   if(dayOfWeek == 0 || dayOfWeek == 6) return "WEEKEND";

   // Session times in GMT (server time assumed to be GMT+2/3 for MT5)
   // Adjusted for typical MT5 server time (EET/EEST)
   bool isTokyo = (hour >= 2 && hour < 11);
   bool isLondon = (hour >= 9 && hour < 18);
   bool isNY = (hour >= 15 && hour < 24);
   bool isSydney = (hour >= 23 || hour < 8);

   if(isLondon && isNY) return "LONDON-NY OVERLAP";
   if(isLondon) return "LONDON";
   if(isNY) return "NEW YORK";
   if(isTokyo) return "TOKYO";
   if(isSydney) return "SYDNEY";

   return "OFF-HOURS";
}

//+------------------------------------------------------------------+
//| Get Current Spread in Points                                     |
//+------------------------------------------------------------------+
int GetCurrentSpread()
{
   long spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   return (int)spread;
}

//+------------------------------------------------------------------+
//| Create User Interface                                            |
//+------------------------------------------------------------------+
void CreateInterface()
{
   int panelX = Inp_PanelX;
   int panelY = Inp_PanelY;
   int panelWidth = 280;  // Increased width for new features
   int panelHeight = CalculateDynamicPanelHeight();  // NEW: Dynamic height

   // Main background panel
   CreateRect("Bg", panelX, panelY, panelWidth, panelHeight, Inp_BgColor, C'55,65,81');
   CreateLabel("Title", "INSTITUTIONAL ANALYTICS v3.20", panelX+15, panelY+15, DASH_CLR_WHITE, 10, true);

   // Signal Panel
   int currentY = panelY + 45;
   CreateRect("Panel1", panelX+10, currentY, panelWidth-20, 70, Inp_PanelColor, DASH_CLR_NONE);
   CreateLabel("SigLbl", "ALGO SIGNAL", panelX+20, currentY+10, C'156,163,175');
   CreateLabel("SigVal", "WAITING", panelX+20, currentY+30, DASH_CLR_WHITE, 14, true);

   // Quality Panel
   currentY += 80;
   CreateLabel("QualLbl", "SIGNAL QUALITY", panelX+20, currentY, C'156,163,175');
   CreateLabel("QualVal", "0/100", panelX+panelWidth-50, currentY, DASH_CLR_WHITE, 8, true);
   currentY += 20;
   CreateRect("MeterBg", panelX+20, currentY, panelWidth-40, 8, C'55,65,81', DASH_CLR_NONE);
   CreateRect("MeterFill", panelX+20, currentY, 0, 8, C'16,185,129', DASH_CLR_NONE);

   // ADX Display
   currentY += 25;
   CreateLabel("AdxLbl", "ADX Trend:", panelX+20, currentY, C'156,163,175');
   CreateLabel("AdxVal", "--", panelX+100, currentY, DASH_CLR_WHITE, 8, true);

   if(Inp_UseADXFilter || Inp_UseSpreadFilter || Inp_UseLiquidityFilter)
   {
      currentY += 20;
      CreateLabel("FilterLbl", "Filter:", panelX+20, currentY, C'156,163,175');
      CreateLabel("FilterVal", "PASS", panelX+80, currentY, C'16,185,129', 8, true);
   }

   // Session Display (if enabled)
   currentY += 25;
   if(Inp_ShowSessions)
   {
      CreateLabel("SessionLbl", "Session:", panelX+20, currentY, C'156,163,175');
      CreateLabel("SessionVal", GetActiveSession(), panelX+80, currentY, C'16,185,129', 8, true);
      currentY += 25;
   }

   // Spread Display (if enabled)
   if(Inp_ShowSpread)
   {
      CreateLabel("SpreadLbl", "Spread:", panelX+20, currentY, C'156,163,175');
      CreateLabel("SpreadVal", "--- pts", panelX+80, currentY, DASH_CLR_WHITE, 8, true);
      currentY += 25;
   }

   // NEW: Volume Display (if enabled)
   if(Inp_ShowVolume)
   {
      CreateLabel("VolumeLbl", "Volume:", panelX+20, currentY, C'156,163,175');
      CreateLabel("VolumeVal", "NORMAL", panelX+80, currentY, DASH_CLR_WHITE, 8, true);
      CreateLabel("VolumeAvg", "x0.00", panelX+150, currentY, C'156,163,175', 7);
      currentY += 25;
   }

   if(Inp_ShowLiquidity)
   {
      CreateLabel("LiqLbl", "Liquidity:", panelX+20, currentY, C'156,163,175');
      CreateLabel("LiqBiasVal", "WAIT", panelX+80, currentY, DASH_CLR_WHITE, 8, true);
      currentY += 20;
      CreateLabel("LiqSupLbl", "SUP:", panelX+20, currentY, C'156,163,175', 7);
      CreateLabel("LiqSupVal", "---", panelX+50, currentY, C'16,185,129', 7, true);
      CreateLabel("LiqResLbl", "RES:", panelX+140, currentY, C'156,163,175', 7);
      CreateLabel("LiqResVal", "---", panelX+170, currentY, C'239,68,68', 7, true);
      currentY += 25;
   }

   // NEW: MTF Trend Display (if enabled)
   if(Inp_ShowMTF)
   {
      CreateLabel("MTFTitle", "MTF TREND:", panelX+20, currentY, C'156,163,175');
      currentY += 20;
      CreateLabel("MTF_H1_Label", "H1:", panelX+20, currentY, C'156,163,175', 7);
      CreateLabel("MTF_H1_Val", "NEUTRAL", panelX+50, currentY, DASH_CLR_WHITE, 7);
      CreateLabel("MTF_H4_Label", "H4:", panelX+120, currentY, C'156,163,175', 7);
      CreateLabel("MTF_H4_Val", "NEUTRAL", panelX+150, currentY, DASH_CLR_WHITE, 7);
      currentY += 25;
   }

   // Position Size Panel
   currentY += 5;
   CreateRect("Panel2", panelX+10, currentY, panelWidth-20, 90, Inp_PanelColor, DASH_CLR_NONE);
   CreateLabel("SizeLbl", "POSITION SIZE", panelX+20, currentY+10, C'156,163,175');
   CreateLabel("RiskLbl", StringFormat("Risk: %.1f%%", Inp_RiskPercent), panelX+panelWidth-90, currentY+10, C'156,163,175', 8);

   CreateLabel("LotVal", "0.00 LOTS", panelX+20, currentY+35, DASH_CLR_WHITE, 16, true);
   CreateLabel("DistLbl", "(Based on ATR Stop)", panelX+20, currentY+65, C'107,114,128', 8);

   // Stop Loss & Take Profit
   currentY += 100;
   CreateLabel("TpVal", "TP: ---", panelX+20, currentY, C'16,185,129');
   CreateLabel("SlVal", "SL: ---", panelX+140, currentY, C'239,68,68');

   // Correlation Panel
   currentY += 30;
   CreateRect("Panel3", panelX+10, currentY, panelWidth-20, 120, Inp_PanelColor, DASH_CLR_NONE);
   CreateLabel("CorrTitle", StringFormat("CORRELATIONS (%d)", Inp_Corr_Period), panelX+20, currentY+10, C'156,163,175');

   // Correlation Labels
   currentY += 30;
   CreateLabel("C1Name", Inp_Corr_Symbol1, panelX+20, currentY, DASH_CLR_WHITE);
   CreateLabel("C1Val", "0.000", panelX+100, currentY, DASH_CLR_WHITE);
   currentY += 20;
   CreateLabel("C2Name", Inp_Corr_Symbol2, panelX+20, currentY, DASH_CLR_WHITE);
   CreateLabel("C2Val", "0.000", panelX+100, currentY, DASH_CLR_WHITE);
   currentY += 20;
   CreateLabel("C3Name", Inp_Corr_Symbol3, panelX+20, currentY, DASH_CLR_WHITE);
   CreateLabel("C3Val", "0.000", panelX+100, currentY, DASH_CLR_WHITE);

   // Correlation Legend
   currentY += 30;
   CreateLabel("CorrLegend1", "Strong +", panelX+20, currentY, C'16,185,129', 7);
   CreateLabel("CorrLegend2", "Neutral", panelX+80, currentY, C'156,163,175', 7);
   CreateLabel("CorrLegend3", "Strong -", panelX+140, currentY, C'239,68,68', 7);
}

//+------------------------------------------------------------------+
//| Update User Interface Elements                                   |
//+------------------------------------------------------------------+
void UpdateUI(string signal, color sigColor, int quality, double adx, double lots, double sl, double tp,
              string s1, double c1, string s2, double c2, string s3, double c3)
{
   // Update Signal
   ObjectSetString(0, prefix+"SigVal", OBJPROP_TEXT, signal);
   ObjectSetInteger(0, prefix+"SigVal", OBJPROP_COLOR, sigColor);

   // Update Quality Meter
   ObjectSetString(0, prefix+"QualVal", OBJPROP_TEXT, IntegerToString(quality)+"/100");

   // Dynamically get width from the background rectangle for robustness
   int meterBgWidth = (int)ObjectGetInteger(0, prefix+"MeterBg", OBJPROP_XSIZE);
   int currentWidth = (int)((quality / 100.0) * meterBgWidth);
   ObjectSetInteger(0, prefix+"MeterFill", OBJPROP_XSIZE, currentWidth);

   // Color based on quality
   color meterColor = C'239,68,68'; // Red
   if(quality > 40) meterColor = C'251,191,36'; // Yellow
   if(quality > 70) meterColor = C'16,185,129'; // Green
   ObjectSetInteger(0, prefix+"MeterFill", OBJPROP_BGCOLOR, meterColor);

   // Update ADX
   string adxText = DoubleToString(adx, 1);
   adxText += (adx > 20) ? " (Trend)" : " (Range)"; // Lower threshold for scalping
   ObjectSetString(0, prefix+"AdxVal", OBJPROP_TEXT, adxText);
   ObjectSetInteger(0, prefix+"AdxVal", OBJPROP_COLOR, (adx > 20 ? C'16,185,129' : C'156,163,175'));

   if(Inp_UseADXFilter || Inp_UseSpreadFilter || Inp_UseLiquidityFilter)
   {
      string filterText = "PASS";
      color filterColor = C'16,185,129';
      if(!g_spreadFilterPassed)
      {
         filterText = "BLOCK SPREAD";
         filterColor = C'239,68,68';
      }
      else if(!g_adxFilterPassed)
      {
         filterText = "BLOCK ADX";
         filterColor = C'239,68,68';
      }
      else if(!g_liquidityFilterPassed)
      {
         filterText = "WARN LIQ";
         filterColor = C'251,191,36';
      }

      ObjectSetString(0, prefix+"FilterVal", OBJPROP_TEXT, filterText);
      ObjectSetInteger(0, prefix+"FilterVal", OBJPROP_COLOR, filterColor);
   }

   // Update Session (if enabled)
   if(Inp_ShowSessions)
   {
      string session = GetActiveSession();
      ObjectSetString(0, prefix+"SessionVal", OBJPROP_TEXT, session);
      // Color coding for sessions
      color sessionColor = C'156,163,175'; // Gray default
      if(session == "LONDON-NY OVERLAP") sessionColor = C'16,185,129'; // Green - best time
      else if(session == "LONDON" || session == "NEW YORK") sessionColor = C'251,191,36'; // Yellow - good time
      else if(session == "WEEKEND") sessionColor = C'239,68,68'; // Red - closed
      ObjectSetInteger(0, prefix+"SessionVal", OBJPROP_COLOR, sessionColor);
   }

   // Update Spread (if enabled)
   if(Inp_ShowSpread)
   {
      int spread = GetCurrentSpread();
      ObjectSetString(0, prefix+"SpreadVal", OBJPROP_TEXT, StringFormat("%d pts", spread));
      // Color based on spread size (warning if high)
      color spreadColor = DASH_CLR_WHITE;
      if(Inp_MaxSpreadAlert > 0 && spread > Inp_MaxSpreadAlert) spreadColor = C'239,68,68'; // Red if exceeds threshold
      else if(spread > 50) spreadColor = C'251,191,36'; // Yellow if moderately high
      ObjectSetInteger(0, prefix+"SpreadVal", OBJPROP_COLOR, spreadColor);
   }

   // NEW: Update Volume (if enabled)
   if(Inp_ShowVolume)
   {
      string volStatus = g_highVolume ? "HIGH" : "NORMAL";
      color volColor = g_highVolume ? C'251,191,36' : DASH_CLR_WHITE;
      ObjectSetString(0, prefix+"VolumeVal", OBJPROP_TEXT, volStatus);
      ObjectSetInteger(0, prefix+"VolumeVal", OBJPROP_COLOR, volColor);
      ObjectSetString(0, prefix+"VolumeAvg", OBJPROP_TEXT, "x" + DoubleToString(g_volumeRatio, 2));
   }

   if(Inp_ShowLiquidity)
   {
      string liquidityBias = "RANGE";
      color liquidityColor = C'156,163,175';

      if(g_nearestSupport > 0.0 && g_nearestResistance <= 0.0)
      {
         liquidityBias = "BREAKOUT";
         liquidityColor = C'16,185,129';
      }
      else if(g_nearestResistance > 0.0 && g_nearestSupport <= 0.0)
      {
         liquidityBias = "REJECT";
         liquidityColor = C'239,68,68';
      }
      else if(g_nearestSupport > 0.0 && g_nearestResistance > 0.0)
      {
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double supportDistance = MathAbs(bid - g_nearestSupport);
         double resistanceDistance = MathAbs(g_nearestResistance - bid);
         if(supportDistance < resistanceDistance)
         {
            liquidityBias = "SUPPORT";
            liquidityColor = C'16,185,129';
         }
         else if(resistanceDistance < supportDistance)
         {
            liquidityBias = "RESIST";
            liquidityColor = C'239,68,68';
         }
      }

      ObjectSetString(0, prefix+"LiqBiasVal", OBJPROP_TEXT, liquidityBias);
      ObjectSetInteger(0, prefix+"LiqBiasVal", OBJPROP_COLOR, liquidityColor);
      ObjectSetString(0, prefix+"LiqSupVal", OBJPROP_TEXT, FormatPriceValue(g_nearestSupport));
      ObjectSetString(0, prefix+"LiqResVal", OBJPROP_TEXT, FormatPriceValue(g_nearestResistance));
   }

   // NEW: Update MTF Trends (if enabled)
   if(Inp_ShowMTF)
   {
      ObjectSetString(0, prefix+"MTF_H1_Val", OBJPROP_TEXT, TrendStateToString(g_trend_H1));
      ObjectSetInteger(0, prefix+"MTF_H1_Val", OBJPROP_COLOR, TrendStateToColor(g_trend_H1));
      ObjectSetString(0, prefix+"MTF_H4_Val", OBJPROP_TEXT, TrendStateToString(g_trend_H4));
      ObjectSetInteger(0, prefix+"MTF_H4_Val", OBJPROP_COLOR, TrendStateToColor(g_trend_H4));
   }

   // Update Position Size
   ObjectSetString(0, prefix+"LotVal", OBJPROP_TEXT, (lots > 0.0 ? DoubleToString(lots, 2) + " LOTS" : "NO TRADE"));

   // Update Stop Loss & Take Profit
   ObjectSetString(0, prefix+"TpVal", OBJPROP_TEXT, (tp > 0.0 ? "TP: " + DoubleToString(tp, _Digits) : "TP: ---"));
   ObjectSetString(0, prefix+"SlVal", OBJPROP_TEXT, (sl > 0.0 ? "SL: " + DoubleToString(sl, _Digits) : "SL: ---"));

   // Update Correlations
   UpdateCorrelationLabels(s1, c1, s2, c2, s3, c3);
}

//+------------------------------------------------------------------+
//| Update Correlation Labels                                        |
//+------------------------------------------------------------------+
void UpdateCorrelationLabels(string s1, double c1, string s2, double c2, string s3, double c3)
{
   // Symbol 1
   if(s1 != "" && s1 != "None") {
      ObjectSetString(0, prefix+"C1Name", OBJPROP_TEXT, s1);
      ObjectSetString(0, prefix+"C1Val", OBJPROP_TEXT, FormatCorrelationValue(c1));
      ObjectSetInteger(0, prefix+"C1Val", OBJPROP_COLOR, GetCorrColor(c1));
   } else {
      ObjectSetString(0, prefix+"C1Name", OBJPROP_TEXT, "---");
      ObjectSetString(0, prefix+"C1Val", OBJPROP_TEXT, "N/A");
      ObjectSetInteger(0, prefix+"C1Val", OBJPROP_COLOR, C'107,114,128');
   }

   // Symbol 2
   if(s2 != "" && s2 != "None") {
      ObjectSetString(0, prefix+"C2Name", OBJPROP_TEXT, s2);
      ObjectSetString(0, prefix+"C2Val", OBJPROP_TEXT, FormatCorrelationValue(c2));
      ObjectSetInteger(0, prefix+"C2Val", OBJPROP_COLOR, GetCorrColor(c2));
   } else {
      ObjectSetString(0, prefix+"C2Name", OBJPROP_TEXT, "---");
      ObjectSetString(0, prefix+"C2Val", OBJPROP_TEXT, "N/A");
      ObjectSetInteger(0, prefix+"C2Val", OBJPROP_COLOR, C'107,114,128');
   }

   // Symbol 3
   if(s3 != "" && s3 != "None") {
      ObjectSetString(0, prefix+"C3Name", OBJPROP_TEXT, s3);
      ObjectSetString(0, prefix+"C3Val", OBJPROP_TEXT, FormatCorrelationValue(c3));
      ObjectSetInteger(0, prefix+"C3Val", OBJPROP_COLOR, GetCorrColor(c3));
   } else {
      ObjectSetString(0, prefix+"C3Name", OBJPROP_TEXT, "---");
      ObjectSetString(0, prefix+"C3Val", OBJPROP_TEXT, "N/A");
      ObjectSetInteger(0, prefix+"C3Val", OBJPROP_COLOR, C'107,114,128');
   }
}

//+------------------------------------------------------------------+
//| Format Correlation Value                                         |
//+------------------------------------------------------------------+
string FormatCorrelationValue(double value)
{
   if(MathAbs(value) < 0.001) return "0.000";
   return DoubleToString(value, 3);
}

//+------------------------------------------------------------------+
//| Get Color Based to Correlation Value                             |
//+------------------------------------------------------------------+
color GetCorrColor(double val)
{
   if(val > 0.7) return C'16,185,129';    // Green
   if(val < -0.7) return C'239,68,68';    // Red
   if(MathAbs(val) < 0.3) return C'156,163,175'; // Gray
   if(val > 0.3) return C'251,191,36';    // Yellow
   return C'245,158,11';                  // Orange
}

//+------------------------------------------------------------------+
//| Create Rectangle Object with error handling                       |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color bg, color border)
{
   string objName = prefix + name;

   if(ObjectFind(0, objName) < 0) {
      if(!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
         PrintFormat("Failed to create Rect '%s': Error %d", objName, GetLastError());
         return;
      }
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 100);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create Label Object with error handling                           |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color col, int size=10, bool bold=false)
{
   string objName = prefix + name;

   if(ObjectFind(0, objName) < 0) {
      if(!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
         // Silently fail for non-critical labels
         return;
      }
   }

   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, objName, OBJPROP_FONT, bold ? "Arial Black" : "Arial");
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 101);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Draw Horizontal Line with error handling                          |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color col, ENUM_LINE_STYLE style)
{
   string objName = prefix + name;

   if(ObjectFind(0, objName) < 0) {
      if(!ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price)) {
         PrintFormat("Failed to create HLine '%s': Error %d", objName, GetLastError());
         return;
      }
   }

   ObjectSetDouble(0, objName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+
