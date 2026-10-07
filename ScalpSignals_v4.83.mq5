//+------------------------------------------------------------------+
//|                                             ScalpSignals_v4.83.mq5|
//|  Scalp Signals v4.83 — v4.82 defects fixed + scalping upgrades.   |
//|                                                                   |
//|  Buffers readable via iCustom/CopyBuffer (EA integration):        |
//|    0 StrongBuy  1 Buy  2 Sell  3 StrongSell  (arrow prices)       |
//|    4 VWAP  5 VWAP upper  6 VWAP lower                             |
//|    7 Buy score  8 Sell score  (0..1, after all gates)             |
//|    9 OBV  10 Trend EMA                                            |
//|    14 Signal code: +2 strong buy, +1 buy, -1 sell, -2 strong sell |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, Advanced Scalping System"
#property link        "https://www.mql5.com"
#property description "RSI / MACD / MA / OBV / VWAP confluence scalping signals."
#property description "v4.83: working ATR spike filter, event memory, O(1) session VWAP, fail-closed MTF gate."
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   7
#property indicator_label1   "Strong Buy Signal"
#property indicator_type1    DRAW_ARROW
#property indicator_color1   clrLimeGreen
#property indicator_style1   STYLE_SOLID
#property indicator_width1   4
#property indicator_label2   "Buy Signal"
#property indicator_type2    DRAW_ARROW
#property indicator_color2   clrDeepSkyBlue
#property indicator_style2   STYLE_SOLID
#property indicator_width2   2
#property indicator_label3   "Sell Signal"
#property indicator_type3    DRAW_ARROW
#property indicator_color3   clrCrimson
#property indicator_style3   STYLE_SOLID
#property indicator_width3   2
#property indicator_label4   "Strong Sell Signal"
#property indicator_type4    DRAW_ARROW
#property indicator_color4   clrMagenta
#property indicator_style4   STYLE_SOLID
#property indicator_width4   4
#property indicator_label5   "VWAP Line"
#property indicator_type5    DRAW_LINE
#property indicator_color5   clrSilver
#property indicator_style5   STYLE_SOLID
#property indicator_width5   2
#property indicator_label6   "VWAP Upper Band"
#property indicator_type6    DRAW_LINE
#property indicator_color6   clrDimGray
#property indicator_style6   STYLE_DOT
#property indicator_width6   1
#property indicator_label7   "VWAP Lower Band"
#property indicator_type7    DRAW_LINE
#property indicator_color7   clrDimGray
#property indicator_style7   STYLE_DOT
#property indicator_width7   1

enum ENUM_ARROW_POSITION
{
   ARROW_POSITION_CLOSE   = 0,
   ARROW_POSITION_HIGHLOW = 1
};
enum ENUM_SIGNAL_MODE
{
   SIGNAL_MODE_CROSS  = 0,
   SIGNAL_MODE_STATE  = 1,
   SIGNAL_MODE_HYBRID = 2
};
enum ENUM_VWAP_MODE
{
   VWAP_MODE_ROLLING = 0,
   VWAP_MODE_SESSION = 1
};

input group "=== MT5 On-Chart Dashboard Panel ==="
input bool             ShowDashboard           = true;
input ENUM_BASE_CORNER DashboardCorner         = CORNER_LEFT_UPPER;
input int              DashboardX              = 18;
input int              DashboardY              = 45;
input color            DashboardBGColor        = C'15,23,42';
input color            DashboardBorderColor    = C'51,65,85';
input color            DashboardTextColor      = clrWhite;
input bool             UseTimerForDashboard    = true;
input int              DashboardRefreshSeconds = 1;

input group "=== Institutional Filters ==="
input bool             RequireTrendAlignment   = true;
input bool             UseDynamicBreakeven     = true;
input double           BreakevenTriggerATR     = 0.80;
input bool             SR_BounceFilter         = true;
input bool             StrictMTFGate           = true;
input bool             DivergenceBoost         = true;
input bool             UseSpreadFilter         = true;
input double           MaxSpreadATRFrac        = 0.18;
input bool             UseSessionFilter        = false;
input int              SessionStartHour        = 7;
input int              SessionEndHour          = 17;

input group "=== Signal Confluence & Weights ==="
input double           SignalThreshold         = 0.50;
input double           SignalStrongThreshold   = 0.75;
input ENUM_SIGNAL_MODE SignalMode              = SIGNAL_MODE_HYBRID;
input int              EventMemoryBars         = 3;      // a cross/hook stays valid (decaying) for this many bars
input bool             ShowStrongSignals       = true;
input bool             ShowRegularSignals      = true;
input bool             SignalOnClosedBarOnly   = true;
input int              SignalCooldownBars      = 2;

input group "=== Arrow Positioning ==="
input ENUM_ARROW_POSITION ArrowPosition        = ARROW_POSITION_HIGHLOW;
input int              ArrowDistancePoints     = 10;
input bool             UseDynamicArrowDistance = true;
input double           ATR_Multiplier          = 0.5;

input group "=== Indicator Parameters ==="
input int              RSI_Period              = 10;
input double           RSI_OverBought          = 70.0;
input double           RSI_OverSold            = 30.0;
input int              MACD_FastEMA            = 5;
input int              MACD_SlowEMA            = 12;
input int              MACD_SignalSMA          = 3;
input int              MA_Fast_Period          = 3;
input int              MA_Slow_Period          = 5;
input ENUM_MA_METHOD   MA_Method               = MODE_EMA;
input int              TrendEMA_Period         = 50;

input group "=== VWAP & Volume Settings ==="
input bool             UseVWAPFilter           = true;
input ENUM_VWAP_MODE   VWAP_Mode               = VWAP_MODE_ROLLING;
input int              VWAP_Period             = 20;
input double           VWAP_Deviation          = 1.5;
input bool             ShowVWAPBands           = true;
input bool             PreferRealVolume        = true;

input group "=== Volatility & Risk Management ==="
input int              ATR_Period              = 14;
input double           ATR_StopLossMultiplier  = 1.2;
input double           ATR_TakeProfitMultiplier= 1.5;
input double           ATR_SpikeThreshold      = 2.2;    // bar true range / previous ATR above this blocks the bar

input group "=== Multi-Timeframe Confirmation ==="
input bool             UseMTFConfirmation      = true;
input ENUM_TIMEFRAMES  MTF_Timeframe           = PERIOD_H1;

input group "=== Alerts & Notifications ==="
input bool             EnableSoundAlert        = true;
input bool             EnablePopupAlert        = true;
input bool             EnablePushAlert         = false;
input int              AlertCooldownMinutes    = 1;

double bufStrongBuy[];
double bufBuy[];
double bufSell[];
double bufStrongSell[];
double bufVWAP[];
double bufVWAPUpper[];
double bufVWAPLower[];
double bufBuyStrength[];
double bufSellStrength[];
double bufOBVTrend[];
double bufTrendEMA[];
double bufCumPV[];
double bufCumV[];
double bufCumPV2[];
double bufSignal[];

int handleRSI      = INVALID_HANDLE;
int handleMACD     = INVALID_HANDLE;
int handleFastMA   = INVALID_HANDLE;
int handleSlowMA   = INVALID_HANDLE;
int handleTrendEMA = INVALID_HANDLE;
int handleATR      = INVALID_HANDLE;
int handleMTFTrend = INVALID_HANDLE;
int handleMTFRSI   = INVALID_HANDLE;

bool     mtfActive      = false;
int      warmBars       = 0;
datetime lastAlertTime  = 0;
datetime lastAlertSignalTime = 0;
datetime lastSignalTime = 0;
string   lastSignalText = "";
bool     alertsArmed    = false;

double lastBuyScore = 0.0;
double lastSellScore = 0.0;
double lastRsi = 50.0;
double lastMacdMain = 0.0;
double lastMacdSig = 0.0;
double lastFastMA = 0.0;
double lastSlowMA = 0.0;
double lastVwap = 0.0;
double lastTrendEMA = 0.0;
double lastATR = 0.0;
double lastClosePrice = 0.0;
int    lastSpread = 0;

const string D_PREFIX = "SSP_";
const int    DASH_W   = 290;
const int    DASH_H   = 396;
const int    LOOKBACK_EXTRA = 30;   // bars needed behind the oldest recalculated bar (divergence = 21)

void CreateDashboard();
void UpdateDashboard(double buyScore, double sellScore, double rsi, double macdM, double macdS,
                     double fMA, double sMA, double vwapVal, double emaVal, double atrVal,
                     double curPrice, int spreadPts);
void DestroyDashboard();
void RefreshDashboardData();
bool CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr);
bool CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font);
void SetLabel(string name, string text, color clr);
bool TriggerAlert(string signalType, bool isBuy, double price, double score, double atr);
double Clamp01(double v);
double ApplyMode(double eventScore, double stateScore, bool hasEvent);
int    ClosedMtfShift(datetime barTime);
bool   SameDay(datetime a, datetime b);

int OnInit()
{
   if(RSI_Period < 2 || MACD_FastEMA < 1 || MACD_SlowEMA <= MACD_FastEMA ||
      MACD_SignalSMA < 1 || MA_Fast_Period < 1 || MA_Slow_Period < MA_Fast_Period ||
      TrendEMA_Period < 2 || ATR_Period < 1 || VWAP_Period < 2 || EventMemoryBars < 1)
   {
      Print("[ScalpSignals v4.83] Invalid indicator periods.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SignalThreshold < 0.0 || SignalThreshold > 1.0 ||
      SignalStrongThreshold < SignalThreshold || SignalStrongThreshold > 1.0 ||
      RSI_OverBought <= RSI_OverSold ||
      VWAP_Deviation < 0.0 || MaxSpreadATRFrac < 0.0 ||
      ATR_Multiplier < 0.0 || AlertCooldownMinutes < 0 ||
      SessionStartHour < 0 || SessionStartHour > 23 ||
      SessionEndHour < 0 || SessionEndHour > 23)
   {
      Print("[ScalpSignals v4.83] Invalid signal, risk, or session parameters.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // The MTF gate only makes sense on a strictly higher timeframe.
   mtfActive = UseMTFConfirmation;
   if(mtfActive && PeriodSeconds(MTF_Timeframe) <= PeriodSeconds(_Period))
   {
      Print("[ScalpSignals v4.83] MTF_Timeframe must be higher than the chart timeframe; MTF gate disabled.");
      mtfActive = false;
   }

   SetIndexBuffer(0, bufStrongBuy,    INDICATOR_DATA);
   SetIndexBuffer(1, bufBuy,          INDICATOR_DATA);
   SetIndexBuffer(2, bufSell,         INDICATOR_DATA);
   SetIndexBuffer(3, bufStrongSell,   INDICATOR_DATA);
   SetIndexBuffer(4, bufVWAP,         INDICATOR_DATA);
   SetIndexBuffer(5, bufVWAPUpper,    INDICATOR_DATA);
   SetIndexBuffer(6, bufVWAPLower,    INDICATOR_DATA);
   SetIndexBuffer(7, bufBuyStrength,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, bufSellStrength, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, bufOBVTrend,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, bufTrendEMA,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, bufCumPV,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, bufCumV,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, bufCumPV2,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, bufSignal,      INDICATOR_CALCULATIONS);

   ArraySetAsSeries(bufStrongBuy,    true);
   ArraySetAsSeries(bufBuy,          true);
   ArraySetAsSeries(bufSell,         true);
   ArraySetAsSeries(bufStrongSell,   true);
   ArraySetAsSeries(bufVWAP,         true);
   ArraySetAsSeries(bufVWAPUpper,    true);
   ArraySetAsSeries(bufVWAPLower,    true);
   ArraySetAsSeries(bufBuyStrength,  true);
   ArraySetAsSeries(bufSellStrength, true);
   ArraySetAsSeries(bufOBVTrend,     true);
   ArraySetAsSeries(bufTrendEMA,     true);
   ArraySetAsSeries(bufCumPV,        true);
   ArraySetAsSeries(bufCumV,         true);
   ArraySetAsSeries(bufCumPV2,       true);
   ArraySetAsSeries(bufSignal,       true);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetInteger(2, PLOT_ARROW, 234);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   for(int i = 0; i < 7; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, UseVWAPFilter ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(5, PLOT_DRAW_TYPE, (UseVWAPFilter && ShowVWAPBands) ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(6, PLOT_DRAW_TYPE, (UseVWAPFilter && ShowVWAPBands) ? DRAW_LINE : DRAW_NONE);

   handleRSI      = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   handleMACD     = iMACD(_Symbol, _Period, MACD_FastEMA, MACD_SlowEMA, MACD_SignalSMA, PRICE_CLOSE);
   handleFastMA   = iMA(_Symbol, _Period, MA_Fast_Period, 0, MA_Method, PRICE_CLOSE);
   handleSlowMA   = iMA(_Symbol, _Period, MA_Slow_Period, 0, MA_Method, PRICE_CLOSE);
   handleTrendEMA = iMA(_Symbol, _Period, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   handleATR      = iATR(_Symbol, _Period, ATR_Period);
   if(mtfActive)
   {
      handleMTFTrend = iMA(_Symbol, MTF_Timeframe, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      handleMTFRSI   = iRSI(_Symbol, MTF_Timeframe, RSI_Period, PRICE_CLOSE);
   }

   if(handleRSI == INVALID_HANDLE || handleMACD == INVALID_HANDLE ||
      handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE ||
      handleTrendEMA == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("[ScalpSignals v4.83] Error creating indicator handles.");
      return(INIT_FAILED);
   }
   if(mtfActive && (handleMTFTrend == INVALID_HANDLE || handleMTFRSI == INVALID_HANDLE))
   {
      Print("[ScalpSignals v4.83] Error creating MTF handles.");
      return(INIT_FAILED);
   }

   // Bars skipped at the oldest end so no signal is built from unconverged/empty indicator values.
   warmBars = MathMax(MathMax(TrendEMA_Period, MACD_SlowEMA + MACD_SignalSMA),
                      MathMax(RSI_Period, ATR_Period)) + 25;

   IndicatorSetString(INDICATOR_SHORTNAME, "ScalpSignals v4.83");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   alertsArmed = false;
   lastAlertSignalTime = 0;
   lastSignalTime = 0;
   lastSignalText = "";

   if(ShowDashboard)
   {
      CreateDashboard();
      if(UseTimerForDashboard)
         EventSetTimer(MathMax(1, DashboardRefreshSeconds));
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(ShowDashboard)
   {
      if(UseTimerForDashboard)
         EventKillTimer();
      DestroyDashboard();
   }
   if(handleRSI != INVALID_HANDLE)      IndicatorRelease(handleRSI);
   if(handleMACD != INVALID_HANDLE)     IndicatorRelease(handleMACD);
   if(handleFastMA != INVALID_HANDLE)   IndicatorRelease(handleFastMA);
   if(handleSlowMA != INVALID_HANDLE)   IndicatorRelease(handleSlowMA);
   if(handleTrendEMA != INVALID_HANDLE) IndicatorRelease(handleTrendEMA);
   if(handleATR != INVALID_HANDLE)      IndicatorRelease(handleATR);
   if(handleMTFTrend != INVALID_HANDLE) IndicatorRelease(handleMTFTrend);
   if(handleMTFRSI != INVALID_HANDLE)   IndicatorRelease(handleMTFRSI);
}

void OnTimer()
{
   if(!ShowDashboard) return;
   RefreshDashboardData();
}

double GetEffectiveVolume(const long &realVol[], const long &tickVol[], int index)
{
   if(PreferRealVolume && realVol[index] > 0)
      return (double)realVol[index];
   return (double)MathMax((double)tickVol[index], 1.0);
}

double Clamp01(double v)
{
   if(v < 0.0) return 0.0;
   if(v > 1.0) return 1.0;
   return v;
}

// hasEvent: a still-valid cross/hook within EventMemoryBars. eventScore decays with age.
double ApplyMode(double eventScore, double stateScore, bool hasEvent)
{
   if(SignalMode == SIGNAL_MODE_CROSS)
      return hasEvent ? eventScore : 0.0;
   if(SignalMode == SIGNAL_MODE_STATE)
      return stateScore;
   return hasEvent ? MathMax(eventScore, stateScore) : stateScore;
}

double EventScore(int age)
{
   if(age < 0) return 0.0;
   return 1.0 - (double)age / (double)(EventMemoryBars + 1);
}

// Age (in bars) of the most recent cross of a over b inside the memory window, or -1.
int CrossAge(const double &a[], const double &b[], int i, int copied, bool up)
{
   for(int k = 0; k < EventMemoryBars; k++)
   {
      int j = i + k;
      if(j + 1 >= copied) break;
      bool crossed = up ? (a[j + 1] <= b[j + 1] && a[j] > b[j])
                        : (a[j + 1] >= b[j + 1] && a[j] < b[j]);
      if(crossed) return k;
   }
   return -1;
}

// Age of the most recent RSI exit from oversold (buy) / overbought (sell), or -1.
int RsiHookAge(const double &r[], int i, int copied, bool buy)
{
   for(int k = 0; k < EventMemoryBars; k++)
   {
      int j = i + k;
      if(j + 1 >= copied) break;
      bool hook = buy ? (r[j + 1] <= RSI_OverSold && r[j] > RSI_OverSold)
                      : (r[j + 1] >= RSI_OverBought && r[j] < RSI_OverBought);
      if(hook) return k;
   }
   return -1;
}

bool SameDay(datetime a, datetime b)
{
   MqlDateTime da, db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
}

// Shift of the latest MTF bar that is fully closed by the close of the current-timeframe bar at barTime.
int ClosedMtfShift(datetime barTime)
{
   int sh = iBarShift(_Symbol, MTF_Timeframe, barTime, false);
   if(sh < 0) return -1;
   datetime htfTime = iTime(_Symbol, MTF_Timeframe, sh);
   if(htfTime <= 0) return -1;
   if(htfTime + (datetime)PeriodSeconds(MTF_Timeframe) > barTime + (datetime)PeriodSeconds(_Period))
      return sh + 1;
   return sh;
}

// Draws the arrow, records it for the cooldown/EA buffer, and fires the (de-duplicated) alert.
void EmitSignal(int i, bool buy, bool strong, double arrowPrice, double score,
                double price, double atr, datetime t)
{
   bool asStrong = strong && ShowStrongSignals;
   if(!asStrong && !ShowRegularSignals)
      return;

   if(buy)
   {
      if(asStrong) bufStrongBuy[i] = arrowPrice; else bufBuy[i] = arrowPrice;
      bufSignal[i] = asStrong ? 2.0 : 1.0;
   }
   else
   {
      if(asStrong) bufStrongSell[i] = arrowPrice; else bufSell[i] = arrowPrice;
      bufSignal[i] = asStrong ? -2.0 : -1.0;
   }

   lastSignalTime = t;
   lastSignalText = StringFormat("%s%s", asStrong ? "STRONG " : "", buy ? "BUY" : "SELL");

   if(alertsArmed && i <= 1 && lastAlertSignalTime != t)
   {
      if(TriggerAlert(lastSignalText, buy, price, score, atr))
         lastAlertSignalTime = t;
   }
}

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
   if(rates_total < warmBars + LOOKBACK_EXTRA)
      return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(spread, true);

   bool firstRun = (prev_calculated <= 0 || prev_calculated > rates_total);
   if(firstRun)
   {
      ArrayInitialize(bufStrongBuy,  EMPTY_VALUE);
      ArrayInitialize(bufBuy,        EMPTY_VALUE);
      ArrayInitialize(bufSell,       EMPTY_VALUE);
      ArrayInitialize(bufStrongSell, EMPTY_VALUE);
      ArrayInitialize(bufVWAP,       EMPTY_VALUE);
      ArrayInitialize(bufVWAPUpper,  EMPTY_VALUE);
      ArrayInitialize(bufVWAPLower,  EMPTY_VALUE);
      ArrayInitialize(bufSignal,     0.0);
   }

   // Oldest bar that may be evaluated (everything older is indicator warm-up).
   int maxBar = rates_total - 1 - warmBars;
   int limit  = firstRun ? rates_total - 1 : rates_total - prev_calculated;
   if(limit < 1) limit = 1;          // always refresh the forming bar and the last closed bar
   if(limit > maxBar) limit = maxBar;

   // Pull only what this pass needs instead of the whole history on every tick.
   int need = MathMin(rates_total, limit + LOOKBACK_EXTRA);
   if(firstRun)
   {
      if(BarsCalculated(handleRSI) < need || BarsCalculated(handleMACD) < need ||
         BarsCalculated(handleFastMA) < need || BarsCalculated(handleSlowMA) < need ||
         BarsCalculated(handleTrendEMA) < need || BarsCalculated(handleATR) < need)
         return(0);
   }

   double rsiArr[], macdMain[], macdSig[], fastMA[], slowMA[], trendEMA[], atrVal[];
   ArraySetAsSeries(rsiArr, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig, true);
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(trendEMA, true);
   ArraySetAsSeries(atrVal, true);

   if(CopyBuffer(handleRSI, 0, 0, need, rsiArr) < need) return(prev_calculated);
   if(CopyBuffer(handleMACD, 0, 0, need, macdMain) < need) return(prev_calculated);
   if(CopyBuffer(handleMACD, 1, 0, need, macdSig) < need) return(prev_calculated);
   if(CopyBuffer(handleFastMA, 0, 0, need, fastMA) < need) return(prev_calculated);
   if(CopyBuffer(handleSlowMA, 0, 0, need, slowMA) < need) return(prev_calculated);
   if(CopyBuffer(handleTrendEMA, 0, 0, need, trendEMA) < need) return(prev_calculated);
   if(CopyBuffer(handleATR, 0, 0, need, atrVal) < need) return(prev_calculated);

   // OBV from actual volume
   int obvFrom = firstRun ? (rates_total - 1) : MathMin(limit + 1, rates_total - 1);
   if(firstRun)
      bufOBVTrend[rates_total - 1] = GetEffectiveVolume(volume, tick_volume, rates_total - 1);
   for(int i = obvFrom; i >= 0; i--)
   {
      if(i == rates_total - 1)
         continue;
      double vol = GetEffectiveVolume(volume, tick_volume, i);
      if(close[i] > close[i + 1])
         bufOBVTrend[i] = bufOBVTrend[i + 1] + vol;
      else if(close[i] < close[i + 1])
         bufOBVTrend[i] = bufOBVTrend[i + 1] - vol;
      else
         bufOBVTrend[i] = bufOBVTrend[i + 1];
   }

   // VWAP. Session mode uses running sums reset at each new day (O(1) per bar);
   // rolling mode is an O(period) window.
   if(UseVWAPFilter)
   {
      int vFrom = firstRun ? (rates_total - 1) : MathMin(limit + 1, rates_total - 1);
      for(int i = vFrom; i >= 0; i--)
      {
         double tp  = (high[i] + low[i] + close[i]) / 3.0;
         double vol = GetEffectiveVolume(volume, tick_volume, i);
         double vwap, sd;

         if(VWAP_Mode == VWAP_MODE_SESSION)
         {
            bool newSession = (i + 1 >= rates_total) || !SameDay(time[i], time[i + 1]);
            double pv  = newSession ? 0.0 : bufCumPV[i + 1];
            double v   = newSession ? 0.0 : bufCumV[i + 1];
            double pv2 = newSession ? 0.0 : bufCumPV2[i + 1];
            bufCumPV[i]  = pv + tp * vol;
            bufCumV[i]   = v + vol;
            bufCumPV2[i] = pv2 + tp * tp * vol;
            vwap = bufCumPV[i] / bufCumV[i];
            double variance = bufCumPV2[i] / bufCumV[i] - vwap * vwap;
            sd = (variance > 0.0) ? MathSqrt(variance) : 0.0;
         }
         else
         {
            int n = MathMin(VWAP_Period, rates_total - i);
            double sumPV = 0.0, sumV = 0.0;
            for(int j = 0; j < n; j++)
            {
               double tpj = (high[i + j] + low[i + j] + close[i + j]) / 3.0;
               double vj  = GetEffectiveVolume(volume, tick_volume, i + j);
               sumPV += tpj * vj;
               sumV  += vj;
            }
            vwap = sumPV / sumV;
            double sumDev = 0.0;
            for(int j = 0; j < n; j++)
            {
               double tpj = (high[i + j] + low[i + j] + close[i + j]) / 3.0;
               double vj  = GetEffectiveVolume(volume, tick_volume, i + j);
               sumDev += vj * (tpj - vwap) * (tpj - vwap);
            }
            sd = MathSqrt(sumDev / sumV);
         }
         bufVWAP[i]      = vwap;
         bufVWAPUpper[i] = vwap + sd * VWAP_Deviation;
         bufVWAPLower[i] = vwap - sd * VWAP_Deviation;
      }
   }

   // MTF values are constant across many chart bars; cache by HTF shift.
   int    mtfCachedShift = -2;
   bool   mtfCachedOk    = false;
   double mtfEmaCached   = 0.0, mtfRsiCached = 50.0;

   // Weight normalisation: a disabled VWAP no longer hands both sides a free constant.
   double wSum = 0.25 + 0.25 + 0.20 + 0.15 + (UseVWAPFilter ? 0.15 : 0.0);

   for(int i = limit; i >= 0; i--)
   {
      bufStrongBuy[i]  = EMPTY_VALUE;
      bufBuy[i]        = EMPTY_VALUE;
      bufSell[i]       = EMPTY_VALUE;
      bufStrongSell[i] = EMPTY_VALUE;
      bufSignal[i]     = 0.0;
      if(i + 1 >= rates_total)
         continue;

      bufTrendEMA[i] = trendEMA[i];
      double currentATR = (atrVal[i] > 0) ? atrVal[i] : (high[i] - low[i]);

      // Spike filter on the bar's true range against the *previous* ATR.
      // (v4.82 compared ATR[i]/ATR[i+1], which is mathematically capped near 1.9 and never fired.)
      bool blocked = false;
      if(atrVal[i + 1] > 0)
      {
         double tr = MathMax(high[i] - low[i],
                     MathMax(MathAbs(high[i] - close[i + 1]), MathAbs(low[i] - close[i + 1])));
         if(tr / atrVal[i + 1] > ATR_SpikeThreshold)
            blocked = true;
      }

      // RSI: hook out of OB/OS (decaying event) or distance from 50 (state).
      double rsiBuyState = 0.0, rsiSellState = 0.0;
      if(rsiArr[i] > 50.0 && rsiArr[i] < RSI_OverBought)
         rsiBuyState = (rsiArr[i] - 50.0) / 20.0;
      if(rsiArr[i] < 50.0 && rsiArr[i] > RSI_OverSold)
         rsiSellState = (50.0 - rsiArr[i]) / 20.0;
      int rsiBuyAge  = RsiHookAge(rsiArr, i, need, true);
      int rsiSellAge = RsiHookAge(rsiArr, i, need, false);
      double rsiBuyScore  = Clamp01(ApplyMode(EventScore(rsiBuyAge),  Clamp01(rsiBuyState),
                                              rsiBuyAge >= 0 && rsiArr[i] > RSI_OverSold));
      double rsiSellScore = Clamp01(ApplyMode(EventScore(rsiSellAge), Clamp01(rsiSellState),
                                              rsiSellAge >= 0 && rsiArr[i] < RSI_OverBought));

      // MACD / MA: a cross only counts while the new state still holds.
      int macdUpAge = CrossAge(macdMain, macdSig, i, need, true);
      int macdDnAge = CrossAge(macdMain, macdSig, i, need, false);
      double macdBuyScore  = Clamp01(ApplyMode(EventScore(macdUpAge), (macdMain[i] > macdSig[i]) ? 0.6 : 0.0,
                                               macdUpAge >= 0 && macdMain[i] > macdSig[i]));
      double macdSellScore = Clamp01(ApplyMode(EventScore(macdDnAge), (macdMain[i] < macdSig[i]) ? 0.6 : 0.0,
                                               macdDnAge >= 0 && macdMain[i] < macdSig[i]));

      int maUpAge = CrossAge(fastMA, slowMA, i, need, true);
      int maDnAge = CrossAge(fastMA, slowMA, i, need, false);
      double maBuyScore  = Clamp01(ApplyMode(EventScore(maUpAge), (fastMA[i] > slowMA[i]) ? 0.5 : 0.0,
                                             maUpAge >= 0 && fastMA[i] > slowMA[i]));
      double maSellScore = Clamp01(ApplyMode(EventScore(maDnAge), (fastMA[i] < slowMA[i]) ? 0.5 : 0.0,
                                             maDnAge >= 0 && fastMA[i] < slowMA[i]));

      double vwapBuyScore = 0.0, vwapSellScore = 0.0;
      if(UseVWAPFilter)
      {
         vwapBuyScore  = (close[i] > bufVWAP[i]) ? ((close[i] <= bufVWAPUpper[i]) ? 0.8 : 0.4) : 0.0;
         vwapSellScore = (close[i] < bufVWAP[i]) ? ((close[i] >= bufVWAPLower[i]) ? 0.8 : 0.4) : 0.0;
      }

      int obvLook = MathMin(5, rates_total - i - 1);
      double obvSlope = bufOBVTrend[i] - bufOBVTrend[i + obvLook];
      double obvBuyScore  = (obvSlope > 0.0) ? 0.8 : ((obvSlope < 0.0) ? 0.2 : 0.5);
      double obvSellScore = (obvSlope < 0.0) ? 0.8 : ((obvSlope > 0.0) ? 0.2 : 0.5);

      double totalBuyScore = Clamp01((rsiBuyScore * 0.25 + macdBuyScore * 0.25 +
                                      maBuyScore * 0.20 + vwapBuyScore * 0.15 + obvBuyScore * 0.15) / wSum);
      double totalSellScore = Clamp01((rsiSellScore * 0.25 + macdSellScore * 0.25 +
                                       maSellScore * 0.20 + vwapSellScore * 0.15 + obvSellScore * 0.15) / wSum);

      // Swing divergence: lowest low (highest high) of the last 6 bars vs the prior 15 bars.
      if(DivergenceBoost && i + 21 < need)
      {
         int loR = ArrayMinimum(low, i, 6);
         int loP = ArrayMinimum(low, i + 6, 15);
         int hiR = ArrayMaximum(high, i, 6);
         int hiP = ArrayMaximum(high, i + 6, 15);
         if(loR >= 0 && loP >= 0 && low[loR] < low[loP] && rsiArr[loR] > rsiArr[loP] &&
            rsiArr[loP] < RSI_OverSold + 10.0)
            totalBuyScore = Clamp01(totalBuyScore + 0.12);
         if(hiR >= 0 && hiP >= 0 && high[hiR] > high[hiP] && rsiArr[hiR] < rsiArr[hiP] &&
            rsiArr[hiP] > RSI_OverBought - 10.0)
            totalSellScore = Clamp01(totalSellScore + 0.12);
      }

      if(blocked)
      {
         totalBuyScore = 0.0;
         totalSellScore = 0.0;
      }

      if(RequireTrendAlignment)
      {
         if(close[i] < trendEMA[i]) totalBuyScore = 0.0;
         if(close[i] > trendEMA[i]) totalSellScore = 0.0;
      }

      // Closed-HTF gate. Fails closed: no HTF data means no signal (v4.82 silently passed).
      if(StrictMTFGate && mtfActive)
      {
         int mtfSh = ClosedMtfShift(time[i]);
         if(mtfSh != mtfCachedShift)
         {
            mtfCachedShift = mtfSh;
            double e[1], r[1];
            mtfCachedOk = (mtfSh >= 0 &&
                           CopyBuffer(handleMTFTrend, 0, mtfSh, 1, e) > 0 &&
                           CopyBuffer(handleMTFRSI, 0, mtfSh, 1, r) > 0);
            if(mtfCachedOk) { mtfEmaCached = e[0]; mtfRsiCached = r[0]; }
         }
         if(!mtfCachedOk)
         {
            totalBuyScore = 0.0;
            totalSellScore = 0.0;
         }
         else
         {
            if(close[i] < mtfEmaCached || mtfRsiCached < 45.0)
               totalBuyScore = 0.0;
            if(close[i] > mtfEmaCached || mtfRsiCached > 55.0)
               totalSellScore = 0.0;
         }
      }

      // S/R shield: block only when price sits just *below* resistance / *above* support.
      // A close beyond the level (breakout) is no longer blocked.
      if(SR_BounceFilter)
      {
         int look = MathMin(20, rates_total - i - 1);
         if(look >= 5)
         {
            int hiIdx = ArrayMaximum(high, i + 1, look);
            int loIdx = ArrayMinimum(low, i + 1, look);
            if(hiIdx >= 0 && loIdx >= 0)
            {
               double dangerZone = 0.65 * currentATR;
               double toRes = high[hiIdx] - close[i];
               double toSup = close[i] - low[loIdx];
               if(toRes >= 0.0 && toRes < dangerZone)
                  totalBuyScore = 0.0;
               if(toSup >= 0.0 && toSup < dangerZone)
                  totalSellScore = 0.0;
            }
         }
      }

      if(UseSpreadFilter && currentATR > 0.0)
      {
         // Bar 0 uses the live spread; history uses the recorded bar spread.
         double spr = ((i == 0) ? (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) : (double)spread[i]) * _Point;
         if(spr > currentATR * MaxSpreadATRFrac)
         {
            totalBuyScore = 0.0;
            totalSellScore = 0.0;
         }
      }

      if(UseSessionFilter)
      {
         MqlDateTime dt;
         TimeToStruct(time[i], dt);
         bool inSession = (SessionStartHour <= SessionEndHour) ?
                          (dt.hour >= SessionStartHour && dt.hour < SessionEndHour) :
                          (dt.hour >= SessionStartHour || dt.hour < SessionEndHour);
         if(!inSession)
         {
            totalBuyScore = 0.0;
            totalSellScore = 0.0;
         }
      }

      bufBuyStrength[i]  = totalBuyScore;
      bufSellStrength[i] = totalSellScore;

      if(i == 0)
      {
         lastBuyScore   = totalBuyScore;
         lastSellScore  = totalSellScore;
         lastRsi        = rsiArr[0];
         lastMacdMain   = macdMain[0];
         lastMacdSig    = macdSig[0];
         lastFastMA     = fastMA[0];
         lastSlowMA     = slowMA[0];
         lastVwap       = UseVWAPFilter ? bufVWAP[0] : 0.0;
         lastTrendEMA   = trendEMA[0];
         lastATR        = currentATR;
         lastClosePrice = close[0];
         lastSpread     = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      }

      bool emitHere = SignalOnClosedBarOnly ? (i >= 1) : true;
      if(!emitHere)
         continue;

      bool cooled = false;
      for(int k = 1; k <= SignalCooldownBars; k++)
      {
         int idx = i + k;
         if(idx >= rates_total) break;
         if(bufSignal[idx] != 0.0)
         {
            cooled = true;
            break;
         }
      }
      if(cooled)
         continue;

      double arrowOffset = (UseDynamicArrowDistance) ?
                           (currentATR * ATR_Multiplier) :
                           (ArrowDistancePoints * _Point);

      if(totalBuyScore >= SignalThreshold && totalBuyScore > totalSellScore)
      {
         double arrowPrice = (ArrowPosition == ARROW_POSITION_HIGHLOW) ?
                             (low[i] - arrowOffset) : (close[i] - arrowOffset);
         EmitSignal(i, true, totalBuyScore >= SignalStrongThreshold, arrowPrice,
                    totalBuyScore, close[i], currentATR, time[i]);
      }
      else if(totalSellScore >= SignalThreshold && totalSellScore > totalBuyScore)
      {
         double arrowPrice = (ArrowPosition == ARROW_POSITION_HIGHLOW) ?
                             (high[i] + arrowOffset) : (close[i] + arrowOffset);
         EmitSignal(i, false, totalSellScore >= SignalStrongThreshold, arrowPrice,
                    totalSellScore, close[i], currentATR, time[i]);
      }
   }

   if(ShowDashboard)
   {
      UpdateDashboard(lastBuyScore, lastSellScore, lastRsi, lastMacdMain, lastMacdSig,
                      lastFastMA, lastSlowMA, lastVwap, lastTrendEMA, lastATR,
                      lastClosePrice, lastSpread);
   }
   alertsArmed = true;
   return(rates_total);
}

void RefreshDashboardData()
{
   lastSpread     = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > 0.0)
      lastClosePrice = bid;
   UpdateDashboard(lastBuyScore, lastSellScore, lastRsi, lastMacdMain, lastMacdSig,
                   lastFastMA, lastSlowMA, lastVwap, lastTrendEMA, lastATR,
                   lastClosePrice, lastSpread);
}

bool CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
}

bool CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
}

void SetLabel(string name, string text, color clr)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   DestroyDashboard();
   int x = DashboardX;
   int y = DashboardY;
   int width = DASH_W;
   int height = DASH_H;
   CreateRect(D_PREFIX + "BG", x, y, width, height, DashboardBGColor, DashboardBorderColor);
   CreateRect(D_PREFIX + "HeaderBG", x + 1, y + 1, width - 2, 28, C'30,41,59', DashboardBorderColor);
   CreateLabel(D_PREFIX + "Title", x + 10, y + 6, "SCALPSIGNALS v4.83", clrCyan, 9, "Segoe UI Bold");
   int curY = y + 36;
   CreateLabel(D_PREFIX + "BiasHdr", x + 12, curY, "CONFLUENCE & BIAS (LIVE BAR)", clrSlateGray, 8, "Segoe UI Bold");
   curY += 18;
   CreateLabel(D_PREFIX + "BiasVal", x + 12, curY, "ANALYZING...", clrWhite, 11, "Segoe UI Bold");
   curY += 20;
   CreateRect(D_PREFIX + "MeterBG", x + 12, curY, width - 24, 7, C'30,41,59', clrNONE);
   CreateRect(D_PREFIX + "MeterFill", x + 12, curY, (width - 24) / 2, 7, clrCyan, clrNONE);
   curY += 16;
   CreateRect(D_PREFIX + "Sep1", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "SubHdr", x + 12, curY, "SUB-FACTOR TELEMETRY", clrSlateGray, 8, "Segoe UI Bold");
   curY += 16;
   CreateLabel(D_PREFIX + "RSI",   x + 12, curY, "RSI: --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "MACD",  x + 12, curY, "MACD: --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "MA",    x + 12, curY, "Fast/Slow MA: --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "Trend", x + 12, curY, "EMA: --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "VWAP",  x + 12, curY, "VWAP: --", clrWhite, 8, "Segoe UI");
   curY += 20;
   CreateRect(D_PREFIX + "Sep2", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "LvlHdr", x + 12, curY, "SUGGESTED SL / TP / BE (BY BIAS)", clrSlateGray, 8, "Segoe UI Bold");
   curY += 16;
   CreateLabel(D_PREFIX + "Levels", x + 12, curY, "SL --  TP --  BE --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "LastSig", x + 12, curY, "Last signal: --", clrWhite, 8, "Segoe UI");
   curY += 20;
   CreateRect(D_PREFIX + "Sep3", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "ShieldHdr", x + 12, curY, "FILTERS", clrSpringGreen, 8, "Segoe UI Bold");
   curY += 16;
   CreateLabel(D_PREFIX + "ShieldTrend", x + 12, curY, "EMA gate", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "ShieldSR",    x + 12, curY, "S/R shield", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "ShieldBE",    x + 12, curY, "Breakeven (manual)", clrWhite, 8, "Segoe UI");
   curY += 20;
   CreateRect(D_PREFIX + "Sep4", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "Footer", x + 12, curY, "ATR: -- | Spread: -- pts", clrDarkGray, 8, "Segoe UI");
   ChartRedraw(0);
}

void UpdateDashboard(double buyScore, double sellScore, double rsi, double macdM, double macdS,
                     double fMA, double sMA, double vwapVal, double emaVal, double atrVal,
                     double curPrice, int spreadPts)
{
   if(!ShowDashboard) return;
   int maxBarW = DASH_W - 24;
   string biasText = "NEUTRAL / FLAT";
   color  biasColor = clrSilver;
   int    fillWidth = maxBarW / 2;
   color  fillColor = clrSlateGray;

   if(buyScore >= SignalStrongThreshold)
   {
      biasText = StringFormat("STRONG BUY (+%.2f)", buyScore);
      biasColor = clrLime; fillWidth = (int)(maxBarW * MathMin(buyScore, 1.0)); fillColor = clrLime;
   }
   else if(buyScore >= SignalThreshold)
   {
      biasText = StringFormat("BUY SIGNAL (+%.2f)", buyScore);
      biasColor = clrDeepSkyBlue; fillWidth = (int)(maxBarW * MathMin(buyScore, 1.0)); fillColor = clrDeepSkyBlue;
   }
   else if(sellScore >= SignalStrongThreshold)
   {
      biasText = StringFormat("STRONG SELL (-%.2f)", sellScore);
      biasColor = clrOrchid; fillWidth = (int)(maxBarW * MathMin(sellScore, 1.0)); fillColor = clrOrchid;
   }
   else if(sellScore >= SignalThreshold)
   {
      biasText = StringFormat("SELL SIGNAL (-%.2f)", sellScore);
      biasColor = clrCrimson; fillWidth = (int)(maxBarW * MathMin(sellScore, 1.0)); fillColor = clrCrimson;
   }
   else if(buyScore > sellScore && buyScore > 0.20)
   {
      biasText = StringFormat("LEAN BUY (+%.2f)", buyScore);
      biasColor = clrLightCyan; fillWidth = (int)(maxBarW * buyScore); fillColor = clrDodgerBlue;
   }
   else if(sellScore > buyScore && sellScore > 0.20)
   {
      biasText = StringFormat("LEAN SELL (-%.2f)", sellScore);
      biasColor = clrLightPink; fillWidth = (int)(maxBarW * sellScore); fillColor = clrIndianRed;
   }
   SetLabel(D_PREFIX + "BiasVal", biasText, biasColor);
   ObjectSetInteger(0, D_PREFIX + "MeterFill", OBJPROP_XSIZE, MathMax(fillWidth, 4));
   ObjectSetInteger(0, D_PREFIX + "MeterFill", OBJPROP_BGCOLOR, fillColor);

   string rsiState = (rsi > 55.0) ? "BULLISH" : ((rsi < 45.0) ? "BEARISH" : "NEUTRAL");
   color  rsiClr   = (rsi > 55.0) ? clrLime : ((rsi < 45.0) ? clrRed : clrWhite);
   SetLabel(D_PREFIX + "RSI", StringFormat("RSI (%d): %.1f [%s]", RSI_Period, rsi, rsiState), rsiClr);

   bool macdUp = (macdM > macdS);
   SetLabel(D_PREFIX + "MACD", StringFormat("MACD: %s [%s]",
            DoubleToString(macdM, 5), macdUp ? "BULLISH" : "BEARISH"),
            macdUp ? clrLime : clrRed);

   bool maBull = (fMA > sMA);
   SetLabel(D_PREFIX + "MA", StringFormat("Fast/Slow MA: [%s]", maBull ? "BULLISH" : "BEARISH"),
            maBull ? clrLime : clrRed);

   bool aboveEMA = (curPrice > emaVal);
   SetLabel(D_PREFIX + "Trend", StringFormat("%d EMA: [%s]", TrendEMA_Period, aboveEMA ? "UPTREND" : "DOWNTREND"),
            aboveEMA ? clrLime : clrOrangeRed);

   if(UseVWAPFilter)
   {
      bool aboveVwap = (curPrice > vwapVal);
      SetLabel(D_PREFIX + "VWAP", StringFormat("VWAP: [%s]", aboveVwap ? "ABOVE" : "BELOW"),
               aboveVwap ? clrLime : clrLightPink);
   }
   else
      SetLabel(D_PREFIX + "VWAP", "VWAP: OFF", clrGray);

   // Levels follow the current bias; v4.82 always printed long-side levels.
   bool   shortBias = (sellScore > buyScore);
   double dir = shortBias ? -1.0 : 1.0;
   double sl = curPrice - dir * atrVal * ATR_StopLossMultiplier;
   double tp = curPrice + dir * atrVal * ATR_TakeProfitMultiplier;
   double be = curPrice + dir * atrVal * BreakevenTriggerATR;
   SetLabel(D_PREFIX + "Levels",
            StringFormat("%s SL %s  TP %s  BE %s", shortBias ? "S" : "L",
                         DoubleToString(sl, _Digits),
                         DoubleToString(tp, _Digits),
                         DoubleToString(be, _Digits)),
            clrWhite);

   if(lastSignalTime > 0)
   {
      int ago = iBarShift(_Symbol, _Period, lastSignalTime, false);
      SetLabel(D_PREFIX + "LastSig", StringFormat("Last signal: %s (%d bars ago)", lastSignalText, ago), clrWhite);
   }
   else
      SetLabel(D_PREFIX + "LastSig", "Last signal: --", clrGray);

   SetLabel(D_PREFIX + "ShieldTrend",
            RequireTrendAlignment ? StringFormat("%d EMA gate: ON", TrendEMA_Period) : StringFormat("%d EMA gate: OFF", TrendEMA_Period),
            RequireTrendAlignment ? clrSpringGreen : clrGray);
   SetLabel(D_PREFIX + "ShieldSR",
            SR_BounceFilter ? "S/R shield: ON" : "S/R shield: OFF",
            SR_BounceFilter ? clrSpringGreen : clrGray);
   SetLabel(D_PREFIX + "ShieldBE",
            UseDynamicBreakeven
               ? StringFormat("BE (manual) %.1fx ATR — indicator cannot move stops", BreakevenTriggerATR)
               : "Breakeven: OFF",
            UseDynamicBreakeven ? clrSpringGreen : clrGray);

   SetLabel(D_PREFIX + "Footer", StringFormat("ATR: %s | Spread: %d pts",
            DoubleToString(atrVal, _Digits), spreadPts), clrDarkGray);
   ChartRedraw(0);
}

void DestroyDashboard()
{
   ObjectsDeleteAll(0, D_PREFIX);
   ChartRedraw(0);
}

bool TriggerAlert(string signalType, bool isBuy, double price, double score, double atr)
{
   datetime now = TimeCurrent();
   if(now - lastAlertTime < AlertCooldownMinutes * 60)
      return false;
   lastAlertTime = now;
   double dir = isBuy ? 1.0 : -1.0;
   string msg = StringFormat("[ScalpSignals v4.83] %s on %s %s at %s | Score: %.2f | SL %s TP %s",
                             signalType, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period),
                             DoubleToString(price, _Digits), score,
                             DoubleToString(price - dir * atr * ATR_StopLossMultiplier, _Digits),
                             DoubleToString(price + dir * atr * ATR_TakeProfitMultiplier, _Digits));
   if(EnablePopupAlert) Alert(msg);
   if(EnableSoundAlert) PlaySound("expert.wav");
   if(EnablePushAlert)  SendNotification(msg);
   return true;
}
