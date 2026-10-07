//+------------------------------------------------------------------+
//|                                             ScalpSignals_v4.82.mq5|
//|      Scalp Signals v4.82 — confluence engine with v4.62 defects   |
//|      patched (HTF look-ahead, dead inputs, fake OBV, HUD,         |
//|      as-series cooldown, first-load alerts).                      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, Advanced Scalping System"
#property link        "https://www.mql5.com"
#property description "RSI / MACD / MA / OBV / VWAP confluence scalping signals."
#property description "v4.82: closed-HTF gate, real OBV, session VWAP, signal modes, non-repaint HUD."
#property indicator_chart_window
#property indicator_buffers 11
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
input double           ATR_SpikeThreshold      = 2.2;

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

int handleRSI      = INVALID_HANDLE;
int handleMACD     = INVALID_HANDLE;
int handleFastMA   = INVALID_HANDLE;
int handleSlowMA   = INVALID_HANDLE;
int handleTrendEMA = INVALID_HANDLE;
int handleATR      = INVALID_HANDLE;
int handleMTFTrend = INVALID_HANDLE;
int handleMTFRSI   = INVALID_HANDLE;

datetime lastAlertTime  = 0;
datetime lastAlertSignalTime = 0;
datetime lastSignalTime = 0;
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

void CreateDashboard();
void UpdateDashboard(double buyScore, double sellScore, double rsi, double macdM, double macdS,
                     double fMA, double sMA, double vwapVal, double emaVal, double atrVal,
                     double curPrice, int spreadPts);
void DestroyDashboard();
void RefreshDashboardData();
bool CreateRect(string name, int x, int y, int w, int h, color bgClr, color borderClr);
bool CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font);
void SetLabel(string name, string text, color clr);
bool TriggerAlert(string signalType, double price, double score);
double Clamp01(double v);
double ApplyMode(double eventScore, double stateScore, bool isEvent);
int    ClosedMtfShift(datetime barTime);
bool   SameDay(datetime a, datetime b);

int OnInit()
{
   if(RSI_Period < 2 || MACD_FastEMA < 1 || MACD_SlowEMA <= MACD_FastEMA ||
      MACD_SignalSMA < 1 || MA_Fast_Period < 1 || MA_Slow_Period < MA_Fast_Period ||
      TrendEMA_Period < 2 || ATR_Period < 1 || VWAP_Period < 2)
   {
      Print("[ScalpSignals v4.82] Invalid indicator periods.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(SignalThreshold < 0.0 || SignalThreshold > 1.0 ||
      SignalStrongThreshold < SignalThreshold || SignalStrongThreshold > 1.0 ||
      VWAP_Deviation < 0.0 || MaxSpreadATRFrac < 0.0 ||
      ATR_Multiplier < 0.0 || AlertCooldownMinutes < 0 ||
      SessionStartHour < 0 || SessionStartHour > 23 ||
      SessionEndHour < 0 || SessionEndHour > 23)
   {
      Print("[ScalpSignals v4.82] Invalid signal, risk, or session parameters.");
      return(INIT_PARAMETERS_INCORRECT);
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
   if(UseMTFConfirmation)
   {
      handleMTFTrend = iMA(_Symbol, MTF_Timeframe, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      handleMTFRSI   = iRSI(_Symbol, MTF_Timeframe, RSI_Period, PRICE_CLOSE);
   }

   if(handleRSI == INVALID_HANDLE || handleMACD == INVALID_HANDLE ||
      handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE ||
      handleTrendEMA == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("[ScalpSignals v4.82] Error creating indicator handles.");
      return(INIT_FAILED);
   }
   if(UseMTFConfirmation && (handleMTFTrend == INVALID_HANDLE || handleMTFRSI == INVALID_HANDLE))
   {
      Print("[ScalpSignals v4.82] Error creating MTF handles.");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "ScalpSignals v4.82");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   alertsArmed = false;
   lastAlertSignalTime = 0;
   lastSignalTime = 0;

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

double ApplyMode(double eventScore, double stateScore, bool isEvent)
{
   if(SignalMode == SIGNAL_MODE_CROSS)
      return isEvent ? eventScore : 0.0;
   if(SignalMode == SIGNAL_MODE_STATE)
      return stateScore;
   return isEvent ? eventScore : stateScore;
}

bool SameDay(datetime a, datetime b)
{
   MqlDateTime da, db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
}

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
   if(rates_total < MathMax(TrendEMA_Period, 50))
      return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(spread, true);

   int limit = rates_total - prev_calculated;
   if(limit <= 0)
      limit = 1;
   if(limit > rates_total - 1)
      limit = rates_total - 1;

   // OBV from actual volume (v4.62 used candle color and ignored iOBV)
   int obvFrom = (prev_calculated <= 0) ? (rates_total - 1) : MathMin(limit + 1, rates_total - 1);
   if(prev_calculated <= 0)
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

   if(UseVWAPFilter)
   {
      for(int i = limit; i >= 0; i--)
      {
         double sumPV = 0.0, sumV = 0.0, sumDevSq = 0.0;
         int vwapBars = 0;
         if(VWAP_Mode == VWAP_MODE_SESSION)
         {
            for(int j = i; j < rates_total; j++)
            {
               if(!SameDay(time[j], time[i]))
                  break;
               double typicalPrice = (high[j] + low[j] + close[j]) / 3.0;
               double vol = GetEffectiveVolume(volume, tick_volume, j);
               sumPV += typicalPrice * vol;
               sumV  += vol;
               vwapBars++;
            }
         }
         else
         {
            vwapBars = MathMin(VWAP_Period, rates_total - i);
            if(vwapBars < 2)
            {
               bufVWAP[i] = close[i];
               bufVWAPUpper[i] = close[i];
               bufVWAPLower[i] = close[i];
               continue;
            }
            for(int j = 0; j < vwapBars; j++)
            {
               int idx = i + j;
               double typicalPrice = (high[idx] + low[idx] + close[idx]) / 3.0;
               double vol = GetEffectiveVolume(volume, tick_volume, idx);
               sumPV += typicalPrice * vol;
               sumV  += vol;
            }
         }
         if(vwapBars < 2)
         {
            bufVWAP[i] = close[i];
            bufVWAPUpper[i] = close[i];
            bufVWAPLower[i] = close[i];
            continue;
         }
         double currentVwap = (sumV > 0) ? (sumPV / sumV) : close[i];
         bufVWAP[i] = currentVwap;
         if(VWAP_Mode == VWAP_MODE_SESSION)
         {
            for(int j = i; j < i + vwapBars && j < rates_total; j++)
            {
               if(!SameDay(time[j], time[i]))
                  break;
               double typicalPrice = (high[j] + low[j] + close[j]) / 3.0;
               double vol = GetEffectiveVolume(volume, tick_volume, j);
               sumDevSq += vol * MathPow(typicalPrice - currentVwap, 2.0);
            }
         }
         else
         {
            for(int j = 0; j < vwapBars; j++)
            {
               int idx = i + j;
               double typicalPrice = (high[idx] + low[idx] + close[idx]) / 3.0;
               double vol = GetEffectiveVolume(volume, tick_volume, idx);
               sumDevSq += vol * MathPow(typicalPrice - currentVwap, 2.0);
            }
         }
         double stdDev = (sumV > 0) ? MathSqrt(sumDevSq / sumV) : 0.0;
         bufVWAPUpper[i] = currentVwap + (stdDev * VWAP_Deviation);
         bufVWAPLower[i] = currentVwap - (stdDev * VWAP_Deviation);
      }
   }

   double rsiArr[], macdMain[], macdSig[], fastMA[], slowMA[], trendEMA[], atrVal[];
   ArraySetAsSeries(rsiArr, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig, true);
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(trendEMA, true);
   ArraySetAsSeries(atrVal, true);

   if(CopyBuffer(handleRSI, 0, 0, rates_total, rsiArr) <= 0) return(prev_calculated);
   if(CopyBuffer(handleMACD, 0, 0, rates_total, macdMain) <= 0) return(prev_calculated);
   if(CopyBuffer(handleMACD, 1, 0, rates_total, macdSig) <= 0) return(prev_calculated);
   if(CopyBuffer(handleFastMA, 0, 0, rates_total, fastMA) <= 0) return(prev_calculated);
   if(CopyBuffer(handleSlowMA, 0, 0, rates_total, slowMA) <= 0) return(prev_calculated);
   if(CopyBuffer(handleTrendEMA, 0, 0, rates_total, trendEMA) <= 0) return(prev_calculated);
   if(CopyBuffer(handleATR, 0, 0, rates_total, atrVal) <= 0) return(prev_calculated);

   int startBar = 0;
   for(int i = limit; i >= startBar; i--)
   {
      bufStrongBuy[i]  = EMPTY_VALUE;
      bufBuy[i]        = EMPTY_VALUE;
      bufSell[i]       = EMPTY_VALUE;
      bufStrongSell[i] = EMPTY_VALUE;
      if(i + 1 >= rates_total)
         continue;

      bufTrendEMA[i] = trendEMA[i];
      double currentATR = (atrVal[i] > 0) ? atrVal[i] : (high[i] - low[i]);

      bool blocked = false;
      if(atrVal[i] > 0 && atrVal[i + 1] > 0 && (atrVal[i] / atrVal[i + 1] > ATR_SpikeThreshold))
         blocked = true;

      double rsiBuyScore = 0.0, rsiSellScore = 0.0;
      bool rsiHookBuy  = (rsiArr[i + 1] <= RSI_OverSold && rsiArr[i] > RSI_OverSold);
      bool rsiHookSell = (rsiArr[i + 1] >= RSI_OverBought && rsiArr[i] < RSI_OverBought);
      if(rsiArr[i] > 50.0 && rsiArr[i] < RSI_OverBought)
         rsiBuyScore = (rsiArr[i] - 50.0) / 20.0;
      if(rsiArr[i] < 50.0 && rsiArr[i] > RSI_OverSold)
         rsiSellScore = (50.0 - rsiArr[i]) / 20.0;
      rsiBuyScore  = Clamp01(ApplyMode(1.0, Clamp01(rsiBuyScore), rsiHookBuy));
      rsiSellScore = Clamp01(ApplyMode(1.0, Clamp01(rsiSellScore), rsiHookSell));

      bool macdBullCross = (macdMain[i + 1] <= macdSig[i + 1] && macdMain[i] > macdSig[i]);
      bool macdBearCross = (macdMain[i + 1] >= macdSig[i + 1] && macdMain[i] < macdSig[i]);
      double macdBuyScore  = Clamp01(ApplyMode(1.0, (macdMain[i] > macdSig[i]) ? 0.6 : 0.0, macdBullCross));
      double macdSellScore = Clamp01(ApplyMode(1.0, (macdMain[i] < macdSig[i]) ? 0.6 : 0.0, macdBearCross));

      bool maBullCross = (fastMA[i + 1] <= slowMA[i + 1] && fastMA[i] > slowMA[i]);
      bool maBearCross = (fastMA[i + 1] >= slowMA[i + 1] && fastMA[i] < slowMA[i]);
      double maBuyScore  = Clamp01(ApplyMode(1.0, (fastMA[i] > slowMA[i]) ? 0.5 : 0.0, maBullCross));
      double maSellScore = Clamp01(ApplyMode(1.0, (fastMA[i] < slowMA[i]) ? 0.5 : 0.0, maBearCross));

      double vwapBuyScore = 0.5, vwapSellScore = 0.5;
      if(UseVWAPFilter)
      {
         vwapBuyScore  = (close[i] > bufVWAP[i]) ? ((close[i] <= bufVWAPUpper[i]) ? 0.8 : 0.4) : 0.0;
         vwapSellScore = (close[i] < bufVWAP[i]) ? ((close[i] >= bufVWAPLower[i]) ? 0.8 : 0.4) : 0.0;
      }

      int obvLook = MathMin(5, rates_total - i - 1);
      double obvSlope = bufOBVTrend[i] - bufOBVTrend[i + obvLook];
      double obvBuyScore  = (obvSlope > 0.0) ? 0.8 : 0.2;
      double obvSellScore = (obvSlope < 0.0) ? 0.8 : 0.2;

      double totalBuyScore = Clamp01(rsiBuyScore * 0.25 + macdBuyScore * 0.25 +
                                     maBuyScore * 0.20 + vwapBuyScore * 0.15 + obvBuyScore * 0.15);
      double totalSellScore = Clamp01(rsiSellScore * 0.25 + macdSellScore * 0.25 +
                                      maSellScore * 0.20 + vwapSellScore * 0.15 + obvSellScore * 0.15);

      if(DivergenceBoost && i + 14 < rates_total)
      {
         if(close[i] < close[i + 14] && rsiArr[i] > rsiArr[i + 14] && rsiArr[i] < 48.0)
            totalBuyScore = Clamp01(totalBuyScore + 0.12);
         if(close[i] > close[i + 14] && rsiArr[i] < rsiArr[i + 14] && rsiArr[i] > 52.0)
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

      if(StrictMTFGate && UseMTFConfirmation && handleMTFTrend != INVALID_HANDLE)
      {
         int mtfSh = ClosedMtfShift(time[i]);
         double mtfEMA[1], mtfRsi[1];
         if(mtfSh >= 0 &&
            CopyBuffer(handleMTFTrend, 0, mtfSh, 1, mtfEMA) > 0 &&
            CopyBuffer(handleMTFRSI, 0, mtfSh, 1, mtfRsi) > 0)
         {
            if(close[i] < mtfEMA[0] || mtfRsi[0] < 45.0)
               totalBuyScore = 0.0;
            if(close[i] > mtfEMA[0] || mtfRsi[0] > 55.0)
               totalSellScore = 0.0;
         }
      }

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
               if((high[hiIdx] - close[i]) < dangerZone)
                  totalBuyScore = 0.0;
               if((close[i] - low[loIdx]) < dangerZone)
                  totalSellScore = 0.0;
            }
         }
      }

      if(UseSpreadFilter && currentATR > 0.0)
      {
         double spr = (double)spread[i] * _Point;
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
         lastVwap       = bufVWAP[0];
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
         if(bufStrongBuy[idx] != EMPTY_VALUE || bufBuy[idx] != EMPTY_VALUE ||
            bufSell[idx] != EMPTY_VALUE || bufStrongSell[idx] != EMPTY_VALUE)
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
         bool strong = (totalBuyScore >= SignalStrongThreshold);
         if(strong && ShowStrongSignals)
         {
            bufStrongBuy[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("STRONG BUY", close[i], totalBuyScore))
                  lastAlertSignalTime = time[i];
            }
         }
         else if(!strong && ShowRegularSignals)
         {
            bufBuy[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("BUY", close[i], totalBuyScore))
                  lastAlertSignalTime = time[i];
            }
         }
         else if(strong && !ShowStrongSignals && ShowRegularSignals)
         {
            bufBuy[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("BUY", close[i], totalBuyScore))
                  lastAlertSignalTime = time[i];
            }
         }
      }
      else if(totalSellScore >= SignalThreshold && totalSellScore > totalBuyScore)
      {
         double arrowPrice = (ArrowPosition == ARROW_POSITION_HIGHLOW) ?
                             (high[i] + arrowOffset) : (close[i] + arrowOffset);
         bool strong = (totalSellScore >= SignalStrongThreshold);
         if(strong && ShowStrongSignals)
         {
            bufStrongSell[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("STRONG SELL", close[i], totalSellScore))
                  lastAlertSignalTime = time[i];
            }
         }
         else if(!strong && ShowRegularSignals)
         {
            bufSell[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("SELL", close[i], totalSellScore))
                  lastAlertSignalTime = time[i];
            }
         }
         else if(strong && !ShowStrongSignals && ShowRegularSignals)
         {
            bufSell[i] = arrowPrice;
            lastSignalTime = time[i];
            if(alertsArmed && i <= 1 && lastAlertSignalTime != time[i])
            {
               if(TriggerAlert("SELL", close[i], totalSellScore))
                  lastAlertSignalTime = time[i];
            }
         }
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
   lastSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
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
   int width = 290;
   int height = 380;
   CreateRect(D_PREFIX + "BG", x, y, width, height, DashboardBGColor, DashboardBorderColor);
   CreateRect(D_PREFIX + "HeaderBG", x + 1, y + 1, width - 2, 28, C'30,41,59', DashboardBorderColor);
   CreateLabel(D_PREFIX + "Title", x + 10, y + 6, "SCALPSIGNALS v4.82", clrCyan, 9, "Segoe UI Bold");
   int curY = y + 36;
   CreateLabel(D_PREFIX + "BiasHdr", x + 12, curY, "MARKET CONFLUENCE & BIAS", clrSlateGray, 8, "Segoe UI Bold");
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
   CreateLabel(D_PREFIX + "Trend", x + 12, curY, "50 EMA: --", clrWhite, 8, "Segoe UI");
   curY += 16;
   CreateLabel(D_PREFIX + "VWAP",  x + 12, curY, "VWAP: --", clrWhite, 8, "Segoe UI");
   curY += 20;
   CreateRect(D_PREFIX + "Sep2", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "LvlHdr", x + 12, curY, "SUGGESTED SL / TP / BE", clrSlateGray, 8, "Segoe UI Bold");
   curY += 16;
   CreateLabel(D_PREFIX + "Levels", x + 12, curY, "SL --  TP --  BE --", clrWhite, 8, "Segoe UI");
   curY += 20;
   CreateRect(D_PREFIX + "Sep3", x + 10, curY, width - 20, 1, C'51,65,85', clrNONE);
   curY += 8;
   CreateLabel(D_PREFIX + "ShieldHdr", x + 12, curY, "FILTERS", clrSpringGreen, 8, "Segoe UI Bold");
   curY += 16;
   CreateLabel(D_PREFIX + "ShieldTrend", x + 12, curY, "50 EMA gate", clrWhite, 8, "Segoe UI");
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
   int width = 265;
   int maxBarW = width - 24;
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
   SetLabel(D_PREFIX + "Trend", StringFormat("50 EMA: [%s]", aboveEMA ? "UPTREND" : "DOWNTREND"),
            aboveEMA ? clrLime : clrOrangeRed);

   bool aboveVwap = (curPrice > vwapVal);
   SetLabel(D_PREFIX + "VWAP", StringFormat("VWAP: [%s]", aboveVwap ? "ABOVE" : "BELOW"),
            aboveVwap ? clrLime : clrLightPink);

   double sl = curPrice - atrVal * ATR_StopLossMultiplier;
   double tp = curPrice + atrVal * ATR_TakeProfitMultiplier;
   double be = curPrice + atrVal * BreakevenTriggerATR;
   SetLabel(D_PREFIX + "Levels",
            StringFormat("L SL %s  TP %s  BE %s",
                         DoubleToString(sl, _Digits),
                         DoubleToString(tp, _Digits),
                         DoubleToString(be, _Digits)),
            clrWhite);

   SetLabel(D_PREFIX + "ShieldTrend",
            RequireTrendAlignment ? "50 EMA gate: ON" : "50 EMA gate: OFF",
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

bool TriggerAlert(string signalType, double price, double score)
{
   datetime now = TimeCurrent();
   if(now - lastAlertTime < AlertCooldownMinutes * 60)
      return false;
   lastAlertTime = now;
   string msg = StringFormat("[ScalpSignals v4.82] %s on %s at %s | Score: %.2f",
                             signalType, _Symbol, DoubleToString(price, _Digits), score);
   if(EnablePopupAlert) Alert(msg);
   if(EnableSoundAlert) PlaySound("expert.wav");
   if(EnablePushAlert)  SendNotification(msg);
   return true;
}
