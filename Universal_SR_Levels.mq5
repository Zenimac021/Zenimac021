//+------------------------------------------------------------------+
//|                                Universal_SR_Levels.mq5           |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                            https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.mql5.com"
#property version   "3.0"
#property description "Universal Support and Resistance Indicator - Professional Edition"
#property description "Combines historical levels, pivot points, fractals, round numbers, and volume profile"
#property description "Features: Zone visualization, breakout alerts, trend detection, stats panel, EA API"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

/*
Universal SR Levels Indicator - Professional Version 3.0
=========================================================
Here's a complete list of all abbreviations used in the Universal SR Levels indicator:

  Support/Resistance Indicators:
  S = Support level
  R = Resistance level
  Method Abbreviations:
  Pivot Points:
  PP = Pivot Point (central pivot)
  R1 = Resistance 1 (first resistance level)
  S1 = Support 1 (first support level)
  R2 = Resistance 2 (second resistance level)
  S2 = Support 2 (second support level)
  R3 = Resistance 3 (third resistance level)
  S3 = Support 3 (third support level)
  
  Camarilla Pivots:
  Cam = Camarilla pivots (proprietary formula for intraday levels)
  H1-H4 = Camarilla resistance levels 1-4
  L1-L4 = Camarilla support levels 1-4
  
  Detection Methods:
  Sw = Swing levels (highs/lows from price swings)
  Fr = Fractal levels (5-bar fractal patterns)
  Rn = Round numbers (psychological price levels)
  VP = Volume Point of Control (highest volume price)
  VH = Value Area High (upper boundary of 70% volume zone)
  VL = Value Area Low (lower boundary of 70% volume zone)
    HT = Higher Timeframe (levels from larger timeframes)
    
  Visual Indicators:
  ★ = Strength rating (1-5 stars)
  ▲ = Rising trend at this level
  ▼ = Falling trend at this level
  📌 = Pin bar signal detected at this level
  📊 = Engulfing pattern detected at this level
*/

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#define MAX_LEVELS_HARD_LIMIT    500
#define ALERT_COOLDOWN_SEC       300
#define STATS_PANEL_NAME         "SRL_StatsPanel"
#define GLOBAL_VAR_PREFIX        "SR_LEVEL_"
#define CSV_EXPORT_FILE          "SR_Levels_Export.csv"
#define PERSISTENCE_FILE          "SR_Levels_Persistence.bin"

#define SWING_STRENGTH_DEFAULT   5
#define VOLUME_BINS              40
#define TREND_LOOKBACK           20
#define TREND_RISING_RATIO       0.7
#define TREND_FALLING_RATIO      0.3
#define ZONE_HALF_WIDTH_PCT      0.2
#define GROUPING_MIN_TICKS       2
#define CONFLUENCE_DISTANCE_PCT  0.05
#define STALE_LEVEL_SEC_PER_DAY  86400.0
#define STATS_PANEL_UPDATE_SEC   5
#define HTF_SWING_LOOKBACK       3
#define FRACTAL_LOOKBACK         2
#define PIVOT_FIB_1              0.382
#define PIVOT_FIB_2              0.618
#define BREAK_THRESHOLD_TICKS    2
#define BOUNCE_MIN_TOUCHES       2
#define ROUND_NUM_RANGE          5
#define LEVEL_ARRAY_INITIAL       200
#define LEVEL_ARRAY_GROWTH       100
#define SPATIAL_HASH_DIVISOR     10
#define OBJ_CLEANUP_HASH_SIZE    1024

// Alert type enumeration
enum ENUM_ALERT_TYPE {
   ALERT_TYPE_ALERT = 0,  // Standard MetaTrader alert
   ALERT_TYPE_EMAIL = 1,  // Email notification
   ALERT_TYPE_PUSH  = 2   // Push notification
};

// Alert mode enumeration
enum ENUM_ALERT_MODE {
   ALERT_MODE_APPROACH = 0,  // Alert when price approaches level
   ALERT_MODE_BREAK  = 1,    // Alert when price breaks through level
   ALERT_MODE_BOUNCE = 2     // Alert when price bounces off level
};

// Debug level enumeration
enum ENUM_DEBUG_LEVEL {
    DEBUG_NONE = 0,      // No debug output
    DEBUG_BASIC = 1,     // Basic debug info
    DEBUG_DETAILED = 2   // Detailed debug
};

// Level display mode
enum ENUM_LEVEL_DISPLAY {
   DISPLAY_LINES = 0,    // Show as lines
   DISPLAY_ZONES = 1     // Show as zones
};

// Input parameters
input group "General Settings";
input string   ObjectPrefix       = "SRL_"; // Prefix for all chart objects
input int      MaxLevels          = 5;      // Maximum number of levels (above and below price)
input bool     ShowLabels         = true;   // Show price labels
input bool     ShowStrength       = true;   // Show strength ratings
input int      LookbackBars       = 500;    // Lookback period in bars
input int      ADR_Period         = 20;     // ADR calculation period
input bool     EnableAlerts       = false;  // Enable price alerts
input ENUM_ALERT_MODE AlertMode   = ALERT_MODE_APPROACH; // Alert mode
input double   AlertDistancePct   = 0.5;    // Alert distance (% of daily range)
input ENUM_ALERT_TYPE AlertType   = ALERT_TYPE_ALERT; // Alert type

input group "Multi-Timeframe Settings";
input bool    UseMultiTimeframe   = true;        // Use multi-timeframe analysis
input bool    UseHTF1             = true;        // Enable HTF1
input ENUM_TIMEFRAMES HigherTF1   = PERIOD_H1;   // Higher timeframe 1
input bool    UseHTF2             = true;        // Enable HTF2
input ENUM_TIMEFRAMES HigherTF2   = PERIOD_H4;   // Higher timeframe 2
input bool    UseLTF              = false;       // Enable LTF
input ENUM_TIMEFRAMES LowerTF     = PERIOD_M15;  // Lower timeframe

input group "Detection Methods";
input bool    UseHistoricalLevels = true;    // Use historical highs/lows
input bool    UsePivotPoints      = true;    // Use pivot points
input bool    UseFractals         = true;    // Use fractals
input bool    UseRoundNumbers     = true;    // Use round numbers
input bool    UseVolumeProfile    = false;   // Use volume profile
input bool    UseOrderBlocks      = true;    // Use order block detection

input group "Visual Settings";
input ENUM_LEVEL_DISPLAY DisplayMode = DISPLAY_LINES; // Display mode
input color   SupportColor      = clrLightGreen;  // Support line color
input color   ResistanceColor   = clrPink;        // Resistance line color
input int     LineWidth         = 1;              // Line width
input ENUM_LINE_STYLE LineStyle = STYLE_DOT;      // Line style
input int     LabelFontSize     = 8;              // Label font size
input double  ZoneWidthPct      = 0.2;            // Zone width (% of price)
input bool    ShowStatsPanel    = true;           // Show statistics panel
input color   StatsPanelTextColor = clrWhite;     // Stats panel text color
input bool    ShowPriceActionSignals = true;      // Show PA signals at levels
input bool    DynamicZoneWidth      = true;       // Adjust zone width based on volatility
input double  DynamicZoneMultiplier = 1.0;        // Multiplier for dynamic zones
input bool    EnablePersistence     = false;      // Save/load levels between sessions
input bool    SessionFilter         = false;      // Filter levels by trading session
input int     SessionStartHour      = 9;          // Session start hour (0-23)
input int     SessionEndHour        = 17;         // Session end hour (0-23)

input group "Advanced Settings";
input double  GroupingFactorPct = 0.1;           // Grouping tolerance (% of price)
input int     MaxLevelsPerType = 15;             // Max historical levels cached
input bool    ShowOnlyStrongLevels = false;      // Strength >= 2.0 filter
input double  StaleLevelDays    = 30.0;          // Auto-remove levels older than (days)
input bool    DetectTrends      = true;          // Detect rising/falling level trends
input bool    EnableEAAPI       = true;          // Export levels for EA via GlobalVariables
input bool    EnableCSVExport   = false;         // Auto-export levels to CSV
input int     CSVExportInterval = 60;            // CSV export interval (seconds)

input group "Debug Settings";
input ENUM_DEBUG_LEVEL DebugLevel = DEBUG_NONE; // Debug output level

//+------------------------------------------------------------------+
//| Conditional debug compilation                                     |
//+------------------------------------------------------------------+
#ifdef DEBUG_MODE
   #define DBG_PRINT(level, msg) if(DebugLevel >= level) Print("[SR_DEBUG] ", msg)
#else
   #define DBG_PRINT(level, msg)
#endif

//+------------------------------------------------------------------+
//| Structs                                                           |
//+------------------------------------------------------------------+
struct SRLevel {
    double price;
    bool isSupport;
    double strength;
    double confluenceScore;  // NEW: Weighted score by method agreement
    string timeframe;
    string method;
    datetime firstTested;
    datetime lastTested;
    int touchCount;
    int bounceCount;         // NEW: Times price bounced off level
    int breakCount;          // NEW: Times level was broken
    bool isVisible;
    int levelID;
    double trend;            // Price trend direction at level
    bool isBroken;           // Whether level has been broken
    datetime breakTime;      // When level was broken
    double zoneTop;          // Zone top price (for zone display)
    double zoneBottom;       // Zone bottom price (for zone display)
    
    // NEW: Price action signals
    bool hasPinBar;
    bool hasEngulfing;
    datetime signalTime;
    double signalPrice;
};

struct LevelScore {
    int index;
    double score;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
SRLevel G_Levels[];
int G_TotalLevels = 0;
double G_AvgDailyRange = 0;
double G_TickSize = 0;
double G_Point = 0;
datetime G_LastFullRecalc = 0;
datetime G_LastAlertTime = 0;
double G_LastAlertPrice = 0;
int G_Digits = 5;
bool G_LevelsChanged = false;
datetime G_StatsPanelUpdate = 0;
datetime G_LastCSVExport = 0;

// Cache for HTF rates
MqlRates G_CachedHTF1[];
MqlRates G_CachedHTF2[];
MqlRates G_CachedLTF[];
datetime G_HTF1CacheTime = 0;
datetime G_HTF2CacheTime = 0;
datetime G_LTFCacheTime = 0;

// Object tracking for efficient cleanup
string G_ActiveObjects[];
int G_ActiveObjectCount = 0;
bool G_ObjectCleanupMap[OBJ_CLEANUP_HASH_SIZE]; // Boolean hash map for O(1) lookups

//+------------------------------------------------------------------+
//| Custom color with alpha (replaces ColorToARGB)                   |
//+------------------------------------------------------------------+
color ColorWithAlpha(color clr, uchar alpha) {
   // MQL5 doesn't support alpha in color type for objects
   // Return original color (alpha handled via OBJPROP_BACK)
   return clr;
}

//+------------------------------------------------------------------+
//| Safe array minimum function                                      |
//+------------------------------------------------------------------+
double ArrayMinimumSafe(const double &arr[], int start = 0, int count = WHOLE_ARRAY) {
   int size = ArraySize(arr);
   if (size == 0 || start >= size) return 0;
   int idx = ArrayMinimum(arr, start, count);
   return (idx != -1) ? arr[idx] : 0;
}

//+------------------------------------------------------------------+
//| Safe array maximum function                                      |
//+------------------------------------------------------------------+
double ArrayMaximumSafe(const double &arr[], int start = 0, int count = WHOLE_ARRAY) {
   int size = ArraySize(arr);
   if (size == 0 || start >= size) return 0;
   int idx = ArrayMaximum(arr, start, count);
   return (idx != -1) ? arr[idx] : 0;
}

//+------------------------------------------------------------------+
//| Initialize stable level ID                                       |
//+------------------------------------------------------------------+
int GetStableID(double price, bool isSupport) {
    long norm = (long)MathRound(price * MathPow(10, G_Digits));
    return (int)((norm % 1000000) + (isSupport ? 1000000 : 2000000));
}

//+------------------------------------------------------------------+
//| Safe price normalization                                         |
//+------------------------------------------------------------------+
double NormalizePrice(double price) {
    return NormalizeDouble(price, G_Digits);
}

//+------------------------------------------------------------------+
//| Validate price within reasonable range                           |
//+------------------------------------------------------------------+
bool IsValidPrice(double price) {
    if (price <= 0 || price != price) return false; // Check for NaN and negative
    
    // Check if price is within reasonable bounds (100x current price)
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (currentPrice <= 0) return true; // Can't validate if no current price
    
    double ratio = price / currentPrice;
    return (ratio > 0.01 && ratio < 100.0);
}

//+------------------------------------------------------------------+
//| Debug print helper                                               |
//+------------------------------------------------------------------+
void DebugPrint(ENUM_DEBUG_LEVEL level, string msg) {
    #ifdef DEBUG_MODE
    if (DebugLevel >= level) Print("[SR_DEBUG] ", msg);
    #endif
}

//+------------------------------------------------------------------+
//| Fast string hash for object tracking                             |
//+------------------------------------------------------------------+
uint StringHash(string str) {
    uint hash = 0;
    int len = StringLen(str);
    for (int i = 0; i < len; i++) {
        hash = hash * 31 + StringGetCharacter(str, i);
    }
    return hash % OBJ_CLEANUP_HASH_SIZE;
}

//+------------------------------------------------------------------+
//| Check if object is in active list (O(1) average)                 |
//+------------------------------------------------------------------+
bool IsObjectActive(string name, uint hash) {
    // Use hash map for O(1) lookup
    if (hash < OBJ_CLEANUP_HASH_SIZE && G_ObjectCleanupMap[hash]) {
        // Verify with linear search (small number of active objects)
        for (int i = 0; i < G_ActiveObjectCount; i++) {
            if (G_ActiveObjects[i] == name) return true;
        }
        // Hash collision but not found, clear map entry
        G_ObjectCleanupMap[hash] = false;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add object to active list                                        |
//+------------------------------------------------------------------+
void AddActiveObject(string name) {
    if (G_ActiveObjectCount >= ArraySize(G_ActiveObjects)) {
        ArrayResize(G_ActiveObjects, G_ActiveObjectCount + 100);
    }
    G_ActiveObjects[G_ActiveObjectCount++] = name;
    
    // Mark in hash map for faster cleanup
    uint hash = StringHash(name);
    G_ObjectCleanupMap[hash] = true;
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Input validation
    if (LookbackBars <= 0) {
        Print("[SR_ERROR] LookbackBars must be > 0");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (MaxLevels <= 0 || MaxLevels > 50) {
        Print("[SR_ERROR] MaxLevels must be between 1 and 50");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (AlertDistancePct < 0 || AlertDistancePct > 10) {
        Print("[SR_ERROR] AlertDistancePct must be between 0 and 10");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (GroupingFactorPct < 0 || GroupingFactorPct > 5) {
        Print("[SR_ERROR] GroupingFactorPct must be between 0 and 5");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (StaleLevelDays < 0) {
        Print("[SR_ERROR] StaleLevelDays must be >= 0");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (ZoneWidthPct < 0 || ZoneWidthPct > 5) {
        Print("[SR_ERROR] ZoneWidthPct must be between 0 and 5");
        return INIT_PARAMETERS_INCORRECT;
    }

    G_Digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    G_TickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if (G_TickSize <= 0) G_TickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    G_Point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (G_Point <= 0) G_Point = 0.00001;

    IndicatorSetString(INDICATOR_SHORTNAME, "Universal SR (" + _Symbol + ") v3.0");
    IndicatorSetInteger(INDICATOR_DIGITS, G_Digits);

    CalculateADR();
    ArrayResize(G_Levels, LEVEL_ARRAY_INITIAL);
    ArrayResize(G_ActiveObjects, 200);
    G_TotalLevels = 0;
    G_ActiveObjectCount = 0;

    // Load persisted levels if enabled
    LoadLevelsFromFile();
    
    EventSetTimer(60);

    DebugPrint(DEBUG_BASIC, "Universal SR Levels v3.0 initialized");
    DebugPrint(DEBUG_BASIC, "Symbol: " + _Symbol + ", Digits: " + IntegerToString(G_Digits));
    DebugPrint(DEBUG_BASIC, "Tick Size: " + DoubleToString(G_TickSize, G_Digits));

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Save levels before exit if enabled
    if (reason != REASON_CHARTCHANGE && reason != REASON_TEMPLATE) {
        SaveLevelsToFile();
    }
    
    ObjectsDeleteAll(0, ObjectPrefix);
    EventKillTimer();
    
    // Clean up global variables if EA API was enabled
    if (EnableEAAPI) {
        for (int i = 0; i < G_TotalLevels; i++) {
            string varName = GLOBAL_VAR_PREFIX + IntegerToString(i);
            GlobalVariableDel(varName);
        }
        GlobalVariableDel(GLOBAL_VAR_PREFIX + "Count");
    }
    
    DebugPrint(DEBUG_BASIC, "Universal SR Levels deinitialized");
}

//+------------------------------------------------------------------+
//| Main Calculation                                                  |
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
                const int &spread[]) {

    if (rates_total < 100) return 0;

    // Set as series for intuitive indexing (0 = current bar)
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(tick_volume, true);

    static datetime lastBarTime = 0; 
    bool newBar = (time[0] != lastBarTime);
    if (newBar) lastBarTime = time[0];

    datetime now = TimeCurrent();
    bool periodic = (now - G_LastFullRecalc > 300);

    // Early exit if nothing changed - INCREMENTAL UPDATE
    if (G_AvgDailyRange <= 0) CalculateADR();

    if (prev_calculated > 0 && !newBar && !periodic) {
        if (EnableAlerts) CheckAlerts(close[0], time[0]);
        UpdateStatsPanel(time[0], close[0]);
        if (EnableEAAPI) ExportToGlobalVariables();
        return rates_total;
    }

    // INCREMENTAL: If only new bar, update existing levels instead of full recalc
    if (prev_calculated > 0 && newBar && !periodic) {
        UpdateExistingLevels(high, low, close, open, tick_volume, time, rates_total);
        CalculateStrengths(close[0]);
        FilterAndVisible(close[0]);
        UpdateTrends(high, low, close, rates_total);
        UpdateObjects(time[0], close[0]);
        UpdateStatsPanel(time[0], close[0]);
        if (EnableAlerts) CheckAlerts(close[0], time[0]);
        if (EnableEAAPI) ExportToGlobalVariables();
        if (EnableCSVExport) CheckCSVExport(now);
        return rates_total;
    }

    // FULL RECALCULATION
    G_TotalLevels = 0;
    G_LastFullRecalc = now;
    G_LevelsChanged = false;
    G_ActiveObjectCount = 0;

    DebugPrint(DEBUG_DETAILED, "Starting full recalculation: bars=" + IntegerToString(rates_total));

    // Check trading session filter
    if (!IsWithinTradingSession()) {
        DebugPrint(DEBUG_DETAILED, "Outside trading session, skipping detection");
        // Still update existing levels but don't add new ones
        CalculateStrengths(close[0]);
        FilterAndVisible(close[0]);
        UpdateObjects(time[0], close[0]);
        UpdateStatsPanel(time[0], close[0]);
        return rates_total;
    }
    
    // 1. Historical Levels
    if (UseHistoricalLevels) DetectHistorical(high, low, time, rates_total);

    // 2. Pivot Points
    if (UsePivotPoints) DetectPivots();

    // 3. Fractals
    if (UseFractals) DetectFractals(high, low, time, rates_total);

    // 4. Round Numbers
    if (UseRoundNumbers) DetectRoundNumbers(close[0]);

    // 5. Volume Profile
    if (UseVolumeProfile) DetectVolume(high, low, close, tick_volume, rates_total);

    // 6. Order Blocks
    if (UseOrderBlocks) DetectOrderBlocks(high, low, open, close, time, rates_total);

    // 7. Multi-Timeframe (with caching)
    if (UseMultiTimeframe) {
        if (UseHTF1) DetectHTF(HigherTF1, "HTF1", G_CachedHTF1, G_HTF1CacheTime);
        if (UseHTF2) DetectHTF(HigherTF2, "HTF2", G_CachedHTF2, G_HTF2CacheTime);
        if (UseLTF) DetectHTF(LowerTF, "LTF", G_CachedLTF, G_LTFCacheTime);
    }

    // Process levels
    CalculateStrengths(close[0]);
    RemoveStaleLevels(now);
    FilterAndVisible(close[0]);
    UpdateTrends(high, low, close, rates_total);
    UpdateObjects(time[0], close[0]);
    UpdateStatsPanel(time[0], close[0]);

    if (EnableAlerts) CheckAlerts(close[0], time[0]);
    if (EnableEAAPI) ExportToGlobalVariables();
    if (EnableCSVExport) CheckCSVExport(now);

    DebugPrint(DEBUG_DETAILED, "Recalculation complete: total_levels=" + IntegerToString(G_TotalLevels));

    return rates_total;
}

//+------------------------------------------------------------------+
//| Update existing levels on new bar (incremental)                  |
//+------------------------------------------------------------------+
void UpdateExistingLevels(const double &high[], const double &low[], const double &close[],
                          const double &open[], const long &tick_volume[], const datetime &time[], int total) {
    double currentPrice = close[0];
    datetime currentTime = time[0];
    
    // Check for new touches/breaks on existing levels
    for (int i = 0; i < G_TotalLevels; i++) {
        double threshold = G_TickSize * BREAK_THRESHOLD_TICKS;
        
        // Check if price touched level
        if (MathAbs(currentPrice - G_Levels[i].price) <= threshold) {
            G_Levels[i].touchCount++;
            G_Levels[i].lastTested = currentTime;
            
            // Check for bounce (price moved away after touch)
            if (G_Levels[i].touchCount >= BOUNCE_MIN_TOUCHES) {
                bool bounced = (G_Levels[i].isSupport && currentPrice > G_Levels[i].price) ||
                              (!G_Levels[i].isSupport && currentPrice < G_Levels[i].price);
                if (bounced) G_Levels[i].bounceCount++;
            }
        }
        
        // Check for break
        if (!G_Levels[i].isBroken) {
            if ((G_Levels[i].isSupport && currentPrice < G_Levels[i].price - threshold) ||
                (!G_Levels[i].isSupport && currentPrice > G_Levels[i].price + threshold)) {
                G_Levels[i].isBroken = true;
                G_Levels[i].breakTime = currentTime;
                G_Levels[i].breakCount++;
            }
        }
    }
    
    // Add new swing levels from recent bars
    // Check completed bars only. For a 5-bar swing, the peak is at index 6 when bar 0 just started.
    int checkDist = SWING_STRENGTH_DEFAULT;
    if (UseHistoricalLevels && total > checkDist * 2 + 1) {
        int i = checkDist + 1; 
        bool isPeak = true, isTrough = true;
        for (int j = 1; j <= checkDist; j++) {
            if (i + j >= total) { isPeak = false; isTrough = false; break; }
            if (high[i] <= high[i-j] || high[i] <= high[i+j]) isPeak = false;
            if (low[i] >= low[i-j] || low[i] >= low[i+j]) isTrough = false;
        }
        if (isPeak) AddLevel(high[i], false, 1.5, "Current", "Swing", time[i]);
        if (isTrough) AddLevel(low[i], true, 1.5, "Current", "Swing", time[i]);
    }
    
    // Update price action signals
    if (ShowPriceActionSignals) {
        DetectPriceActionSignals(high, low, open, close, time, total);
    }
}

//+------------------------------------------------------------------+
//| Calculate Average Daily Range                                    |
//+------------------------------------------------------------------+
void CalculateADR() {
    MqlRates r[];
    int copied = CopyRates(_Symbol, PERIOD_D1, 1, ADR_Period, r);
    if (copied > 0) {
        double sum = 0;
        for (int i = 0; i < copied; i++) sum += (r[i].high - r[i].low);
        G_AvgDailyRange = sum / copied;
    }
    if (G_AvgDailyRange <= 0) G_AvgDailyRange = G_Point * 200;

    DebugPrint(DEBUG_DETAILED, "ADR calculated: " + DoubleToString(G_AvgDailyRange, G_Digits));
}

//+------------------------------------------------------------------+
//| Add or Merge Level                                               |
//+------------------------------------------------------------------+
void AddLevel(double price, bool isSupport, double strength, string tf, string method, datetime time, int count=1) {
    // Enhanced validation
    if (price <= 0 || !IsValidPrice(price) || G_TotalLevels >= MAX_LEVELS_HARD_LIMIT) {
        DebugPrint(DEBUG_BASIC, "AddLevel: Invalid parameters - price=" + DoubleToString(price, G_Digits) + ", total=" + IntegerToString(G_TotalLevels));
        return;
    }

    price = NormalizePrice(price);
    
    // Validate strength and method
    if (strength <= 0 || strength > 10.0) strength = MathMax(0.1, MathMin(10.0, strength));
    if (method == "" || StringLen(method) > 20) method = "Unknown";
    if (tf == "" || StringLen(tf) > 10) tf = "Current";

    double threshold = (GroupingFactorPct / 100.0) * price;
    double minThreshold = G_TickSize * GROUPING_MIN_TICKS;
    if (threshold < minThreshold) threshold = minThreshold;

    // Check for existing level within threshold
    for (int i = 0; i < G_TotalLevels; i++) {
        if (G_Levels[i].isSupport == isSupport && MathAbs(G_Levels[i].price - price) <= threshold) {
            // Merge logic
            G_Levels[i].touchCount += count;
            G_Levels[i].lastTested = time;
            if (strength > G_Levels[i].strength) {
                G_Levels[i].strength = strength;
                G_Levels[i].method = method;
                G_Levels[i].timeframe = tf;
            }
            if (time > G_Levels[i].firstTested) {
                G_Levels[i].firstTested = time;
            }
            // Weighted price adjustment for precision
            G_Levels[i].price = NormalizePrice((G_Levels[i].price * 0.7) + (price * 0.3));
            return;
        }
    }

    // Resize array if needed with error handling
    if (G_TotalLevels >= ArraySize(G_Levels)) {
        int newSize = G_TotalLevels + LEVEL_ARRAY_GROWTH;
        if (newSize > MAX_LEVELS_HARD_LIMIT) newSize = MAX_LEVELS_HARD_LIMIT;
        
        if (!ArrayResize(G_Levels, newSize)) {
            DebugPrint(DEBUG_BASIC, "AddLevel: Failed to resize array to " + IntegerToString(newSize));
            return;
        }
    }

    if (G_TotalLevels >= MAX_LEVELS_HARD_LIMIT) {
        DebugPrint(DEBUG_BASIC, "AddLevel: Maximum levels limit reached");
        return;
    }

    G_Levels[G_TotalLevels].price = price;
    G_Levels[G_TotalLevels].isSupport = isSupport;
    G_Levels[G_TotalLevels].strength = strength;
    G_Levels[G_TotalLevels].confluenceScore = 0;
    G_Levels[G_TotalLevels].timeframe = tf;
    G_Levels[G_TotalLevels].method = method;
    G_Levels[G_TotalLevels].firstTested = time;
    G_Levels[G_TotalLevels].lastTested = time;
    G_Levels[G_TotalLevels].touchCount = count;
    G_Levels[G_TotalLevels].bounceCount = 0;
    G_Levels[G_TotalLevels].breakCount = 0;
    G_Levels[G_TotalLevels].isVisible = false;
    G_Levels[G_TotalLevels].levelID = GetStableID(price, isSupport);
    G_Levels[G_TotalLevels].trend = 0;
    G_Levels[G_TotalLevels].isBroken = false;
    G_Levels[G_TotalLevels].breakTime = 0;
    G_Levels[G_TotalLevels].hasPinBar = false;
    G_Levels[G_TotalLevels].hasEngulfing = false;
    G_Levels[G_TotalLevels].signalTime = 0;
    G_Levels[G_TotalLevels].signalPrice = 0;

    // Calculate zone boundaries with dynamic adjustment
    double zoneHalfWidth = CalculateZoneWidth(price);
    if (zoneHalfWidth <= 0) zoneHalfWidth = G_TickSize * 5;
    
    double zoneTop = NormalizePrice(price + zoneHalfWidth);
    double zoneBottom = NormalizePrice(price - zoneHalfWidth);
    
    // Ensure zone boundaries are valid
    if (zoneTop <= zoneBottom) {
        zoneTop = price + G_TickSize * 5;
        zoneBottom = price - G_TickSize * 5;
    }
    
    G_Levels[G_TotalLevels].zoneTop = zoneTop;
    G_Levels[G_TotalLevels].zoneBottom = zoneBottom;

    G_TotalLevels++;
    G_LevelsChanged = true;
}

//+------------------------------------------------------------------+
//| Calculate dynamic zone width based on volatility                   |
//+------------------------------------------------------------------+
double CalculateZoneWidth(double price) {
    double baseWidth = (ZoneWidthPct / 100.0) * price;
    
    if (!DynamicZoneWidth) return baseWidth;
    
    // Adjust zone width based on recent volatility
    double volatilityRatio = G_AvgDailyRange > 0 ? (G_AvgDailyRange / price) : 0.01;
    double adjustedWidth = baseWidth * DynamicZoneMultiplier * (1.0 + volatilityRatio);
    
    // Ensure reasonable bounds
    double minWidth = G_TickSize * 5;
    double maxWidth = price * 0.02; // Max 2% of price
    
    return MathMax(minWidth, MathMin(maxWidth, adjustedWidth));
}

//+------------------------------------------------------------------+
//| Save levels to file for persistence                              |
//+------------------------------------------------------------------+
void SaveLevelsToFile() {
    if (!EnablePersistence || G_TotalLevels == 0) return;
    
    int handle = FileOpen(PERSISTENCE_FILE, FILE_WRITE | FILE_BIN);
    if (handle == INVALID_HANDLE) {
        DebugPrint(DEBUG_BASIC, "Failed to open persistence file for writing");
        return;
    }
    
    // Write header with version and timestamp
    FileWriteInteger(handle, 3); // Version 3
    FileWriteLong(handle, TimeCurrent());
    FileWriteInteger(handle, G_TotalLevels);
    
    // Write levels
    for (int i = 0; i < G_TotalLevels; i++) {
        FileWriteDouble(handle, G_Levels[i].price);
        FileWriteInteger(handle, G_Levels[i].isSupport ? 1 : 0);
        FileWriteDouble(handle, G_Levels[i].strength);
        FileWriteDouble(handle, G_Levels[i].confluenceScore);
        FileWriteString(handle, G_Levels[i].timeframe, 10);
        FileWriteString(handle, G_Levels[i].method, 20);
        FileWriteLong(handle, G_Levels[i].firstTested);
        FileWriteLong(handle, G_Levels[i].lastTested);
        FileWriteInteger(handle, G_Levels[i].touchCount);
        FileWriteInteger(handle, G_Levels[i].bounceCount);
        FileWriteInteger(handle, G_Levels[i].breakCount);
        FileWriteInteger(handle, G_Levels[i].isBroken ? 1 : 0);
        FileWriteDouble(handle, G_Levels[i].trend);
        FileWriteLong(handle, G_Levels[i].breakTime);
    }
    
    FileClose(handle);
    DebugPrint(DEBUG_BASIC, "Saved " + IntegerToString(G_TotalLevels) + " levels to persistence file");
}

//+------------------------------------------------------------------+
//| Load levels from file for persistence                              |
//+------------------------------------------------------------------+
void LoadLevelsFromFile() {
    if (!EnablePersistence) return;
    
    int handle = FileOpen(PERSISTENCE_FILE, FILE_READ | FILE_BIN);
    if (handle == INVALID_HANDLE) {
        DebugPrint(DEBUG_BASIC, "No persistence file found");
        return;
    }
    
    // Read header
    int version = FileReadInteger(handle);
    if (version != 3) {
        DebugPrint(DEBUG_BASIC, "Incompatible persistence file version: " + IntegerToString(version));
        FileClose(handle);
        return;
    }
    
    datetime fileTime = (datetime)FileReadLong(handle);
    int savedCount = FileReadInteger(handle);
    
    // Check if file is too old (older than 7 days)
    if (TimeCurrent() - fileTime > 7 * 24 * 3600) {
        DebugPrint(DEBUG_BASIC, "Persistence file too old, ignoring");
        FileClose(handle);
        return;
    }
    
    // Ensure array size
    if (savedCount > 0 && savedCount < MAX_LEVELS_HARD_LIMIT) {
        ArrayResize(G_Levels, savedCount);
        
        // Read levels
        for (int i = 0; i < savedCount; i++) {
            G_Levels[i].price = FileReadDouble(handle);
            G_Levels[i].isSupport = (FileReadInteger(handle) == 1);
            G_Levels[i].strength = FileReadDouble(handle);
            G_Levels[i].confluenceScore = FileReadDouble(handle);
            G_Levels[i].timeframe = FileReadString(handle, 10);
            G_Levels[i].method = FileReadString(handle, 20);
            G_Levels[i].firstTested = (datetime)FileReadLong(handle);
            G_Levels[i].lastTested = (datetime)FileReadLong(handle);
            G_Levels[i].touchCount = FileReadInteger(handle);
            G_Levels[i].bounceCount = FileReadInteger(handle);
            G_Levels[i].breakCount = FileReadInteger(handle);
            G_Levels[i].isBroken = (FileReadInteger(handle) == 1);
            G_Levels[i].trend = FileReadDouble(handle);
            G_Levels[i].breakTime = (datetime)FileReadLong(handle);
            
            // Initialize other fields
            G_Levels[i].isVisible = false;
            G_Levels[i].levelID = GetStableID(G_Levels[i].price, G_Levels[i].isSupport);
            G_Levels[i].hasPinBar = false;
            G_Levels[i].hasEngulfing = false;
            G_Levels[i].signalTime = 0;
            G_Levels[i].signalPrice = 0;
            
            // Recalculate zone boundaries
            double zoneHalfWidth = CalculateZoneWidth(G_Levels[i].price);
            G_Levels[i].zoneTop = NormalizePrice(G_Levels[i].price + zoneHalfWidth);
            G_Levels[i].zoneBottom = NormalizePrice(G_Levels[i].price - zoneHalfWidth);
        }
        
        G_TotalLevels = savedCount;
        DebugPrint(DEBUG_BASIC, "Loaded " + IntegerToString(savedCount) + " levels from persistence file");
    }
    
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool IsWithinTradingSession() {
    if (!SessionFilter) return true;
    
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    int currentHour = timeStruct.hour;

    if (SessionStartHour <= SessionEndHour) {
        return (currentHour >= SessionStartHour && currentHour <= SessionEndHour);
    } else {
        // Overnight session (e.g., 22:00 to 06:00)
        return (currentHour >= SessionStartHour || currentHour <= SessionEndHour);
    }
}

//+------------------------------------------------------------------+
//| Detection: Historical (Enhanced)                                  |
//+------------------------------------------------------------------+
void DetectHistorical(const double &high[], const double &low[], const datetime &time[], int total) {
    int lookback = MathMin(LookbackBars, total - 10);
    
    // Adaptive swing strength based on volatility
    int baseStrength = SWING_STRENGTH_DEFAULT;
    double volatility = CalculateVolatility(high, low, MathMin(100, total));
    int adaptiveStrength = (volatility > G_AvgDailyRange * 0.5) ? baseStrength + 1 : baseStrength;
    adaptiveStrength = MathMin(adaptiveStrength, 8); // Cap at 8 to avoid over-smoothing

    // Enhanced swing detection with volume confirmation
    for (int i = adaptiveStrength; i < lookback - adaptiveStrength && i + adaptiveStrength < total; i++) {
        bool isPeak = true, isTrough = true;
        double peakStrength = 0, troughStrength = 0;
        
        // Check swing points
        for (int j = 1; j <= adaptiveStrength; j++) {
            if (high[i] <= high[i-j] || high[i] <= high[i+j]) isPeak = false;
            if (low[i] >= low[i-j] || low[i] >= low[i+j]) isTrough = false;
            
            // Calculate strength based on how much the level stands out
            if (isPeak) {
                peakStrength += (high[i] - MathMax(high[i-j], high[i+j])) / G_Point;
            }
            if (isTrough) {
                troughStrength += (MathMin(low[i-j], low[i+j]) - low[i]) / G_Point;
            }
        }
        
        // Add levels with adaptive strength
        if (isPeak) {
            double strength = 1.5 + (peakStrength / adaptiveStrength) * 0.5;
            AddLevel(high[i], false, strength, "Current", "Swing", time[i]);
        }
        if (isTrough) {
            double strength = 1.5 + (troughStrength / adaptiveStrength) * 0.5;
            AddLevel(low[i], true, strength, "Current", "Swing", time[i]);
        }
    }

    DebugPrint(DEBUG_DETAILED, "Enhanced historical detection complete, adaptive strength: " + IntegerToString(adaptiveStrength));
}

//+------------------------------------------------------------------+
//| Calculate volatility for adaptive algorithms                     |
//+------------------------------------------------------------------+
double CalculateVolatility(const double &high[], const double &low[], int lookback) {
    if (lookback < 2) return 0;
    
    double sum = 0;
    for (int i = 0; i < lookback - 1; i++) {
        double range = high[i] - low[i];
        sum += range * range; // Sum of squared ranges
    }
    
    return MathSqrt(sum / (lookback - 1));
}

//+------------------------------------------------------------------+
//| Detection: Pivots (Enhanced)                                     |
//+------------------------------------------------------------------+
void DetectPivots() {
    MqlRates r[];
    int copied = CopyRates(_Symbol, PERIOD_D1, 0, 5, r);
    if (copied < 3) {
        DebugPrint(DEBUG_BASIC, "DetectPivots: Insufficient daily data (" + IntegerToString(copied) + " bars)");
        return;
    }
    ArraySetAsSeries(r, true);

    // Use previous day's data for more accurate pivots
    double range = r[1].high - r[1].low;
    if (range <= 0) return;

    double pp = (r[1].high + r[1].low + r[1].close) / 3.0;
    double close = r[0].close; // Current day's open/close

    // Standard pivots with adaptive strength based on previous day's range
    double rangeFactor = MathMin(range / G_AvgDailyRange, 2.0); // Cap at 2x ADR
    
    AddLevel(pp, (pp < close), 2.0 * rangeFactor, "D1", "Pivot PP", r[1].time);
    AddLevel(pp + range * PIVOT_FIB_1, false, 1.0 * rangeFactor, "D1", "Pivot R1", r[1].time);
    AddLevel(pp - range * PIVOT_FIB_1, true, 1.0 * rangeFactor, "D1", "Pivot S1", r[1].time);
    AddLevel(pp + range * PIVOT_FIB_2, false, 1.2 * rangeFactor, "D1", "Pivot R2", r[1].time);
    AddLevel(pp - range * PIVOT_FIB_2, true, 1.2 * rangeFactor, "D1", "Pivot S2", r[1].time);
    
    // Additional R3/S3 levels for wider ranges
    if (rangeFactor > 1.2) {
        AddLevel(pp + range, false, 0.8 * rangeFactor, "D1", "Pivot R3", r[1].time);
        AddLevel(pp - range, true, 0.8 * rangeFactor, "D1", "Pivot S3", r[1].time);
    }
    
    // Camarilla pivots for intraday precision
    double h = r[1].high, l = r[1].low, c = r[1].close;
    AddLevel(h + (h - l) * 1.1/12, false, 0.9, "D1", "Camarilla H1", r[1].time);
    AddLevel(h + (h - l) * 1.1/6, false, 0.9, "D1", "Camarilla H2", r[1].time);
    AddLevel(h + (h - l) * 1.1/4, false, 0.9, "D1", "Camarilla H3", r[1].time);
    AddLevel(h + (h - l) * 1.1/2, false, 0.9, "D1", "Camarilla H4", r[1].time);
    AddLevel(l - (h - l) * 1.1/12, true, 0.9, "D1", "Camarilla L1", r[1].time);
    AddLevel(l - (h - l) * 1.1/6, true, 0.9, "D1", "Camarilla L2", r[1].time);
    AddLevel(l - (h - l) * 1.1/4, true, 0.9, "D1", "Camarilla L3", r[1].time);
    AddLevel(l - (h - l) * 1.1/2, true, 0.9, "D1", "Camarilla L4", r[1].time);

    DebugPrint(DEBUG_DETAILED, "Enhanced pivot detection complete, range factor: " + DoubleToString(rangeFactor, 2));
}

//+------------------------------------------------------------------+
//| Detection: Fractals                                              |
//+------------------------------------------------------------------+
void DetectFractals(const double &high[], const double &low[], const datetime &time[], int total) {
    int lookback = MathMin(LookbackBars, total - 5);

    // Bounds-safe loop with additional safety check
    for (int i = FRACTAL_LOOKBACK; i < lookback - FRACTAL_LOOKBACK && i + FRACTAL_LOOKBACK < total; i++) {
        if (high[i] > high[i-1] && high[i] > high[i-2] && high[i] > high[i+1] && high[i] > high[i+2])
            AddLevel(high[i], false, 0.8, "Current", "Fractal", time[i]);
        if (low[i] < low[i-1] && low[i] < low[i-2] && low[i] < low[i+1] && low[i] < low[i+2])
            AddLevel(low[i], true, 0.8, "Current", "Fractal", time[i]);
    }

    DebugPrint(DEBUG_DETAILED, "Fractal detection complete");
}

//+------------------------------------------------------------------+
//| Detection: Round Numbers                                         |
//+------------------------------------------------------------------+
void DetectRoundNumbers(double price) {
    double p = MathPow(10, MathFloor(MathLog10(price)));
    double steps[3] = {p, p/2, p/4};

    for (int i = 0; i < 3; i++) {
        double step = steps[i];
        double base = MathFloor(price / step) * step;
        for (int j = -ROUND_NUM_RANGE; j <= ROUND_NUM_RANGE; j++) {
            double level = base + j * step;
            if (level <= 0) continue;
            AddLevel(level, (level < price), 1.2 - (i * 0.2), "Psy", "Round", TimeCurrent());
        }
    }

    DebugPrint(DEBUG_DETAILED, "Round number detection complete");
}

//+------------------------------------------------------------------+
//| Detection: Volume Profile (Enhanced)                             |
//+------------------------------------------------------------------+
void DetectVolume(const double &high[], const double &low[], const double &close[], const long &vol[], int total) {
    int lookback = MathMin(LookbackBars, total - 1);
    
    if (lookback < 10) {
        DebugPrint(DEBUG_BASIC, "DetectVolume: Insufficient data (" + IntegerToString(lookback) + " bars)");
        return;
    }
    
    // Validate volume data
    bool hasVolume = false;
    for (int i = 0; i < lookback && !hasVolume; i++) {
        if (vol[i] > 0) hasVolume = true;
    }
    if (!hasVolume) {
        DebugPrint(DEBUG_BASIC, "DetectVolume: No volume data available");
        return;
    }
    
    // Use safe array functions for min/max
    double minP = ArrayMinimumSafe(low, 0, lookback);
    double maxP = ArrayMaximumSafe(high, 0, lookback);
    
    if (maxP <= minP || maxP - minP < G_TickSize * 10) {
        DebugPrint(DEBUG_BASIC, "DetectVolume: Insufficient price range");
        return;
    }

    int bins = MathMin(VOLUME_BINS, lookback / 2); // Adjust bins based on data
    if (bins < 5) bins = 5;
    
    double step = (maxP - minP) / bins;
    if (step <= G_TickSize) {
        DebugPrint(DEBUG_BASIC, "DetectVolume: Step size too small");
        return;
    }
    
    double vBins[]; 
    if (!ArrayResize(vBins, bins)) {
        DebugPrint(DEBUG_BASIC, "DetectVolume: Failed to allocate volume bins");
        return;
    }
    ArrayInitialize(vBins, 0);
    
    double vHigh[]; ArrayResize(vHigh, bins); ArrayInitialize(vHigh, 0);
    double vLow[]; ArrayResize(vLow, bins); ArrayInitialize(vLow, DBL_MAX);
    long countBins[]; ArrayResize(countBins, bins); ArrayInitialize(countBins, 0);

    // Enhanced volume analysis with price range tracking
    for (int i = 0; i < lookback; i++) {
        int idx = (int)((close[i] - minP) / step);
        if (idx >= 0 && idx < bins) {
            vBins[idx] += (double)vol[i];
            vHigh[idx] = MathMax(vHigh[idx], high[i]);
            vLow[idx] = MathMin(vLow[idx], low[i]);
            countBins[idx]++;
        }
    }

    // Find Volume Point of Control (VPOC) - highest volume level
    double maxVolume = 0;
    int vpocIdx = -1;
    for (int i = 0; i < bins; i++) {
        if (vBins[i] > maxVolume) {
            maxVolume = vBins[i];
            vpocIdx = i;
        }
    }
    
    if (vpocIdx >= 0) {
        double vpocPrice = minP + vpocIdx * step + step / 2;
        double strength = 1.0 + (maxVolume / (lookback * 1000)) * 0.5; // Strength based on volume intensity
        AddLevel(vpocPrice, (vpocPrice < close[0]), strength, "Vol", "VPOC", TimeCurrent());
    }
    
    // Find Value Area High/Low (70% of total volume)
    double totalVolume = 0;
    for (int i = 0; i < bins; i++) totalVolume += vBins[i];
    
    if (totalVolume > 0) {
        double targetVolume = totalVolume * 0.7;
        double accumulatedVolume = 0;
        int vahIdx = -1, valIdx = -1;
        
        // Start from VPOC and expand outward
        if (vpocIdx >= 0) {
            accumulatedVolume = vBins[vpocIdx];
            
            // Expand up and down from VPOC
            for (int dist = 1; dist < bins && accumulatedVolume < targetVolume; dist++) {
                // Check upper side
                if (vpocIdx + dist < bins) {
                    accumulatedVolume += vBins[vpocIdx + dist];
                    if (vahIdx == -1 && accumulatedVolume >= targetVolume) vahIdx = vpocIdx + dist;
                }
                // Check lower side
                if (vpocIdx - dist >= 0) {
                    accumulatedVolume += vBins[vpocIdx - dist];
                    if (valIdx == -1 && accumulatedVolume >= targetVolume) valIdx = vpocIdx - dist;
                }
            }
            
            // Add Value Area levels
            if (vahIdx >= 0) {
                double vahPrice = minP + vahIdx * step + step / 2;
                AddLevel(vahPrice, (vahPrice < close[0]), 0.8, "Vol", "VAH", TimeCurrent());
            }
            if (valIdx >= 0) {
                double valPrice = minP + valIdx * step + step / 2;
                AddLevel(valPrice, (valPrice < close[0]), 0.8, "Vol", "VAL", TimeCurrent());
            }
        }
    }

    DebugPrint(DEBUG_DETAILED, "Enhanced volume profile detection complete");
}

//+------------------------------------------------------------------+
//| Detection: Order Blocks                                          |
//+------------------------------------------------------------------+
void DetectOrderBlocks(const double &high[], const double &low[], const double &open[], const double &close[], const datetime &time[], int total) {
    int lookback = MathMin(LookbackBars, total - 5);
    int obCount = 0;
    
    for (int i = 5; i < lookback; i++) {
        double range = high[i] - low[i];
        if (range <= 0) continue;
        
        bool isBearish = close[i] < open[i];
        bool isBullish = close[i] > open[i];
        
        // Look for strong imbalance in the next 1-3 candles
        double imbalanceUp = 0;
        double imbalanceDown = 0;
        
        for (int j = 1; j <= 3; j++) {
            if (i - j < 0) break;
            if (close[i-j] > open[i-j]) imbalanceUp += (close[i-j] - open[i-j]);
            if (close[i-j] < open[i-j]) imbalanceDown += (open[i-j] - close[i-j]);
        }
        
        // Bullish OB: Last bearish candle before strong up move
        if (isBearish && imbalanceUp > range * 2.0) {
            AddLevel(low[i], true, 3.5, "Current", "Bullish OB", time[i]);
            obCount++;
            i += 3; // Skip ahead to avoid multiple OBs in the same move
        }
        // Bearish OB: Last bullish candle before strong down move
        else if (isBullish && imbalanceDown > range * 2.0) {
            AddLevel(high[i], false, 3.5, "Current", "Bearish OB", time[i]);
            obCount++;
            i += 3;
        }
        
        if (obCount >= MaxLevelsPerType) break;
    }
    
    DebugPrint(DEBUG_DETAILED, "Order Block detection complete");
}

//+------------------------------------------------------------------+
//| Detection: HTF (with caching)                                    |
//+------------------------------------------------------------------+
void DetectHTF(ENUM_TIMEFRAMES tf, string label, MqlRates &cachedRates[], datetime &cacheTime) {
    if (tf == _Period || tf == PERIOD_CURRENT) return;

    // Use cached data if recent (< 60 seconds)
    datetime now = TimeCurrent();
    bool useCache = (now - cacheTime < 60) && ArraySize(cachedRates) > 10;
    
    if (!useCache) {
        int copied = CopyRates(_Symbol, tf, 0, LookbackBars, cachedRates);
        if (copied < HTF_SWING_LOOKBACK * 2 + 1) return;
        ArraySetAsSeries(cachedRates, true);
        cacheTime = now;
    }

    int copied = ArraySize(cachedRates);
    double tfMult = 1.0;
    if (tf >= PERIOD_D1) tfMult = 2.0;
    else if (tf >= PERIOD_H1) tfMult = 1.5;

    int levelsAdded = 0;
    for (int i = HTF_SWING_LOOKBACK; i < copied - HTF_SWING_LOOKBACK && levelsAdded < MaxLevelsPerType; i++) {
        if (cachedRates[i].high > cachedRates[i-1].high && cachedRates[i].high > cachedRates[i-2].high && cachedRates[i].high > cachedRates[i-3].high &&
            cachedRates[i].high > cachedRates[i+1].high && cachedRates[i].high > cachedRates[i+2].high && cachedRates[i].high > cachedRates[i+3].high) {
            AddLevel(cachedRates[i].high, false, 1.2 * tfMult, EnumToString(tf), "HTF Swing", cachedRates[i].time);
            levelsAdded++;
        }
        if (cachedRates[i].low < cachedRates[i-1].low && cachedRates[i].low < cachedRates[i-2].low && cachedRates[i].low < cachedRates[i-3].low &&
            cachedRates[i].low < cachedRates[i+1].low && cachedRates[i].low < cachedRates[i+2].low && cachedRates[i].low < cachedRates[i+3].low) {
            AddLevel(cachedRates[i].low, true, 1.2 * tfMult, EnumToString(tf), "HTF Swing", cachedRates[i].time);
            levelsAdded++;
        }
    }

    DebugPrint(DEBUG_DETAILED, "HTF " + label + " detection complete, added " + IntegerToString(levelsAdded) + " levels");
}

//+------------------------------------------------------------------+
//| Detect Price Action Signals                                      |
//+------------------------------------------------------------------+
void DetectPriceActionSignals(const double &high[], const double &low[], const double &open[], 
                               const double &close[], const datetime &time[], int total) {
    if (total < 3) return;
    
    // Reset signals
    for (int i = 0; i < G_TotalLevels; i++) {
        G_Levels[i].hasPinBar = false;
        G_Levels[i].hasEngulfing = false;
    }
    
    // Check last 3 bars for signals near levels
    int checkBars = MathMin(3, total - 1);
    for (int bar = 0; bar < checkBars; bar++) {
        double body = MathAbs(close[bar] - open[bar]);
        double range = high[bar] - low[bar];
        if (range <= 0) continue;
        
        for (int i = 0; i < G_TotalLevels; i++) {
            double threshold = range * 0.3; // Signal if within 30% of bar range
            
            if (MathAbs(G_Levels[i].price - close[bar]) > threshold) continue;
            
            // Pin bar detection
            double upperWick = high[bar] - MathMax(open[bar], close[bar]);
            double lowerWick = MathMin(open[bar], close[bar]) - low[bar];
            
            if (G_Levels[i].isSupport && lowerWick > body * 2 && upperWick < body) {
                G_Levels[i].hasPinBar = true;
                G_Levels[i].signalTime = time[bar];
                G_Levels[i].signalPrice = close[bar];
            }
            if (!G_Levels[i].isSupport && upperWick > body * 2 && lowerWick < body) {
                G_Levels[i].hasPinBar = true;
                G_Levels[i].signalTime = time[bar];
                G_Levels[i].signalPrice = close[bar];
            }
            
            // Engulfing detection
            if (bar + 1 < total) {
                double prevBody = MathAbs(close[bar+1] - open[bar+1]);
                bool bullishEngulf = (close[bar] > open[bar]) && (close[bar+1] < open[bar+1]) && 
                                    (close[bar] >= open[bar+1]) && (open[bar] <= close[bar+1]);
                bool bearishEngulf = (close[bar] < open[bar]) && (close[bar+1] > open[bar+1]) && 
                                    (open[bar] >= close[bar+1]) && (close[bar] <= open[bar+1]);
                
                if (G_Levels[i].isSupport && bullishEngulf && body > prevBody) {
                    G_Levels[i].hasEngulfing = true;
                    G_Levels[i].signalTime = time[bar];
                    G_Levels[i].signalPrice = close[bar];
                }
                if (!G_Levels[i].isSupport && bearishEngulf && body > prevBody) {
                    G_Levels[i].hasEngulfing = true;
                    G_Levels[i].signalTime = time[bar];
                    G_Levels[i].signalPrice = close[bar];
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Strength (with confluence scoring)                     |
//+------------------------------------------------------------------+
void CalculateStrengths(double close) {
    datetime now = TimeCurrent();
    double range = G_AvgDailyRange > 0 ? G_AvgDailyRange : G_TickSize * 100;
    
    // Early exit if no levels
    if (G_TotalLevels == 0) return;
    
    // Cache frequently used values
    double staleSecPerDay = STALE_LEVEL_SEC_PER_DAY;
    double confluenceDistancePct = CONFLUENCE_DISTANCE_PCT;

    // Spatial hashing for confluence check (cached values)
    double bucketSize = range * confluenceDistancePct;
    if (bucketSize <= 0) bucketSize = G_TickSize * 10;
    
    // Find minimum price to use as baseline
    double minLevelPrice = DBL_MAX;
    for (int i = 0; i < G_TotalLevels; i++) {
        if (G_Levels[i].price < minLevelPrice) minLevelPrice = G_Levels[i].price;
    }

    int bucketCount = (int)(G_TotalLevels / SPATIAL_HASH_DIVISOR) + 1;
    if (bucketCount < 1) bucketCount = 1;
    int buckets[];
    ArrayResize(buckets, bucketCount);
    ArrayInitialize(buckets, -1);

    int nextInBucket[];
    ArrayResize(nextInBucket, G_TotalLevels);
    ArrayInitialize(nextInBucket, -1);

    // Build spatial hash
    for (int i = 0; i < G_TotalLevels; i++) {
        int bucketIdx = 0;
        if (bucketSize > 0) bucketIdx = (int)((G_Levels[i].price - minLevelPrice) / bucketSize);
        if (bucketIdx < 0) bucketIdx = 0;
        if (bucketIdx >= bucketCount) bucketIdx = bucketCount - 1;

        nextInBucket[i] = buckets[bucketIdx];
        buckets[bucketIdx] = i;
    }

    for (int i = 0; i < G_TotalLevels; i++) {
        double s = G_Levels[i].strength;
        int methodCount = 1;

        // 1. Touches
        s += MathMin(G_Levels[i].touchCount * 0.1, 1.0);

        // 2. Recency (cached calculation)
        double ageDays = (double)(now - G_Levels[i].firstTested) / staleSecPerDay;
        if (ageDays < 1.0) s += 0.5;
        else if (ageDays < 7.0) s += 0.2;

        // 3. Confluence (spatial hash optimized)
        int bucketIdx = 0;
        if (bucketSize > 0) bucketIdx = (int)((G_Levels[i].price - minLevelPrice) / bucketSize);
        if (bucketIdx < 0) bucketIdx = 0;
        if (bucketIdx >= bucketCount) bucketIdx = bucketCount - 1;

        int confluenceMethods = 0;
        string methods[10];
        methods[0] = G_Levels[i].method;
        confluenceMethods++;
        
        for (int b = MathMax(0, bucketIdx - 1); b <= MathMin(bucketCount - 1, bucketIdx + 1); b++) {
            int j = buckets[b];
            while (j != -1) {
                if (i != j && MathAbs(G_Levels[i].price - G_Levels[j].price) < bucketSize) {
                    // Check if method already counted
                    bool found = false;
                    for (int m = 0; m < confluenceMethods; m++) {
                        if (methods[m] == G_Levels[j].method) { found = true; break; }
                    }
                    if (!found && confluenceMethods < 10) {
                        methods[confluenceMethods++] = G_Levels[j].method;
                        s += 0.3;
                    }
                }
                j = nextInBucket[j];
            }
        }
        
        // NEW: Confluence score (0-100)
        G_Levels[i].confluenceScore = (double)(confluenceMethods - 1) / 9.0 * 100.0;

        // 4. Bounce history bonus
        s += MathMin(G_Levels[i].bounceCount * 0.2, 1.5);

        G_Levels[i].strength = s;
    }

    DebugPrint(DEBUG_DETAILED, "Strength calculation complete");
}

//+------------------------------------------------------------------+
//| Remove stale levels                                              |
//+------------------------------------------------------------------+
void RemoveStaleLevels(datetime now) {
    if (StaleLevelDays <= 0) return;

    int writeIdx = 0;
    double maxAgeSec = StaleLevelDays * STALE_LEVEL_SEC_PER_DAY;

    for (int i = 0; i < G_TotalLevels; i++) {
        double ageSec = (double)(now - G_Levels[i].firstTested);
        if (ageSec < maxAgeSec) {
            if (writeIdx != i) {
                G_Levels[writeIdx] = G_Levels[i];
            }
            writeIdx++;
        }
    }

    if (writeIdx < G_TotalLevels) {
        DebugPrint(DEBUG_BASIC, "Removed " + IntegerToString(G_TotalLevels - writeIdx) + " stale levels");
        G_TotalLevels = writeIdx;
    }
}

//+------------------------------------------------------------------+
//| Update trends at levels                                          |
//+------------------------------------------------------------------+
void UpdateTrends(const double &high[], const double &low[], const double &close[], int total) {
    if (!DetectTrends || total < TREND_LOOKBACK + 1) return;

    int lookback = MathMin(TREND_LOOKBACK, total - 1);

    for (int i = 0; i < G_TotalLevels; i++) {
        int aboveCount = 0;
        for (int j = 0; j < lookback; j++) {
            if (close[j] > G_Levels[i].price) aboveCount++;
        }

        double ratio = (double)aboveCount / lookback;
        if (ratio > TREND_RISING_RATIO) G_Levels[i].trend = 1.0;
        else if (ratio < TREND_FALLING_RATIO) G_Levels[i].trend = -1.0;
        else G_Levels[i].trend = 0;
    }
}

//+------------------------------------------------------------------+
//| Filter and Sort                                                  |
//+------------------------------------------------------------------+
void FilterAndVisible(double close) {
    LevelScore sDesc[], rDesc[];
    int sCount = 0, rCount = 0;

    ArrayResize(sDesc, G_TotalLevels);
    ArrayResize(rDesc, G_TotalLevels);

    double minS = ShowOnlyStrongLevels ? 2.0 : 0.0;

    for (int i = 0; i < G_TotalLevels; i++) {
        G_Levels[i].isVisible = false;
        if (G_Levels[i].strength < minS) continue;

        double dist = MathAbs(G_Levels[i].price - close);

        // Safe division
        double adr = (G_AvgDailyRange > 0) ? G_AvgDailyRange : G_TickSize * 100;
        double score = (dist / adr) - (G_Levels[i].strength * 0.2);

        if (G_Levels[i].isSupport && G_Levels[i].price < close) {
            sDesc[sCount].index = i;
            sDesc[sCount].score = score;
            sCount++;
        } else if (!G_Levels[i].isSupport && G_Levels[i].price > close) {
            rDesc[rCount].index = i;
            rDesc[rCount].score = score;
            rCount++;
        }
    }

    // Sort and mark visible
    SortScores(sDesc, sCount);
    SortScores(rDesc, rCount);

    for (int i = 0; i < MathMin(sCount, MaxLevels); i++) G_Levels[sDesc[i].index].isVisible = true;
    for (int i = 0; i < MathMin(rCount, MaxLevels); i++) G_Levels[rDesc[i].index].isVisible = true;

    DebugPrint(DEBUG_DETAILED, "Filter complete: " + IntegerToString(sCount) + " supports, " + IntegerToString(rCount) + " resistances");
}

void SortScores(LevelScore &arr[], int size) {
    for (int i = 0; i < size - 1; i++) {
        for (int j = i + 1; j < size; j++) {
            if (arr[j].score < arr[i].score) {
                LevelScore tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Objects                                                   |
//+------------------------------------------------------------------+
void UpdateObjects(datetime currentTime, double currentPrice) {
    // Reset active tracking
    G_ActiveObjectCount = 0;
    ArrayResize(G_ActiveObjects, G_TotalLevels * 3);
    ArrayInitialize(G_ObjectCleanupMap, false);

    bool showZones = (DisplayMode == DISPLAY_ZONES);

    // NEW: track Y coordinates for anti-overlap
    int usedY[];
    int usedYCount = 0;
    ArrayResize(usedY, MaxLevels * 2 + 10);

    for (int i = 0; i < G_TotalLevels; i++) {
        if (!G_Levels[i].isVisible) continue;

        string name = ObjectPrefix + IntegerToString(G_Levels[i].levelID);
        color clr = G_Levels[i].isSupport ? SupportColor : ResistanceColor;

        // Fade broken levels
        if (G_Levels[i].isBroken) {
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
        }

        // Check if level has been broken
        CheckLevelBreak(i, currentPrice, currentTime);

        // Zone display
        if (showZones) {
            string zoneName = name + "_Zone";
            datetime zoneEndTime = currentTime + PeriodSeconds(_Period) * 10;
            
            if (ObjectFind(0, zoneName) < 0) {
                ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, currentTime, G_Levels[i].zoneTop, zoneEndTime, G_Levels[i].zoneBottom);
            } else {
                ObjectMove(0, zoneName, 0, currentTime, G_Levels[i].zoneTop);
                ObjectMove(0, zoneName, 1, zoneEndTime, G_Levels[i].zoneBottom);
            }
            ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);

            AddActiveObject(zoneName);
        }

        // Horizontal line
        if (ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_HLINE, 0, 0, G_Levels[i].price);
        }
        
        int drawWidth = LineWidth;
        ENUM_LINE_STYLE drawStyle = LineStyle;
        if (G_Levels[i].strength >= 4.0) {
            if (drawStyle == STYLE_SOLID) drawWidth = LineWidth + 2;
        } else if (G_Levels[i].strength >= 3.0) {
            if (drawStyle == STYLE_SOLID) drawWidth = LineWidth + 1;
        } else if (G_Levels[i].strength < 2.0) {
            drawWidth = 1;
            drawStyle = STYLE_DOT;
        }

        // In MetaTrader, dotted/dashed styles only show when line width is 1
        if (drawStyle != STYLE_SOLID) drawWidth = 1;

        ObjectSetDouble(0, name, OBJPROP_PRICE, G_Levels[i].price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, drawStyle);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, drawWidth);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

        // Tooltip with optimized string building
        string tooltip;
        StringConcatenate(tooltip, G_Levels[i].method, " (", G_Levels[i].timeframe, ")",
                         "\nStrength: ", DoubleToString(G_Levels[i].strength, 1),
                         "\nTouches: ", G_Levels[i].touchCount,
                         "\nBounces: ", G_Levels[i].bounceCount,
                         "\nConfluence: ", DoubleToString(G_Levels[i].confluenceScore, 0), "%");
        if (G_Levels[i].trend != 0) {
            tooltip += "\nTrend: " + (G_Levels[i].trend > 0 ? "Rising" : "Falling");
        }
        if (G_Levels[i].isBroken) {
            tooltip += "\nBROKEN " + IntegerToString(G_Levels[i].breakCount) + "x";
        }
        if (G_Levels[i].hasPinBar) tooltip += "\n📌 Pin Bar";
        if (G_Levels[i].hasEngulfing) tooltip += "\n📊 Engulfing";
        
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);

        AddActiveObject(name);

        // Price Label
        if (ShowLabels) {
            string lblName = name + "_L";
            if (ObjectFind(0, lblName) < 0) {
                ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
            }

            // Build label text
            string txt = DoubleToString(G_Levels[i].price, G_Digits);

            if (ShowStrength) {
                int stars = (int)MathMin(G_Levels[i].strength, 5.0);
                string starTxt = " ";
                for (int k = 0; k < stars; k++) starTxt += "★";
                txt += starTxt;
            }

            // Use proper support/resistance indicator and method abbreviation
            string srIndicator = G_Levels[i].isSupport ? "S" : "R";
            string methodAbbr = "";
            
            // Create method abbreviations
            if (G_Levels[i].method == "Swing") methodAbbr = "Sw";
            else if (G_Levels[i].method == "Pivot PP") methodAbbr = "PP";
            else if (G_Levels[i].method == "Pivot R1") methodAbbr = "R1";
            else if (G_Levels[i].method == "Pivot S1") methodAbbr = "S1";
            else if (G_Levels[i].method == "Pivot R2") methodAbbr = "R2";
            else if (G_Levels[i].method == "Pivot S2") methodAbbr = "S2";
            else if (G_Levels[i].method == "Pivot R3") methodAbbr = "R3";
            else if (G_Levels[i].method == "Pivot S3") methodAbbr = "S3";
            else if (G_Levels[i].method == "Fractal") methodAbbr = "Fr";
            else if (G_Levels[i].method == "Round") methodAbbr = "Rn";
            else if (G_Levels[i].method == "VPOC") methodAbbr = "VP";
            else if (G_Levels[i].method == "VAH") methodAbbr = "VH";
            else if (G_Levels[i].method == "VAL") methodAbbr = "VL";
            else if (StringFind(G_Levels[i].method, "Camarilla") >= 0) methodAbbr = "Cam";
            else if (StringFind(G_Levels[i].method, "HTF") >= 0) methodAbbr = "HT";
            else if (StringFind(G_Levels[i].method, "OB") >= 0) methodAbbr = "OB";
            else methodAbbr = StringSubstr(G_Levels[i].method, 0, 2);
            
            txt += " " + srIndicator + "[" + methodAbbr + "]";

            if (DetectTrends && G_Levels[i].trend != 0) {
                txt += (G_Levels[i].trend > 0 ? " ▲" : " ▼");
            }
            
            if (ShowPriceActionSignals) {
                if (G_Levels[i].hasPinBar) txt += " 📌";
                if (G_Levels[i].hasEngulfing) txt += " 📊";
            }

            // Position label
            int x, y;
            if (ChartTimePriceToXY(0, 0, currentTime, G_Levels[i].price, x, y)) {
                // Anti-overlap logic
                bool collision = true;
                int maxIterations = 10;
                while (collision && maxIterations > 0) {
                    collision = false;
                    for (int uy = 0; uy < usedYCount; uy++) {
                        if (MathAbs(y - usedY[uy]) < 15) {
                            y += (y >= usedY[uy]) ? 15 : -15;
                            collision = true;
                            break;
                        }
                    }
                    maxIterations--;
                }
                if (usedYCount < ArraySize(usedY)) usedY[usedYCount++] = y;

                ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 150);
                ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, y);
            } else {
                ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 150);
                ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, 50 + (i * 20));
            }

            ObjectSetString(0, lblName, OBJPROP_TEXT, txt);
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, LabelFontSize);
            ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
            ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);

            AddActiveObject(lblName);
        }
    }

    // Cleanup old objects using optimized hash tracking
    int total = ObjectsTotal(0, 0, -1);
    int deletedCount = 0;
    
    for (int i = total - 1; i >= 0; i--) {
        string n = ObjectName(0, i, -1);
        if (StringFind(n, ObjectPrefix) == 0) {
            uint hash = StringHash(n);
            if (!IsObjectActive(n, hash)) {
                ObjectDelete(0, n);
                deletedCount++;
                // Clear hash map entry
                if (hash < OBJ_CLEANUP_HASH_SIZE) G_ObjectCleanupMap[hash] = false;
            }
        }
    }
    
    if (deletedCount > 0) {
        DebugPrint(DEBUG_DETAILED, "Cleaned up " + IntegerToString(deletedCount) + " old objects");
    }
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Check if level has been broken                                   |
//+------------------------------------------------------------------+
void CheckLevelBreak(int levelIdx, double currentPrice, datetime currentTime) {
    if (G_Levels[levelIdx].isBroken) return;

    double threshold = G_TickSize * BREAK_THRESHOLD_TICKS;

    if (G_Levels[levelIdx].isSupport && currentPrice < G_Levels[levelIdx].price - threshold) {
        G_Levels[levelIdx].isBroken = true;
        G_Levels[levelIdx].breakTime = currentTime;
        G_Levels[levelIdx].breakCount++;
        DebugPrint(DEBUG_BASIC, "Support broken: " + DoubleToString(G_Levels[levelIdx].price, G_Digits));
    } else if (!G_Levels[levelIdx].isSupport && currentPrice > G_Levels[levelIdx].price + threshold) {
        G_Levels[levelIdx].isBroken = true;
        G_Levels[levelIdx].breakTime = currentTime;
        G_Levels[levelIdx].breakCount++;
        DebugPrint(DEBUG_BASIC, "Resistance broken: " + DoubleToString(G_Levels[levelIdx].price, G_Digits));
    }
}

//+------------------------------------------------------------------+
//| Check Alerts                                                     |
//+------------------------------------------------------------------+
void CheckAlerts(double close, datetime currentTime) {
    if (TimeCurrent() - G_LastAlertTime < ALERT_COOLDOWN_SEC) return;

    double threshold = (AlertDistancePct / 100.0) * G_AvgDailyRange;
    if (threshold <= 0) threshold = G_TickSize * 10;

    for (int i = 0; i < G_TotalLevels; i++) {
        if (!G_Levels[i].isVisible) continue;

        double dist = MathAbs(G_Levels[i].price - close);
        bool trigger = false;
        string alertMsg = "";

        if (AlertMode == ALERT_MODE_APPROACH && dist <= threshold) {
            StringConcatenate(alertMsg, _Symbol, ": ", EnumToString(_Period), 
                           " approaching ", (G_Levels[i].isSupport ? "Support" : "Resistance"),
                           " at ", DoubleToString(G_Levels[i].price, G_Digits));
            trigger = true;
        } else if (AlertMode == ALERT_MODE_BREAK && G_Levels[i].isBroken) {
            if (G_LastAlertPrice != G_Levels[i].price) {
                StringConcatenate(alertMsg, _Symbol, ": ", EnumToString(_Period),
                               " ", (G_Levels[i].isSupport ? "Support" : "Resistance"),
                               " BROKEN at ", DoubleToString(G_Levels[i].price, G_Digits));
                trigger = true;
                G_LastAlertPrice = G_Levels[i].price;
            }
        } else if (AlertMode == ALERT_MODE_BOUNCE && dist <= threshold) {
            if (G_Levels[i].touchCount >= BOUNCE_MIN_TOUCHES) {
                StringConcatenate(alertMsg, _Symbol, ": ", EnumToString(_Period),
                               " bounce off ", (G_Levels[i].isSupport ? "Support" : "Resistance"),
                               " at ", DoubleToString(G_Levels[i].price, G_Digits));
                trigger = true;
            }
        }

        if (trigger && alertMsg != "") {
            if (AlertType == ALERT_TYPE_ALERT) Alert(alertMsg);
            else if (AlertType == ALERT_TYPE_PUSH) SendNotification(alertMsg);
            else if (AlertType == ALERT_TYPE_EMAIL) SendMail("SR Level Alert", alertMsg);

            G_LastAlertTime = TimeCurrent();
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Update Statistics Panel                                          |
//+------------------------------------------------------------------+
void UpdateStatsPanel(datetime currentTime, double currentPrice) {
    if (!ShowStatsPanel) return;

    if (TimeCurrent() - G_StatsPanelUpdate < STATS_PANEL_UPDATE_SEC) return;
    G_StatsPanelUpdate = TimeCurrent();

    string panelName = STATS_PANEL_NAME;
    if (ObjectFind(0, panelName) < 0) {
        ObjectCreate(0, panelName, OBJ_LABEL, 0, 0, 0);
    }

    int visibleSupports = 0, visibleResistances = 0;
    double avgStrength = 0;
    int strengthCount = 0;
    int totalBounces = 0;
    int totalBreaks = 0;

    for (int i = 0; i < G_TotalLevels; i++) {
        if (G_Levels[i].isVisible) {
            if (G_Levels[i].isSupport) visibleSupports++;
            else visibleResistances++;
            avgStrength += G_Levels[i].strength;
            strengthCount++;
            totalBounces += G_Levels[i].bounceCount;
            totalBreaks += G_Levels[i].breakCount;
        }
    }

    if (strengthCount > 0) avgStrength /= strengthCount;

    string txt;
    StringConcatenate(txt, "═══ SR Levels Stats ═══\n",
                      "Symbol: ", _Symbol, "\n",
                      "Price: ", DoubleToString(currentPrice, G_Digits), "\n",
                      "───────────────────\n",
                      "Total Levels: ", G_TotalLevels, "\n",
                      "Supports: ", visibleSupports, "\n",
                      "Resistances: ", visibleResistances, "\n",
                      "Avg Strength: ", DoubleToString(avgStrength, 1), "\n",
                      "Total Bounces: ", totalBounces, "\n",
                      "Total Breaks: ", totalBreaks, "\n",
                      "ADR: ", DoubleToString(G_AvgDailyRange, G_Digits), "\n",
                      "═══════════════════");

    ObjectSetString(0, panelName, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, panelName, OBJPROP_COLOR, StatsPanelTextColor);
    ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Export levels to Global Variables (EA API)                       |
//+------------------------------------------------------------------+
void ExportToGlobalVariables() {
    if (!EnableEAAPI) return;
    
    // Export level count
    GlobalVariableSet(GLOBAL_VAR_PREFIX + "Count", G_TotalLevels);
    
    for (int i = 0; i < G_TotalLevels; i++) {
        string base = GLOBAL_VAR_PREFIX + IntegerToString(i) + "_";
        GlobalVariableSet(base + "Price", G_Levels[i].price);
        GlobalVariableSet(base + "IsSupport", G_Levels[i].isSupport ? 1 : 0);
        GlobalVariableSet(base + "Strength", G_Levels[i].strength);
        GlobalVariableSet(base + "Confluence", G_Levels[i].confluenceScore);
        GlobalVariableSet(base + "TouchCount", G_Levels[i].touchCount);
        GlobalVariableSet(base + "BounceCount", G_Levels[i].bounceCount);
        GlobalVariableSet(base + "BreakCount", G_Levels[i].breakCount);
        GlobalVariableSet(base + "IsBroken", G_Levels[i].isBroken ? 1 : 0);
        GlobalVariableSet(base + "Trend", G_Levels[i].trend);
        GlobalVariableSet(base + "HasPinBar", G_Levels[i].hasPinBar ? 1 : 0);
        GlobalVariableSet(base + "HasEngulfing", G_Levels[i].hasEngulfing ? 1 : 0);
    }
}

//+------------------------------------------------------------------+
//| Export levels to CSV                                             |
//+------------------------------------------------------------------+
void ExportToCSV() {
    if (!EnableCSVExport || G_TotalLevels == 0) return;
    
    int handle = FileOpen(CSV_EXPORT_FILE, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
    if (handle == INVALID_HANDLE) {
        DebugPrint(DEBUG_BASIC, "Failed to open CSV file");
        return;
    }
    
    // Header
    FileWrite(handle, "Price", "IsSupport", "Strength", "Confluence%", "Method", "Timeframe", 
              "Touches", "Bounces", "Breaks", "IsBroken", "Trend", "PinBar", "Engulfing");
    
    // Data
    for (int i = 0; i < G_TotalLevels; i++) {
        FileWrite(handle,
            G_Levels[i].price,
            G_Levels[i].isSupport ? "Support" : "Resistance",
            G_Levels[i].strength,
            G_Levels[i].confluenceScore,
            G_Levels[i].method,
            G_Levels[i].timeframe,
            G_Levels[i].touchCount,
            G_Levels[i].bounceCount,
            G_Levels[i].breakCount,
            G_Levels[i].isBroken ? "Yes" : "No",
            G_Levels[i].trend,
            G_Levels[i].hasPinBar ? "Yes" : "No",
            G_Levels[i].hasEngulfing ? "Yes" : "No"
        );
    }
    
    FileClose(handle);
    DebugPrint(DEBUG_BASIC, "CSV exported: " + CSV_EXPORT_FILE);
}

//+------------------------------------------------------------------+
//| Check if CSV export is due                                       |
//+------------------------------------------------------------------+
void CheckCSVExport(datetime now) {
    if (now - G_LastCSVExport >= CSVExportInterval) {
        ExportToCSV();
        G_LastCSVExport = now;
    }
}

//+------------------------------------------------------------------+
//| Timer                                                            |
//+------------------------------------------------------------------+
void OnTimer() {
    // Force recalculation on timer
    G_LastFullRecalc = 0;
    ChartRedraw();
}
//+------------------------------------------------------------------+
