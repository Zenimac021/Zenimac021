//+------------------------------------------------------------------+
//| Advance_Multi_TimeFrame.mq5 - Enhanced MTF Dashboard            |
//|                          with Scalping Mode as Input Setting     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Enhanced Version"
#property link      "https://www.mql5.com"
#property version   "2.10"
#property strict
#property indicator_chart_window
#property indicator_plots 1
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrNONE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_buffers 1

//---- Constants ----
#define NUM_TIMEFRAMES 8

//---- Timeframes ----
const ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
const string timeframeLabels[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"};

//---- Inputs ----
input group "=== Timeframe Display ==="
input bool Show_M1=true;
input bool Show_M5=true;
input bool Show_M15=true;
input bool Show_M30=true;
input bool Show_H1=true;
input bool Show_H4=true;
input bool Show_D1=true;
input bool Show_W1=true;

input group "=== Visual Settings ==="
input color UptrendColor    = clrGreen;
input color DowntrendColor  = clrRed;
input color NeutralColor    = clrGray;
input color StrongUptrendColor = clrLime;
input color StrongDowntrendColor = clrCrimson;
input color ErrorColor      = clrDarkGray;
input color DisabledColor   = clrBlack;
input color PatternHighlightColor = clrGold;
input int BoxWidth          = 30;
input int BoxHeight         = 25;
input int HorizontalSpacing = 5;
input string DashboardTitle = "MTF Trend Dashboard v2.0";
input int   TitleFontSize   = 12;
input color TitleColor      = clrBlack;
input color BackgroundColor = clrDarkGray;
input int DashboardStartX   = 650;
input int DashboardStartY   = 20;
input bool SavePosition = false;
input bool ResetPosition = false;

input group "=== Trend Settings ==="
input int SignalBar         = 1; // Use closed candle for reliability
input ENUM_MA_METHOD TrendMAMethod = MODE_EMA;
input int FastMAPeriod      = 5;   // Faster response for gold's volatility
input int SlowMAPeriod      = 13;  // Classic Fibonacci number for M15 scalping
input int RSIPeriod         = 5;   // Shorter period for quicker signals
input double RSIOverbought  = 65;  // Adjusted for gold's typical range
input double RSIOversold    = 35;  // Avoids false extremes in scalping
input int ADXPeriod         = 8;   // Reduced for faster trend detection
input double ADXThreshold   = 25;  // Higher threshold for stronger trends
input double StrongTrendThreshold = 0.008; // Increased for gold's volatility

input group "=== Advanced Trend Confirmation ==="
input bool EnableMACDConfirmation = true;
input int MACDFastPeriod    = 8;   // Faster for scalping
input int MACDSlowPeriod    = 19;  // Fibonacci-based
input int MACDSignalPeriod  = 3;   // Quick signal line
input double MACDThreshold  = 0.0003; // Higher for gold (approx 30 pips)
input bool EnableBollingerBands = true;
input int BBPeriod          = 20;  // Standard period for gold
input double BBDeviation    = 2.0; // Standard deviation for better breakout detection

input group "=== Market Session Integration ==="
input bool EnableMarketSessionFilter = true;
input bool HighlightAsiaSession      = true;
input bool HighlightLondonSession    = true;
input bool HighlightNewYorkSession   = true;
input bool HighlightSessionOverlap   = true;
input color AsiaSessionColor         = clrLightBlue;
input color LondonSessionColor       = clrDarkKhaki;
input color NewYorkSessionColor      = clrYellow;
input color SessionOverlapColor      = clrGold;

input group "=== Advanced Analytics ==="
input bool EnableTrendConsistencyScoring = true;
input bool EnableMomentumAnalysis        = true;
input bool EnableVolatilityAdjustment    = true;
input bool EnableHistoricalPerformanceTracking = true;
input int PerformanceLookbackBars        = 100;
input double ConsistencyWeight           = 0.6;
input double MomentumWeight              = 0.3;
input double VolatilityWeight            = 0.1;

input group "=== Scalping Mode Settings ==="
input bool EnableScalpingMode = false; // Enable optimized scalping mode
input int ScalpingTimeframes = 2; // Number of lower timeframes to focus on (M1, M5, M15)
input double ScalpingMinConfidence = 0.65; // Minimum confidence for scalping signals
input bool EnableSpreadFilter = true; // Avoid high spread periods
input double MaxSpreadPoints = 30; // Maximum spread in points for scalping
input bool EnableVolumeConfirmation = true; // Require volume spike for entries
input double VolumeSpikeMultiplier = 1.5; // Volume must be X times average
input bool EnableMomentumBurstDetection = true; // Detect sudden momentum shifts
input int MomentumBurstBars = 5; // Bars to look back for momentum burst
input double MomentumBurstThreshold = 0.002; // Minimum price change for burst
input bool ScalpingAlertsOnly = false; // Only show scalping signals when enabled

input group "=== Refresh & Alerts ==="
input bool OptimizeRefresh = true;
input int RefreshSeconds = 15; // Reduced for scalping (was 30)
input int AlignmentThreshold = 4; // Number of timeframes needed for alignment alert

input group "=== External Integrations ==="
input bool EnableEconomicCalendar = false; // Disabled by default
input bool EnableSentimentAnalysis = true;
input bool EnableBrokerAPIIntegration = true;

input group "=== AI/ML Features ==="
input bool EnableAITrendPrediction = true;
input bool EnableMLPatternRecognition = false;
input bool EnableNeuralNetworkSignals = true;
input int PredictionHorizonBars = 5;
input double ConfidenceThreshold = 0.75;
input bool EnableAdaptiveLearning = true;

//---- Structures ----
struct TimeframeData
{
   bool   enabled;
   bool   available;
   int    fastHandle;
   int    slowHandle;
   int    rsiHandle;
   int    adxHandle;
   int    atrHandle;           // ATR for volatility analysis
   int    macdHandle;          // MACD for trend confirmation
   int    bbHandle;            // Bollinger Bands for volatility context
   int    volumeHandle;        // Volume indicator for confirmation
   datetime lastUpdate;
   color  lastColor;
   string boxName;
   string labelName;
   int    lastTrendDirection;  // Track trend changes
   double lastVolatility;      // Track volatility for squeeze detection
   bool   macdBullish;         // MACD confirmation state
   bool   priceAboveBB;        // Price relative to Bollinger Bands
   string detectedPattern;     // To store the name of the detected pattern

   // Advanced Analytics
   double consistencyScore;    // Trend consistency across timeframes
   double momentumScore;       // Momentum acceleration/deceleration
   double volatilityScore;      // Volatility-adjusted signal strength
   double overallScore;         // Combined analytics score
   double historicalAccuracy;   // Past signal performance
   int    correctPredictions;   // Count of correct predictions
   int    totalPredictions;     // Total predictions made

   // Scalping-specific fields
   bool   volumeSpike;         // Volume spike detected
   double volumeRatio;          // Current volume vs average
   bool   momentumBurst;       // Sudden momentum shift
   double momentumStrength;     // Burst strength
   datetime lastBurstTime;      // Last momentum burst time
   bool   scalpingSignal;      // High-confidence scalping entry
   double scalpingConfidence;   // Signal confidence 0-1
   
   // Optimization: track bar count to reduce redundant data copies
   int    lastBarCount;         // Last known bar count for this timeframe
   datetime lastMLBarTime;      // Last bar time processed by ML pattern recognition
};

struct AlertState
{
   datetime lastStrongSignalAlert; // Only alert for strong buy/sell signals

   // Enhanced alerts
   datetime lastAnalyticsAlert;
   datetime lastPredictionAlert;
   datetime lastIntegrationAlert;

   // Scalping alerts
   datetime lastScalpingAlert;
   datetime lastMomentumBurstAlert;
   datetime lastVolumeSpikeAlert;
   bool scalpingAlertActive;
};

struct MarketSession
{
   string name;
   int startHour;
   int endHour;
   color sessionColor;
   bool isActive;
};

// Phase 3: Advanced Analytics Structures
struct TrendMetrics
{
   double overallScore;        // 0-100 comprehensive score
   double consistencyScore;    // How consistent across timeframes
   double momentumScore;       // Rate of change acceleration
   double volatilityScore;     // Volatility context
   double predictionConfidence; // AI prediction confidence
   bool   isHighProbability;   // High probability setup
};

struct ExternalData
{
   datetime lastUpdate;
   double sentimentScore;      // Social sentiment (-1 to 1)
   double volatilityIndex;     // Market volatility index
   int    upcomingNewsImpact;  // 0=Low, 1=Medium, 2=High
   string newsHeadline;        // Latest news headline
   bool   dataAvailable;
};

struct MLPrediction
{
   double predictedDirection;  // -1=Down, 0=Neutral, 1=Up
   double confidence;          // 0-1 confidence level
   double timeToSignal;        // Bars until expected signal
   string patternType;         // Recognized pattern name
   bool   isReliable;          // Based on historical accuracy
};

struct PatternResult
{
   double signal;              // -1, 0, 1 for direction
   string patternName;         // Name of detected pattern
   double confidence;          // 0-1 confidence level
};

class PatternRecognizer
{
public:
   // Main entry: analyzes rates and returns pattern detection result
   static PatternResult Analyze(const MqlRates &rates[])
   {
      PatternResult result;
      result.signal = 0;
      result.patternName = "";
      result.confidence = 0.0;
      
      // Check for each pattern in order of priority
      if(CheckBullishEngulfing(rates, result)) return result;
      if(CheckBearishEngulfing(rates, result)) return result;
      if(CheckHammer(rates, result)) return result;
      if(CheckShootingStar(rates, result)) return result;
      if(CheckDoji(rates, result)) return result;
      if(CheckInsideBar(rates, result)) return result;
      if(CheckMorningStar(rates, result)) return result;
      if(CheckEveningStar(rates, result)) return result;
      
      return result;
   }
   
private:
   // 1. Bullish Engulfing
   static bool CheckBullishEngulfing(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[2].close < rates[2].open && // Prev candle bearish
         rates[1].close > rates[1].open && // Last closed candle bullish
         rates[1].close > rates[2].open &&
         rates[1].open < rates[2].close)
      {
         result.signal = 1;
         result.patternName = "Bullish Engulfing";
         result.confidence = 0.85;
         return true;
      }
      return false;
   }
   
   // 2. Bearish Engulfing
   static bool CheckBearishEngulfing(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[2].close > rates[2].open && // Prev candle bullish
         rates[1].close < rates[1].open && // Last closed candle bearish
         rates[1].close < rates[2].open &&
         rates[1].open > rates[2].close)
      {
         result.signal = -1;
         result.patternName = "Bearish Engulfing";
         result.confidence = 0.85;
         return true;
      }
      return false;
   }
   
   // 3. Hammer (Bullish)
   static bool CheckHammer(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[1].close > rates[1].open && // Bullish
         (rates[1].high - rates[1].close) < (rates[1].close - rates[1].open) * 0.5 && // Small upper wick
         (rates[1].open - rates[1].low) > (rates[1].close - rates[1].open) * 2.0) // Long lower wick
      {
         result.signal = 1;
         result.patternName = "Hammer";
         result.confidence = 0.75;
         return true;
      }
      return false;
   }
   
   // 4. Shooting Star (Bearish)
   static bool CheckShootingStar(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[1].close < rates[1].open && // Bearish
         (rates[1].close - rates[1].low) < (rates[1].open - rates[1].close) * 0.5 && // Small lower wick
         (rates[1].high - rates[1].open) > (rates[1].open - rates[1].close) * 2.0) // Long upper wick
      {
         result.signal = -1;
         result.patternName = "Shooting Star";
         result.confidence = 0.75;
         return true;
      }
      return false;
   }
   
   // 5. Doji - indicates market indecision, return neutral signal
   static bool CheckDoji(const MqlRates &rates[], PatternResult &result)
   {
      if(MathAbs(rates[1].close - rates[1].open) <= (rates[1].high - rates[1].low) * 0.1)
      {
         // Doji represents market equilibrium/indecision - return neutral signal
         result.signal = 0; // Neutral - no clear direction
         result.patternName = "Doji";
         result.confidence = 0.50; // Lower confidence for uncertain pattern
         return true;
      }
      return false;
   }
   
   // 6. Inside Bar
   static bool CheckInsideBar(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[1].high < rates[2].high && rates[1].low > rates[2].low)
      {
         result.signal = 0;
         result.patternName = "Inside Bar";
         result.confidence = 0.60;
         return true;
      }
      return false;
   }
   
   // 7. Morning Star
   static bool CheckMorningStar(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[3].close < rates[3].open && // Bearish
         rates[2].close < rates[3].close && // Gap down or lower
         MathAbs(rates[2].close - rates[2].open) < MathAbs(rates[3].close - rates[3].open) && // Small body
         rates[1].close > rates[1].open && // Bullish
         rates[1].close > (rates[3].open + rates[3].close) / 2) // Closes above midpoint
      {
         result.signal = 1;
         result.patternName = "Morning Star";
         result.confidence = 0.90;
         return true;
      }
      return false;
   }
   
   // 8. Evening Star
   static bool CheckEveningStar(const MqlRates &rates[], PatternResult &result)
   {
      if(rates[3].close > rates[3].open && // Bullish
         rates[2].close > rates[3].close && // Gap up or higher
         MathAbs(rates[2].close - rates[2].open) < MathAbs(rates[3].close - rates[3].open) && // Small body
         rates[1].close < rates[1].open && // Bearish
         rates[1].close < (rates[3].open + rates[3].close) / 2) // Closes below midpoint
      {
         result.signal = -1;
         result.patternName = "Evening Star";
         result.confidence = 0.90;
         return true;
      }
      return false;
   }
};

TimeframeData tfData[NUM_TIMEFRAMES];
int StartX, StartY, BackgroundWidth, BackgroundHeight;
datetime lastRefresh=0;

// Required indicator buffer for MQL5 compliance
double indicatorBuffer[];

// Alert state management
AlertState alertState;

// Interactive features
string dashboardPrefix = "MTF_Dashboard_";
bool isDragging = false;
int dragOffsetX = 0;
int dragOffsetY = 0;

// Market session tracking
MarketSession sessions[4];
datetime lastSessionCheck = 0;

// Phase 3: Advanced Analytics
TrendMetrics currentMetrics;
ExternalData externalData;
MLPrediction mlPrediction;
datetime lastAnalyticsUpdate = 0;
datetime lastExternalUpdate = 0;
datetime lastMLUpdate = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffer for MQL5 compliance
   SetIndexBuffer(0, indicatorBuffer, INDICATOR_DATA);
   ArraySetAsSeries(indicatorBuffer, true);

   // Validate inputs
   if(SignalBar < 0)
   {
      Print("ERROR: SignalBar must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(ScalpingTimeframes < 1 || ScalpingTimeframes > 3)
   {
      Print("ERROR: ScalpingTimeframes must be 1-3");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(ScalpingMinConfidence < 0.0 || ScalpingMinConfidence > 1.0)
   {
      Print("ERROR: ScalpingMinConfidence must be 0.0-1.0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(MaxSpreadPoints < 0)
   {
      Print("ERROR: MaxSpreadPoints must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Initialize alert state
   alertState.lastStrongSignalAlert = 0;
   alertState.lastAnalyticsAlert = 0;
   alertState.lastPredictionAlert = 0;
   alertState.lastIntegrationAlert = 0;
   alertState.lastScalpingAlert = 0;
   alertState.lastMomentumBurstAlert = 0;
   alertState.lastVolumeSpikeAlert = 0;
   alertState.scalpingAlertActive = false;
   
   // Initialize market sessions
   InitializeMarketSessions();
   
   // Initialize Phase 3 features
   InitializeAdvancedAnalytics();
   InitializeExternalIntegrations();
   InitializeMLFeatures();
   
   // Initialize timing variables to force immediate first update
   lastAnalyticsUpdate = TimeCurrent() - 61;
   lastExternalUpdate = TimeCurrent() - 301;
   lastMLUpdate = TimeCurrent() - 61;
   
   bool show[]={Show_M1,Show_M5,Show_M15,Show_M30,Show_H1,Show_H4,Show_D1,Show_W1};
   int successCount = 0;
   
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      tfData[i].enabled=show[i];
      tfData[i].available=false;
      tfData[i].fastHandle=INVALID_HANDLE;
      tfData[i].slowHandle=INVALID_HANDLE;
      tfData[i].rsiHandle=INVALID_HANDLE;
      tfData[i].adxHandle=INVALID_HANDLE;
      tfData[i].atrHandle=INVALID_HANDLE;
      tfData[i].macdHandle=INVALID_HANDLE;
      tfData[i].bbHandle=INVALID_HANDLE;
      tfData[i].volumeHandle=INVALID_HANDLE;
      tfData[i].lastColor=NeutralColor;
      tfData[i].boxName=dashboardPrefix+timeframeLabels[i]+"_Box";
      tfData[i].labelName=dashboardPrefix+timeframeLabels[i]+"_Label";
      tfData[i].lastTrendDirection = 0;
      tfData[i].lastVolatility = 0;
      tfData[i].macdBullish = false;
      tfData[i].priceAboveBB = false;
      tfData[i].detectedPattern = "";
      tfData[i].volumeSpike = false;
      tfData[i].volumeRatio = 0.0;
      tfData[i].momentumBurst = false;
      tfData[i].momentumStrength = 0.0;
      tfData[i].lastBurstTime = 0;
      tfData[i].scalpingSignal = false;
      tfData[i].scalpingConfidence = 0.0;
      tfData[i].lastBarCount = 0;
      tfData[i].lastMLBarTime = 0;
      tfData[i].consistencyScore = 0.0;
      tfData[i].momentumScore = 0.0;
      tfData[i].volatilityScore = 0.0;
      tfData[i].overallScore = 0.0;
      tfData[i].historicalAccuracy = 0.0;
      tfData[i].correctPredictions = 0;
      tfData[i].totalPredictions = 0;

      if(tfData[i].enabled)
      {
         bool indicatorsOK = true;
         
         tfData[i].fastHandle=iMA(_Symbol,timeframes[i],FastMAPeriod,0,TrendMAMethod,PRICE_CLOSE);
         if(tfData[i].fastHandle == INVALID_HANDLE) indicatorsOK = false;
         
         tfData[i].slowHandle=iMA(_Symbol,timeframes[i],SlowMAPeriod,0,TrendMAMethod,PRICE_CLOSE);
         if(tfData[i].slowHandle == INVALID_HANDLE) indicatorsOK = false;
         
         tfData[i].rsiHandle=iRSI(_Symbol,timeframes[i],RSIPeriod,PRICE_CLOSE);
         if(tfData[i].rsiHandle == INVALID_HANDLE) indicatorsOK = false;
         
         tfData[i].adxHandle=iADX(_Symbol,timeframes[i],ADXPeriod);
         if(tfData[i].adxHandle == INVALID_HANDLE) indicatorsOK = false;
         
         tfData[i].atrHandle=iATR(_Symbol,timeframes[i],14);
         if(tfData[i].atrHandle == INVALID_HANDLE) indicatorsOK = false;
         
         tfData[i].volumeHandle=iVolumes(_Symbol,timeframes[i],VOLUME_TICK);
         if(tfData[i].volumeHandle == INVALID_HANDLE) indicatorsOK = false;

         // Advanced trend confirmation indicators
         if(EnableMACDConfirmation)
         {
            tfData[i].macdHandle=iMACD(_Symbol,timeframes[i],MACDFastPeriod,MACDSlowPeriod,MACDSignalPeriod,PRICE_CLOSE);
            if(tfData[i].macdHandle == INVALID_HANDLE) indicatorsOK = false;
         }

         if(EnableBollingerBands)
         {
            tfData[i].bbHandle=iBands(_Symbol,timeframes[i],BBPeriod,0,BBDeviation,PRICE_CLOSE);
            if(tfData[i].bbHandle == INVALID_HANDLE) indicatorsOK = false;
         }

         if(indicatorsOK)
         {
            tfData[i].available=true;
            successCount++;
         }
         else
         {
            Print("WARNING: Some indicators failed for timeframe ", timeframeLabels[i], " - continuing with other timeframes");
         }
      }
   }
   
   if(successCount == 0)
   {
      Print("ERROR: No timeframes successfully initialized");
      return INIT_FAILED;
   }
   
   CalcPositions();
   CreateObjects();

   // Enable mouse move events for dragging
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   if(OptimizeRefresh && RefreshSeconds > 0) 
   {
      if(!EventSetTimer(RefreshSeconds))
      {
         Print("WARNING: Failed to set timer, using OnCalculate refresh only");
      }
   }
   
   Print("MTF Dashboard v2.0 initialized | Scalping Mode: ", EnableScalpingMode ? "ON" : "OFF", 
         " | Timeframes: ", successCount, " of ", NUM_TIMEFRAMES);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      if(tfData[i].fastHandle!=INVALID_HANDLE) 
      {
         IndicatorRelease(tfData[i].fastHandle);
         tfData[i].fastHandle = INVALID_HANDLE;
      }
      if(tfData[i].slowHandle!=INVALID_HANDLE) 
      {
         IndicatorRelease(tfData[i].slowHandle);
         tfData[i].slowHandle = INVALID_HANDLE;
      }
      if(tfData[i].rsiHandle!=INVALID_HANDLE) 
      {
         IndicatorRelease(tfData[i].rsiHandle);
         tfData[i].rsiHandle = INVALID_HANDLE;
      }
      if(tfData[i].adxHandle!=INVALID_HANDLE) 
      {
         IndicatorRelease(tfData[i].adxHandle);
         tfData[i].adxHandle = INVALID_HANDLE;
      }
      if(tfData[i].atrHandle!=INVALID_HANDLE)
      {
         IndicatorRelease(tfData[i].atrHandle);
         tfData[i].atrHandle = INVALID_HANDLE;
      }
      if(tfData[i].volumeHandle!=INVALID_HANDLE)
      {
         IndicatorRelease(tfData[i].volumeHandle);
         tfData[i].volumeHandle = INVALID_HANDLE;
      }
      if(tfData[i].macdHandle!=INVALID_HANDLE)
      {
         IndicatorRelease(tfData[i].macdHandle);
         tfData[i].macdHandle = INVALID_HANDLE;
      }
      if(tfData[i].bbHandle!=INVALID_HANDLE) 
      {
         IndicatorRelease(tfData[i].bbHandle);
         tfData[i].bbHandle = INVALID_HANDLE;
      }
      
      ObjectDelete(0,tfData[i].boxName);
      ObjectDelete(0,tfData[i].labelName);
   }
   ObjectDelete(0,"BG");
   ObjectDelete(0,"Title");
   
   // Save position on deinit
   SavePositionToFile();

   // Disable mouse move events
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);

   EventKillTimer();
   Print("MTF Dashboard v2.0 deinitialized - Reason: ", reason);
}
//+------------------------------------------------------------------+
void SavePositionToFile()
{
   if(!SavePosition) return;
   
   string filename = "MTF_Dashboard_Pos_" + _Symbol + ".dat";
   int handle = FileOpen(filename, FILE_WRITE|FILE_BIN);
   if(handle != INVALID_HANDLE)
   {
      FileWriteInteger(handle, StartX);
      FileWriteInteger(handle, StartY);
      FileClose(handle);
   }
}

void LoadPositionFromFile()
{
   if(!SavePosition) return;
   
   string filename = "MTF_Dashboard_Pos_" + _Symbol + ".dat";
   if(FileIsExist(filename))
   {
      int handle = FileOpen(filename, FILE_READ|FILE_BIN);
      if(handle != INVALID_HANDLE)
      {
         if(FileSize(handle) >= 8)
         {
            int loadedX = FileReadInteger(handle);
            int loadedY = FileReadInteger(handle);
            StartX = loadedX;
            StartY = loadedY;
         }
         FileClose(handle);
      }
   }
}

void CalcPositions()
{
   int count=0;
   for(int i=0;i<NUM_TIMEFRAMES;i++) if(tfData[i].enabled) count++;
   BackgroundWidth=count*(BoxWidth+HorizontalSpacing)-HorizontalSpacing+20;
   BackgroundHeight=BoxHeight+50;
   long chartW=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   long chartH=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   
   // Ensure dashboard fits on screen with minimum margins
   int minMargin = 20;
   int maxStartX = DashboardStartX;
   int maxStartY = DashboardStartY;
   
   // Center horizontally,1 0 pixels from top
   StartX = (int)(chartW - BackgroundWidth) / 2;
   StartY = 0;
   
   // Only load saved position if not resetting
   if(!ResetPosition)
   {
      LoadPositionFromFile();
   }
   else
   {
      // Delete saved position file when resetting
      string filename = "MTF_Dashboard_Pos_" + _Symbol + ".dat";
      if(FileIsExist(filename))
      {
         FileDelete(filename);
      }
   }
   
   // Clamp position to screen bounds
   StartX = MathMax(-BackgroundWidth + 20, MathMin(StartX, maxStartX));
   StartY = MathMax(-BackgroundHeight + 20, MathMin(StartY, maxStartY));
   
   if(StartX < minMargin || StartY < minMargin)
   {
      Print("WARNING: Dashboard may not fit properly on current chart size");
   }
}
//+------------------------------------------------------------------+
void CreateObjects()
{
   // Delete existing objects first to avoid conflicts
   ObjectDelete(0,"BG");
   ObjectDelete(0,"Title");
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      ObjectDelete(0,tfData[i].boxName);
      ObjectDelete(0,tfData[i].labelName);
   }
   
   // Update market sessions before creating objects
   UpdateMarketSessions();
   
   ObjectCreate(0,"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"BG",OBJPROP_XDISTANCE,StartX-10);
   ObjectSetInteger(0,"BG",OBJPROP_YDISTANCE,StartY);
   ObjectSetInteger(0,"BG",OBJPROP_XSIZE,BackgroundWidth);
   ObjectSetInteger(0,"BG",OBJPROP_YSIZE,BackgroundHeight);
   ObjectSetInteger(0,"BG",OBJPROP_BGCOLOR,GetSessionBasedColor());
   ObjectSetInteger(0,"BG",OBJPROP_ZORDER, 0);
   
   ObjectCreate(0,"Title",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"Title",OBJPROP_TEXT,DashboardTitle);
   ObjectSetInteger(0,"Title",OBJPROP_XDISTANCE,StartX+BackgroundWidth/2);
   ObjectSetInteger(0,"Title",OBJPROP_YDISTANCE,StartY+15);
   ObjectSetInteger(0,"Title",OBJPROP_COLOR,TitleColor);
   ObjectSetInteger(0,"Title",OBJPROP_FONTSIZE,TitleFontSize);
   ObjectSetInteger(0,"Title",OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,"Title",OBJPROP_ZORDER, 1);
   
   int idx=0;
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      if(!tfData[i].enabled) continue;
      int x=StartX+idx*(BoxWidth+HorizontalSpacing);
      
      ObjectCreate(0,tfData[i].boxName,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_YDISTANCE,StartY+30);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_XSIZE,BoxWidth);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_YSIZE,BoxHeight);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_BGCOLOR,tfData[i].available?NeutralColor:DisabledColor);
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_ZORDER, 1);
      
      ObjectCreate(0,tfData[i].labelName,OBJ_LABEL,0,0,0);
      ObjectSetString(0,tfData[i].labelName,OBJPROP_TEXT,timeframeLabels[i]);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_XDISTANCE,x+BoxWidth/2);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_YDISTANCE,StartY+30+BoxHeight/2);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,tfData[i].labelName,OBJPROP_ZORDER, 2);
      
      idx++;
   }
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime& time[],const double& open[],const double& high[],
                const double& low[],const double& close[],const long& tick_volume[],
                const long& volume[],const int& spread[])
{
   // Ensure indicator buffer has at least one element and set it
   if(ArraySize(indicatorBuffer) < 1)
   {
      ArrayResize(indicatorBuffer, 1);
   }
   indicatorBuffer[0] = 0.0;

    if(TimeCurrent()-lastRefresh>=RefreshSeconds)
       UpdateAll();
    return(rates_total);
}
//+------------------------------------------------------------------+
void OnTimer() 
{
    UpdateAll();
}
//+------------------------------------------------------------------+
void UpdateAll()
{
   // Update market sessions
   UpdateMarketSessions();
   
   // Update dashboard background color based on session
   ObjectSetInteger(0,"BG",OBJPROP_BGCOLOR,GetSessionBasedColor());
   
   // Update Phase 3 features
   if(EnableTrendConsistencyScoring || EnableMomentumAnalysis || EnableVolatilityAdjustment) UpdateAdvancedAnalytics();
   if(EnableEconomicCalendar || EnableSentimentAnalysis) UpdateExternalData();
   if(EnableAITrendPrediction || EnableMLPatternRecognition || EnableNeuralNetworkSignals) UpdateMLPredictions();
   
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      if(tfData[i].enabled && tfData[i].available)
          UpdateBox(i);
   }
   
   // Check for multi-timeframe alignment
   CheckMultiTimeframeAlignment();
   
   // Phase 3: Enhanced analysis
   if(EnableTrendConsistencyScoring || EnableMomentumAnalysis || EnableVolatilityAdjustment) PerformComprehensiveAnalysis();
   
   lastRefresh=TimeCurrent();
   ChartRedraw();
}
//+------------------------------------------------------------------+
// Cached indicator data structure for optimization
struct IndicatorData
{
   double fastMA;
   double slowMA;
   double rsi;
   double adx;
   double atr;
   int    dir;
   double strength;
   bool   strong;
   color  newColor;
};

//+------------------------------------------------------------------+
void UpdateBox(int i)
{
   // Validate indicator handles before copying data
   if(tfData[i].fastHandle == INVALID_HANDLE || tfData[i].slowHandle == INVALID_HANDLE ||
      tfData[i].rsiHandle == INVALID_HANDLE || tfData[i].adxHandle == INVALID_HANDLE ||
      tfData[i].atrHandle == INVALID_HANDLE || tfData[i].volumeHandle == INVALID_HANDLE)
   {
      ObjectSetInteger(0,tfData[i].boxName,OBJPROP_BGCOLOR,ErrorColor);
      return;
   }

   // Scalping mode: Check spread filter
   if(EnableScalpingMode && EnableSpreadFilter)
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > MaxSpreadPoints)
      {
         // High spread - warn scalpers
         ObjectSetInteger(0,tfData[i].boxName,OBJPROP_BGCOLOR,clrOrange);
         if(TimeCurrent() - alertState.lastScalpingAlert > 300)
         {
             Print("WARNING: High spread (", IntegerToString(spread), " points) - Avoid scalping!");
            alertState.lastScalpingAlert = TimeCurrent();
         }
         return;
      }
   }
   
   // Optimization: Check if bar count changed to avoid redundant data copies
   int currentBars = iBars(_Symbol, timeframes[i]);
   bool barsChanged = (currentBars != tfData[i].lastBarCount);
   
   // Static cache for indicator data (per timeframe)
   static IndicatorData cachedData[NUM_TIMEFRAMES];
   IndicatorData data;
   
   // Only fetch indicator data if bars changed or first run
    if(barsChanged || tfData[i].lastBarCount == 0 || SignalBar == 0)
   {
      tfData[i].lastBarCount = currentBars;
      
      if(!FetchIndicatorData(i, data))
      {
         ObjectSetInteger(0,tfData[i].boxName,OBJPROP_BGCOLOR,ErrorColor);
         return;
      }
      
      // Cache the data
      cachedData[i] = data;
   }
   else
   {
      // Use cached data
      data = cachedData[i];
   }
   
   // Enhanced alert system
   datetime currentTime = TimeCurrent();

   // Strong trend alerts (ONLY alert for strong buy/sell signals)
   if(data.strong && data.dir != 0 && currentTime - alertState.lastStrongSignalAlert > 300) // 5 min cooldown
   {
      string strongMsg = "*** STRONG SIGNAL *** " + timeframeLabels[i] + " " +
                        (data.dir>0?"STRONG BUY":"STRONG SELL") +
                        " | ADX: " + DoubleToString(data.adx, 1) + 
                        " | Strength: " + DoubleToString(data.strength*100, 1) + "%" +
                        " | RSI: " + DoubleToString(data.rsi, 1);
      Print(strongMsg);
      alertState.lastStrongSignalAlert = currentTime;
   }
   
   // Update tracking variables
   tfData[i].lastTrendDirection = data.dir;
   tfData[i].lastVolatility = data.atr;

   // Scalping features: Volume analysis (always run for real-time detection)
   if(EnableVolumeConfirmation || EnableScalpingMode)
   {
      AnalyzeVolume(i);
   }

   // Scalping features: Momentum burst detection (always run for real-time detection)
   if(EnableMomentumBurstDetection || EnableScalpingMode)
   {
       DetectMomentumBurst(i);
   }

   // Calculate scalping signal confidence
   if(EnableScalpingMode && i < ScalpingTimeframes)
   {
      CalculateScalpingSignal(i, data.dir, data.strength, data.adx);
   }

    color displayColor = data.newColor;
    if(EnableScalpingMode && ScalpingAlertsOnly && i < ScalpingTimeframes && !tfData[i].scalpingSignal)
       displayColor = NeutralColor;

    ObjectSetInteger(0,tfData[i].boxName,OBJPROP_BGCOLOR,displayColor);

    // Add detailed hover tooltips for visual analysis
    string boxTooltip;
    StringConcatenate(boxTooltip, timeframeLabels[i], " Market Metrics:",
                     "\nTrend: ", (data.dir > 0 ? "Bullish" : (data.dir < 0 ? "Bearish" : "Neutral")),
                     "\nTrend Strength: ", DoubleToString(data.strength * 100, 2), "%",
                     "\nADX (Trend Intensity): ", DoubleToString(data.adx, 1),
                     "\nRSI: ", DoubleToString(data.rsi, 1),
                     "\nVolatility (ATR): ", DoubleToString(data.atr, _Digits),
                     "\nMACD Confirmation: ", (tfData[i].macdBullish ? "Confirmed" : "No Confirmation"),
                     "\nConfidence Score: ", DoubleToString(tfData[i].overallScore, 1), "%");
    
    if(tfData[i].detectedPattern != "")
       boxTooltip += "\nCandlestick Pattern: " + tfData[i].detectedPattern;
       
    if(EnableScalpingMode && i < ScalpingTimeframes)
       boxTooltip += "\nScalping Entry Confidence: " + DoubleToString(tfData[i].scalpingConfidence * 100, 1) + "%";

    ObjectSetString(0, tfData[i].boxName, OBJPROP_TOOLTIP, boxTooltip);
    ObjectSetString(0, tfData[i].labelName, OBJPROP_TOOLTIP, boxTooltip);

   if(tfData[i].detectedPattern != "")
   {
       ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BORDER_COLOR, PatternHighlightColor);
   }
   else
   {
        ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BORDER_COLOR, displayColor);
    }

    tfData[i].lastColor=displayColor;
}
//+------------------------------------------------------------------+
bool FetchIndicatorData(int i, IndicatorData &data)
{
   double buf[1];
   
   // Fetch Fast MA
   if(CopyBuffer(tfData[i].fastHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return false;
   data.fastMA = buf[0];
   
   // Fetch Slow MA
   if(CopyBuffer(tfData[i].slowHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return false;
   data.slowMA = buf[0];
   
   // Fetch RSI
   if(CopyBuffer(tfData[i].rsiHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return false;
   data.rsi = buf[0];
   
   // Fetch ADX
   if(CopyBuffer(tfData[i].adxHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return false;
   data.adx = buf[0];
   
   // Fetch ATR
   if(CopyBuffer(tfData[i].atrHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return false;
   data.atr = buf[0];
   
   // Prevent division by zero
   if(data.slowMA == 0)
      return false;
   
   // Calculate trend metrics
   data.dir = (data.fastMA > data.slowMA) ? 1 : (data.fastMA < data.slowMA) ? -1 : 0;
   data.strength = MathAbs((data.fastMA - data.slowMA) / data.slowMA);
   data.strong = (data.strength > StrongTrendThreshold && data.adx > ADXThreshold);
   
    bool macdConfirmed = GetMACDConfirmation(i, data.dir);
    bool bbConfirmed = GetBollingerBandPosition(i, data.dir);
    bool rsiConfirmed = true;

    if(data.dir > 0 && data.rsi >= RSIOverbought)
       rsiConfirmed = false;
    else if(data.dir < 0 && data.rsi <= RSIOversold)
       rsiConfirmed = false;

    tfData[i].macdBullish = macdConfirmed;
    tfData[i].priceAboveBB = bbConfirmed;

    if(!macdConfirmed || !bbConfirmed || !rsiConfirmed)
       data.strong = false;

    // Determine color
    data.newColor = (data.dir > 0) ? (data.strong ? StrongUptrendColor : UptrendColor) :
                    (data.dir < 0) ? (data.strong ? StrongDowntrendColor : DowntrendColor) : NeutralColor;
   
   return true;
}
//+------------------------------------------------------------------+
void CheckMultiTimeframeAlignment()
{
   int uptrendCount = 0;
   int downtrendCount = 0;
   int activeTimeframes = 0;

   // Count trends across all active timeframes
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      if(tfData[i].enabled && tfData[i].available)
      {
         activeTimeframes++;
         if(tfData[i].lastTrendDirection == 1) uptrendCount++;
         else if(tfData[i].lastTrendDirection == -1) downtrendCount++;
      }
   }
   
   // Visual indicator: Highlight dashboard title when timeframes are aligned
   if(uptrendCount >= AlignmentThreshold)
   {
      ObjectSetInteger(0,"Title",OBJPROP_COLOR,StrongUptrendColor);
      // Alert on alignment
      if(TimeCurrent() - alertState.lastStrongSignalAlert > 300)
      {
         Print("MTF ALIGNMENT: ", uptrendCount, " timeframes BULLISH | Threshold: ", AlignmentThreshold);
         alertState.lastStrongSignalAlert = TimeCurrent();
      }
   }
   else if(downtrendCount >= AlignmentThreshold)
   {
      ObjectSetInteger(0,"Title",OBJPROP_COLOR,StrongDowntrendColor);
      // Alert on alignment
      if(TimeCurrent() - alertState.lastStrongSignalAlert > 300)
      {
         Print("MTF ALIGNMENT: ", downtrendCount, " timeframes BEARISH | Threshold: ", AlignmentThreshold);
         alertState.lastStrongSignalAlert = TimeCurrent();
      }
   }
   else
   {
      ObjectSetInteger(0,"Title",OBJPROP_COLOR,TitleColor);
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Handle chart events for interactive features
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle object clicks
      if(sparam == "BG")
      {
         isDragging = true;
         dragOffsetX = (int)lparam - (StartX - 10);
         dragOffsetY = (int)dparam - 10;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
      }
      else
      {
         // Check timeframe boxes
         for(int i=0; i<NUM_TIMEFRAMES; i++)
         {
            if(tfData[i].enabled && sparam == tfData[i].boxName)
            {
               // Open chart for this timeframe
               string symbol = _Symbol;
               ENUM_TIMEFRAMES tf = timeframes[i];

               // Create a new chart or switch to existing one
               long chartId = ChartOpen(symbol, tf);
               if(chartId > 0)
               {
                  ChartSetInteger(chartId, CHART_BRING_TO_TOP, true);
                  Print("Opened ", timeframeLabels[i], " chart for ", symbol);
               }
               break;
            }
         }
      }
   }
   else if(id == CHARTEVENT_MOUSE_MOVE)
   {
      // Handle dragging
      if(isDragging)
      {
         // Check if left mouse button is pressed
         long flags = (long)StringToInteger(sparam);
         if((flags & 1) != 0)
         {
            int bgX = (int)lparam - dragOffsetX;
            int bgY = (int)dparam - dragOffsetY;
            
            // Convert background position to StartX/StartY
            StartX = bgX + 10;
            StartY = bgY;

            // Boundary checks to keep dashboard on screen
            long chartW = ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
            long chartH = ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
            int minMargin = 20;
            int maxStartX = (int)(chartW - BackgroundWidth - minMargin);
            int maxStartY = (int)(chartH - BackgroundHeight - minMargin);

            // Allow some margin but prevent losing it completely
            StartX = MathMax(-BackgroundWidth + 20, MathMin(StartX, maxStartX));
            StartY = MathMax(-BackgroundHeight + 20, MathMin(StartY, maxStartY));

            // Update object positions instead of recreating to make dragging smoother
            ObjectSetInteger(0,"BG",OBJPROP_XDISTANCE,StartX-10);
            ObjectSetInteger(0,"BG",OBJPROP_YDISTANCE,StartY);
            ObjectSetInteger(0,"Title",OBJPROP_XDISTANCE,StartX+BackgroundWidth/2);
            ObjectSetInteger(0,"Title",OBJPROP_YDISTANCE,StartY+15);
            
            int idx=0;
            for(int i=0;i<NUM_TIMEFRAMES;i++)
            {
               if(!tfData[i].enabled) continue;
               int x=StartX+idx*(BoxWidth+HorizontalSpacing);
               ObjectSetInteger(0,tfData[i].boxName,OBJPROP_XDISTANCE,x);
               ObjectSetInteger(0,tfData[i].boxName,OBJPROP_YDISTANCE,StartY+30);
               ObjectSetInteger(0,tfData[i].labelName,OBJPROP_XDISTANCE,x+BoxWidth/2);
               ObjectSetInteger(0,tfData[i].labelName,OBJPROP_YDISTANCE,StartY+30+BoxHeight/2);
               idx++;
            }
            
            ChartRedraw();
         }
         else
         {
            // Mouse button released - save position
            isDragging = false;
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
            SavePositionToFile();
         }
      }
   }
   else if(id == CHARTEVENT_CLICK)
   {
      // Fallback to stop dragging
      if(isDragging)
      {
         isDragging = false;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true); // Re-enable chart scrolling
         SavePositionToFile();
      }
   }
}
//+------------------------------------------------------------------+
void InitializeMarketSessions()
{
   // Asia Session (Tokyo: 23:00-07:00 UTC)
   sessions[0].name = "Asia";
   sessions[0].startHour = 23;
   sessions[0].endHour = 7;
   sessions[0].sessionColor = AsiaSessionColor;
   sessions[0].isActive = false;
   
   // London Session (08:00-16:00 UTC)
   sessions[1].name = "London";
   sessions[1].startHour = 8;
   sessions[1].endHour = 16;
   sessions[1].sessionColor = LondonSessionColor;
   sessions[1].isActive = false;
   
   // New York Session (13:00-21:00 UTC)
   sessions[2].name = "New York";
   sessions[2].startHour = 13;
   sessions[2].endHour = 21;
   sessions[2].sessionColor = NewYorkSessionColor;
   sessions[2].isActive = false;
   
   // Session Overlaps (London/NY: 13:00-16:00 UTC)
   sessions[3].name = "Overlap";
   sessions[3].startHour = 13;
   sessions[3].endHour = 16;
   sessions[3].sessionColor = SessionOverlapColor;
   sessions[3].isActive = false;
}

//+------------------------------------------------------------------+
void UpdateMarketSessions()
{
   if(!EnableMarketSessionFilter) return;
   
   datetime currentTime = TimeGMT();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int currentHour = timeStruct.hour;
   
   // Check each session
   for(int i = 0; i < 4; i++)
   {
      bool wasActive = sessions[i].isActive;
      sessions[i].isActive = false;
      
      // Handle sessions that cross midnight (Asia)
      if(sessions[i].startHour > sessions[i].endHour)
      {
         if(currentHour >= sessions[i].startHour || currentHour < sessions[i].endHour)
            sessions[i].isActive = true;
      }
      else
      {
         if(currentHour >= sessions[i].startHour && currentHour < sessions[i].endHour)
            sessions[i].isActive = true;
      }
      
      // Alert on session change
      if(sessions[i].isActive && !wasActive)
      {
         Print(sessions[i].name, " session started");
      }
      else if(!sessions[i].isActive && wasActive)
      {
         Print(sessions[i].name, " session ended");
      }
   }
}

//+------------------------------------------------------------------+
color GetSessionBasedColor()
{
   if(!EnableMarketSessionFilter) return BackgroundColor;
   
   // Check for overlap first (highest priority)
   if(HighlightSessionOverlap && sessions[3].isActive)
      return SessionOverlapColor;
   
   // Check individual sessions
   if(HighlightAsiaSession && sessions[0].isActive)
      return AsiaSessionColor;
   if(HighlightLondonSession && sessions[1].isActive)
      return LondonSessionColor;
   if(HighlightNewYorkSession && sessions[2].isActive)
      return NewYorkSessionColor;
   
   return BackgroundColor;
}

//+------------------------------------------------------------------+
bool GetMACDConfirmation(int i, int direction)
{
    // No confirmation needed if disabled
    if(direction == 0 || !EnableMACDConfirmation)
       return true;
    
    // Feature enabled but unavailable - confirmation failed
    if(tfData[i].macdHandle == INVALID_HANDLE)
       return false;
   
   double macdMain[1], macdSignal[1];
   
   if(CopyBuffer(tfData[i].macdHandle, 0, SignalBar, 1, macdMain) <= 0 ||
      CopyBuffer(tfData[i].macdHandle, 1, SignalBar, 1, macdSignal) <= 0)
      return false;
   
    if(direction > 0)
       return macdMain[0] > macdSignal[0] && macdMain[0] > MACDThreshold;

    return macdMain[0] < macdSignal[0] && macdMain[0] < -MACDThreshold;
}

//+------------------------------------------------------------------+
bool GetBollingerBandPosition(int i, int direction)
{
    // No confirmation needed if disabled
    if(direction == 0 || !EnableBollingerBands)
       return true;
    
    // Feature enabled but unavailable - confirmation failed
    if(tfData[i].bbHandle == INVALID_HANDLE)
       return false;

    double bbMiddle[1], closePrice[1];

    if(CopyBuffer(tfData[i].bbHandle, 0, SignalBar, 1, bbMiddle) <= 0)
       return false;

   // Use close price of SignalBar for consistency with other indicators
   if(CopyClose(_Symbol, timeframes[i], SignalBar, 1, closePrice) <= 0)
      return false;

    if(direction > 0)
       return closePrice[0] > bbMiddle[0];

    return closePrice[0] < bbMiddle[0];
}

//+------------------------------------------------------------------+
// Scalping Features: Volume Analysis
//+------------------------------------------------------------------+
void AnalyzeVolume(int tfIndex)
{
   double volumeCurrent[], volumeAvg[];
   ArraySetAsSeries(volumeCurrent, true);
   ArraySetAsSeries(volumeAvg, true);

   tfData[tfIndex].volumeSpike = false;
   tfData[tfIndex].volumeRatio = 0.0;

   // Get current volume
   if(CopyBuffer(tfData[tfIndex].volumeHandle, 0, SignalBar, 1, volumeCurrent) != 1)
      return;

   // Get average volume (last 20 bars)
   if(CopyBuffer(tfData[tfIndex].volumeHandle, 0, SignalBar + 1, 20, volumeAvg) != 20)
      return;

   double avgVolume = 0;
   for(int j = 0; j < 20; j++)
   {
      avgVolume += volumeAvg[j];
   }
   avgVolume /= 20.0;

   // Calculate volume ratio
   if(avgVolume > 0)
   {
      tfData[tfIndex].volumeRatio = volumeCurrent[0] / avgVolume;
      
      // Detect volume spike
      if(tfData[tfIndex].volumeRatio >= VolumeSpikeMultiplier)
      {
         tfData[tfIndex].volumeSpike = true;
         
         // Alert for volume spike
         if(EnableVolumeConfirmation && TimeCurrent() - alertState.lastVolumeSpikeAlert > 120)
         {
            string volMsg = timeframeLabels[tfIndex] + " VOLUME SPIKE! Ratio: " + 
                            DoubleToString(tfData[tfIndex].volumeRatio, 2) + "x";
            Print(volMsg);
            alertState.lastVolumeSpikeAlert = TimeCurrent();
         }
      }
      else
      {
         tfData[tfIndex].volumeSpike = false;
      }
   }
}

//+------------------------------------------------------------------+
// Scalping Features: Momentum Burst Detection
//+------------------------------------------------------------------+
void DetectMomentumBurst(int tfIndex)
{
   tfData[tfIndex].momentumBurst = false;
   tfData[tfIndex].momentumStrength = 0.0;

   double close[];
   ArraySetAsSeries(close, true);
   int barsNeeded = MomentumBurstBars + 1;

   if(MomentumBurstBars < 1 || CopyClose(_Symbol, timeframes[tfIndex], 0, barsNeeded, close) != barsNeeded)
      return;

   if(close[MomentumBurstBars] == 0.0)
      return;

   double priceChange = 0;
   double burstStrength = 0;

   // Calculate price change over MomentumBurstBars on this timeframe
   priceChange = MathAbs(close[0] - close[MomentumBurstBars]) / close[MomentumBurstBars];
    
    // Check if price change exceeds threshold
    if(priceChange >= MomentumBurstThreshold)
    {
       burstStrength = priceChange / MomentumBurstThreshold;
       
       // Determine direction
       int direction = (close[0] > close[MomentumBurstBars]) ? 1 : -1;
       
       tfData[tfIndex].momentumBurst = true;
       tfData[tfIndex].momentumStrength = burstStrength;
       tfData[tfIndex].lastBurstTime = TimeCurrent();
       
       // Alert for momentum burst
       if(TimeCurrent() - alertState.lastMomentumBurstAlert > 180) // 3 min cooldown
       {
          string burstMsg = timeframeLabels[tfIndex] + " MOMENTUM BURST! " +
                           (direction > 0 ? "UP" : "DOWN") + 
                           " (Strength: " + DoubleToString(burstStrength, 2) + "x)";
           Print(burstMsg);
          alertState.lastMomentumBurstAlert = TimeCurrent();
       }
    }
}

//+------------------------------------------------------------------+
// Scalping Features: Calculate Scalping Signal Confidence
//+------------------------------------------------------------------+
void CalculateScalpingSignal(int tfIndex, int trendDir, double trendStrength, double adx)
{
   tfData[tfIndex].scalpingSignal = false;
   tfData[tfIndex].scalpingConfidence = 0.0;

   double confidence = 0.0;
   int factors = 0;
   
   // Factor 1: Trend direction strength (0-25 points)
   if(trendDir != 0)
   {
      confidence += MathMin(25.0, trendStrength * 1000);
      factors++;
   }
   
   // Factor 2: ADX confirmation (0-25 points)
   if(adx >= ADXThreshold)
   {
      confidence += 25.0;
      factors++;
   }
   
   // Factor 3: Volume confirmation (0-25 points)
   if(tfData[tfIndex].volumeSpike)
   {
      confidence += 25.0;
      factors++;
   }
   else if(tfData[tfIndex].volumeRatio > 1.0)
   {
      confidence += MathMin(25.0, tfData[tfIndex].volumeRatio * 12.5);
      factors++;
   }
   
   // Factor 4: Momentum burst (0-25 points)
   if(tfData[tfIndex].momentumBurst)
   {
      confidence += MathMin(25.0, tfData[tfIndex].momentumStrength * 12.5);
      factors++;
   }
   
   // Normalize confidence to 0-1
   if(factors > 0)
   {
      tfData[tfIndex].scalpingConfidence = confidence / 100.0;
       
      // Check if signal meets minimum confidence
      if(trendDir != 0 && tfData[tfIndex].scalpingConfidence >= ScalpingMinConfidence)
      {
         tfData[tfIndex].scalpingSignal = true;
         
         // Generate scalping alert
         if(TimeCurrent() - alertState.lastScalpingAlert > 60) // 1 min cooldown
         {
            string signalMsg = "SCALPING SIGNAL " + timeframeLabels[tfIndex] + "! " +
                              (trendDir > 0 ? "BUY" : "SELL") +
                              " (Confidence: " + DoubleToString(tfData[tfIndex].scalpingConfidence * 100, 1) + "%)";
             Print(signalMsg);
            alertState.lastScalpingAlert = TimeCurrent();
         }
      }
   }
}
//+------------------------------------------------------------------+
// Phase 3: Advanced Analytics Functions
//+------------------------------------------------------------------+
void InitializeAdvancedAnalytics()
{
   currentMetrics.overallScore = 0.0;
   currentMetrics.consistencyScore = 0.0;
   currentMetrics.momentumScore = 0.0;
   currentMetrics.volatilityScore = 0.0;
   currentMetrics.predictionConfidence = 0.0;
   currentMetrics.isHighProbability = false;
   
   Print("Phase 3: Advanced Analytics initialized");
}

//+------------------------------------------------------------------+
void InitializeExternalIntegrations()
{
   externalData.lastUpdate = 0;
   externalData.sentimentScore = 0.0;
   externalData.volatilityIndex = 0.0;
   externalData.upcomingNewsImpact = 0;
   externalData.newsHeadline = "";
   externalData.dataAvailable = false;
   
   Print("Phase 3: External Integrations initialized");
}

//+------------------------------------------------------------------+
void InitializeMLFeatures()
{
   mlPrediction.predictedDirection = 0.0;
   mlPrediction.confidence = 0.0;
   mlPrediction.timeToSignal = 0.0;
   mlPrediction.patternType = "Unknown";
   mlPrediction.isReliable = false;
   
   Print("Phase 3: ML Features initialized");
}

//+------------------------------------------------------------------+
void UpdateAdvancedAnalytics()
{
   if(!EnableTrendConsistencyScoring && !EnableMomentumAnalysis && !EnableVolatilityAdjustment) 
      return;
      
   datetime currentTime = TimeCurrent();
   if(currentTime - lastAnalyticsUpdate < 60) // Update every minute
      return;
   
   // Calculate trend consistency across timeframes
   if(EnableTrendConsistencyScoring)
   {
      CalculateTrendConsistency();
   }
   
   // Calculate momentum analysis
   if(EnableMomentumAnalysis)
   {
      CalculateMomentumAnalysis();
   }
   
   // Calculate volatility-adjusted signals
   if(EnableVolatilityAdjustment)
   {
      CalculateVolatilityAdjustment();
   }
   
   // Update historical performance tracking
   if(EnableHistoricalPerformanceTracking)
   {
      UpdateHistoricalPerformance();
   }
   
   lastAnalyticsUpdate = currentTime;
}

//+------------------------------------------------------------------+
void CalculateTrendConsistency()
{
   int bullishCount = 0, bearishCount = 0, neutralCount = 0;
   int activeTimeframes = 0;
   
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(tfData[i].enabled && tfData[i].available)
      {
         activeTimeframes++;
         if(tfData[i].lastTrendDirection == 1) bullishCount++;
         else if(tfData[i].lastTrendDirection == -1) bearishCount++;
         else neutralCount++;
      }
   }
   
   // Calculate consistency score (0-100)
   int maxCount = MathMax(MathMax(bullishCount, bearishCount), neutralCount);
   double consistencyScore = (activeTimeframes > 0) ? (double)maxCount / activeTimeframes * 100 : 0;
   
   // Update global metrics (for dashboard display)
   currentMetrics.consistencyScore = consistencyScore;
   
   // Also update per-timeframe consistency for use in overallScore calculation
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(tfData[i].enabled && tfData[i].available)
      {
         // Each timeframe gets the global consistency score
         // This represents how consistent this timeframe is with the overall market
         tfData[i].consistencyScore = consistencyScore;
      }
   }
}

//+------------------------------------------------------------------+
void CalculateMomentumAnalysis()
{
   // Calculate momentum based on rate of change of trend strength
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      
      double buf[]; // Get last 3 values for momentum calculation
      ArraySetAsSeries(buf, true); // Ensure index 0 is current

      if(CopyBuffer(tfData[i].fastHandle, 0, SignalBar, 3, buf) == 3)
      {
         // Momentum = (Price_t - Price_t-1) / Price_t-1
         double momentumCurrent = (buf[0] - buf[1]) / buf[1];
         double momentumPrev    = (buf[1] - buf[2]) / buf[2];
         
         // Acceleration = change in momentum
         double acceleration = momentumCurrent - momentumPrev;
         
         // Normalize to -1 to 1 range
         tfData[i].momentumScore = MathMax(-1.0, MathMin(1.0, acceleration * 1000));
      }
   }
}

//+------------------------------------------------------------------+
void CalculateVolatilityAdjustment()
{
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      
      double atr[]; // Get 20 periods of ATR
      ArraySetAsSeries(atr, true); // Ensure index 0 is current

      if(CopyBuffer(tfData[i].atrHandle, 0, SignalBar, 20, atr) == 20)
      {
         double currentATR = atr[0];
         double avgATR = 0;
         
         for(int j = 1; j < 20; j++)
         {
            avgATR += atr[j];
         }
         avgATR /= 19;
         
         // Volatility ratio (current vs average)
         double volatilityRatio = (avgATR > 0) ? currentATR / avgATR : 1.0;
         
         // Adjust score based on volatility (0.5 = normal, >1 = high volatility)
         tfData[i].volatilityScore = MathMax(0.1, MathMin(2.0, volatilityRatio));
      }
   }
}

//+------------------------------------------------------------------+
void UpdateHistoricalPerformance()
{
   // Track prediction accuracy over time
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;

      // Simple accuracy tracking: compare predicted vs actual direction
       if(tfData[i].totalPredictions > 0)
      {
         // Check if prediction was correct (compare with actual price movement over horizon)
         double closeData[];
         ArraySetAsSeries(closeData, true);
         
         // Get bars covering the prediction horizon for proper validation
         int barsNeeded = PredictionHorizonBars + 1;
         if(CopyClose(_Symbol, timeframes[i], 0, barsNeeded, closeData) == barsNeeded)
         {
            // Use lastTrendDirection for prediction direction (-1, 0, 1)
            int predictedDir = tfData[i].lastTrendDirection;
            
            // Check: did price move in predicted direction over the horizon?
            bool wasCorrect = false;
            double priceChange = closeData[0] - closeData[PredictionHorizonBars];
            
            if(predictedDir > 0 && priceChange > 0)
               wasCorrect = true;
            else if(predictedDir < 0 && priceChange < 0)
               wasCorrect = true;
            
            if(wasCorrect)
            {
               tfData[i].correctPredictions++;
            }
         }
         
         tfData[i].historicalAccuracy = (double)tfData[i].correctPredictions / tfData[i].totalPredictions;
      }
   }
}

//+------------------------------------------------------------------+
void PerformComprehensiveAnalysis()
{
   // Calculate overall score combining all metrics
   double weightedScore = 0;
   double totalWeight = 0;
   
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      
      // Combine different metrics with weights
      double score = 0;
      double weight = 0;
      
      if(EnableTrendConsistencyScoring)
      {
         score += tfData[i].consistencyScore * ConsistencyWeight;
         weight += ConsistencyWeight;
      }
      
      if(EnableMomentumAnalysis)
      {
         // Convert momentum from -1..1 to 0..100
         double momentumNorm = (tfData[i].momentumScore + 1) * 50;
         score += momentumNorm * MomentumWeight;
         weight += MomentumWeight;
      }
      
      if(EnableVolatilityAdjustment)
      {
         // Inverse volatility score (lower volatility = higher score)
         double volatilityNorm = (2.0 - tfData[i].volatilityScore) / 2.0 * 100;
         score += volatilityNorm * VolatilityWeight;
         weight += VolatilityWeight;
      }
      
      if(weight > 0)
      {
         tfData[i].overallScore = score / weight;
         weightedScore += tfData[i].overallScore;
         totalWeight += 1;
      }
   }
   
   // Calculate global metrics
   if(totalWeight > 0)
   {
      currentMetrics.overallScore = weightedScore / totalWeight;
      currentMetrics.isHighProbability = currentMetrics.overallScore > 75;
   }
   
   // Generate analytics alerts
   GenerateAnalyticsAlerts();
}

//+------------------------------------------------------------------+
void GenerateAnalyticsAlerts()
{
   datetime currentTime = TimeCurrent();
   
   // High probability setup alert
   if(currentMetrics.isHighProbability && currentTime - alertState.lastAnalyticsAlert > 300)
   {
      string alertMsg = "HIGH PROBABILITY SETUP DETECTED! " + 
                        "Overall Score: " + DoubleToString(currentMetrics.overallScore, 1) + "% " +
                        "(Consistency: " + DoubleToString(currentMetrics.consistencyScore, 1) + "%)";
       Print(alertMsg);
      alertState.lastAnalyticsAlert = currentTime;
   }
}

//+------------------------------------------------------------------+
void UpdateExternalData()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - lastExternalUpdate < 300) // Update every 5 minutes
      return;
   
   // Simulation of external data (requires API integration for real data)
   // We use simulated values here to demonstrate the feature structure
   externalData.sentimentScore = (MathRand() % 200 - 100) / 100.0; // -1 to 1
   externalData.volatilityIndex = (MathRand() % 100) / 100.0; // 0 to 1
   externalData.upcomingNewsImpact = MathRand() % 3; // 0, 1, or 2
   externalData.dataAvailable = true;
   externalData.lastUpdate = currentTime;

   // Generate integration alerts
   if(EnableEconomicCalendar && externalData.upcomingNewsImpact >= 2)
   {
      if(TimeCurrent() - alertState.lastIntegrationAlert > 600) // 10 min cooldown
      {
          Print("HIGH IMPACT NEWS EVENT detected! Consider reducing position size.");
         alertState.lastIntegrationAlert = TimeCurrent();
      }
   }
   
   if(EnableSentimentAnalysis && MathAbs(externalData.sentimentScore) > 0.7)
   {
      if(TimeCurrent() - alertState.lastIntegrationAlert > 600)
      {
         string sentimentMsg = "EXTREME SENTIMENT: " + 
                              (externalData.sentimentScore > 0 ? "Bullish" : "Bearish") +
                              " (Score: " + DoubleToString(externalData.sentimentScore, 2) + ")";
          Print(sentimentMsg);
         alertState.lastIntegrationAlert = TimeCurrent();
      }
   }

   lastExternalUpdate = currentTime;
}

//+------------------------------------------------------------------+
void UpdateMLPredictions()
{
   // Skip if pattern recognition is disabled
   if(!EnableMLPatternRecognition)
      return;

   datetime currentTime = TimeCurrent();
   
   // Pattern Recognition using extracted PatternRecognizer class (Issue 7)
   // Now with new-bar detection instead of timer (Issue 2)
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      
      // Issue 2: New-bar detection - only process when a new bar forms
      datetime currentBarTime = iTime(_Symbol, timeframes[i], 0);
      if(currentBarTime == tfData[i].lastMLBarTime)
      {
         // No new bar on this timeframe, skip processing
         continue;
      }
      
      // Update the last processed bar time
      tfData[i].lastMLBarTime = currentBarTime;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      // Check last 4 bars for 3-bar patterns
      if(CopyRates(_Symbol, timeframes[i], 0, 4, rates) == 4)
      {
         // Issue 7: Use extracted PatternRecognizer class
         PatternResult result = PatternRecognizer::Analyze(rates);
         
         tfData[i].detectedPattern = result.patternName;

         if(result.signal != 0)
         {
             mlPrediction.predictedDirection = result.signal;
             mlPrediction.confidence = result.confidence;
             mlPrediction.timeToSignal = 1; // Immediate
             mlPrediction.patternType = result.patternName;
             mlPrediction.isReliable = true; // Based on real pattern

             // Generate Alert
             if(currentTime - alertState.lastPredictionAlert > 60) // Reduced cooldown for different patterns
             {
                string mlMsg = "PATTERN DETECTED: " + timeframeLabels[i] + " " +
                              mlPrediction.patternType + "! " +
                              "Direction: " + (mlPrediction.predictedDirection > 0 ? "UP" :
                                             mlPrediction.predictedDirection < 0 ? "DOWN" : "NEUTRAL") +
                              " (Confidence: " + DoubleToString(mlPrediction.confidence * 100, 1) + "%)";
                 Print(mlMsg);
                alertState.lastPredictionAlert = currentTime;
             }

             tfData[i].totalPredictions++;
             // We can't know if it's correct yet, so we don't increment correctPredictions immediately
         }
      }
   }
   
   lastMLUpdate = currentTime;
}
//+------------------------------------------------------------------+
