//+------------------------------------------------------------------+
//| Premium_Multi_TimeFrame.mq5                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.24"
// Updated 2026-05-16: Fixed MACD and Bollinger Band confirmation for bearish signals
// 1. Updated GetMACDConfirmation to handle both bullish and bearish directions
// 2. Updated GetBollingerBandPosition to handle both bullish and bearish directions
// 3. Updated CalculateSignalState to pass direction to confirmation functions
// 4. Fixed line 808 to check for both bullish and bearish directions
// Updated 2026-05-19: Fixed MTF Momentum Burst timeframe logic and optimized UI placement
// Updated 2026-06-03 (v1.24):
// 1. BUGFIX: Initialize atr/volume/macd/bb handles to INVALID_HANDLE for all timeframes
//    (prevents IndicatorRelease(0) on disabled timeframes in OnDeinit)
// 2. PERF: Avoid OnCalculate/OnTimer double-refresh when the refresh timer is active
// 3. FEATURE: Per-timeframe strong-signal alert cooldowns (was a single shared cooldown)
// 4. FEATURE: Trend-arrow glyphs (up/down/flat) added to each timeframe box label
// 5. FEATURE: Dashboard reflows on chart resize in auto-right mode (CHARTEVENT_CHART_CHANGE)
// 6. FEATURE: New panel row showing best scalping signal and multi-timeframe confluence
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
input group "Timeframe Display"
input bool Show_M1=true, Show_M5=true, Show_M15=true, Show_M30=true,
           Show_H1=true, Show_H4=true, Show_D1=true, Show_W1=true;

input group "Visual Settings"
input color UptrendColor    = C'46,204,113'; // Emerald
input color DowntrendColor  = C'231,76,60'; // Alizarin
input color NeutralColor    = C'149,165,166'; // Asbestos gray
input color StrongUptrendColor = C'39,174,96'; // Nephritis
input color StrongDowntrendColor = C'192,57,43'; // Pomegranate

input color ErrorColor      = clrDarkGray;
input color DisabledColor   = clrBlack;
input color PatternHighlightColor = clrGold;
input int BoxWidth          = 37;
input int BoxHeight         = 30;
input int HorizontalSpacing = 5;
input string DashboardTitle="MTF Trend Dashboard";
input int   TitleFontSize=12;
input color TitleColor=clrBlack;
input color BackgroundColor=clrDarkGray;
input int   DashboardX      = 525;         // Dashboard X Position (0 = Auto-Right)
input int   DashboardY      = 40;        // Dashboard Y Position

input group "Trend Settings"
input int SignalBar         = 1; // Use closed candle for reliability
input ENUM_MA_METHOD TrendMAMethod=MODE_EMA;
input int FastMAPeriod            = 5;   // Faster response for gold's volatility
input int SlowMAPeriod            = 13;  // Classic Fibonacci number for M15 scalping
input int RSIPeriod               = 14;   // Shorter period for quicker signals
input double RSIOverbought        = 70;  // Adjusted for gold's typical range
input double RSIOversold          = 30;  // Avoids false extremes in scalping
input int ADXPeriod               = 12;   // Reduced for faster trend detection
input double ADXThreshold         = 20;  // Higher threshold for stronger trends
input double StrongTrendThreshold = 0.0008; // Optimized for scalping sensitivity
input bool UseStrongSignalANDLogic=false; // EITHER strength OR ADX for faster entry signals
input double MinBodyToRangeRatio  = 0.35; // Filter: Body must be > 35% of total range to be 'Strong'

input group "Advanced Trend Confirmation"
input bool EnableMACDConfirmation = true;
input int MACDFastPeriod          = 5;   // Faster for scalping
input int MACDSlowPeriod          = 13;  // Fibonacci-based
input int MACDSignalPeriod        = 3;   // Quick signal line
input double MACDThreshold        = 0.0003; // Higher for gold (approx 30 pips)
input bool EnableBollingerBands   = true;
input int BBPeriod                = 20;  // Standard period for gold
input double BBDeviation          = 2.0; // Standard deviation for better breakout detection

input group "Market Session Integration"
input bool EnableMarketSessionFilter = true;
input bool HighlightAsiaSession      = true;
input bool HighlightLondonSession    = true;
input bool HighlightNewYorkSession   = true;
input bool HighlightSessionOverlap   = true;
input color AsiaSessionColor         = clrLightBlue;
input color LondonSessionColor       = clrDarkKhaki;
input color NewYorkSessionColor      = clrYellow;
input color SessionOverlapColor      = clrGold;

input group "Phase 3: Advanced Analytics"
input bool EnableTrendConsistencyScoring = true;
input bool EnableMomentumAnalysis        = true;
input bool EnableVolatilityAdjustment    = true;
input bool EnableHistoricalPerformanceTracking = true;
input int PerformanceLookbackBars        = 100;
input double ConsistencyWeight           = 0.6;
input double MomentumWeight              = 0.3;
input double VolatilityWeight            = 0.1;

input group "Phase 3: External Integrations"
input bool EnableTradingViewSync      = false;
input bool EnableEconomicCalendar     = false; // Disabled - high impact news alerts turned off
input bool EnableSentimentAnalysis    = true;
input bool EnableBrokerAPIIntegration = true;
input string TradingViewApiKey="";
input string NewsApiKey="";

input group "Phase 3: AI/ML Features"
input bool EnableAITrendPrediction    = true;
input bool EnableMLPatternRecognition = true;
input bool EnableNeuralNetworkSignals = true;
input int PredictionHorizonBars       = 5;
input double ConfidenceThreshold      = 0.75;
input bool EnableAdaptiveLearning     = true;

input group "Refresh & Alerts"
input bool OptimizeRefresh=true;
input int  RefreshSeconds=5; // High-speed refresh for scalping
input bool EnablePopupAlerts=false; // Alerts disabled
// Note: Only STRONG BUY/SELL alerts are shown (based on ADX + Strength threshold)
input int  AlignmentThreshold=4; // Number of timeframes needed for alignment alert

input group "Scalping Features"
input bool EnableScalpingMode=true; // Enabled by default for scalping setup
input int  ScalpingTimeframes=2; // Number of lowest timeframes to focus on (2 = M1, M5)
input double ScalpingMinConfidence=0.65; // Minimum confidence for scalping signals
input bool EnableSpreadFilter=true; // Avoid high spread periods
input double MaxSpreadPoints=300; // Realistic spread limit for Gold/Majors
input bool EnableVolumeConfirmation=true; // Require volume spike for entries
input double VolumeSpikeMultiplier=1.5; // Volume must be X times average
input bool EnableMomentumBurstDetection=true; // Detect sudden momentum shifts
input int  MomentumBurstBars=5; // Bars to look back for momentum burst
input double MomentumBurstThreshold=0.0005; // More sensitive burst detection

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

   // Phase 3: Advanced Analytics
   double consistencyScore;    // Trend consistency across timeframes
   double momentumScore;       // Momentum acceleration/deceleration
   double volatilityScore;      // Volatility-adjusted signal strength
   double overallScore;         // Combined analytics score
   double historicalAccuracy;   // Past signal performance
   int    correctPredictions;   // Count of correct predictions
   int    totalPredictions;     // Total predictions made
   datetime lastBarTime;        // For performance tracking

   // Scalping-specific fields
   bool   volumeSpike;         // Volume spike detected
   double volumeRatio;          // Current volume vs average
   bool   momentumBurst;       // Sudden momentum shift
   double momentumStrength;     // Burst strength
   datetime lastBurstTime;      // Last momentum burst time
   bool   scalpingSignal;      // High-confidence scalping entry
   double scalpingConfidence;   // Signal confidence 0-1
   datetime lastStrongSignalAlert; // Per-timeframe strong-signal alert cooldown
};

struct AlertState
{
   datetime lastStrongSignalAlert; // Only alert for strong buy/sell signals

   // Phase 3: Enhanced alerts
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

// Signal processing result structure - decouples calculation from UI
struct SignalState
{
   bool   isValid;            // True if all indicator data was retrieved successfully
   int    direction;          // 1=Bullish, -1=Bearish, 0=Neutral
   double strength;           // Trend strength value
   bool   isStrong;           // True if meets strong signal criteria
   double fastMA;             // Fast MA value
   double slowMA;             // Slow MA value
   double rsi;                // RSI value
   double adx;                // ADX value
   double atr;                // ATR value
   bool   macdConfirmed;        // MACD confirmation state
   bool   bbConfirmed;          // Bollinger Band confirmation state
   bool   wickFilterPassed;     // True if candle body is significant
   color  displayColor;         // Calculated color for UI
   string alertMessage;         // Alert message if strong signal
   bool   shouldAlert;          // Whether to trigger alert
};

TimeframeData tfData[NUM_TIMEFRAMES];
int StartX, StartY, BackgroundWidth, BackgroundHeight;
datetime lastRefresh=0;
bool g_timerActive=false; // True when refresh timer is running (avoids OnCalculate double-refresh)

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
datetime lastSessionAlert = 0; // Track last session alert to prevent spam

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
    lastSessionAlert = 0; // Initialize session alert tracking

   // Initialize Phase 3 features
   InitializeAdvancedAnalytics();
   InitializeExternalIntegrations();
   InitializeMLFeatures();
   
   bool show[]={Show_M1,Show_M5,Show_M15,Show_M30,Show_H1,Show_H4,Show_D1,Show_W1};
   int successCount = 0;
   
   for(int i=0;i<NUM_TIMEFRAMES;i++)
   {
      tfData[i].enabled=show[i];
      tfData[i].available=false;
      tfData[i].fastHandle=tfData[i].slowHandle=tfData[i].rsiHandle=tfData[i].adxHandle=INVALID_HANDLE;
      tfData[i].atrHandle=tfData[i].volumeHandle=tfData[i].macdHandle=tfData[i].bbHandle=INVALID_HANDLE;
      tfData[i].lastStrongSignalAlert=0;
      tfData[i].lastColor=NeutralColor;
       tfData[i].boxName=dashboardPrefix+timeframeLabels[i]+"_Box";
       tfData[i].labelName=dashboardPrefix+timeframeLabels[i]+"_Label";
      tfData[i].detectedPattern = "";

      if(tfData[i].enabled)
      {
         tfData[i].fastHandle=iMA(_Symbol,timeframes[i],FastMAPeriod,0,TrendMAMethod,PRICE_CLOSE);
         tfData[i].slowHandle=iMA(_Symbol,timeframes[i],SlowMAPeriod,0,TrendMAMethod,PRICE_CLOSE);
         tfData[i].rsiHandle=iRSI(_Symbol,timeframes[i],RSIPeriod,PRICE_CLOSE);
         tfData[i].adxHandle=iADX(_Symbol,timeframes[i],ADXPeriod);
         tfData[i].atrHandle=iATR(_Symbol,timeframes[i],14); // ATR for volatility analysis
         tfData[i].volumeHandle=iVolumes(_Symbol,timeframes[i],VOLUME_TICK); // Volume for confirmation

         // Advanced trend confirmation indicators
         if(EnableMACDConfirmation)
            tfData[i].macdHandle=iMACD(_Symbol,timeframes[i],MACDFastPeriod,MACDSlowPeriod,MACDSignalPeriod,PRICE_CLOSE);
         else
            tfData[i].macdHandle=INVALID_HANDLE;

         if(EnableBollingerBands)
            tfData[i].bbHandle=iBands(_Symbol,timeframes[i],BBPeriod,0,BBDeviation,PRICE_CLOSE);
         else
            tfData[i].bbHandle=INVALID_HANDLE;

         tfData[i].lastTrendDirection = 0;
         tfData[i].lastVolatility = 0;
         tfData[i].macdBullish = false;
         tfData[i].priceAboveBB = false;
         tfData[i].volumeSpike = false;
         tfData[i].volumeRatio = 0.0;
         tfData[i].momentumBurst = false;
         tfData[i].momentumStrength = 0.0;
         tfData[i].lastBurstTime = 0;
         tfData[i].scalpingSignal = false;
         tfData[i].scalpingConfidence = 0.0;
         
         // Initialize Phase 3 analytics
         tfData[i].consistencyScore = 0.0;
         tfData[i].momentumScore = 0.0;
         tfData[i].volatilityScore = 0.0;
         tfData[i].overallScore = 0.0;
         tfData[i].historicalAccuracy = 0.0;
         tfData[i].correctPredictions = 0;
         tfData[i].totalPredictions = 0;
         tfData[i].lastBarTime = 0;
         
         if(tfData[i].fastHandle!=INVALID_HANDLE && tfData[i].slowHandle!=INVALID_HANDLE &&
            tfData[i].rsiHandle!=INVALID_HANDLE && tfData[i].adxHandle!=INVALID_HANDLE &&
            tfData[i].atrHandle!=INVALID_HANDLE && tfData[i].volumeHandle!=INVALID_HANDLE &&
            (!EnableMACDConfirmation || tfData[i].macdHandle!=INVALID_HANDLE) &&
            (!EnableBollingerBands || tfData[i].bbHandle!=INVALID_HANDLE))
         {
            tfData[i].available=true;
            successCount++;
         }
         else
         {
            Print("ERROR: Failed to create indicators for timeframe ", timeframeLabels[i]);
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
      if(EventSetTimer(RefreshSeconds))
         g_timerActive = true;
      else
         Print("WARNING: Failed to set timer, using OnCalculate refresh only");
   }
   
   Print("MTF Dashboard initialized with ", successCount, " of ", NUM_TIMEFRAMES, " timeframes");
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
   }
   
   // Delete all chart objects created by this indicator using prefix
   ObjectsDeleteAll(0, dashboardPrefix);
   
   // Disable mouse move events
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);

   EventKillTimer();
   g_timerActive = false;
   Print("MTF Dashboard deinitialized - Reason: ", reason);
}
//+------------------------------------------------------------------+
void CalcPositions()
{
   int count=0;
   for(int i=0;i<NUM_TIMEFRAMES;i++) if(tfData[i].enabled) count++;
   BackgroundWidth=count*(BoxWidth+HorizontalSpacing)-HorizontalSpacing+20;
   BackgroundHeight=BoxHeight+150; // Expanded for four-row analytics/scalping panel




   long chartW=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   long chartH=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   
   // Use manual position if X > 0, otherwise default to right-side auto placement
   if(DashboardX > 0)
   {
      StartX = DashboardX;
   }
   else
   {
      int minMargin = 50;
      int maxStartX = (int)(chartW - BackgroundWidth - minMargin);
      StartX = MathMax(minMargin, MathMin(maxStartX, (int)(chartW - BackgroundWidth - 20)));
   }
   
   // Use manual Y position with safety bounds
   int minMarginY = 20;
   int maxStartY = (int)(chartH - BackgroundHeight - minMarginY);
   StartY = MathMax(minMarginY, MathMin(maxStartY, DashboardY));
   
   if(StartX < 20 || StartY < 20)
   {
      Print("WARNING: Dashboard may not fit properly on current chart size");
   }
}
//+------------------------------------------------------------------+
void CreateObjects()
{
   // Update market sessions before creating objects
   UpdateMarketSessions();
   
   // Background
   CreateOrUpdateRectLabel(dashboardPrefix+"BG", StartX-10, StartY-30, BackgroundWidth, BackgroundHeight, GetSessionBasedColor(), BORDER_FLAT, CORNER_LEFT_UPPER);
   
   // Title
   CreateOrUpdateLabel(dashboardPrefix+"Title", StartX+BackgroundWidth/2, StartY-15, DashboardTitle, TitleColor, TitleFontSize, ANCHOR_CENTER);
  
    int idx=0;
    for(int i=0;i<NUM_TIMEFRAMES;i++)
    {
       if(!tfData[i].enabled) continue;
       int x=StartX+idx*(BoxWidth+HorizontalSpacing);

       // Timeframe Box
       CreateOrUpdateRectLabel(tfData[i].boxName, x, StartY, BoxWidth, BoxHeight, tfData[i].available?NeutralColor:DisabledColor, BORDER_SUNKEN, CORNER_LEFT_UPPER);

       // Timeframe Label (e.g., "M1", "M5")
       string timeframeText = timeframeLabels[i];
       CreateOrUpdateLabel(tfData[i].labelName, x+BoxWidth/2, StartY+BoxHeight/2, timeframeText, clrWhite, 8, ANCHOR_CENTER);

       idx++;
    }

   // Analytics Panel
   int panelY = StartY + BoxHeight + 12;
   CreateOrUpdateRectLabel(dashboardPrefix+"PanelBG", StartX, panelY, BackgroundWidth-25, 102, C'35,35,35', BORDER_SUNKEN, CORNER_LEFT_UPPER);
   
   // Row 1: General Trend
   CreateOrUpdateLabel(dashboardPrefix+"BiasLabel", StartX+10, panelY+8, "Global Bias: Neutral", clrWhite, 9, ANCHOR_LEFT_UPPER);
   CreateOrUpdateLabel(dashboardPrefix+"ScoreLabel", StartX+BackgroundWidth-30, panelY+8, "Score: 0%", clrWhite, 9, ANCHOR_RIGHT_UPPER);
   
   // Row 2: AI/ML Patterns
   CreateOrUpdateLabel(dashboardPrefix+"PatternLabel", StartX+10, panelY+30, "AI Pattern: None", clrSilver, 9, ANCHOR_LEFT_UPPER);
   CreateOrUpdateLabel(dashboardPrefix+"ConfidenceLabel", StartX+BackgroundWidth-30, panelY+30, "AI Conf: 0%", clrSilver, 9, ANCHOR_RIGHT_UPPER);
   
   // Row 3: Sentiment & Time
   CreateOrUpdateLabel(dashboardPrefix+"SentimentLabel", StartX+10, panelY+52, "Sentiment: Neutral", clrSilver, 8, ANCHOR_LEFT_UPPER);
   CreateOrUpdateLabel(dashboardPrefix+"TimeLabel", StartX+BackgroundWidth-30, panelY+52, "Updated: 00:00:00", clrSilver, 8, ANCHOR_RIGHT_UPPER);

   // Row 4: Scalping signal & multi-timeframe confluence
   CreateOrUpdateLabel(dashboardPrefix+"ScalpLabel", StartX+10, panelY+74, "Scalp: --", clrSilver, 8, ANCHOR_LEFT_UPPER);
   CreateOrUpdateLabel(dashboardPrefix+"ConfluenceLabel", StartX+BackgroundWidth-30, panelY+74, "Confluence: 0/0", clrSilver, 8, ANCHOR_RIGHT_UPPER);
}

//+------------------------------------------------------------------+
//| Helper to create or update rectangle labels                      |
//+------------------------------------------------------------------+
void CreateOrUpdateRectLabel(string name, int x, int y, int w, int h, color bg, ENUM_BORDER_TYPE border, ENUM_BASE_CORNER corner)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, border);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper to create or update labels                                |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, int x, int y, string text, color clr, int fontSize, ENUM_ANCHOR_POINT anchor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Optimized dashboard movement during drag                         |
//+------------------------------------------------------------------+
void UpdateDashboardPosition()
{
   ObjectSetInteger(0, dashboardPrefix+"BG", OBJPROP_XDISTANCE, StartX-10);
   ObjectSetInteger(0, dashboardPrefix+"BG", OBJPROP_YDISTANCE, StartY-30);
   
   ObjectSetInteger(0, dashboardPrefix+"Title", OBJPROP_XDISTANCE, StartX+BackgroundWidth/2);
   ObjectSetInteger(0, dashboardPrefix+"Title", OBJPROP_YDISTANCE, StartY-15);
   
   int idx=0;
   for(int i=0; i<NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled) continue;
      int x = StartX + idx * (BoxWidth + HorizontalSpacing);
      
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_YDISTANCE, StartY);
      
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_XDISTANCE, x + BoxWidth/2);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_YDISTANCE, StartY + BoxHeight/2);
      
      idx++;
   }
   
   // Update Analytics Panel position
   int panelY = StartY + BoxHeight + 12;
   ObjectSetInteger(0, dashboardPrefix+"PanelBG", OBJPROP_XDISTANCE, StartX);
   ObjectSetInteger(0, dashboardPrefix+"PanelBG", OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, dashboardPrefix+"PanelBG", OBJPROP_YSIZE, 102);
   
   // Row 1
   ObjectSetInteger(0, dashboardPrefix+"BiasLabel", OBJPROP_XDISTANCE, StartX+10);
   ObjectSetInteger(0, dashboardPrefix+"BiasLabel", OBJPROP_YDISTANCE, panelY+8);
   ObjectSetInteger(0, dashboardPrefix+"ScoreLabel", OBJPROP_XDISTANCE, StartX+BackgroundWidth-30);
   ObjectSetInteger(0, dashboardPrefix+"ScoreLabel", OBJPROP_YDISTANCE, panelY+8);
   
   // Row 2
   ObjectSetInteger(0, dashboardPrefix+"PatternLabel", OBJPROP_XDISTANCE, StartX+10);
   ObjectSetInteger(0, dashboardPrefix+"PatternLabel", OBJPROP_YDISTANCE, panelY+30);
   ObjectSetInteger(0, dashboardPrefix+"ConfidenceLabel", OBJPROP_XDISTANCE, StartX+BackgroundWidth-30);
   ObjectSetInteger(0, dashboardPrefix+"ConfidenceLabel", OBJPROP_YDISTANCE, panelY+30);
   
   // Row 3
   ObjectSetInteger(0, dashboardPrefix+"SentimentLabel", OBJPROP_XDISTANCE, StartX+10);
   ObjectSetInteger(0, dashboardPrefix+"SentimentLabel", OBJPROP_YDISTANCE, panelY+52);
   ObjectSetInteger(0, dashboardPrefix+"TimeLabel", OBJPROP_XDISTANCE, StartX+BackgroundWidth-30);
   ObjectSetInteger(0, dashboardPrefix+"TimeLabel", OBJPROP_YDISTANCE, panelY+52);

   // Row 4
   ObjectSetInteger(0, dashboardPrefix+"ScalpLabel", OBJPROP_XDISTANCE, StartX+10);
   ObjectSetInteger(0, dashboardPrefix+"ScalpLabel", OBJPROP_YDISTANCE, panelY+74);
   ObjectSetInteger(0, dashboardPrefix+"ConfluenceLabel", OBJPROP_XDISTANCE, StartX+BackgroundWidth-30);
   ObjectSetInteger(0, dashboardPrefix+"ConfluenceLabel", OBJPROP_YDISTANCE, panelY+74);
}


//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime& time[],const double& open[],const double& high[],
                const double& low[],const double& close[],const long& tick_volume[],
                const long& volume[],const int& spread[])
{
   // Always refresh on first calculation. Afterwards, if the refresh timer is
   // active, let OnTimer drive updates to avoid doing the work twice per cycle.
   if(prev_calculated == 0)
      UpdateAll();
   else if(!g_timerActive && TimeCurrent()-lastRefresh>=RefreshSeconds)
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
   // Guard: Ensure terminal is connected and data is synchronized
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !SeriesInfoInteger(_Symbol, _Period, SERIES_SYNCHRONIZED))
      return;

   // Update market sessions
   UpdateMarketSessions();
   
   // Update dashboard background color based on session
   ObjectSetInteger(0,dashboardPrefix+"BG",OBJPROP_BGCOLOR,GetSessionBasedColor());
   
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
   
   // Update Analytics UI
   string biasIcon = (currentMetrics.overallScore > 60 ? "▲ " : (currentMetrics.overallScore < 40 ? "▼ " : "● "));
   string biasText = "Global Bias: " + biasIcon + (currentMetrics.overallScore > 60 ? "Bullish" : (currentMetrics.overallScore < 40 ? "Bearish" : "Neutral"));
   color biasColor = (currentMetrics.overallScore > 60 ? clrLime : (currentMetrics.overallScore < 40 ? clrOrangeRed : clrWhite));

   
   ObjectSetString(0, dashboardPrefix+"BiasLabel", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, dashboardPrefix+"BiasLabel", OBJPROP_COLOR, biasColor);
   
   ObjectSetString(0, dashboardPrefix+"ScoreLabel", OBJPROP_TEXT, "Score: " + DoubleToString(currentMetrics.overallScore, 1) + "%");
   
   // Update ML Pattern UI
   string patternText = "AI Pattern: " + (mlPrediction.patternType == "" ? "None" : mlPrediction.patternType);
   color patternColor = (mlPrediction.predictedDirection > 0 ? clrLime : (mlPrediction.predictedDirection < 0 ? clrOrangeRed : clrSilver));
   ObjectSetString(0, dashboardPrefix+"PatternLabel", OBJPROP_TEXT, patternText);
   ObjectSetInteger(0, dashboardPrefix+"PatternLabel", OBJPROP_COLOR, patternColor);
   
   ObjectSetString(0, dashboardPrefix+"ConfidenceLabel", OBJPROP_TEXT, "AI Conf: " + DoubleToString(mlPrediction.confidence * 100, 1) + "%");
   
    // Update Sentiment UI
    string sentText = "Sentiment: " + (externalData.sentimentScore > 0.2 ? "Bullish" : (externalData.sentimentScore < -0.2 ? "Bearish" : "Neutral"));
    color sentColor = (externalData.sentimentScore > 0.2 ? clrMediumSpringGreen : (externalData.sentimentScore < -0.2 ? clrTomato : clrSilver));
    ObjectSetString(0, dashboardPrefix+"SentimentLabel", OBJPROP_TEXT, sentText + " (" + DoubleToString(externalData.sentimentScore, 2) + ")");
    ObjectSetInteger(0, dashboardPrefix+"SentimentLabel", OBJPROP_COLOR, sentColor);

    // Update timestamp with more detail
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    string timeStr = StringFormat("Updated: %02d:%02d:%02d", dt.hour, dt.min, dt.sec);
    ObjectSetString(0, dashboardPrefix+"TimeLabel", OBJPROP_TEXT, timeStr);

    // Update Scalping & Confluence UI (Row 4)
    UpdateScalpingAndConfluenceUI();

    lastRefresh=TimeCurrent();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Row 4: best scalping signal + multi-timeframe confluence  |
//+------------------------------------------------------------------+
void UpdateScalpingAndConfluenceUI()
{
   // --- Best scalping signal among the configured scalping timeframes ---
   double bestConf = 0.0;
   int    bestTF   = -1;
   bool   anyBurst = false;
   for(int i = 0; i < NUM_TIMEFRAMES && i < ScalpingTimeframes; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      if(tfData[i].scalpingConfidence > bestConf)
      {
         bestConf = tfData[i].scalpingConfidence;
         bestTF   = i;
      }
      if(tfData[i].momentumBurst) anyBurst = true;
   }

   string scalpText;
   color  scalpColor = clrSilver;
   if(bestTF >= 0 && bestConf > 0.0)
   {
      int dir = tfData[bestTF].lastTrendDirection;
      string dirStr = (dir > 0 ? "BUY" : (dir < 0 ? "SELL" : "FLAT"));
      scalpText = StringFormat("Scalp: %s %s %.0f%%%s",
                               timeframeLabels[bestTF], dirStr, bestConf * 100.0,
                               (anyBurst ? " [BURST]" : ""));
      if(tfData[bestTF].scalpingSignal)
         scalpColor = (dir > 0 ? clrLime : (dir < 0 ? clrOrangeRed : clrSilver));
   }
   else
   {
      scalpText = "Scalp: --";
   }
   ObjectSetString(0, dashboardPrefix+"ScalpLabel", OBJPROP_TEXT, scalpText);
   ObjectSetInteger(0, dashboardPrefix+"ScalpLabel", OBJPROP_COLOR, scalpColor);

   // --- Multi-timeframe confluence (aligned timeframes / active timeframes) ---
   int up = 0, down = 0, active = 0;
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      active++;
      if(tfData[i].lastTrendDirection == 1) up++;
      else if(tfData[i].lastTrendDirection == -1) down++;
   }
   int aligned = MathMax(up, down);
   string arrow = (up > down ? "▲" : (down > up ? "▼" : "●"));
   color confColor = (up > down ? clrLime : (down > up ? clrOrangeRed : clrSilver));
   ObjectSetString(0, dashboardPrefix+"ConfluenceLabel", OBJPROP_TEXT,
                   StringFormat("Confluence: %d/%d %s", aligned, active, arrow));
   ObjectSetInteger(0, dashboardPrefix+"ConfluenceLabel", OBJPROP_COLOR, confColor);
}

//+------------------------------------------------------------------+
// Data Processing Layer: Calculate signal state independently of UI
// This function encapsulates all calculation logic, allowing unit testing
//+------------------------------------------------------------------+
SignalState CalculateSignalState(int i)
{
   SignalState state;
   double buf[1];
   
   // Initialize state
   state.isValid = false;
   state.direction = 0;
   state.strength = 0;
   state.isStrong = false;
   state.fastMA = 0;
   state.slowMA = 0;
   state.rsi = 0;
   state.adx = 0;
   state.atr = 0;
   state.macdConfirmed = false;
   state.bbConfirmed = false;
   state.wickFilterPassed = true;
   state.displayColor = ErrorColor;
   state.alertMessage = "";
   state.shouldAlert = false;
   
   // Validate indicator handles before copying data
   if(tfData[i].fastHandle == INVALID_HANDLE || tfData[i].slowHandle == INVALID_HANDLE ||
      tfData[i].rsiHandle == INVALID_HANDLE || tfData[i].adxHandle == INVALID_HANDLE ||
      tfData[i].atrHandle == INVALID_HANDLE || tfData[i].volumeHandle == INVALID_HANDLE)
   {
      return state; // Return invalid state - UI will handle error display
   }
   
   // Scalping mode: Check spread filter
   if(EnableScalpingMode && EnableSpreadFilter)
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > MaxSpreadPoints)
      {
         state.displayColor = clrOrange; // High spread warning color
         state.alertMessage = "WARNING: High spread (" + IntegerToString(spread) + " points) - Avoid scalping!";
         return state;
      }
   }
   
   // Use SignalBar for data retrieval
   if(CopyBuffer(tfData[i].fastHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return state;
   state.fastMA = buf[0];
   
   if(CopyBuffer(tfData[i].slowHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return state;
   state.slowMA = buf[0];
   
   if(CopyBuffer(tfData[i].rsiHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return state;
   state.rsi = buf[0];
   
   if(CopyBuffer(tfData[i].adxHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return state;
   state.adx = buf[0];
   
   if(CopyBuffer(tfData[i].atrHandle,0,SignalBar,1,buf)<=0 || buf[0]==EMPTY_VALUE)
      return state;
   state.atr = buf[0];
   
   // Prevent division by zero
   if(state.slowMA == 0)
      return state;
   
   // Scalping Enhancement: Body-to-Wick Ratio Filter
   MqlRates rates[1];
   if(CopyRates(_Symbol, timeframes[i], SignalBar, 1, rates) == 1)
   {
      double totalRange = rates[0].high - rates[0].low;
      double bodySize = MathAbs(rates[0].open - rates[0].close);
      
      if(totalRange > 0)
      {
         double ratio = bodySize / totalRange;
         if(ratio < MinBodyToRangeRatio)
            state.wickFilterPassed = false;
      }
   }

   // Calculate trend direction and strength
   state.direction = (state.fastMA > state.slowMA) ? 1 : (state.fastMA < state.slowMA) ? -1 : 0;
   state.strength = MathAbs((state.fastMA - state.slowMA) / state.slowMA);
   
   // Determine if signal is strong based on logic preference
   // Apply Wick Filter: If candle is too 'spiky' (long wicks), it cannot be a strong signal
   bool baseStrong = UseStrongSignalANDLogic ? 
                    (state.strength > StrongTrendThreshold && state.adx > ADXThreshold) :
                    (state.strength > StrongTrendThreshold || state.adx > ADXThreshold);
   
   state.isStrong = baseStrong && state.wickFilterPassed;
   
   // Apply MACD confirmation filter
   state.macdConfirmed = GetMACDConfirmation(i, state.direction);
   
   // Apply Bollinger Band confirmation filter
   state.bbConfirmed = GetBollingerBandPosition(i, state.direction);
   
   // Require confirmation for strong signals when filters are enabled
   if(state.isStrong)
   {
      if(EnableMACDConfirmation && !state.macdConfirmed)
         state.isStrong = false;
      if(EnableBollingerBands && !state.bbConfirmed && state.direction != 0)
         state.isStrong = false;
   }
   
   // Determine display color based on direction and strength
   state.displayColor = (state.direction > 0) ? 
                        (state.isStrong ? StrongUptrendColor : UptrendColor) :
                        (state.direction < 0) ? 
                        (state.isStrong ? StrongDowntrendColor : DowntrendColor) : 
                        NeutralColor;
   
   // Prepare alert if conditions met
   datetime currentTime = TimeCurrent();
   if(state.isStrong && state.direction != 0 && currentTime - tfData[i].lastStrongSignalAlert > 300)
   {
      state.shouldAlert = true;
      state.alertMessage = "★★★ STRONG SIGNAL ★★★ " + timeframeLabels[i] + " " +
                          (state.direction > 0 ? "STRONG BUY" : "STRONG SELL") +
                          " | ADX: " + DoubleToString(state.adx, 1) + 
                          " | Strength: " + DoubleToString(state.strength * 100, 1) + "%" +
                          " | RSI: " + DoubleToString(state.rsi, 1);
   }
   
   state.isValid = true;
   return state;
}

//+------------------------------------------------------------------+
// UI Update Layer: Purely handles rendering based on calculated state
//+------------------------------------------------------------------+
void UpdateBox(int i)
{
   // Get calculated signal state from data processing layer
   SignalState state = CalculateSignalState(i);
   
   // Handle high spread warning (special case)
   if(EnableScalpingMode && EnableSpreadFilter && state.displayColor == clrOrange)
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, clrOrange);
      if(TimeCurrent() - alertState.lastScalpingAlert > 300)
      {
         ShowAlert(state.alertMessage);
         alertState.lastScalpingAlert = TimeCurrent();
      }
      return;
   }
   
   // Handle invalid state (error)
   if(!state.isValid)
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, ErrorColor);
      return;
   }
   
   // Update tracking variables from state
   tfData[i].lastTrendDirection = state.direction;
   tfData[i].lastVolatility = state.atr;
   tfData[i].macdBullish = state.macdConfirmed;
   tfData[i].priceAboveBB = state.bbConfirmed;
   
   // Trigger alert if needed (per-timeframe cooldown)
   if(state.shouldAlert)
   {
      ShowAlert(state.alertMessage);
      tfData[i].lastStrongSignalAlert = TimeCurrent();
   }

   // Scalping features: Volume analysis
   if(EnableVolumeConfirmation || EnableScalpingMode)
   {
      AnalyzeVolume(i);
   }

   // Scalping features: Momentum burst detection
   if(EnableMomentumBurstDetection || EnableScalpingMode)
   {
      DetectMomentumBurst(i);
   }

   // Calculate scalping signal confidence
   if(EnableScalpingMode && i < ScalpingTimeframes)
   {
      CalculateScalpingSignal(i, state.direction, state.strength, state.adx);
   }

    // Update UI elements with calculated color
    ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, state.displayColor);

    if(tfData[i].detectedPattern != "")
    {
        ObjectSetInteger(0, tfData[i].boxName, OBJPROP_COLOR, PatternHighlightColor);
    }
    else
    {
        ObjectSetInteger(0, tfData[i].boxName, OBJPROP_COLOR, state.displayColor);
    }

    // Trend-arrow glyph in the timeframe label (▲ up, ▼ down, ● neutral)
    string arrow = (state.direction > 0 ? "▲" : (state.direction < 0 ? "▼" : "●"));
    ObjectSetString(0, tfData[i].labelName, OBJPROP_TEXT, timeframeLabels[i] + " " + arrow);

    tfData[i].lastColor = state.displayColor;
}

//+------------------------------------------------------------------+
void CheckMultiTimeframeAlignment()
{
   // Multi-timeframe alignment check (no alerts - for visual reference only)
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
      ObjectSetInteger(0,dashboardPrefix+"Title",OBJPROP_COLOR,StrongUptrendColor);
   }
   else if(downtrendCount >= AlignmentThreshold)
   {
      ObjectSetInteger(0,dashboardPrefix+"Title",OBJPROP_COLOR,StrongDowntrendColor);
   }
   else
   {
      ObjectSetInteger(0,dashboardPrefix+"Title",OBJPROP_COLOR,TitleColor);
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   // Reflow the dashboard when the chart is resized (only meaningful in
   // auto-right mode where DashboardX <= 0). Skip while the user is dragging.
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(!isDragging && DashboardX <= 0)
      {
         CalcPositions();
         UpdateDashboardPosition();
         ChartRedraw();
      }
      return;
   }

   // Handle chart events for interactive features
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle object clicks
      if(sparam == dashboardPrefix+"BG")
      {
         isDragging = true;
         // Store start position; actual offset will be set on first mouse move
         dragOffsetX = 0;
         dragOffsetY = 0;
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
         // Check if left mouse button is pressed (bit 0 of sparam)
         if(((int)StringToInteger(sparam) & 1) != 0)
         {
            // On first move, calculate offset from current mouse pos to dashboard origin
            if(dragOffsetX == 0 && dragOffsetY == 0)
            {
               dragOffsetX = (int)lparam - StartX;
               dragOffsetY = (int)dparam - StartY;
            }

            int newX = (int)lparam - dragOffsetX;
            int newY = (int)dparam - dragOffsetY;

            // Boundary checks to keep dashboard on screen
            long chartW = ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
            long chartH = ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);

            // Allow some margin but prevent losing it completely
            newX = MathMax(-BackgroundWidth + 20, MathMin(newX, (int)chartW - 20));
            newY = MathMax(-BackgroundHeight + 20, MathMin(newY, (int)chartH - 20));

            // Update dashboard position
            StartX = newX;
            StartY = newY;
            
            // Optimized update: only change positions, don't recreate objects
            UpdateDashboardPosition();
            ChartRedraw();
         }
         else
         {
            // Mouse button released
            isDragging = false;
            dragOffsetX = 0;
            dragOffsetY = 0;
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
         }
      }
   }
   else if(id == CHARTEVENT_CLICK)
   {
      // Fallback to stop dragging
      if(isDragging)
      {
         isDragging = false;
         dragOffsetX = 0;
         dragOffsetY = 0;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true); // Re-enable chart scrolling
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

    datetime currentTime = TimeCurrent();
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

       // Alert on session change (throttled to prevent spam)
       if(sessions[i].isActive && !wasActive && currentTime - lastSessionAlert > 60)
       {
          Print(sessions[i].name, " session started at ", TimeToString(currentTime));
          lastSessionAlert = currentTime;
       }
       else if(!sessions[i].isActive && wasActive && currentTime - lastSessionAlert > 60)
       {
          Print(sessions[i].name, " session ended at ", TimeToString(currentTime));
          lastSessionAlert = currentTime;
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
   if(!EnableMACDConfirmation || tfData[i].macdHandle == INVALID_HANDLE)
      return true; // No confirmation needed if disabled
   
   double macdMain[1], macdSignal[1];
   
   if(CopyBuffer(tfData[i].macdHandle, 0, SignalBar, 1, macdMain) <= 0 ||
      CopyBuffer(tfData[i].macdHandle, 1, SignalBar, 1, macdSignal) <= 0)
      return false;
   
   if(direction > 0) // Bullish
      return macdMain[0] > macdSignal[0] && macdMain[0] > MACDThreshold;
   else if(direction < 0) // Bearish
      return macdMain[0] < macdSignal[0] && macdMain[0] < -MACDThreshold;
   else // Neutral
      return true;
}

//+------------------------------------------------------------------+
bool GetBollingerBandPosition(int i, int direction)
{
    if(!EnableBollingerBands || tfData[i].bbHandle == INVALID_HANDLE)
       return true; // No confirmation needed if disabled

    double bbUpper[1], bbMiddle[1], bbLower[1], currentPrice;

    if(CopyBuffer(tfData[i].bbHandle, 1, SignalBar, 1, bbUpper) <= 0 ||
       CopyBuffer(tfData[i].bbHandle, 0, SignalBar, 1, bbMiddle) <= 0 ||
       CopyBuffer(tfData[i].bbHandle, 2, SignalBar, 1, bbLower) <= 0)
       return false;

    // For price, if SignalBar=0 we use current Bid, if 1+ we use Close of bar SignalBar
    if(SignalBar == 0)
       currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    else
    {
       double closePrice[1];
       if(CopyClose(_Symbol, timeframes[i], SignalBar, 1, closePrice) > 0)
          currentPrice = closePrice[0];
       else
          return false;
    }

    // Price confirmation: bullish when above middle band, bearish when below middle band
    if(direction > 0)
       return currentPrice > bbMiddle[0];
    else if(direction < 0)
       return currentPrice < bbMiddle[0];
    else
       return true;
}

//+------------------------------------------------------------------+
// Scalping Features: Volume Analysis
//+------------------------------------------------------------------+
void AnalyzeVolume(int tfIndex)
{
   double volumeCurrent[], volumeAvg[];
   ArraySetAsSeries(volumeCurrent, true);
   ArraySetAsSeries(volumeAvg, true);

   // Get current volume
   if(CopyBuffer(tfData[tfIndex].volumeHandle, 0, SignalBar, 1, volumeCurrent) <= 0)
      return;

   // Get average volume (last 20 bars)
   if(CopyBuffer(tfData[tfIndex].volumeHandle, 0, SignalBar + 1, 20, volumeAvg) <= 0)
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
             ShowAlert(volMsg);
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
   double priceChange = 0;
   double burstStrength = 0;
   
   double closePrices[];
   ArraySetAsSeries(closePrices, true);

   // Copy prices for the specific timeframe to fix MTF logic bug
   if(CopyClose(_Symbol, timeframes[tfIndex], SignalBar, MomentumBurstBars + 1, closePrices) < MomentumBurstBars + 1)
   {
      tfData[tfIndex].momentumBurst = false;
      tfData[tfIndex].momentumStrength = 0;
      return;
   }

   if(closePrices[MomentumBurstBars] == 0)
   {
      tfData[tfIndex].momentumBurst = false;
      tfData[tfIndex].momentumStrength = 0;
      return;
   }

   priceChange = MathAbs(closePrices[0] - closePrices[MomentumBurstBars]) / closePrices[MomentumBurstBars];
      
      // Check if price change exceeds threshold
      if(priceChange >= MomentumBurstThreshold)
      {
         burstStrength = priceChange / MomentumBurstThreshold;
         
         // Determine direction
         int direction = (closePrices[0] > closePrices[MomentumBurstBars]) ? 1 : -1;
         
         tfData[tfIndex].momentumBurst = true;
         tfData[tfIndex].momentumStrength = burstStrength;
         tfData[tfIndex].lastBurstTime = TimeCurrent();
         
          // Alert for momentum burst
          if(TimeCurrent() - alertState.lastMomentumBurstAlert > 180) // 3 min cooldown
          {
             string burstMsg = timeframeLabels[tfIndex] + " MOMENTUM BURST! " +
                              (direction > 0 ? "UP" : "DOWN") + 
                              " (Strength: " + DoubleToString(burstStrength, 2) + "x)";
             ShowAlert(burstMsg);
             alertState.lastMomentumBurstAlert = TimeCurrent();
          }
      }
      else
      {
         tfData[tfIndex].momentumBurst = false;
         tfData[tfIndex].momentumStrength = 0;
      }
}

//+------------------------------------------------------------------+
// Scalping Features: Calculate Scalping Signal Confidence
//+------------------------------------------------------------------+
void CalculateScalpingSignal(int tfIndex, int trendDir, double trendStrength, double adx)
{
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
      if(tfData[tfIndex].scalpingConfidence >= ScalpingMinConfidence)
      {
         tfData[tfIndex].scalpingSignal = true;
         
         // Generate scalping alert
         if(TimeCurrent() - alertState.lastScalpingAlert > 60) // 1 min cooldown
         {
            string signalMsg = "SCALPING SIGNAL " + timeframeLabels[tfIndex] + "! " +
                              (trendDir > 0 ? "BUY" : "SELL") +
                              " (Confidence: " + DoubleToString(tfData[tfIndex].scalpingConfidence * 100, 1) + "%)";
            ShowAlert(signalMsg);
            alertState.lastScalpingAlert = TimeCurrent();
         }
      }
      else
      {
         tfData[tfIndex].scalpingSignal = false;
      }
   }
   
   // Update the UI labels for this timeframe if needed (e.g. adding confidence text)
   // For now, we update the global analytics panel in UpdateAll
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
   mlPrediction.patternType = "None";
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
   
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(tfData[i].enabled && tfData[i].available)
         tfData[i].consistencyScore = consistencyScore;
   }
   
   currentMetrics.consistencyScore = consistencyScore;
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
         // Guard against division by zero or invalid values
         // Use epsilon-based comparison to handle near-zero indicator values
         const double epsilon = 1e-10;
         if(buf[0] == EMPTY_VALUE || buf[1] == EMPTY_VALUE || buf[2] == EMPTY_VALUE) continue;
         if(MathAbs(buf[1]) < epsilon || MathAbs(buf[2]) < epsilon) continue;
         
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
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;

      // Use iTime to check if a new bar has closed for this timeframe
      datetime currentBarTime = 0;
      if(!SeriesInfoInteger(_Symbol, timeframes[i], SERIES_LASTBAR_DATE, currentBarTime)) continue;
      
      // Only update performance metrics once per candle
      if(currentBarTime == tfData[i].lastBarTime) continue;
      
      // Check the performance of the PREVIOUS bar (index 1)
      MqlRates rates[2];
      if(CopyRates(_Symbol, timeframes[i], 1, 1, rates) == 1)
      {
         int barMovement = (rates[0].close > rates[0].open) ? 1 : (rates[0].close < rates[0].open ? -1 : 0);
         
         // If we had a trend direction established at the start of that bar
         if(tfData[i].lastTrendDirection != 0 && barMovement != 0)
         {
            tfData[i].totalPredictions++;
            if(tfData[i].lastTrendDirection == barMovement)
               tfData[i].correctPredictions++;
               
            tfData[i].historicalAccuracy = (double)tfData[i].correctPredictions / tfData[i].totalPredictions;
         }
      }
      
      tfData[i].lastBarTime = currentBarTime;
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
      ShowAlert(alertMsg);
      alertState.lastAnalyticsAlert = currentTime;
   }
}

//+------------------------------------------------------------------+
// Pattern recognition result structure
struct PatternResult
{
   double signal;       // -1=Sell, 0=Neutral, 1=Buy
   string pattern;      // Pattern name
   double confidence;   // 0-1 confidence level
   bool   detected;     // True if pattern was detected
};

//+------------------------------------------------------------------+
// Pattern Detection Functions - Each isolates a single pattern algorithm
//+------------------------------------------------------------------+

PatternResult DetectBullishEngulfing(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   if(rates[2].close < rates[2].open && // Prev candle bearish
      rates[1].close > rates[1].open && // Last closed candle bullish
      rates[1].close > rates[2].open &&
      rates[1].open < rates[2].close)
   {
      result.signal = 1;
      result.pattern = "Bullish Engulfing";
      result.confidence = 0.85;
      result.detected = true;
   }
   return result;
}

PatternResult DetectBearishEngulfing(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   if(rates[2].close > rates[2].open && // Prev candle bullish
      rates[1].close < rates[1].open && // Last closed candle bearish
      rates[1].close < rates[2].open &&
      rates[1].open > rates[2].close)
   {
      result.signal = -1;
      result.pattern = "Bearish Engulfing";
      result.confidence = 0.85;
      result.detected = true;
   }
   return result;
}

PatternResult DetectHammer(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   double bodySize = rates[1].close - rates[1].open;
   double upperWick = rates[1].high - rates[1].close;
   double lowerWick = rates[1].open - rates[1].low;
   
   if(rates[1].close > rates[1].open && // Bullish
      upperWick < bodySize * 0.5 && // Small upper wick
      lowerWick > bodySize * 2.0) // Long lower wick
   {
      result.signal = 1;
      result.pattern = "Hammer";
      result.confidence = 0.75;
      result.detected = true;
   }
   return result;
}

PatternResult DetectShootingStar(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   double bodySize = rates[1].open - rates[1].close;
   double lowerWick = rates[1].close - rates[1].low;
   double upperWick = rates[1].high - rates[1].open;
   
   if(rates[1].close < rates[1].open && // Bearish
      lowerWick < bodySize * 0.5 && // Small lower wick
      upperWick > bodySize * 2.0) // Long upper wick
   {
      result.signal = -1;
      result.pattern = "Shooting Star";
      result.confidence = 0.75;
      result.detected = true;
   }
   return result;
}

PatternResult DetectDoji(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   double bodySize = MathAbs(rates[1].close - rates[1].open);
   double range = rates[1].high - rates[1].low;
   
   if(bodySize <= range * 0.1)
   {
      result.signal = (rates[2].close > rates[2].open) ? -0.5 : 0.5; // Reversal potential
      result.pattern = "Doji";
      result.confidence = 0.65;
      result.detected = true;
   }
   return result;
}

PatternResult DetectInsideBar(const MqlRates &rates[])
{
    PatternResult result;
    result.signal = 0;
    result.pattern = "";
    result.confidence = 0.0;
    result.detected = false;

    if(rates[1].high < rates[2].high && rates[1].low > rates[2].low)
    {
       result.signal = 0;
       result.pattern = "Inside Bar";
       result.confidence = 0.60;
       result.detected = true;
    }
    return result;
}

PatternResult DetectBullishHarami(const MqlRates &rates[])
{
    PatternResult result;
    result.signal = 0;
    result.pattern = "";
    result.confidence = 0.0;
    result.detected = false;

    double prevBody = MathAbs(rates[2].close - rates[2].open);
    double currBody = MathAbs(rates[1].close - rates[1].open);

    if(rates[2].close < rates[2].open && // Previous candle bearish
       rates[1].close > rates[1].open && // Current candle bullish
       currBody < prevBody && // Current body smaller
       rates[1].open > rates[2].close && // Current body completely inside previous body
       rates[1].close < rates[2].open)
    {
       result.signal = 1;
       result.pattern = "Bullish Harami";
       result.confidence = 0.75;
       result.detected = true;
    }
    return result;
}

PatternResult DetectBearishHarami(const MqlRates &rates[])
{
    PatternResult result;
    result.signal = 0;
    result.pattern = "";
    result.confidence = 0.0;
    result.detected = false;

    double prevBody = MathAbs(rates[2].close - rates[2].open);
    double currBody = MathAbs(rates[1].close - rates[1].open);

    if(rates[2].close > rates[2].open && // Previous candle bullish
       rates[1].close < rates[1].open && // Current candle bearish
       currBody < prevBody && // Current body smaller
       rates[1].open < rates[2].close && // Current body completely inside previous body
       rates[1].close > rates[2].open)
    {
       result.signal = -1;
       result.pattern = "Bearish Harami";
       result.confidence = 0.75;
       result.detected = true;
    }
    return result;
}

PatternResult DetectMorningStar(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   double prevBody = MathAbs(rates[3].close - rates[3].open);
   double middleBody = MathAbs(rates[2].close - rates[2].open);
   double midpoint = (rates[3].open + rates[3].close) / 2;
   
   if(rates[3].close < rates[3].open && // Bearish
      rates[2].close < rates[3].close && // Gap down or lower
      middleBody < prevBody && // Small body
      rates[1].close > rates[1].open && // Bullish
      rates[1].close > midpoint) // Closes above midpoint
   {
      result.signal = 1;
      result.pattern = "Morning Star";
      result.confidence = 0.90;
      result.detected = true;
   }
   return result;
}

PatternResult DetectEveningStar(const MqlRates &rates[])
{
   PatternResult result;
   result.signal = 0;
   result.pattern = "";
   result.confidence = 0.0;
   result.detected = false;
   
   double prevBody = MathAbs(rates[3].close - rates[3].open);
   double middleBody = MathAbs(rates[2].close - rates[2].open);
   double midpoint = (rates[3].open + rates[3].close) / 2;
   
   if(rates[3].close > rates[3].open && // Bullish
      rates[2].close > rates[3].close && // Gap up or higher
      middleBody < prevBody && // Small body
      rates[1].close < rates[1].open && // Bearish
      rates[1].close < midpoint) // Closes below midpoint
   {
      result.signal = -1;
      result.pattern = "Evening Star";
      result.confidence = 0.90;
      result.detected = true;
   }
   return result;
}

//+------------------------------------------------------------------+
// Master pattern detection - runs all individual detectors
//+------------------------------------------------------------------+
PatternResult DetectCandlestickPattern(const MqlRates &rates[])
{
    PatternResult result;

    // Try each pattern detector in priority order (highest confidence first)
    result = DetectMorningStar(rates);
    if(result.detected) return result;

    result = DetectEveningStar(rates);
    if(result.detected) return result;

    result = DetectBullishEngulfing(rates);
    if(result.detected) return result;

    result = DetectBearishEngulfing(rates);
    if(result.detected) return result;

    result = DetectHammer(rates);
    if(result.detected) return result;

    result = DetectShootingStar(rates);
    if(result.detected) return result;

    result = DetectBullishHarami(rates);
    if(result.detected) return result;

    result = DetectBearishHarami(rates);
    if(result.detected) return result;

    result = DetectDoji(rates);
    if(result.detected) return result;

    result = DetectInsideBar(rates);
    if(result.detected) return result;

    // No pattern detected
    result.signal = 0;
    result.pattern = "";
    result.confidence = 0.0;
    result.detected = false;
    return result;
}

//+------------------------------------------------------------------+
void UpdateExternalData()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - lastExternalUpdate < 300) // Update every 5 minutes
      return;
   
   // Simulation of external data (requires API integration for real data)
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
         ShowAlert("HIGH IMPACT NEWS EVENT detected! Consider reducing position size.");
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
         ShowAlert(sentimentMsg);
         alertState.lastIntegrationAlert = TimeCurrent();
      }
   }
   lastExternalUpdate = currentTime;
}

//+------------------------------------------------------------------+
void UpdateMLPredictions()
{
   // Skip if all ML features are disabled
   if(!EnableMLPatternRecognition && !EnableAITrendPrediction && !EnableNeuralNetworkSignals)
      return;

   datetime currentTime = TimeCurrent();
   if(currentTime - lastMLUpdate < 20) // Update every 20 seconds for better responsiveness
      return;
   
   // Reset global prediction before scanning timeframes
   mlPrediction.patternType = "None";
   mlPrediction.confidence = 0.0;
   mlPrediction.predictedDirection = 0;

   // AI Trend Prediction: Use trend momentum across timeframes for directional bias
   if(EnableAITrendPrediction)
   {
      int bullishTFs = 0, bearishTFs = 0, totalTFs = 0;
      for(int i = 0; i < NUM_TIMEFRAMES; i++)
      {
         if(!tfData[i].enabled || !tfData[i].available) continue;
         totalTFs++;
         if(tfData[i].lastTrendDirection == 1) bullishTFs++;
         else if(tfData[i].lastTrendDirection == -1) bearishTFs++;
      }
      
      if(totalTFs > 0)
      {
         double bias = (double)(bullishTFs - bearishTFs) / totalTFs;
         if(MathAbs(bias) >= 0.5)
         {
            mlPrediction.predictedDirection = (bias > 0) ? 1.0 : -1.0;
            mlPrediction.confidence = MathAbs(bias);
            mlPrediction.timeToSignal = PredictionHorizonBars;
            mlPrediction.patternType = "AI Trend Bias";
            mlPrediction.isReliable = mlPrediction.confidence >= ConfidenceThreshold;
            
            if(mlPrediction.isReliable && currentTime - alertState.lastPredictionAlert > 300)
            {
               string aiMsg = "AI TREND PREDICTION: " +
                             (bias > 0 ? "BULLISH" : "BEARISH") +
                             " bias across " + IntegerToString(totalTFs) + " TFs " +
                             "(Confidence: " + DoubleToString(mlPrediction.confidence * 100, 1) + "%)";
               ShowAlert(aiMsg);
               alertState.lastPredictionAlert = currentTime;
            }
         }
      }
   }
   
   // Neural Network Signals: Use consistency + momentum composite as neural signal
   if(EnableNeuralNetworkSignals)
   {
      if(currentMetrics.overallScore > 0)
      {
         double neuralScore = currentMetrics.overallScore / 100.0;
         if(neuralScore >= ConfidenceThreshold && currentTime - alertState.lastPredictionAlert > 300)
         {
            string nnMsg = "NEURAL SIGNAL: Score " + DoubleToString(currentMetrics.overallScore, 1) + "% " +
                          "(" + (currentMetrics.isHighProbability ? "HIGH PROB" : "MODERATE") + ")";
            ShowAlert(nnMsg);
            alertState.lastPredictionAlert = currentTime;
         }
      }
   }
   
    // Pattern Recognition using extracted detection methods
    if(EnableMLPatternRecognition)
    {
       for(int i = 0; i < NUM_TIMEFRAMES; i++)
       {
          if(!tfData[i].enabled || !tfData[i].available) continue;

          MqlRates rates[];
          ArraySetAsSeries(rates, true);

          // Check last 6 bars for pattern detection (increased from 4 for better context)
          if(CopyRates(_Symbol, timeframes[i], 0, 6, rates) == 6)
          {
             // Use the extracted pattern detection function (operates on indices 1-3)
             PatternResult patternResult = DetectCandlestickPattern(rates);

             tfData[i].detectedPattern = patternResult.pattern;

             if(patternResult.detected && patternResult.signal != 0)
             {
                // Update global prediction if this pattern has higher confidence
                if(patternResult.confidence >= mlPrediction.confidence)
                {
                   mlPrediction.predictedDirection = patternResult.signal;
                   mlPrediction.confidence = patternResult.confidence;
                   mlPrediction.timeToSignal = 1; // Immediate
                   mlPrediction.patternType = patternResult.pattern;
                   mlPrediction.isReliable = true;
                }

                // Generate Alert
                if(currentTime - alertState.lastPredictionAlert > 60)
                {
                   string directionStr = (patternResult.signal > 0) ? "UP" :
                                         (patternResult.signal < 0) ? "DOWN" : "NEUTRAL";
                   string mlMsg = "PATTERN DETECTED: " + timeframeLabels[i] + " " +
                                 patternResult.pattern + "! " +
                                 "Direction: " + directionStr +
                                 " (Confidence: " + DoubleToString(patternResult.confidence * 100, 1) + "%)";
                   ShowAlert(mlMsg);
                   alertState.lastPredictionAlert = currentTime;
                }

                tfData[i].totalPredictions++;
             }
          }
       }
    }

   lastMLUpdate = currentTime;
}

//+------------------------------------------------------------------+
//| Centralized Alert Handler respecting EnablePopupAlerts setting   |
//+------------------------------------------------------------------+
void ShowAlert(string msg)
{
   if(EnablePopupAlerts)
   {
      Alert(msg);
   }
   else
   {
      Print(msg); // Log to experts tab even if popups are disabled
   }
}
//+------------------------------------------------------------------+