//+------------------------------------------------------------------+
//|                     Gold M5 Signal_Generator.mq5                 |
//|                        Reviewed & Enhanced v3.20                 |
//|                                                                  |
//|  ENHANCED VERSION v3.20 - Scalping Pack: MTF fix, fresh-cross,   |
//|  over-extension, spread-adaptive SL/TP, partial levels, perf opt |
//+------------------------------------------------------------------+
#property copyright "Updated by Grok (xAI) - Reviewed v3.20"
#property link      "https://x.ai"
#property version   "3.20"
#property strict
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   6

//--- Plot definitions
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  C'0,255,127'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  C'255,69,0'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "EMA Short"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrNONE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "EMA Long"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrNONE
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- Price Action Plot Definitions
#property indicator_label5  "Bullish Price Action"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  C'0,255,64'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

#property indicator_label6  "Bearish Price Action"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  C'255,0,0'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

//+------------------------------------------------------------------+
//| Constants and Configuration                                      |
//+------------------------------------------------------------------+
//--- Indicator Constants
const int MIN_BARS_REQUIRED        = 100;
const int ADX_STRONG_THRESHOLD     = 25;
const int ADX_WEAK_THRESHOLD       = 20;
const double RSI_OVERBOUGHT        = 76.0;
const double RSI_OVERSOLD          = 24.0;
const double RSI_NEUTRAL_HIGH      = 55.0;
const double RSI_NEUTRAL_LOW       = 45.0;
const double DI_RATIO_STRONG_BUY   = 1.6;
const double DI_RATIO_STRONG_SELL  = 1.6;
const int SIGNAL_RESET_BARS        = 12;
const int SIGNAL_RESET_CONDITIONS  = 4;
const int PANEL_UPDATE_INTERVAL    = 1;
const int MAX_HISTORY_ITEMS        = 100;
const int ALERT_COOLDOWN_BARS      = 5;
const int SIGNAL_SHIFT             = 1;
const int VOLUME_MA_PERIOD         = 20;
const int ARRAY_RESIZE_PADDING     = 500;
const int SIGNAL_VALID_BARS        = 10;

//--- Agent specific constants
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_RANDOM_WALK,
   REGIME_UNKNOWN
};

//--- Enum for Signal Types
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};

//--- Enum for Trend Direction
enum ENUM_TREND_DIRECTION
{
   TREND_WEAK_SIDEWAYS,
   TREND_BULLISH,
   TREND_STRONG_BULLISH,
   TREND_BEARISH,
   TREND_STRONG_BEARISH,
   TREND_MIXED
};

//--- [ENH-06] MTF Filter Mode
enum ENUM_MTF_MODE
{
   MTF_OFF,          // No MTF filter
   MTF_BLOCK,        // Block counter-trend signals
   MTF_DOWNGRADE     // Allow but don't count as "strong"
};

//--- Input parameters for periods and thresholds - OPTIMIZED FOR GOLD M5
input group "Indicator Parameters"
input int EMA_Short_Period       = 13;         // Fast momentum path (Captures M5 explosive moves)
input int EMA_Long_Period        = 50;         // Clean structural baseline (Avoids 21-period whipsaws)
input int RSI_Period             = 7;          // Kept at 7 (Perfect for spotting Gold price exhaustion)
input int MACD_Fast              = 12;         // Shifted to standard cycle to prevent overlapping EMA logic
input int MACD_Slow              = 26;         // Shifted to standard cycle to prevent overlapping EMA logic
input int MACD_Signal_Period     = 9;          // Shifted to standard cycle to prevent overlapping EMA logic
input int ADX_Period             = 14;         // Increased to 14 to filter out false Asian session breakouts
input int ATR_Period             = 14;         // Smooths out random 5-minute news candle spikes

input group "Signal Settings"
input double Volume_Threshold    = 1.35;       // Raised to 1.35 (Requires definitive institutional volume)
input int Signal_Cooldown        = 3;          // Raised to 3 bars to prevent over-trading the same M5 swing
input double Risk_Reward_Min     = 1.5;        // Raised to 1.5 (Gold requires higher RR to outrun spreads)
input double ATR_Stop_Multiplier = 2.2;        // Raised to 2.2 (Gives Gold room to breathe without early stop-outs)
input double ATR_Take_Multiplier = 3.3;        // Scaled up to hit a healthy 1:1.5 standard structural payout
input bool UsePriceAction        = true;       // Keep true (Essential for confirming Gold candlestick reversals)
input int Max_History_Signals    = 15;
input double Max_Spread_Pips     = 6.0;        // Raised to 6.0 Pips (\$0.60) to avoid execution blocks during New York volume


input group "Price Action Colors"
input color PriceAction_Bullish = C'0,255,64';
input color PriceAction_Bearish = C'255,0,0';

input group "Alert Settings"
input bool EnableAlerts          = false;
input bool EnableEmail           = false;
input bool EnablePush            = false;

input group "Time Filtering"
input bool UseTimeFilter         = false;
input int StartHour              = 0;
input int EndHour                = 23;

input group "Session Detection"
input bool UseSessionDetection   = true;
input int Session_LondonStart    = 7;
input int Session_LondonEnd      = 16;
input int Session_NYStart        = 13;
input int Session_NYEnd          = 21;
input bool TradeLondonOnly       = false;
input bool TradeNYOnly           = false;
input bool TradeOverlap          = false;

input group "Agent Hub (v4.1)"
input bool   InpUseAgentMemory   = true;
input string InpPythonHubUrl     = "http://localhost:8000";
input double InpMinAgentConf     = 0.65;
input bool   InpBlockRandomWalk  = true;

//--- [ENH-01] ATR Envelope Filter
input group "ATR Envelope Filter"
input bool   UseATREnvelope       = true;
input double ATR_Min_Multiplier   = 0.4;    // Minimum ATR as fraction of ATR MA
input double ATR_Max_Multiplier   = 2.5;    // Maximum ATR as fraction of ATR MA
input int    ATR_MA_Period        = 50;     // Lookback for ATR average

//--- [ENH-02] Multi-Timeframe Filter
input group "Multi-Timeframe Filter"
input bool   UseMTFFilter         = true;
input ENUM_MTF_MODE MTF_Mode      = MTF_BLOCK;
input int    MTF_EMA_Period       = 21;     // EMA period for M15/H1

//--- [ENH-03] Spread Cost Filter
input group "Spread Cost Filter"
input bool   UseSpreadCostFilter  = true;
input double Max_Spread_Pct_TP     = 25.0;   // Max spread as % of TP distance

//--- [ENH-04] Pullback Entry
input group "Pullback Entry"
input bool   UsePullbackEntry     = true;
input double Pullback_ATR_Factor  = 0.5;    // Max distance from EMA for pullback

//--- [ENH-05] Consecutive Bar Confirmation
input group "Consecutive Bar Confirmation"
input int    Consecutive_Bars_Req = 1;      // 1 = current behavior, 2+ = stricter

//--- [BUG-11] Configurable Signal Strength Weights
input group "Signal Strength Weights"
input double Weight_ADX           = 20.0;
input double Weight_Volume        = 25.0;
input double Weight_Trend         = 35.0;
input double Weight_RSI            = 15.0;
input double Weight_MACD          = 5.0;

//--- [BUG-12] Configurable Arrow Offset
input group "Arrow Display"
input double Arrow_Offset_ATR_Mult = 0.5;

//--- [SCALP v3.20] Scalping Enhancements (all default-safe)
input group "Scalping Enhancements (v3.20)"
input bool   UseH1Confirmation      = false;  // Require H1 trend agreement in MTF filter
input bool   UseOverExtensionFilter = true;   // Skip entries too far from EMA Short
input double Max_Extension_ATR      = 1.2;    // Max |close-EMA| in ATR units before skipping
input bool   UseFreshCrossFilter    = true;   // Require a recent EMA Short/Long cross
input int    Fresh_Cross_MaxBars    = 4;      // Max bars since cross to accept signal
input bool   UseSpreadAdaptiveSLTP  = true;   // Pad SL/TP by current spread (cost-aware)
input bool   Show_Partial_Levels    = true;   // Show TP1 (50%) line on the panel
input bool   UseIncrementalCalc     = true;   // Perf: only recompute recent bars per tick

//--- Panel settings
input group "Panel Settings"
input int Panel_X                = 10;
input int Panel_Y                = 100;
input int Panel_Width            = 230;
input int Panel_Height           = 350;
input int Level_Line_Bars        = 12;
input color Panel_Background      = C'27,27,36';
input color Panel_Border          = C'47,47,68';
input color Panel_Text            = clrWhite;
input color Panel_Title_Color     = C'255,215,0';
input color Signal_Buy            = C'0,255,127';
input color Signal_Strong_Buy     = C'0,255,64';
input color Signal_Sell          = C'255,69,0';
input color Signal_Strong_Sell    = C'255,0,0';
input color Signal_Neutral       = C'169,169,169';
input color Value_Color          = C'88,166,255';
input color Warning_Color        = C'234,179,8';
input color Success_Color        = C'34,197,94';
input color Time_Color           = C'148,163,184';
input color Divider_Color        = C'65,65,95';
input string Font_Name           = "Arial";
input int Title_Font_Size        = 11;
input int Text_Font_Size         = 10;

//+------------------------------------------------------------------+
//| Signal Data Structure                                            |
//+------------------------------------------------------------------+
struct SSignalData
{
   ENUM_SIGNAL_TYPE type;
   datetime         time;
   double           price;
   double           sl;
   double           tp;
   double           strength;
};

struct SSignalHistoryItem
{
   datetime       time;
   string         type;
   double         price;
   double         success;
};

//+------------------------------------------------------------------+
//| CAgentBridge - Interfaces with Python Hub logic                  |
//+------------------------------------------------------------------+
class CAgentBridge
{
private:
   string            m_baseUrl;
   bool              m_isConnected;

public:
   CAgentBridge() : m_baseUrl(InpPythonHubUrl), m_isConnected(false) {}

   // Simulates the Memory Check (Gate 11 in architecture)
   bool CheckMemorySimilarity(double rsiVal, double adxVal, ENUM_SIGNAL_TYPE dir, double &outConfidence)
   {
      if(!InpUseAgentMemory) { outConfidence = 1.0; return true; }

      char data[], result[];
      string result_headers;
      string url = m_baseUrl + "/api/v1/memory/check";
      string directionStr = (dir == SIGNAL_BUY) ? "BUY" : "SELL";

      string json = StringFormat("{\"features\": {\"rsi_m5\": %.2f, \"adx\": %.2f}, \"direction\": \"%s\", \"regime\": \"TRENDING\", \"session\": \"LONDON\"}",
                                 rsiVal, adxVal, directionStr);
      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);

      g_LastServerPing = TimeCurrent();

      int res = WebRequest("POST", url, "Content-Type: application/json", 500, data, result, result_headers);

      if(res == 200)
      {
         string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         int pos = StringFind(response, "\"win_rate\":");
         if(pos >= 0 && StringFind(response, "\"should_trade\":true") >= 0)
         {
            outConfidence = StringToDouble(StringSubstr(response, pos + 11));
            return (outConfidence >= InpMinAgentConf);
         }
      }
      return true; // Pass if hub is unreachable
   }

   bool GetRiskMode(double daily_dd, double total_dd, bool is_new_day, double &outMultiplier)
   {
      if(!InpUseAgentMemory) { outMultiplier = 1.0; return true; }

      char data[], result[];
      string result_headers;
      string url = m_baseUrl + "/api/v1/memory/risk-mode";

      string json = StringFormat("{\"daily_dd\": %.2f, \"total_dd\": %.2f, \"is_new_day\": %s}",
                                 daily_dd, total_dd, is_new_day ? "true" : "false");
      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);

      g_LastServerPing = TimeCurrent();

      int res = WebRequest("POST", url, "Content-Type: application/json", 200, data, result, result_headers);
      if(res == 200)
      {
         string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         int pos = StringFind(response, "\"size_multiplier\":");
         if(pos >= 0) {
            outMultiplier = StringToDouble(StringSubstr(response, pos + 18));
            return true;
         }
      }
      outMultiplier = 1.0;
      return false;
   }

   void RecordTrade(const bool winner, const double profit, const ENUM_SIGNAL_TYPE dir, const double rsiVal, const double adxVal)
   {
      if(!InpUseAgentMemory) return;

      char data[], result[];
      string result_headers;
      string url = m_baseUrl + "/api/v1/memory/record";
      string directionStr = (dir == SIGNAL_BUY) ? "BUY" : "SELL";

      string json = StringFormat("{\"is_winner\": %s, \"profit_loss\": %.2f, \"direction\": \"%s\", \"regime\": \"TRENDING\", \"session\": \"LONDON\", \"signal_tier\": \"A\", \"spread_state\": \"LOW\", \"raw_features\": {\"rsi_m5\": %.2f, \"adx\": %.2f}}",
                                 winner ? "true" : "false", profit, directionStr, rsiVal, adxVal);

      StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
      g_LastServerPing = TimeCurrent();
      WebRequest("POST", url, "Content-Type: application/json", 500, data, result, result_headers);
   }

   // [BUG-07 FIX] Consistent shift parameter for all timeframes
   ENUM_MARKET_REGIME DetectRegime(const double &m5Prices[], const int shift, const double adxMain)
   {
      // 1. Calculate M5 entropy using the same shift
      double s5 = CalculateEntropy(m5Prices, shift, 100);

      // 2. Fetch Higher Timeframe Data (M30 and H1) - [BUG-07 FIX] use shift=1 for all
      double closeM30[], closeH1[];
      ArraySetAsSeries(closeM30, true);
      ArraySetAsSeries(closeH1, true);

      if(CopyClose(_Symbol, PERIOD_M30, 0, 102, closeM30) < 102 ||
         CopyClose(_Symbol, PERIOD_H1, 0, 102, closeH1) < 102)
         return REGIME_UNKNOWN;

      // Use shift=1 for consistency with M5 confirmed bar
      double s30 = CalculateEntropy(closeM30, 1, 100);
      double sH1 = CalculateEntropy(closeH1, 1, 100);

      // 3. Multi-Timeframe Noise Filter
      if(s5 > 3.05 || s30 > 3.15 || sH1 > 3.2) return REGIME_RANDOM_WALK;

      // 4. Trend Detection
      if(adxMain > ADX_STRONG_THRESHOLD)
         return REGIME_TRENDING;
      if(adxMain < ADX_WEAK_THRESHOLD)
         return REGIME_RANGING;

      return REGIME_RANGING;
   }

private:
   double CalculateEntropy(const double &prices[], const int shift, const int period)
   {
      if(period < 10 || ArraySize(prices) < shift + period + 1) return 0;

      int counts[10];
      ArrayInitialize(counts, 0);

      double min_r = DBL_MAX, max_r = -DBL_MAX;
      double returns[];
      ArrayResize(returns, period);

      for(int i = 0; i < period; i++) {
         returns[i] = prices[shift + i] - prices[shift + i + 1];
         if(returns[i] < min_r) min_r = returns[i];
         if(returns[i] > max_r) max_r = returns[i];
      }

      double range = max_r - min_r;
      if(range == 0) return 0;

      for(int i = 0; i < period; i++) {
         int bin = (int)MathFloor(((returns[i] - min_r) / range) * (10 - 1));
         if(bin >= 0 && bin < 10) counts[bin]++;
      }

      double entropy = 0;
      for(int i = 0; i < 10; i++) {
         if(counts[i] > 0) {
            double p = (double)counts[i] / period;
            entropy -= p * (MathLog(p) / MathLog(2.0));
         }
      }
      return entropy;
   }
};

//+------------------------------------------------------------------+
//| CIndicatorManager Class - Manages all indicator handles          |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   int               m_rsiHandle;
   int               m_macdHandle;
   int               m_adxHandle;
   int               m_atrHandle;
   int               m_emaShortHandle;
   int               m_emaLongHandle;
   int               m_emaM15Handle;     // [ENH-02 FIX] Proper M15 EMA handle
   int               m_emaH1Handle;      // [ENH-02] Optional H1 EMA handle

public:
                     CIndicatorManager();
                     ~CIndicatorManager();

   bool              Initialize();
   void              ReleaseAll();

   // Getters for handles
   int               GetRSIHandle()       const { return m_rsiHandle; }
   int               GetMACDHandle()      const { return m_macdHandle; }
   int               GetADXHandle()       const { return m_adxHandle; }
   int               GetATRHandle()       const { return m_atrHandle; }
   int               GetEMAShortHandle()  const { return m_emaShortHandle; }
   int               GetEMALongHandle()   const { return m_emaLongHandle; }
   int               GetEMAM15Handle()    const { return m_emaM15Handle; }   // [ENH-02]
   int               GetEMAH1Handle()     const { return m_emaH1Handle; }    // [ENH-02]

   bool              IsValid() const;
};

CIndicatorManager::CIndicatorManager() :
   m_rsiHandle(INVALID_HANDLE),
   m_macdHandle(INVALID_HANDLE),
   m_adxHandle(INVALID_HANDLE),
   m_atrHandle(INVALID_HANDLE),
   m_emaShortHandle(INVALID_HANDLE),
   m_emaLongHandle(INVALID_HANDLE),
   m_emaM15Handle(INVALID_HANDLE),    // [ENH-02]
   m_emaH1Handle(INVALID_HANDLE)      // [ENH-02]
{
}

CIndicatorManager::~CIndicatorManager()
{
   ReleaseAll();
}

bool CIndicatorManager::Initialize()
{
   // Current timeframe (M5) indicators
   m_rsiHandle = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE);
   m_macdHandle = iMACD(NULL, 0, MACD_Fast, MACD_Slow, MACD_Signal_Period, PRICE_CLOSE);
   m_adxHandle = iADX(NULL, 0, ADX_Period);
   m_atrHandle = iATR(NULL, 0, ATR_Period);
   m_emaShortHandle = iMA(NULL, 0, EMA_Short_Period, 0, MODE_EMA, PRICE_CLOSE);
   m_emaLongHandle = iMA(NULL, 0, EMA_Long_Period, 0, MODE_EMA, PRICE_CLOSE);

   // [ENH-02 FIX] Proper M30 and H1 EMA handles
   m_emaM15Handle = iMA(_Symbol, PERIOD_M30, MTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   m_emaH1Handle  = iMA(_Symbol, PERIOD_H1, MTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(m_rsiHandle == INVALID_HANDLE || m_macdHandle == INVALID_HANDLE ||
      m_adxHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE ||
      m_emaShortHandle == INVALID_HANDLE || m_emaLongHandle == INVALID_HANDLE)
   {
      Print("[GOLD] Error creating indicator handles: ", GetLastError());
      return false;
   }

   // [ENH-02] Warn if MTF handles fail (non-fatal)
   if(m_emaM15Handle == INVALID_HANDLE)
      Print("[GOLD] Warning: Failed to create M30 EMA handle. MTF filter disabled.");
   if(m_emaH1Handle == INVALID_HANDLE)
      Print("[GOLD] Warning: Failed to create H1 EMA handle. MTF filter uses M30 only.");

   return true;
}

void CIndicatorManager::ReleaseAll()
{
   if(m_rsiHandle != INVALID_HANDLE) { IndicatorRelease(m_rsiHandle); m_rsiHandle = INVALID_HANDLE; }
   if(m_macdHandle != INVALID_HANDLE) { IndicatorRelease(m_macdHandle); m_macdHandle = INVALID_HANDLE; }
   if(m_adxHandle != INVALID_HANDLE) { IndicatorRelease(m_adxHandle); m_adxHandle = INVALID_HANDLE; }
   if(m_atrHandle != INVALID_HANDLE) { IndicatorRelease(m_atrHandle); m_atrHandle = INVALID_HANDLE; }
   if(m_emaShortHandle != INVALID_HANDLE) { IndicatorRelease(m_emaShortHandle); m_emaShortHandle = INVALID_HANDLE; }
   if(m_emaLongHandle != INVALID_HANDLE) { IndicatorRelease(m_emaLongHandle); m_emaLongHandle = INVALID_HANDLE; }
   if(m_emaM15Handle != INVALID_HANDLE) { IndicatorRelease(m_emaM15Handle); m_emaM15Handle = INVALID_HANDLE; }
   if(m_emaH1Handle != INVALID_HANDLE) { IndicatorRelease(m_emaH1Handle); m_emaH1Handle = INVALID_HANDLE; }
}

bool CIndicatorManager::IsValid() const
{
   return (m_rsiHandle != INVALID_HANDLE && m_macdHandle != INVALID_HANDLE &&
           m_adxHandle != INVALID_HANDLE && m_atrHandle != INVALID_HANDLE &&
           m_emaShortHandle != INVALID_HANDLE && m_emaLongHandle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| CSignalManager Class - Manages signal state and history          |
//+------------------------------------------------------------------+
class CSignalManager
{
private:
   ENUM_SIGNAL_TYPE  m_currentSignal;
   double            m_signalPrice;
   datetime          m_signalTime;
   datetime          m_signalBarTime;
   int               m_signalBarIndex;
   double            m_stopLoss;
   double            m_takeProfit;
   int               m_alertCounter;
   double            m_agentConfidence;
   SSignalHistoryItem m_signalHistory[];

   // [ENH-05] Consecutive bar tracking
   int               m_buyConsecutiveCount;
   int               m_sellConsecutiveCount;
   datetime          m_lastConsecutiveBarTime;

public:
                     CSignalManager();
                     ~CSignalManager();

   void              Reset();
   void              SetSignal(ENUM_SIGNAL_TYPE type, double price, datetime time, int barIndex, double sl, double tp, double confidence = 0);
   void              ResetSignalIfNeeded(const double &emaShort[], const double &emaLong[],
                                         const double &macdMain[], const double &macdSignal[],
                                         const double &rsiArr[], const double &adxPlusDiArr[],
                                         const double &adxMinusDi[], const double &close[], int shift);

   // [ENH-05] Consecutive bar management
   void              UpdateConsecutiveCounts(bool buyAligned, bool sellAligned, datetime barTime);
   int               GetBuyConsecutiveCount()  const { return m_buyConsecutiveCount; }
   int               GetSellConsecutiveCount() const { return m_sellConsecutiveCount; }
   void              ResetConsecutiveCounts();

   // Getters
   ENUM_SIGNAL_TYPE  GetCurrentSignal()   const { return m_currentSignal; }
   double            GetSignalPrice()      const { return m_signalPrice; }
   datetime          GetSignalTime()       const { return m_signalTime; }
   datetime          GetSignalBarTime()   const { return m_signalBarTime; }
   double            GetStopLoss()        const { return m_stopLoss; }
   double            GetTakeProfit()      const { return m_takeProfit; }
   int               GetAlertCounter()     const { return m_alertCounter; }
   double            GetAgentConfidence() const { return m_agentConfidence; }
   int               GetSignalBarIndex()  const { return m_signalBarIndex; }

   void              IncrementAlertCounter() { m_alertCounter++; }
   void              ResetAlertCounter()    { m_alertCounter = 0; }
   bool              CanGenerateAlert()     const { return m_alertCounter < ALERT_COOLDOWN_BARS; }

   void              AddToHistory(string type, double price);
   void              GetSignalInfo(string &type, double &price, double &sl, double &tp) const;

   bool              IsSignalStillValid(int currentShift) const;
};

CSignalManager::CSignalManager() :
   m_currentSignal(SIGNAL_NONE),
   m_signalPrice(0),
   m_signalTime(0),
   m_signalBarTime(0),
   m_signalBarIndex(-1),
   m_stopLoss(0),
   m_takeProfit(0),
   m_alertCounter(0),
   m_agentConfidence(0),
   m_buyConsecutiveCount(0),    // [ENH-05]
   m_sellConsecutiveCount(0),    // [ENH-05]
   m_lastConsecutiveBarTime(0)
{
   ArrayResize(m_signalHistory, 0);
}

CSignalManager::~CSignalManager()
{
}

void CSignalManager::Reset()
{
   m_currentSignal = SIGNAL_NONE;
   m_signalPrice = 0;
   m_signalTime = 0;
   m_signalBarTime = 0;
   m_signalBarIndex = -1;
   m_stopLoss = 0;
   m_takeProfit = 0;
   m_agentConfidence = 0;
   m_alertCounter = 0;
   m_buyConsecutiveCount = 0;
   m_sellConsecutiveCount = 0;
   m_lastConsecutiveBarTime = 0;
}

void CSignalManager::SetSignal(ENUM_SIGNAL_TYPE type, double price, datetime time, int barIndex, double sl, double tp, double confidence = 0)
{
   m_currentSignal = type;
   m_signalPrice = price;
   m_signalTime = time;
   m_signalBarTime = time;
   m_signalBarIndex = barIndex;
   m_agentConfidence = confidence;
   m_stopLoss = sl;
   m_takeProfit = tp;
   m_alertCounter = 0;

   // Reset consecutive counts after a signal fires
   m_buyConsecutiveCount = 0;
   m_sellConsecutiveCount = 0;

   string typeStr = (type == SIGNAL_BUY) ? "BUY" : "SELL";
   AddToHistory(typeStr, price);

   Print("[SIGNAL] Signal Set: ", typeStr, " Price: ", price, " SL: ", sl, " TP: ", tp, " BarIndex: ", barIndex);
}

// [ENH-05] Track consecutive bars with aligned conditions
void CSignalManager::UpdateConsecutiveCounts(bool buyAligned, bool sellAligned, datetime barTime)
{
   if(barTime == 0 || barTime == m_lastConsecutiveBarTime)
      return;

   m_lastConsecutiveBarTime = barTime;

   if(buyAligned)
      m_buyConsecutiveCount++;
   else
      m_buyConsecutiveCount = 0;

   if(sellAligned)
      m_sellConsecutiveCount++;
   else
      m_sellConsecutiveCount = 0;
}

void CSignalManager::ResetConsecutiveCounts()
{
   m_buyConsecutiveCount = 0;
   m_sellConsecutiveCount = 0;
   m_lastConsecutiveBarTime = 0;
}

bool CSignalManager::IsSignalStillValid(int currentShift) const
{
   if(m_currentSignal == SIGNAL_NONE || m_signalBarTime == 0)
      return false;

   int signalCurrentIndex = iBarShift(_Symbol, PERIOD_CURRENT, m_signalBarTime);
   int barsSinceSignal = signalCurrentIndex - currentShift;

   return (barsSinceSignal >= 0 && barsSinceSignal < SIGNAL_VALID_BARS);
}

void CSignalManager::ResetSignalIfNeeded(const double &emaShortArr[], const double &emaLongArr[],
                                         const double &macdMainArr[], const double &macdSignalArr[],
                                         const double &rsiArr[], const double &adxPlusDiArr[],
                                         const double &adxMinusDiArr[], const double &closeArr[], int shift)
{
   if(m_currentSignal == SIGNAL_NONE || m_signalBarIndex < 0)
      return;

   // Only check at the signal bar or more recent bars
   if(shift > m_signalBarIndex)
      return;

   int invalidConditions = 0;

   if(m_currentSignal == SIGNAL_BUY)
   {
      if(emaShortArr[shift] < emaLongArr[shift]) invalidConditions++;
      if(macdMainArr[shift] < macdSignalArr[shift]) invalidConditions++;
      if(rsiArr[shift] > RSI_NEUTRAL_HIGH) invalidConditions++;
      if(adxMinusDiArr[shift] > adxPlusDiArr[shift]) invalidConditions++;
      if(closeArr[shift] < m_signalPrice) invalidConditions++;
   }
   else if(m_currentSignal == SIGNAL_SELL)
   {
      if(emaShortArr[shift] > emaLongArr[shift]) invalidConditions++;
      if(macdMainArr[shift] > macdSignalArr[shift]) invalidConditions++;
      if(rsiArr[shift] < RSI_NEUTRAL_LOW) invalidConditions++;
      if(adxPlusDiArr[shift] > adxMinusDiArr[shift]) invalidConditions++;
      if(closeArr[shift] > m_signalPrice) invalidConditions++;
   }

   if(invalidConditions >= SIGNAL_RESET_CONDITIONS)
   {
      Print("[GOLD] Signal Reset: Invalid=", invalidConditions, "/", SIGNAL_RESET_CONDITIONS, ", Signal Bar=", m_signalBarIndex, " Current Bar=", shift);
      Reset();
   }
}

// [BUG-09 FIX] Initialize new history slots after resize
void CSignalManager::AddToHistory(string type, double price)
{
   int size = ArraySize(m_signalHistory);
   int newSize = MathMin(MAX_HISTORY_ITEMS, MathMax(1, Max_History_Signals));

   if(size != newSize)
   {
      ArrayResize(m_signalHistory, newSize);
      // Initialize new slots to prevent garbage data
      for(int i = size; i < newSize; i++)
      {
         m_signalHistory[i].time = 0;
         m_signalHistory[i].type = "";
         m_signalHistory[i].price = 0;
         m_signalHistory[i].success = 0;
      }
   }

   // Shift existing history
   for(int i = newSize - 1; i > 0; i--)
      m_signalHistory[i] = m_signalHistory[i-1];

   // Add new entry
   m_signalHistory[0].time = (m_signalTime != 0) ? m_signalTime : TimeCurrent();
   m_signalHistory[0].type = type;
   m_signalHistory[0].price = price;
   m_signalHistory[0].success = 0;
}

void CSignalManager::GetSignalInfo(string &type, double &price, double &sl, double &tp) const
{
   type = (m_currentSignal == SIGNAL_BUY) ? "BUY" : (m_currentSignal == SIGNAL_SELL) ? "SELL" : "NONE";
   price = m_signalPrice;
   sl = m_stopLoss;
   tp = m_takeProfit;
}

//+------------------------------------------------------------------+
//| CPanelHelper Class - Manages panel creation and updates          |
//+------------------------------------------------------------------+
class CPanelHelper
{
private:
   string            m_panelName;
   string            m_fontName;
   int               m_panelX;
   int               m_panelY;
   int               m_panelWidth;
   int               m_panelHeight;
   int               m_lineHeight;
   int               m_textFontSize;
   int               m_titleFontSize;
   datetime          m_lastUpdateTime;
   CAgentBridge      m_agent;

   string            EntryLineName()  const { return m_panelName + "_EntryLine"; }
   string            TPLineName()     const { return m_panelName + "_TPLine"; }
   string            TP1LineName()    const { return m_panelName + "_TP1Line"; }  // [SCALP v3.20]
   string            SLLineName()     const { return m_panelName + "_SLLine"; }

public:
                     CPanelHelper(string symbol);
                     ~CPanelHelper();

   void              DeleteAllObjects();
   void              Create();
   // [BUG-06 FIX] Pass regime from OnCalculate instead of recalculating
   void              Update(const double &closeArr[], const double &rsiArr[], const double &adxMainArr[], const double &adxPlusDiArr[],
                             const double &adxMinusDiArr[], const double &macdMainArr[], const double &macdSignalArr[],
                             const double &volumeMAArr[], const double &tickVolumeArr[],
                             const double &emaShortArr[], const double &emaLongArr[],
                             CSignalManager &signalMgr, const double &atrArr[], int shift,
                             string filterReason = "None",
                             ENUM_MARKET_REGIME regime = REGIME_UNKNOWN,    // [BUG-06 FIX]
                             double spreadPctTP = 0);                       // [ENH-03]

private:
   void              CreateLabel(string name, int x, int y, string text, color textColor, int fontSize = -1);
   void              CreateRectangle(string name, int x, int y, int width, int height, color bgColor);
   void              DrawHorizontalLines(double entryPrice, double tp, double sl, datetime signalTime);
   string            DetermineTrendDirection(const double &emaShort[], const double &emaLong[],
                                              const double &adxMain[], const double &adxPlusDi[],
                                              const double &adxMinusDi[], int shift) const;
   double            CalculateSignalStrength(const double &adxMainArr[], const double &volumeMAArr[],
                                             const double &tickVolumeArr[], const double &emaShortArr[],
                                              const double &emaLongArr[], const double &adxPlusDi[],
                                              const double &adxMinusDi[], const double &rsiArr[],
                                              const double &macdMainArr[], const double &macdSignalArr[],
                                              int shift) const;
};

CPanelHelper::CPanelHelper(string symbol) :
   m_panelName("SignalPanel_" + symbol + "_" + EnumToString(PERIOD_CURRENT)),
   m_fontName(Font_Name),
   m_panelX(Panel_X),
   m_panelY(Panel_Y),
   m_panelWidth(Panel_Width),
   m_panelHeight(Panel_Height),
   m_lineHeight(20),
   m_textFontSize(Text_Font_Size),
   m_titleFontSize(Title_Font_Size),
   m_lastUpdateTime(0)
{
}

CPanelHelper::~CPanelHelper()
{
}

void CPanelHelper::DeleteAllObjects()
{
   string prefix = m_panelName;

   string objects[] = {"_BG", "_Title_BG", "_Title", "_Divider", "_Signal", "_Trend", "_Strength",
                       "_RSI", "_ADX", "_DI", "_Volume", "_TP", "_SL", "_RR", "_Time", "_Regime", "_Agent", "_Filter",
                       "_MiniDivider", "_Entry", "_MiniDivider1", "_MiniDivider2", "_MACD", "_SpreadPct"};

   for(int i = 0; i < ArraySize(objects); i++)
      ObjectDelete(0, prefix + objects[i]);

   // Delete horizontal lines
   ObjectDelete(0, EntryLineName());
   ObjectDelete(0, TPLineName());
   ObjectDelete(0, TP1LineName());   // [SCALP v3.20]
   ObjectDelete(0, SLLineName());

   // Delete remaining objects with prefix
   int total = ObjectsTotal(0, -1, OBJ_LABEL);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, OBJ_LABEL);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }

   total = ObjectsTotal(0, -1, OBJ_RECTANGLE_LABEL);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, OBJ_RECTANGLE_LABEL);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

void CPanelHelper::Create()
{
   DeleteAllObjects();

   CreateRectangle(m_panelName + "_BG", m_panelX, m_panelY, m_panelWidth, m_panelHeight, Panel_Background);
   ObjectSetInteger(0, m_panelName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, m_panelName + "_BG", OBJPROP_COLOR, Panel_Border);
   ObjectSetInteger(0, m_panelName + "_BG", OBJPROP_WIDTH, 2);

   CreateRectangle(m_panelName + "_Title_BG", m_panelX, m_panelY, m_panelWidth, 35, Panel_Border);
   CreateLabel(m_panelName + "_Title", m_panelX + 10, m_panelY + 10, "SIGNAL GENERATOR v3.20", Panel_Title_Color, m_titleFontSize);

   CreateRectangle(m_panelName + "_Divider", m_panelX + 5, m_panelY + 40, m_panelWidth - 10, 2, Divider_Color);

   ChartRedraw();
}

void CPanelHelper::CreateLabel(string name, int x, int y, string text, color textColor, int fontSize = -1)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (fontSize > 0) ? fontSize : m_textFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CPanelHelper::CreateRectangle(string name, int x, int y, int width, int height, color bgColor)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// [BUG-05 FIX] Add RAY_RIGHT so lines extend to chart edge
void CPanelHelper::DrawHorizontalLines(double entryPrice, double tp, double sl, datetime signalTime)
{
   if(entryPrice == 0)
   {
      ObjectDelete(0, EntryLineName());
      ObjectDelete(0, TPLineName());
      ObjectDelete(0, TP1LineName());   // [SCALP v3.20]
      ObjectDelete(0, SLLineName());
      return;
   }

   int barsSpan = MathMax(1, Level_Line_Bars);
   int periodSeconds = MathMax(1, PeriodSeconds());

   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime startTime = signalTime;
   datetime endTime = currentBarTime + (datetime)(barsSpan * periodSeconds);

   // Entry line with RAY_RIGHT
   if(ObjectFind(0, EntryLineName()) < 0) {
      ObjectCreate(0, EntryLineName(), OBJ_TREND, 0, startTime, entryPrice, endTime, entryPrice);
      ObjectSetInteger(0, EntryLineName(), OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, EntryLineName(), OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, EntryLineName(), OBJPROP_RAY_RIGHT, true);  // [BUG-05 FIX]
   } else {
      ObjectMove(0, EntryLineName(), 0, startTime, entryPrice);
      ObjectMove(0, EntryLineName(), 1, endTime, entryPrice);
   }

   // TP line with RAY_RIGHT
   if(tp != 0)
   {
      if(ObjectFind(0, TPLineName()) < 0) {
         ObjectCreate(0, TPLineName(), OBJ_TREND, 0, startTime, tp, endTime, tp);
         ObjectSetInteger(0, TPLineName(), OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, TPLineName(), OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, TPLineName(), OBJPROP_RAY_RIGHT, true);  // [BUG-05 FIX]
      } else {
         ObjectMove(0, TPLineName(), 0, startTime, tp);
         ObjectMove(0, TPLineName(), 1, endTime, tp);
      }
   } else ObjectDelete(0, TPLineName());

   // SL line with RAY_RIGHT
   if(sl != 0)
   {
      if(ObjectFind(0, SLLineName()) < 0) {
         ObjectCreate(0, SLLineName(), OBJ_TREND, 0, startTime, sl, endTime, sl);
         ObjectSetInteger(0, SLLineName(), OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, SLLineName(), OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, SLLineName(), OBJPROP_RAY_RIGHT, true);  // [BUG-05 FIX]
      } else {
         ObjectMove(0, SLLineName(), 0, startTime, sl);
         ObjectMove(0, SLLineName(), 1, endTime, sl);
      }
   } else ObjectDelete(0, SLLineName());

   // [SCALP v3.20] Partial TP1 line at 50% of the way to TP (move SL to BE here)
   if(Show_Partial_Levels && tp != 0)
   {
      double tp1 = entryPrice + (tp - entryPrice) * 0.5;
      if(ObjectFind(0, TP1LineName()) < 0) {
         ObjectCreate(0, TP1LineName(), OBJ_TREND, 0, startTime, tp1, endTime, tp1);
         ObjectSetInteger(0, TP1LineName(), OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, TP1LineName(), OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, TP1LineName(), OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, TP1LineName(), OBJPROP_RAY_RIGHT, true);
      } else {
         ObjectMove(0, TP1LineName(), 0, startTime, tp1);
         ObjectMove(0, TP1LineName(), 1, endTime, tp1);
      }
   } else ObjectDelete(0, TP1LineName());
}

string CPanelHelper::DetermineTrendDirection(const double &emaShortArr[], const double &emaLongArr[],
                                              const double &adxMainArr[], const double &adxPlusDiArr[],
                                              const double &adxMinusDiArr[], int shift) const
{
   bool emaBullish = (emaShortArr[shift] > emaLongArr[shift]);
   bool emaBearish = (emaShortArr[shift] < emaLongArr[shift]);
   bool diBullish = (adxPlusDiArr[shift] > adxMinusDiArr[shift]);
   bool diBearish = (adxMinusDiArr[shift] > adxPlusDiArr[shift]);

   if(emaBullish && diBullish)
      return (adxMainArr[shift] > ADX_STRONG_THRESHOLD) ? "Strong Bullish" : "Bullish";
   else if(emaBearish && diBearish)
      return (adxMainArr[shift] > ADX_STRONG_THRESHOLD) ? "Strong Bearish" : "Bearish";
   else if(adxMainArr[shift] < 18)
      return "Weak/Sideways";

   return "Mixed/Transitioning";
}

// [BUG-11 FIX] Use configurable weights instead of magic numbers
double CPanelHelper::CalculateSignalStrength(const double &adxMainArr[], const double &volumeMAArr[],
                                             const double &tickVolumeArr[], const double &emaShortArr[],
                                              const double &emaLongArr[], const double &adxPlusDi[],
                                              const double &adxMinusDi[], const double &rsiArr[],
                                              const double &macdMainArr[], const double &macdSignalArr[],
                                              int shift) const
{
   double strength = 0;

   // ADX contribution (uses configurable weight)
   strength += MathMin(adxMainArr[shift] * (Weight_ADX / 40.0), Weight_ADX);

   // Volume contribution
   if(volumeMAArr[shift] > 0)
      strength += MathMin(((double)tickVolumeArr[shift] / volumeMAArr[shift]) * (Weight_Volume / 2.0), Weight_Volume);
   else if(tickVolumeArr[shift] > 0)
      strength += Weight_Volume / 2.0;

   // Trend alignment contribution
   bool emaAligned = (emaShortArr[shift] > emaLongArr[shift]);
   bool diAligned = (adxPlusDi[shift] > adxMinusDi[shift]);
   if((emaAligned && diAligned) || (!emaAligned && !diAligned))
      strength += Weight_Trend;

   // RSI contribution
   if(rsiArr[shift] > 50 && rsiArr[shift] < RSI_OVERBOUGHT)
      strength += Weight_RSI;
   else if(rsiArr[shift] < 50 && rsiArr[shift] > RSI_OVERSOLD)
      strength += Weight_RSI;
   else if(rsiArr[shift] >= RSI_OVERBOUGHT || rsiArr[shift] <= RSI_OVERSOLD)
      strength += Weight_RSI / 3.0;

   // MACD contribution
   double macdHist = macdMainArr[shift] - macdSignalArr[shift];
   if(macdHist != 0)
      strength += MathMin(MathAbs(macdHist) * 100, Weight_MACD);

   return MathMin(strength, 100);
}

// [BUG-06 FIX] Regime passed from OnCalculate; [ENH-03] spreadPctTP shown
void CPanelHelper::Update(const double &closeArr[], const double &rsiArr[], const double &adxMainArr[], const double &adxPlusDiArr[],
                           const double &adxMinusDiArr[], const double &macdMainArr[], const double &macdSignalArr[],
                           const double &volumeMAArr[], const double &tickVolumeArr[],
                           const double &emaShortArr[], const double &emaLongArr[],
                           CSignalManager &signalMgr, const double &atrArr[], int shift,
                           string filterReason, ENUM_MARKET_REGIME regime, double spreadPctTP)
{
   // Update horizontal lines FIRST
   double entryPrice = signalMgr.GetSignalPrice();
   double tp = signalMgr.GetTakeProfit();
   double sl = signalMgr.GetStopLoss();
   datetime signalTime = signalMgr.GetSignalTime();

   if(signalMgr.GetCurrentSignal() != SIGNAL_NONE && entryPrice > 0 && signalMgr.IsSignalStillValid(shift))
   {
      DrawHorizontalLines(entryPrice, tp, sl, signalTime);
   }
   else
   {
      ObjectDelete(0, EntryLineName());
      ObjectDelete(0, TPLineName());
      ObjectDelete(0, TP1LineName());   // [SCALP v3.20]
      ObjectDelete(0, SLLineName());
   }

   // Recreate panel if needed
   if(ObjectFind(0, m_panelName + "_BG") < 0)
      Create();

   double displayedVolumeRatio = (volumeMAArr[shift] > 0.0) ? ((double)tickVolumeArr[shift] / volumeMAArr[shift]) : 0.0;
   double strength = CalculateSignalStrength(adxMainArr, volumeMAArr, tickVolumeArr, emaShortArr, emaLongArr,
                                              adxPlusDiArr, adxMinusDiArr, rsiArr, macdMainArr, macdSignalArr, shift);
   string trendDirection = DetermineTrendDirection(emaShortArr, emaLongArr, adxMainArr, adxPlusDiArr, adxMinusDiArr, shift);

   // [BUG-03 FIX] Use the SAME dynamic threshold as signal generation (single source of truth)
   double dynamicThreshold = GetDynamicVolumeThreshold(regime);

   // Get signal info
   string signalTypeStr;
   double signalPrice, signalSL, signalTP;
   signalMgr.GetSignalInfo(signalTypeStr, signalPrice, signalSL, signalTP);

   ENUM_SIGNAL_TYPE signalType = signalMgr.GetCurrentSignal();

   // Determine signal display
   string signalText = "NEUTRAL";
   color signalColor = Signal_Neutral;
   string trendSymbol = "o";

   if(signalType == SIGNAL_BUY && signalMgr.IsSignalStillValid(shift))
   {
      signalText = (strength >= 80) ? "STRONG BUY" : "BUY";
      signalColor = (strength >= 80) ? Signal_Strong_Buy : Signal_Buy;
      trendSymbol = CharToString((uchar)252); // up arrow
   }
   else if(signalType == SIGNAL_SELL && signalMgr.IsSignalStillValid(shift))
   {
      signalText = (strength >= 80) ? "STRONG SELL" : "SELL";
      signalColor = (strength >= 80) ? Signal_Strong_Sell : Signal_Sell;
      trendSymbol = CharToString((uchar)253); // down arrow
   }

   int currentY = m_panelY + 50;
   int sectionSpacing = 8;

   // Signal status
   CreateLabel(m_panelName + "_Signal", m_panelX + 15, currentY, trendSymbol + " " + signalText, signalColor, m_textFontSize + 1);
   currentY += m_lineHeight;

   // Trend direction
   color trendColor = Signal_Neutral;
   if(trendDirection == "Strong Bullish") trendColor = Signal_Strong_Buy;
   else if(trendDirection == "Bullish") trendColor = Signal_Buy;
   else if(trendDirection == "Strong Bearish") trendColor = Signal_Strong_Sell;
   else if(trendDirection == "Bearish") trendColor = Signal_Sell;

   CreateLabel(m_panelName + "_Trend", m_panelX + 15, currentY, "Trend: " + trendDirection, trendColor);
   currentY += m_lineHeight;

   // Market Regime
   string regimeStr = "UNKNOWN";
   color regimeColor = Signal_Neutral;
   if(regime == REGIME_TRENDING) { regimeStr = "TRENDING"; regimeColor = Success_Color; }
   else if(regime == REGIME_RANGING) { regimeStr = "RANGING"; regimeColor = Value_Color; }
   else if(regime == REGIME_RANDOM_WALK) { regimeStr = "RANDOM WALK"; regimeColor = Warning_Color; }

   CreateLabel(m_panelName + "_Regime", m_panelX + 15, currentY, "Regime: " + regimeStr, regimeColor);
   currentY += m_lineHeight;

   // Filter Reason
   if(signalType == SIGNAL_NONE || !signalMgr.IsSignalStillValid(shift))
   {
      color reasonColor = (filterReason == "None") ? Time_Color : Warning_Color;
      CreateLabel(m_panelName + "_Filter", m_panelX + 15, currentY, "Filter: " + filterReason, reasonColor);
      currentY += m_lineHeight;
   }

   // Agent Confidence
   if(signalMgr.GetAgentConfidence() > 0)
   {
      double conf = signalMgr.GetAgentConfidence();
      color confColor = (conf >= 0.8) ? Success_Color : (conf >= 0.7) ? Value_Color : Warning_Color;
      CreateLabel(m_panelName + "_Agent", m_panelX + 15, currentY, "Agent Conf: " + DoubleToString(conf*100, 1) + "%", confColor);
      currentY += m_lineHeight;
   }

   // Signal strength
   color strengthColor = Warning_Color;
   if(strength >= 80) strengthColor = Success_Color;
   else if(strength >= 60) strengthColor = Signal_Buy;
   else if(strength >= 40) strengthColor = Value_Color;
   else if(strength >= 20) strengthColor = Signal_Sell;

   CreateLabel(m_panelName + "_Strength", m_panelX + 15, currentY, "Strength: " + IntegerToString((int)strength) + "%", strengthColor);
   currentY += m_lineHeight + sectionSpacing;

   // Mini divider
   CreateRectangle(m_panelName + "_MiniDivider1", m_panelX + 15, currentY, m_panelWidth - 30, 1, Divider_Color);
   currentY += sectionSpacing;

   // Entry, TP, SL, RR
   if(signalType != SIGNAL_NONE && signalPrice > 0 && signalMgr.IsSignalStillValid(shift))
   {
      string entryArrow = (signalType == SIGNAL_BUY) ? CharToString((uchar)217) : CharToString((uchar)218);
      color entryColor = (signalType == SIGNAL_BUY) ? Signal_Buy : Signal_Sell;
      CreateLabel(m_panelName + "_Entry", m_panelX + 15, currentY,
                  entryArrow + " Entry: " + DoubleToString(signalPrice, _Digits), entryColor);
      currentY += m_lineHeight;

      if(signalTP != 0)
      {
         CreateLabel(m_panelName + "_TP", m_panelX + 15, currentY,
                     CharToString((uchar)217) + " TP: " + DoubleToString(signalTP, _Digits), Success_Color);
         currentY += m_lineHeight;
      }

      if(signalSL != 0)
      {
         CreateLabel(m_panelName + "_SL", m_panelX + 15, currentY,
                     CharToString((uchar)218) + " SL: " + DoubleToString(signalSL, _Digits), Signal_Sell);
         currentY += m_lineHeight;
      }

      // Risk:Reward
      double rr = 0;
      if(signalTP != 0 && signalSL != 0)
      {
         double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         double profit = MathAbs(signalTP - signalPrice) - spread;
         double loss = MathAbs(signalSL - signalPrice) + spread;
         if(loss > 0)
            rr = profit / loss;
      }

      if(rr > 0)
      {
         color rrColor = (rr >= Risk_Reward_Min) ? Success_Color : Warning_Color;
         CreateLabel(m_panelName + "_RR", m_panelX + 15, currentY, "R:R -> " + DoubleToString(rr, 2), rrColor);
         currentY += m_lineHeight;
      }

      // [ENH-03] Show spread cost as percentage of TP
      if(UseSpreadCostFilter && spreadPctTP > 0)
      {
         color spreadColor = (spreadPctTP > Max_Spread_Pct_TP) ? Signal_Sell : Value_Color;
         CreateLabel(m_panelName + "_SpreadPct", m_panelX + 15, currentY,
                     "Spread: " + DoubleToString(spreadPctTP, 1) + "% of TP", spreadColor);
         currentY += m_lineHeight;
      }
   }
   else
   {
      CreateLabel(m_panelName + "_Entry", m_panelX + 15, currentY, "No Active Signal", Signal_Neutral);
      currentY += m_lineHeight;
   }

   currentY += sectionSpacing;

   // Mini divider 2
   CreateRectangle(m_panelName + "_MiniDivider2", m_panelX + 15, currentY, m_panelWidth - 30, 1, Divider_Color);
   currentY += sectionSpacing;

   // RSI
   color rsiColor = Value_Color;
   if(rsiArr[shift] > 70) rsiColor = Signal_Sell;
   else if(rsiArr[shift] < 30) rsiColor = Signal_Buy;
   CreateLabel(m_panelName + "_RSI", m_panelX + 15, currentY, "RSI: " + DoubleToString(rsiArr[shift], 1), rsiColor);
   currentY += m_lineHeight;

   // ADX
   color adxColor = Value_Color;
   if(adxMainArr[shift] > 40) adxColor = Success_Color;
   else if(adxMainArr[shift] <= 20) adxColor = Warning_Color;
   CreateLabel(m_panelName + "_ADX", m_panelX + 15, currentY, "ADX: " + DoubleToString(adxMainArr[shift], 1), adxColor);
   currentY += m_lineHeight;

   // DI
   color diColor = (adxPlusDiArr[shift] > adxMinusDiArr[shift]) ? Signal_Buy : Signal_Sell;
   CreateLabel(m_panelName + "_DI", m_panelX + 15, currentY,
               "+DI: " + DoubleToString(adxPlusDiArr[shift], 1) + "  -DI: " + DoubleToString(adxMinusDiArr[shift], 1), diColor);
   currentY += m_lineHeight;

   // MACD
   color macdColor = (macdMainArr[shift] > macdSignalArr[shift]) ? Signal_Buy : Signal_Sell;
   CreateLabel(m_panelName + "_MACD", m_panelX + 15, currentY, "MACD: " + DoubleToString(macdMainArr[shift], 5), macdColor);
   currentY += m_lineHeight;

   // Volume (using same threshold as signal engine)
   color volColor = (displayedVolumeRatio >= dynamicThreshold) ? Success_Color : Value_Color;
   CreateLabel(m_panelName + "_Volume", m_panelX + 15, currentY, "Vol x: " + DoubleToString(displayedVolumeRatio, 2), volColor);
   currentY += m_lineHeight;

   // Time
   datetime barTime = (signalTime != 0) ? signalTime : TimeCurrent();
   CreateLabel(m_panelName + "_Time", m_panelX + 15, currentY, "Bar: " + TimeToString(barTime, TIME_MINUTES), Time_Color);

   m_lastUpdateTime = TimeCurrent();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CIndicatorManager  g_indicatorMgr;
CSignalManager     g_signalMgr;
CAgentBridge       g_agent;
CPanelHelper      *g_panel = NULL;

//--- Global Engine Copies for Calculated Tolerances
double   g_MaxSpreadPoints   = 0.0;    // Calculated max spread threshold in raw points
int      g_ShortEMAHandle    = INVALID_HANDLE;
int      g_LongEMAHandle     = INVALID_HANDLE;
int      g_ATRHandle         = INVALID_HANDLE;
datetime g_LastServerPing    = 0;      // Prevents thread bottlenecks
datetime g_LastPythonHubPollBar = 0;

//--- Indicator buffers
double EMA_Short_Buffer[];
double EMA_Long_Buffer[];
double Buy_Signal_Buffer[];
double Sell_Signal_Buffer[];
double Bullish_Price_Action_Buffer[];
double Bearish_Price_Action_Buffer[];

//--- Calculation buffers
double rsi[];
double macd_main[];
double macd_signal[];
double adx_main[];
double adx_plus_di[];
double adx_minus_di[];
double volume_ma[];
double tick_volume_buffer[];
double atr_buffer[];

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
int NormalizeHour(int hour)
{
   int normalized = hour % 24;
   if(normalized < 0)
      normalized += 24;
   return normalized;
}

bool IsHourInRange(int hour, int startHour, int endHour)
{
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour <= endHour);
   return (hour >= startHour || hour <= endHour);
}

bool ShouldPollPythonHub(datetime barOpenTime)
{
   if(!InpUseAgentMemory || barOpenTime == 0)
      return false;

   if(g_LastPythonHubPollBar == barOpenTime)
      return false;

   g_LastPythonHubPollBar = barOpenTime;
   return true;
}

int GetServerToGMTOffset()
{
   return (int)MathRound((double)(TimeCurrent() - TimeGMT()) / 3600.0);
}

double CalculateVolumeAverage(const double &volumeData[], int shift, int period)
{
   if(period <= 0 || ArraySize(volumeData) <= shift)
      return 0.0;

   int available = ArraySize(volumeData) - shift;
   int sampleSize = MathMin(period, available);
   if(sampleSize <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + sampleSize; i++)
      sum += (double)volumeData[i];

   return sum / sampleSize;
}

bool ValidateBuffers()
{
   return (ArraySize(rsi) > 1 && ArraySize(macd_main) > 1 && ArraySize(macd_signal) > 1 &&
           ArraySize(adx_main) > 1 && ArraySize(adx_plus_di) > 1 && ArraySize(adx_minus_di) > 1 &&
           ArraySize(atr_buffer) > 1 && ArraySize(EMA_Short_Buffer) > 1 &&
           ArraySize(EMA_Long_Buffer) > 1 && ArraySize(tick_volume_buffer) > 1);
}

bool CheckIndicatorsValid(int shift)
{
   return (rsi[shift] > 0 && rsi[shift] <= 100 && adx_main[shift] >= 0 &&
           atr_buffer[shift] > 0 && EMA_Short_Buffer[shift] > 0 &&
           EMA_Long_Buffer[shift] > 0);
}

double GetPipSize()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;

   if(_Digits == 3 || _Digits == 5)
      return tickSize * 10.0;

   return tickSize;
}

double GetCurrentSpreadPips()
{
   double spreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double pipSize = GetPipSize();
   if(pipSize <= 0.0)
      return 0.0;

   return (spreadPoints * _Point) / pipSize;
}

// [BUG-03 FIX] Unified dynamic volume threshold calculation
double GetDynamicVolumeThreshold(ENUM_MARKET_REGIME regime)
{
   double threshold = Volume_Threshold;
   if(Volume_Threshold > 0)
   {
      switch(regime)
      {
         case REGIME_TRENDING:    threshold = Volume_Threshold * 1.0; break;
         case REGIME_RANGING:     threshold = Volume_Threshold * 1.25; break;
         case REGIME_RANDOM_WALK: threshold = Volume_Threshold * 1.5; break;
         default:                 threshold = Volume_Threshold * 1.1; break;
      }
   }
   return threshold;
}

// [ENH-01] ATR Envelope Check
bool IsATREnvelopeOK(const double &atrArr[], int shift)
{
   if(!UseATREnvelope || ATR_MA_Period <= 0)
      return true;

   // Calculate ATR moving average
   double atrSum = 0;
   int count = 0;
   int lookback = MathMin(ATR_MA_Period, ArraySize(atrArr) - shift - 1);
   if(lookback <= 0)
      return true;

   for(int i = shift; i < shift + lookback; i++)
   {
      if(atrArr[i] > 0)
      {
         atrSum += atrArr[i];
         count++;
      }
   }

   if(count == 0)
      return true;

   double atrMA = atrSum / count;
   if(atrMA == 0)
      return true;

   double ratio = atrArr[shift] / atrMA;
   return (ratio >= ATR_Min_Multiplier && ratio <= ATR_Max_Multiplier);
}

// [ENH-02] MTF Alignment Check
bool CheckMTFAlignment(ENUM_SIGNAL_TYPE direction, bool &outDowngraded)
{
   outDowngraded = false;

   if(!UseMTFFilter || MTF_Mode == MTF_OFF)
      return true;

   // Fetch M30 EMA and close
   double emaM30[];
   double closeM30[];
   ArraySetAsSeries(emaM30, true);
   ArraySetAsSeries(closeM30, true);

   if(g_indicatorMgr.GetEMAM15Handle() == INVALID_HANDLE)
      return true; // Graceful degradation

   if(CopyBuffer(g_indicatorMgr.GetEMAM15Handle(), 0, 0, 2, emaM30) < 2)
      return true;
   if(CopyClose(_Symbol, PERIOD_M30, 0, 2, closeM30) < 2)
      return true;

   // M30 trend: bullish if close > EMA
   bool m30Bullish = (closeM30[1] > emaM30[1]); // Use confirmed bar [1]

   // Also check H1 if available
   bool h1Available = false;
   bool h1Bullish = true; // Default to aligned if unavailable
   if(g_indicatorMgr.GetEMAH1Handle() != INVALID_HANDLE)
   {
      double emaH1[], closeH1[];
      ArraySetAsSeries(emaH1, true);
      ArraySetAsSeries(closeH1, true);
      if(CopyBuffer(g_indicatorMgr.GetEMAH1Handle(), 0, 0, 2, emaH1) >= 2 &&
         CopyClose(_Symbol, PERIOD_H1, 0, 2, closeH1) >= 2)
      {
         h1Bullish = (closeH1[1] > emaH1[1]);
         h1Available = true;
      }
   }

   // [BUG FIX v3.20] Previous logic '(A&&B)||A' collapsed to 'A', so H1 was dead code.
   // When UseH1Confirmation is enabled and H1 data exists, require both TFs to agree.
   bool mtfBullish, mtfBearish;
   if(UseH1Confirmation && h1Available)
   {
      mtfBullish = (m30Bullish && h1Bullish);
      mtfBearish = (!m30Bullish && !h1Bullish);
   }
   else
   {
      mtfBullish = m30Bullish;   // M30-only behavior (default)
      mtfBearish = !m30Bullish;
   }

   if(direction == SIGNAL_BUY && mtfBearish)
   {
      if(MTF_Mode == MTF_BLOCK)
         return false;
      else if(MTF_Mode == MTF_DOWNGRADE)
         outDowngraded = true;
   }
   else if(direction == SIGNAL_SELL && mtfBullish)
   {
      if(MTF_Mode == MTF_BLOCK)
         return false;
      else if(MTF_Mode == MTF_DOWNGRADE)
         outDowngraded = true;
   }

   return true;
}

// [ENH-03] Spread cost as percentage of TP
double CalculateSpreadPctOfTP(double tp, double entry)
{
   if(tp == 0 || entry == 0 || !UseSpreadCostFilter)
      return 0;

   double spread = GetCurrentSpreadPips() * GetPipSize();
   double tpDistance = MathAbs(tp - entry);
   if(tpDistance <= 0)
      return 999; // Invalid

   return (spread / tpDistance) * 100.0;
}

// [ENH-04] Check for pullback entry
bool CheckPullbackEntry(ENUM_SIGNAL_TYPE direction, const double &emaShortArr[], const double &lowArr[],
                        const double &highArr[], const double &atrArr[], int shift)
{
   if(!UsePullbackEntry)
      return true; // Don't filter if disabled

   double emaVal = emaShortArr[shift];
   double threshold = atrArr[shift] * Pullback_ATR_Factor;

   if(direction == SIGNAL_BUY)
   {
      // Price pulled back close to EMA Short from above
      return (lowArr[shift] <= emaVal + threshold && lowArr[shift] >= emaVal - threshold);
   }
   else if(direction == SIGNAL_SELL)
   {
      // Price pulled back close to EMA Short from below
      return (highArr[shift] >= emaVal - threshold && highArr[shift] <= emaVal + threshold);
   }

   return true;
}

// [SCALP v3.20] Over-extension filter: avoid chasing price far from EMA Short
bool IsOverExtended(const double &closeArr[], const double &emaShortArr[], const double &atrArr[], int shift)
{
   if(!UseOverExtensionFilter || atrArr[shift] <= 0.0)
      return false;

   double distInATR = MathAbs(closeArr[shift] - emaShortArr[shift]) / atrArr[shift];
   return (distInATR > Max_Extension_ATR);
}

// [SCALP v3.20] Bars since the EMA Short/Long cross (relative to shift). -1 if no cross in window.
int BarsSinceEMACross(const double &emaShortArr[], const double &emaLongArr[], int shift, int maxLook)
{
   bool bullNow = (emaShortArr[shift] > emaLongArr[shift]);
   int limit = shift + maxLook;
   for(int i = shift + 1; i <= limit && (i + 1) < ArraySize(emaShortArr); i++)
   {
      bool bullPrev = (emaShortArr[i] > emaLongArr[i]);
      if(bullPrev != bullNow)
         return (i - shift);
   }
   return -1;
}

// [SCALP v3.20] Require a recent cross so entries are not late in an extended trend
bool IsFreshCross(const double &emaShortArr[], const double &emaLongArr[], int shift)
{
   if(!UseFreshCrossFilter)
      return true;

   int bars = BarsSinceEMACross(emaShortArr, emaLongArr, shift, Fresh_Cross_MaxBars);
   return (bars >= 0 && bars <= Fresh_Cross_MaxBars);
}

// [SCALP v3.20] Pad SL/TP by the current spread so cost is accounted for in the levels
void ApplySpreadAdaptiveSLTP(ENUM_SIGNAL_TYPE direction, double &sl, double &tp)
{
   if(!UseSpreadAdaptiveSLTP)
      return;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread <= 0.0)
      return;

   if(direction == SIGNAL_BUY)
   {
      sl -= spread;
      tp += spread;
   }
   else if(direction == SIGNAL_SELL)
   {
      sl += spread;
      tp -= spread;
   }
}

// Keep projected levels on the correct side of entry after adaptive adjustments.
void EnsureProtectiveLevels(ENUM_SIGNAL_TYPE direction, double entry, double &sl, double &tp)
{
   if(entry <= 0.0)
      return;

   double minDist = MathMax(_Point, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   if(minDist <= 0.0)
      minDist = _Point;

   if(direction == SIGNAL_BUY)
   {
      if(sl >= entry - minDist)
         sl = entry - minDist;
      if(tp <= entry + minDist)
         tp = entry + minDist;
   }
   else if(direction == SIGNAL_SELL)
   {
      if(sl <= entry + minDist)
         sl = entry + minDist;
      if(tp >= entry - minDist)
         tp = entry - minDist;
   }
}

//+------------------------------------------------------------------+
//| Price Action Pattern Recognition                                 |
//+------------------------------------------------------------------+
bool ConfirmPriceAction(string type, const double &high[], const double &low[],
                        const double &close[], const double &open[], int shift = 1)
{
   if(ArraySize(high) <= shift + 1 || ArraySize(low) <= shift + 1 ||
      ArraySize(close) <= shift + 1 || ArraySize(open) <= shift + 1)
      return false;

   int prevShift = shift + 1;
   double body = MathAbs(close[shift] - open[shift]);
   double upperWick = high[shift] - MathMax(close[shift], open[shift]);
   double lowerWick = MathMin(close[shift], open[shift]) - low[shift];
   double totalRange = high[shift] - low[shift];

   if(totalRange == 0)
      return false;

   if(type == "BUY")
   {
      // Bullish engulfing
      if(close[prevShift] < open[prevShift] && close[shift] > open[prevShift] && open[shift] < close[prevShift])
         return true;
      // Hammer
      if(body < totalRange * 0.3 && lowerWick > body * 2 && upperWick < body)
         return true;
      // Bullish close
      if(close[shift] > open[shift] && (high[shift] - close[shift]) < body * 0.2)
         return true;
   }
   else if(type == "SELL")
   {
      // Bearish engulfing
      if(close[prevShift] > open[prevShift] && close[shift] < open[prevShift] && open[shift] > close[prevShift])
         return true;
      // Shooting star
      if(body < totalRange * 0.3 && upperWick > body * 2 && lowerWick < body)
         return true;
      // Bearish close
      if(close[shift] < open[shift] && (close[shift] - low[shift]) < body * 0.2)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Risk/Reward Calculations                                         |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entry, double tp, double sl)
{
   if(entry == 0 || tp == 0 || sl == 0)
      return 0;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double profit = MathAbs(tp - entry) - spread;
   double loss = MathAbs(sl - entry) + spread;

   if(profit <= 0 || loss <= 0)
      return 0;

   return profit / loss;
}

bool IsRiskRewardAcceptable(double entry, double sl, double tp)
{
   if(Risk_Reward_Min <= 0)
      return true;

   double rr = CalculateRiskRewardRatio(entry, tp, sl);
   return (rr >= Risk_Reward_Min);
}

//+------------------------------------------------------------------+
//| Time and Session Filtering                                       |
//+------------------------------------------------------------------+
bool IsTimeFilterPassed(datetime barTime)
{
   if(!UseTimeFilter)
      return true;

   MqlDateTime dt;
   TimeToStruct(barTime, dt);
   int gmtHour = NormalizeHour(dt.hour - GetServerToGMTOffset());

   return IsHourInRange(gmtHour, StartHour, EndHour);
}

bool IsSessionFilterPassed(datetime barTime)
{
   if(!UseSessionDetection)
      return true;

   MqlDateTime dt;
   TimeToStruct(barTime, dt);
   int gmtHour = NormalizeHour(dt.hour - GetServerToGMTOffset());

   bool inLondon = IsHourInRange(gmtHour, Session_LondonStart, Session_LondonEnd);
   bool inNY = IsHourInRange(gmtHour, Session_NYStart, Session_NYEnd);

   if(TradeOverlap)
   {
      int overlapStart = MathMax(Session_LondonStart, Session_NYStart);
      int overlapEnd = MathMin(Session_LondonEnd, Session_NYEnd);
      return (overlapStart <= overlapEnd) && IsHourInRange(gmtHour, overlapStart, overlapEnd);
   }
   else if(TradeLondonOnly)
      return inLondon && !inNY;
   else if(TradeNYOnly)
      return inNY && !inLondon;

   return inLondon || inNY;
}

//+------------------------------------------------------------------+
//| Alert System                                                     |
//+------------------------------------------------------------------+
void TriggerAlerts(string type)
{
   if(!EnableAlerts && !EnableEmail && !EnablePush)
      return;

   if(!g_signalMgr.CanGenerateAlert())
      return;

   g_signalMgr.IncrementAlertCounter();

   string message = "GOLD " + _Symbol + " " + type + " Signal at " + DoubleToString(g_signalMgr.GetSignalPrice(), _Digits);

   if(EnableAlerts)
      Alert(message);
   if(EnableEmail)
      SendMail("GOLD Signal: " + type, message);
   if(EnablePush)
      SendNotification(message);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate structural pricing data for the active symbol
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(pointSize <= 0.0)
   {
      Print("[GOLD] Error: Failed to retrieve point size for ", _Symbol);
      return INIT_FAILED;
   }

   g_MaxSpreadPoints = Max_Spread_Pips * 10.0 * pointSize;

   g_LastServerPing = 0;
   g_LastPythonHubPollBar = 0;

   // Validate input parameters
   if(EMA_Short_Period < 1 || EMA_Short_Period > 100)
   {
      Print("[GOLD] Error: EMA_Short_Period must be between 1 and 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(EMA_Long_Period < 1 || EMA_Long_Period > 200)
   {
      Print("[GOLD] Error: EMA_Long_Period must be between 1 and 200");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(EMA_Short_Period >= EMA_Long_Period)
   {
      Print("[GOLD] Error: EMA_Short_Period must be less than EMA_Long_Period");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(RSI_Period < 1 || RSI_Period > 50)
   {
      Print("[GOLD] Error: RSI_Period must be between 1 and 50");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(MACD_Fast < 1 || MACD_Fast >= MACD_Slow)
   {
      Print("[GOLD] Error: MACD_Fast must be >= 1 and < MACD_Slow");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(ADX_Period < 1 || ADX_Period > 50)
   {
      Print("[GOLD] Error: ADX_Period must be between 1 and 50");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(ATR_Period < 1 || ATR_Period > 50)
   {
      Print("[GOLD] Error: ATR_Period must be between 1 and 50");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Network pipeline validation for the agent hub
   if(InpUseAgentMemory)
   {
      if(InpPythonHubUrl == "" || InpPythonHubUrl == "http://localhost:8000")
      {
         Print("[GOLD] Warning: Using local Python hub endpoint at ", InpPythonHubUrl,
               ". Ensure the service is listening on port 8000.");
      }
   }

   if(StartHour < 0 || StartHour > 23 || EndHour < 0 || EndHour > 23)
   {
      Print("[GOLD] Error: StartHour and EndHour must be between 0 and 23");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Signal_Cooldown < 0)
   {
      Print("[GOLD] Error: Signal_Cooldown must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Volume_Threshold < 0)
   {
      Print("[GOLD] Error: Volume_Threshold must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_History_Signals < 1 || Max_History_Signals > MAX_HISTORY_ITEMS)
   {
      Print("[GOLD] Error: Max_History_Signals must be between 1 and ", MAX_HISTORY_ITEMS);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Level_Line_Bars < 1 || Level_Line_Bars > 500)
   {
      Print("[GOLD] Error: Level_Line_Bars must be between 1 and 500");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Consecutive_Bars_Req < 1 || Consecutive_Bars_Req > 5)
   {
      Print("[GOLD] Error: Consecutive_Bars_Req must be between 1 and 5");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(ATR_Min_Multiplier <= 0 || ATR_Max_Multiplier <= 0 || ATR_Min_Multiplier >= ATR_Max_Multiplier)
   {
      Print("[GOLD] Error: ATR_Min_Multiplier must be < ATR_Max_Multiplier and both > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Arrow_Offset_ATR_Mult <= 0 || Arrow_Offset_ATR_Mult > 3.0)
   {
      Print("[GOLD] Error: Arrow_Offset_ATR_Mult must be between 0.01 and 3.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_Spread_Pips <= 0.0)
   {
      Print("[GOLD] Error: Max_Spread_Pips must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_Spread_Pct_TP <= 0.0 || Max_Spread_Pct_TP > 100.0)
   {
      Print("[GOLD] Error: Max_Spread_Pct_TP must be between 0.01 and 100.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Pullback_ATR_Factor <= 0.0 || Pullback_ATR_Factor > 2.0)
   {
      Print("[GOLD] Error: Pullback_ATR_Factor must be between 0.01 and 2.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Max_Extension_ATR <= 0.0 || Max_Extension_ATR > 5.0)
   {
      Print("[GOLD] Error: Max_Extension_ATR must be between 0.01 and 5.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Fresh_Cross_MaxBars < 1 || Fresh_Cross_MaxBars > 30)
   {
      Print("[GOLD] Error: Fresh_Cross_MaxBars must be between 1 and 30");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Initialize structural indicator handles through the manager
   if(!g_indicatorMgr.Initialize())
   {
      Print("[GOLD] Failed to initialize indicators");
      return INIT_FAILED;
   }

   // Cache engine-level copies for compatibility with the runtime environment
   g_ShortEMAHandle = g_indicatorMgr.GetEMAShortHandle();
   g_LongEMAHandle  = g_indicatorMgr.GetEMALongHandle();
   g_ATRHandle      = g_indicatorMgr.GetATRHandle();

   // Initialize signal manager
   g_signalMgr.Reset();

   // Create panel helper
   g_panel = new CPanelHelper(_Symbol);
   g_panel.Create();

   // Set indicator and calculation buffers
   SetIndexBuffer(0, Buy_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Sell_Signal_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, EMA_Short_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, EMA_Long_Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, Bullish_Price_Action_Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, Bearish_Price_Action_Buffer, INDICATOR_DATA);
   SetIndexBuffer(6, rsi, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, macd_main, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, macd_signal, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, adx_main, INDICATOR_CALCULATIONS);
   SetIndexBuffer(10, adx_plus_di, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, adx_minus_di, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, volume_ma, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, atr_buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, tick_volume_buffer, INDICATOR_CALCULATIONS);

   // Set buffers as series
   ArraySetAsSeries(Buy_Signal_Buffer, true);
   ArraySetAsSeries(Sell_Signal_Buffer, true);
   ArraySetAsSeries(EMA_Short_Buffer, true);
   ArraySetAsSeries(EMA_Long_Buffer, true);
   ArraySetAsSeries(Bullish_Price_Action_Buffer, true);
   ArraySetAsSeries(Bearish_Price_Action_Buffer, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(adx_main, true);
   ArraySetAsSeries(adx_plus_di, true);
   ArraySetAsSeries(adx_minus_di, true);
   ArraySetAsSeries(volume_ma, true);
   ArraySetAsSeries(atr_buffer, true);
   ArraySetAsSeries(tick_volume_buffer, true);

   // Initialize buffers
   ArrayInitialize(Buy_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(Sell_Signal_Buffer, EMPTY_VALUE);
   ArrayInitialize(EMA_Short_Buffer, EMPTY_VALUE);
   ArrayInitialize(EMA_Long_Buffer, EMPTY_VALUE);
   ArrayInitialize(Bullish_Price_Action_Buffer, EMPTY_VALUE);
   ArrayInitialize(Bearish_Price_Action_Buffer, EMPTY_VALUE);

   // Configure plot appearance
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_ARROW, 217);
   PlotIndexSetInteger(5, PLOT_ARROW, 218);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, PriceAction_Bullish);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, PriceAction_Bearish);

   Print("[GOLD] Indicator initialized successfully - Version 3.20 (Scalping Pack)");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_indicatorMgr.ReleaseAll();

   if(g_panel != NULL)
   {
      g_panel.DeleteAllObjects();
      delete g_panel;
      g_panel = NULL;
   }

   ChartRedraw();
   Print("[GOLD] Indicator deinitialized");
}

//+------------------------------------------------------------------+
//| Main Calculation Function                                        |
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
   int minBars = MathMax(EMA_Long_Period,
                 MathMax(RSI_Period,
                 MathMax(MACD_Slow,
                 MathMax(ADX_Period,
                 MathMax(ATR_Period, ATR_MA_Period))))) + MathMax(MIN_BARS_REQUIRED, VOLUME_MA_PERIOD + SIGNAL_SHIFT + 5);

   if(rates_total < minBars)
      return 0;

   // Set series arrays
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(tick_volume, true);

   // [PERF v3.20] On a fully calculated chart only the most recent bars change, so we
   // recompute a bounded window instead of the whole history on every tick. EMA/RSI/etc.
   // on older bars are immutable and retain their previously copied values.
   int copyCount = rates_total;
   if(UseIncrementalCalc && prev_calculated > 0)
   {
      int neededWindow = MathMax(ATR_MA_Period, MathMax(VOLUME_MA_PERIOD, MIN_BARS_REQUIRED)) + SIGNAL_SHIFT + 10;
      copyCount = MathMin(rates_total, neededWindow);
   }

   // Copy indicator data
   int shortEmaHandle = (g_ShortEMAHandle != INVALID_HANDLE) ? g_ShortEMAHandle : g_indicatorMgr.GetEMAShortHandle();
   int longEmaHandle  = (g_LongEMAHandle != INVALID_HANDLE) ? g_LongEMAHandle : g_indicatorMgr.GetEMALongHandle();
   int atrHandle      = (g_ATRHandle != INVALID_HANDLE) ? g_ATRHandle : g_indicatorMgr.GetATRHandle();

   if(CopyBuffer(shortEmaHandle, 0, 0, copyCount, EMA_Short_Buffer) <= 0 ||
      CopyBuffer(longEmaHandle, 0, 0, copyCount, EMA_Long_Buffer) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetRSIHandle(), 0, 0, copyCount, rsi) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetMACDHandle(), 0, 0, copyCount, macd_main) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetMACDHandle(), 1, 0, copyCount, macd_signal) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetADXHandle(), 0, 0, copyCount, adx_main) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetADXHandle(), 1, 0, copyCount, adx_plus_di) <= 0 ||
      CopyBuffer(g_indicatorMgr.GetADXHandle(), 2, 0, copyCount, adx_minus_di) <= 0 ||
      CopyBuffer(atrHandle, 0, 0, copyCount, atr_buffer) <= 0)
   {
      Print("[GOLD] Error copying indicator buffers: ", GetLastError());
      ResetLastError();
      return prev_calculated;
   }

   // Copy tick volume to double buffer (same bounded window)
   for(int i = 0; i < copyCount; i++)
      tick_volume_buffer[i] = (double)tick_volume[i];

   // Validate data availability
   const int shift = SIGNAL_SHIFT;
   if(!ValidateBuffers() || !CheckIndicatorsValid(shift))
      return prev_calculated;

   // Clear current bar signals
   Buy_Signal_Buffer[0] = EMPTY_VALUE;
   Sell_Signal_Buffer[0] = EMPTY_VALUE;
   Bullish_Price_Action_Buffer[0] = EMPTY_VALUE;
   Bearish_Price_Action_Buffer[0] = EMPTY_VALUE;

   datetime signalBarTime = time[shift];

   // Calculate volume metrics
   double baselineVolume = CalculateVolumeAverage(tick_volume_buffer, shift + 1, VOLUME_MA_PERIOD);
   volume_ma[shift] = baselineVolume;

   // [BUG-03 FIX] Use unified dynamic volume threshold
   ENUM_MARKET_REGIME regime = g_agent.DetectRegime(close, shift, adx_main[shift]);
   double dynamicVolThreshold = GetDynamicVolumeThreshold(regime);
   double volumeRatio = (baselineVolume > 0.0) ? ((double)tick_volume_buffer[shift] / baselineVolume) : 0.0;

   // Enhancement 1: Spread Filter
   double currentSpreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double currentSpreadPrice = currentSpreadPoints * _Point;
   bool spreadOK = currentSpreadPrice <= g_MaxSpreadPoints;

   // Time filters
   bool timeFilterOK = IsTimeFilterPassed(signalBarTime);
   bool sessionFilterOK = IsSessionFilterPassed(signalBarTime);

   // [ENH-01] ATR Envelope Filter
   bool atrEnvelopeOK = IsATREnvelopeOK(atr_buffer, shift);

   // [BUG-04 FIX] Proper filter reason cascade using else-if chain
   string filterReason = "None";
   if(!atrEnvelopeOK)
      filterReason = "ATR Envelope";
   else if(!timeFilterOK)
      filterReason = "Time Window";
   else if(!sessionFilterOK)
      filterReason = "Session";
   else if(!spreadOK)
      filterReason = "High Spread";
   else if(baselineVolume > 0.0 && volumeRatio < dynamicVolThreshold)
      filterReason = "Low Vol";

   // Cooldown check
   bool cooldownOK = true;
   if(g_signalMgr.GetSignalBarTime() != 0 && Signal_Cooldown > 0)
   {
      cooldownOK = ((signalBarTime - g_signalMgr.GetSignalBarTime()) >= (datetime)(PeriodSeconds() * Signal_Cooldown));
      if(!cooldownOK && filterReason == "None") filterReason = "Cooldown";
   }

   // Price action confirmation
   bool bullishPriceAction = UsePriceAction ? ConfirmPriceAction("BUY", high, low, close, open, shift) : false;
   bool bearishPriceAction = UsePriceAction ? ConfirmPriceAction("SELL", high, low, close, open, shift) : false;

   if(bullishPriceAction && timeFilterOK && volumeRatio >= dynamicVolThreshold)
      Bullish_Price_Action_Buffer[shift] = low[shift] - atr_buffer[shift] * 0.25;
   if(bearishPriceAction && timeFilterOK && volumeRatio >= dynamicVolThreshold)
      Bearish_Price_Action_Buffer[shift] = high[shift] + atr_buffer[shift] * 0.25;

   // Check for signal reset
   if(g_signalMgr.GetCurrentSignal() != SIGNAL_NONE)
   {
      g_signalMgr.ResetSignalIfNeeded(EMA_Short_Buffer, EMA_Long_Buffer, macd_main, macd_signal,
                                       rsi, adx_plus_di, adx_minus_di, close, shift);
   }

   // Random Walk filter
   if(regime == REGIME_RANDOM_WALK && InpBlockRandomWalk)
   {
      atrEnvelopeOK = false;
      if(filterReason == "None") filterReason = "Noisy Regime";
   }

   // ADX Weak filter
   if(filterReason == "None" && adx_main[shift] <= ADX_WEAK_THRESHOLD)
      filterReason = "ADX Weak";

   // [ENH-05] Determine if conditions are aligned (for consecutive count)
   bool buyAligned  = (EMA_Short_Buffer[shift] > EMA_Long_Buffer[shift] &&
                       rsi[shift] < RSI_OVERBOUGHT &&
                       macd_main[shift] > macd_signal[shift] &&
                       adx_plus_di[shift] > adx_minus_di[shift]);

   bool sellAligned = (EMA_Short_Buffer[shift] < EMA_Long_Buffer[shift] &&
                       rsi[shift] > RSI_OVERSOLD &&
                       macd_main[shift] < macd_signal[shift] &&
                       adx_minus_di[shift] > adx_plus_di[shift]);

   g_signalMgr.UpdateConsecutiveCounts(buyAligned, sellAligned, signalBarTime);

   // [ENH-03] Calculate spread percentage of TP for panel display
   double spreadPctTP = 0;

   bool volumeOK = (Volume_Threshold <= 0.0) ||
                   (baselineVolume > 0.0 && volumeRatio >= dynamicVolThreshold) ||
                   (baselineVolume <= 0.0 && tick_volume_buffer[shift] > 0);

   bool signalFound = false;

   // [SCALP v3.20+] Reuse scalp gates once so panel reasons and execution logic stay aligned.
   bool overExtended = IsOverExtended(close, EMA_Short_Buffer, atr_buffer, shift);
   bool freshCrossOK = IsFreshCross(EMA_Short_Buffer, EMA_Long_Buffer, shift);
   if(filterReason == "None" && overExtended)
      filterReason = "Over-Extended";
   else if(filterReason == "None" && !freshCrossOK)
      filterReason = "Stale Cross";

   // Common filter combination
   bool allFiltersOK = volumeOK && timeFilterOK && sessionFilterOK && cooldownOK && spreadOK && atrEnvelopeOK && !overExtended && freshCrossOK;

   // [BUG-01 FIX] Added sessionFilterOK + atrEnvelopeOK to strong signals
   // [ENH-05] Added Consecutive_Bars_Req check
   // [ENH-02] Added MTF alignment
   // Check for STRONG signals (ADX > threshold)
   if(adx_main[shift] > ADX_STRONG_THRESHOLD && allFiltersOK)
   {
      // Strong BUY signal
      if(buyAligned &&
         (!UsePriceAction || bullishPriceAction) &&
         g_signalMgr.GetBuyConsecutiveCount() >= Consecutive_Bars_Req)
      {
         // [ENH-02] MTF check
         bool mtfDowngraded = false;
         bool mtfOK = CheckMTFAlignment(SIGNAL_BUY, mtfDowngraded);

         if(mtfOK)
         {
            double sl = close[shift] - atr_buffer[shift] * ATR_Stop_Multiplier;
            double tp = close[shift] + atr_buffer[shift] * ATR_Take_Multiplier;
            ApplySpreadAdaptiveSLTP(SIGNAL_BUY, sl, tp);   // [SCALP v3.20]
            EnsureProtectiveLevels(SIGNAL_BUY, close[shift], sl, tp);

            double agentConf = 0;
            bool memoryPass = true;
            if(ShouldPollPythonHub(time[0]))
               memoryPass = g_agent.CheckMemorySimilarity(rsi[shift], adx_main[shift], SIGNAL_BUY, agentConf);

            // [ENH-03] Spread cost check
            spreadPctTP = CalculateSpreadPctOfTP(tp, close[shift]);
            bool spreadCostOK = !UseSpreadCostFilter || spreadPctTP <= Max_Spread_Pct_TP;

            // [ENH-04] Pullback check
            bool pullbackOK = CheckPullbackEntry(SIGNAL_BUY, EMA_Short_Buffer, low, high, atr_buffer, shift);

            if(IsRiskRewardAcceptable(close[shift], sl, tp) && memoryPass && spreadCostOK && pullbackOK)
            {
               Buy_Signal_Buffer[shift] = low[shift] - atr_buffer[shift] * Arrow_Offset_ATR_Mult;
               g_signalMgr.SetSignal(SIGNAL_BUY, close[shift], signalBarTime, shift, sl, tp,
                                     (mtfDowngraded) ? MathMax(agentConf, 0) * 0.85 : agentConf);
               signalFound = true;

               Print("[GOLD] AGENT CONFIRMED STRONG BUY: Conf=", agentConf, " Price=", close[shift],
                     " SL=", sl, " TP=", tp, " BarIndex=", shift, " Time=", signalBarTime,
                     (mtfDowngraded ? " [MTF-DOWNGRADED]" : ""));
               TriggerAlerts("BUY");
            }
         }
      }
      // Strong SELL signal
      else if(sellAligned &&
              (!UsePriceAction || bearishPriceAction) &&
              g_signalMgr.GetSellConsecutiveCount() >= Consecutive_Bars_Req)
      {
         bool mtfDowngraded = false;
         bool mtfOK = CheckMTFAlignment(SIGNAL_SELL, mtfDowngraded);

         if(mtfOK)
         {
            double sl = close[shift] + atr_buffer[shift] * ATR_Stop_Multiplier;
            double tp = close[shift] - atr_buffer[shift] * ATR_Take_Multiplier;
            ApplySpreadAdaptiveSLTP(SIGNAL_SELL, sl, tp);   // [SCALP v3.20]
            EnsureProtectiveLevels(SIGNAL_SELL, close[shift], sl, tp);

            double agentConf = 0;
            bool memoryPass = true;
            if(ShouldPollPythonHub(time[0]))
               memoryPass = g_agent.CheckMemorySimilarity(rsi[shift], adx_main[shift], SIGNAL_SELL, agentConf);

            spreadPctTP = CalculateSpreadPctOfTP(tp, close[shift]);
            bool spreadCostOK = !UseSpreadCostFilter || spreadPctTP <= Max_Spread_Pct_TP;

            bool pullbackOK = CheckPullbackEntry(SIGNAL_SELL, EMA_Short_Buffer, low, high, atr_buffer, shift);

            if(IsRiskRewardAcceptable(close[shift], sl, tp) && memoryPass && spreadCostOK && pullbackOK)
            {
               Sell_Signal_Buffer[shift] = high[shift] + atr_buffer[shift] * Arrow_Offset_ATR_Mult;
               g_signalMgr.SetSignal(SIGNAL_SELL, close[shift], signalBarTime, shift, sl, tp,
                                     (mtfDowngraded) ? MathMax(agentConf, 0) * 0.85 : agentConf);
               signalFound = true;

               Print("[GOLD] AGENT CONFIRMED STRONG SELL: Conf=", agentConf, " Price=", close[shift],
                     " SL=", sl, " TP=", tp, " BarIndex=", shift, " Time=", signalBarTime,
                     (mtfDowngraded ? " [MTF-DOWNGRADED]" : ""));
               TriggerAlerts("SELL");
            }
         }
      }
   }

   // Check for WEAK signals (ADX > weak threshold but below strong)
   if(!signalFound && allFiltersOK)
   {
      // Weak BUY signal
      if(buyAligned &&
         adx_main[shift] > ADX_WEAK_THRESHOLD &&
         (!UsePriceAction || bullishPriceAction) &&
         g_signalMgr.GetBuyConsecutiveCount() >= Consecutive_Bars_Req)
      {
         bool mtfDowngraded = false;
         bool mtfOK = CheckMTFAlignment(SIGNAL_BUY, mtfDowngraded);

         if(mtfOK && !mtfDowngraded) // Block counter-trend weak signals
         {
            double sl = close[shift] - atr_buffer[shift] * ATR_Stop_Multiplier;
            double tp = close[shift] + atr_buffer[shift] * ATR_Take_Multiplier;
            ApplySpreadAdaptiveSLTP(SIGNAL_BUY, sl, tp);   // [SCALP v3.20]
            EnsureProtectiveLevels(SIGNAL_BUY, close[shift], sl, tp);

            spreadPctTP = CalculateSpreadPctOfTP(tp, close[shift]);
            bool spreadCostOK = !UseSpreadCostFilter || spreadPctTP <= Max_Spread_Pct_TP;
            bool pullbackOK = CheckPullbackEntry(SIGNAL_BUY, EMA_Short_Buffer, low, high, atr_buffer, shift);

            if(IsRiskRewardAcceptable(close[shift], sl, tp) && spreadCostOK && pullbackOK)
            {
               Buy_Signal_Buffer[shift] = low[shift] - atr_buffer[shift] * Arrow_Offset_ATR_Mult;
               g_signalMgr.SetSignal(SIGNAL_BUY, close[shift], signalBarTime, shift, sl, tp);
               signalFound = true;

               Print("[GOLD] BUY SIGNAL SET: Price=", close[shift],
                     " SL=", sl, " TP=", tp, " BarIndex=", shift, " Time=", signalBarTime);
               TriggerAlerts("BUY");
            }
         }
      }
      // Weak SELL signal
      else if(sellAligned &&
              adx_main[shift] > ADX_WEAK_THRESHOLD &&
              (!UsePriceAction || bearishPriceAction) &&
              g_signalMgr.GetSellConsecutiveCount() >= Consecutive_Bars_Req)
      {
         bool mtfDowngraded = false;
         bool mtfOK = CheckMTFAlignment(SIGNAL_SELL, mtfDowngraded);

         if(mtfOK && !mtfDowngraded)
         {
            double sl = close[shift] + atr_buffer[shift] * ATR_Stop_Multiplier;
            double tp = close[shift] - atr_buffer[shift] * ATR_Take_Multiplier;
            ApplySpreadAdaptiveSLTP(SIGNAL_SELL, sl, tp);   // [SCALP v3.20]
            EnsureProtectiveLevels(SIGNAL_SELL, close[shift], sl, tp);

            spreadPctTP = CalculateSpreadPctOfTP(tp, close[shift]);
            bool spreadCostOK = !UseSpreadCostFilter || spreadPctTP <= Max_Spread_Pct_TP;
            bool pullbackOK = CheckPullbackEntry(SIGNAL_SELL, EMA_Short_Buffer, low, high, atr_buffer, shift);

            if(IsRiskRewardAcceptable(close[shift], sl, tp) && spreadCostOK && pullbackOK)
            {
               Sell_Signal_Buffer[shift] = high[shift] + atr_buffer[shift] * Arrow_Offset_ATR_Mult;
               g_signalMgr.SetSignal(SIGNAL_SELL, close[shift], signalBarTime, shift, sl, tp);
               signalFound = true;

               Print("[GOLD] SELL SIGNAL SET: Price=", close[shift],
                     " SL=", sl, " TP=", tp, " BarIndex=", shift, " Time=", signalBarTime);
               TriggerAlerts("SELL");
            }
         }
      }
   }

   // [BUG-06 FIX] Pass regime and spreadPctTP to panel (no recalculation)
   if(g_panel != NULL)
   {
      g_panel.Update(close, rsi, adx_main, adx_plus_di, adx_minus_di, macd_main, macd_signal,
                    volume_ma, tick_volume_buffer, EMA_Short_Buffer, EMA_Long_Buffer,
                    g_signalMgr, atr_buffer, shift, filterReason, regime, spreadPctTP);
   }

   ResetLastError();
   return rates_total;
}
//+------------------------------------------------------------------+
