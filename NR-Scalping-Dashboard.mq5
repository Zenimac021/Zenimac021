//+------------------------------------------------------------------+
//|                              NR-Scalping Dashboard v3.14.mq5     |
//|                                               Copyright 2026     |
//|                                         https://www.mql5.com     |
//|  FIXED & DEBUGGED VERSION - Complete Implementation               |
//+------------------------------------------------------------------+
#property copyright "NR-Scalping Dashboard v3.14"
#property link      "https://www.mql5.com"
#property version   "3.14"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//─────────────────────────────────────────────────────────────────
// ENUMS
//─────────────────────────────────────────────────────────���───────
enum ENUM_SIGNAL_DIR {
   SIG_DIR_BOTH = 0,    // All Signals
   SIG_DIR_BUY  = 1,    // Buy Only
   SIG_DIR_SELL = 2     // Sell Only
};

enum ENUM_BROKER_PROFILE {
   BROKER_TIGHT = 0,    // Low spread broker / ECN
   BROKER_STANDARD = 1, // Average retail broker
   BROKER_WIDE = 2      // Wider spread broker
};

//─────────────────────────────────────────────────────────────────
// INPUT PARAMETERS - OPTIMIZED FOR GOLD (XAU/USD) M5 SCALPING
//─────────────────────────────────────────────────────────────────
input group "Moving Averages"
input int             Inp_MA_Fast       = 13;          // Fast EMA (Quick momentum shift)
input int             Inp_MA_Slow       = 34;          // Slow EMA (Intraday dynamic support)
input int             Inp_MA_Major      = 200;         // Major Trend Anchor
input ENUM_TIMEFRAMES Inp_MA_Major_TF   = PERIOD_M30;  // 30-Minute macro trend alignment

input group "Oscillators"
input int             Inp_RSI_Period    = 7;           // Fast RSI for crisp Gold turnaround spikes
input double          Inp_RSI_OB        = 76.0;        // Tuned to 76 to avoid early shorting on vertical trends
input double          Inp_RSI_OS        = 24.0;        // Tuned to 24 to avoid catching falling knives
input int             Inp_Stoch_K       = 8;           // Smoothed K for rapid M5 cycle execution
input int             Inp_Stoch_D       = 3;           
input int             Inp_Stoch_Slowing = 3;           
input int             Inp_MACD_Fast     = 12;          
input int             Inp_MACD_Slow     = 26;          
input int             Inp_MACD_Signal   = 9;           

input group "Volatility & Trend"
input int             Inp_BB_Period     = 20;          
input double          Inp_BB_Dev        = 2.3;         // Raised to 2.3 to clear standard Gold intraday noise
input int             Inp_ADX_Period    = 14;          
input int             Inp_ATR_Period    = 14;          
input int             Inp_WPR_Period    = 9;           
input int             Inp_CCI_Period    = 20;          

input group "Alerts"
input bool            Inp_Alert_Popup   = true;        
input bool            Inp_Alert_Sound   = false;       
input string          Inp_Alert_Sound_File = "alert.wav"; 
input bool            Inp_Alert_Push    = false;       
input bool            Inp_Alert_Email   = false;       
input int             Inp_Alert_MinBars = 5;           

input group "Scalping Filters"
input ENUM_BROKER_PROFILE Inp_Broker_Profile = BROKER_STANDARD; 
input int             Inp_Max_Spread    = 600;         // Raised to 600 points ($0.60 spread ceiling) for NY session
input bool            Inp_Use_Adaptive_Spread = true;  
input double          Inp_Max_Spread_ATR_Ratio = 0.08; // Expanded slightly to ensure execution on volatile M5 entries
input int             Inp_Start_Hour    = 7;           // Shifted to 7 UTC to capture pre-London volume injection
input int             Inp_End_Hour      = 17;          // Kept at 17 UTC to miss late NY illiquid washouts
input double          Inp_Max_Wick_Body_Ratio = 3.5;   
input int             Inp_Min_Consec_Bars = 1;         
input double          Inp_Min_RR_Ratio  = 1.5;         
input bool            Inp_Vol_Adapt_SL  = true;        
input int             Inp_Avg_Tick_Vol_Period = 20;    

input group "Dashboard Settings"
input int             Inp_X_Offset      = 10;
input int             Inp_Y_Offset      = 80;
input bool            Inp_Pro_Mode      = true;        
input ENUM_SIGNAL_DIR Inp_Signal_Dir    = SIG_DIR_BOTH;
input int             Inp_Update_Interval = 0;         // Every tick processing for execution accuracy

//─────────────────────────────────────────────────────────────────
// NAMED CONSTANTS - CRITICAL CORRECTIONS FOR GOLD ASSET CLASS
//─────────────────────────────────────────────────────────────────
// RSI Trend Pullback Boundaries
const double RSI_TREND_UP_PULLBACK_LOW    = 42.0;      // Shifted upward to fit Gold's strong structural bids
const double RSI_TREND_UP_PULLBACK_HIGH   = 55.0;      
const double RSI_TREND_DN_BOUNCE_LOW      = 45.0;      
const double RSI_TREND_DN_BOUNCE_HIGH     = 58.0;      
const double RSI_EXTREME_BUFFER           = 15.0;
const double RSI_MAX_SAFE                 = 100.0;
const double RSI_MIN_SAFE                 = 0.0;

// Volatility & Trend Matrix
const double VOL_RATIO_EXTREME            = 2.5;       // Raised to 2.5 to map high-impact economic news flushes
const double BB_SQUEEZE_FACTOR            = 0.65;      // Tightened from 0.8 to properly map compressed contraction states
const double TREND_DIFF_MIN_FOR_ACTIVE    = 0.15;      // FIXED: Adjusted from 0.0001 (FX scale) to Gold price scale ($0.15)
const double MA_THRESHOLD_MULTIPLIER      = 100;       // Scaled to match Gold point weightings

// Signal Filtering Logic
const double MIN_BASESTRENGTH_FOR_SIGNAL  = 0.55;      // Slightly higher barrier to increase entry confirmation
const double MIN_CONSENSUS_FOR_SIGNAL     = 0.70;      // Stricter multi-indicator agreement threshold
const double MIN_BASESTRENGTH_MEDIUM      = 0.75;      
const double MIN_CONSENSUS_MEDIUM         = 0.60;      

// Adaptive Risk Framework (Calculated against XAU ATR)
const double ATR_SL_MULT_BASE             = 2.2;       // FIXED: Raised from 1.5. A 1.5 SL sits inside normal M5 noise
const double ATR_TP_MULT_BASE             = 3.3;       // Secures a robust 1:1.5 baseline Risk-to-Reward payout
const double ATR_SL_MULT_VOL_HIGH         = 1.8;       // High Volume: Tightens multiplier as candle range expands
const double ATR_TP_MULT_VOL_HIGH         = 4.5;       // Maximizes returns during strong news expansion waves
const double ATR_SL_MULT_VOL_LOW          = 2.5;       // Low Volume: Expands buffer to protect against random spikes
const double ATR_TP_MULT_VOL_LOW          = 2.5;       

// Volatility Decay Parameters
const double VOL_RATIO_HIGH               = 1.8;       
const double VOL_RATIO_LOW                = 0.5;       // Lowered to isolate complete dead-zone market states
const double DECAY_FACTOR                 = 0.85;      // Accelerated signature decay on fast M5 reversals
const double SIGNAL_DECAY_BARS            = 2;         // Reduced from 3 to invalidate old signals faster

// Price Action Rejection Thresholds
const double BODY_TO_ATRATIO_MIN          = 0.4;       // Assures signal candle has real momentum weight
const double ENGULF_SIZE_MULT             = 1.3;       // Requires clear structural domination to confirm reversal
const double WICK_TO_BODY_RATIO_HAMMER    = 3.0;       // Raised from 2.5 to target true institutional cash flushes
const double WICK_TO_BODY_RATIO_STAR      = 3.0;       

// Dashboard UI Constants
const string UI_PREFIX_MAIN    = "NR_Dash_";
const string UI_PREFIX_HEADER  = "NR_Header_";
const int    DASHBOARD_WIDTH   = 320;
const int    DASHBOARD_HEIGHT  = 480;
const color  COLOR_BUY         = clrLimeGreen;
const color  COLOR_SELL        = clrCrimson;
const color  COLOR_NEUTRAL     = clrDarkGray;
const color  COLOR_HEADER_BG   = clrDarkSlateGray;
const color  COLOR_BG          = clrBlack;

//─────────────────────────────────────────────────────────────────
// STRUCTURES
//─────────────────────────────────────────────────────────────────
struct IndicatorResult {
   string name;
   double value;
   int    vote;
   double confidence;
   double weight;
};

struct AlertState {
   int    lastBuyBar;
   int    lastSellBar;
   int    totalBuyToday;
   int    totalSellToday;
};

struct SignalStats {
   int    totalSignals;
   int    buySignals;
   int    sellSignals;
   double avgStrength;
   double avgConfidence;
   datetime lastSignalTime;
   int    consecBars;
   bool   lastDirWasBuy;
   double signalDecay;
};

//─────────────────────────────────────────────────────────────────
// INDICATOR HANDLES
//─────────────────────────────────────────────────────────────────
int h_MA_Fast, h_MA_Slow, h_MA_Major, h_MA_Major_HTF;
int h_RSI, h_Stoch, h_MACD;
int h_BB, h_ADX, h_WPR, h_CCI, h_ATR;

int g_MA_Fast, g_MA_Slow, g_MA_Major;
double g_RSI_OB, g_RSI_OS;
int g_Alert_MinBars, g_Update_Interval;
int g_MaxSpread, g_StartHour, g_EndHour;
double g_MaxSpreadATRRatio;

//─────────────────────────────────────────────────────────────────
// INDICATOR BUFFERS
//─────────────────────────────────────────────────────────────────
double buf_ma_fast[], buf_ma_slow[], buf_ma_major[], buf_ma_major_htf[];
double buf_rsi[];
double buf_stoch_k[], buf_stoch_d[];
double buf_macd_main[], buf_macd_sig[];
double buf_bb_upper[], buf_bb_lower[];
double buf_adx[];
double buf_wpr[];
double buf_cci[];
double buf_atr[];

//─────────────────────────────────────────────────────────────────
// SIGNAL WEIGHTS
//─────────────────────────────────────────────────────────────────
const double W_TREND = 3.0;
const double W_MACD  = 2.5;
const double W_RSI   = 1.5;
const double W_BB    = 1.5;
const double W_ADX   = 1.5;
const double W_STOCH = 1.0;
const double W_WPR   = 0.5;
const double W_CCI   = 0.5;

const int BUFFER_LOOKBACK = 15;

//─────────────────────────────────────────────────────────────────
// STATE TRACKING
//─────────────────────────────────────────────────────────────────
bool      g_LastSignalActive = false;
bool      g_LastSignalIsBuy  = false;
AlertState g_AlertState;
datetime   g_TodayDate        = 0;

static double g_LastStrength       = -1;
static string g_LastCondition      = "";
static bool   g_UIUpdateNeeded     = true;

uint g_TotalCalcTimeMs    = 0;
int  g_CalcCount          = 0;
double g_AvgCalcMs        = 0;

static datetime s_lastUpdateTime = 0;

SignalStats g_Stats;

// v3.13: Tick volume tracking
double g_AvgTickVolume = 0;
static int s_tickVolCount = 0;
static double s_tickVolSum = 0;

// Current market state (for UI display)
string g_CurrentCondition = "INIT";
string g_CurrentStatus    = "INIT";
double g_CurrentStrength  = 0.0;

//+------------------------------------------------------------------+
//| CreateGUI - Initialize Dashboard UI                              |
//+------------------------------------------------------------------+
void CreateGUI()
{
   // FIXED v3.14: Complete GUI creation function (was missing)
   ObjectsDeleteAll(0, UI_PREFIX_MAIN);
   ObjectsDeleteAll(0, UI_PREFIX_HEADER);
   
   int x = Inp_X_Offset;
   int y = Inp_Y_Offset;
   
   // Header background
   if(!ObjectCreate(0, UI_PREFIX_HEADER + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print("Failed to create header background");
      return;
   }
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_XSIZE, DASHBOARD_WIDTH);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_YSIZE, 40);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_BGCOLOR, COLOR_HEADER_BG);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Header text
   if(!ObjectCreate(0, UI_PREFIX_HEADER + "TEXT", OBJ_LABEL, 0, 0, 0)) {
      Print("Failed to create header text");
      return;
   }
   ObjectSetInteger(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_XDISTANCE, x + 10);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_YDISTANCE, y + 8);
   ObjectSetInteger(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_TEXT, "NR-Scalping v3.14");
   ObjectSetInteger(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, UI_PREFIX_HEADER + "TEXT", OBJPROP_COLOR, clrWhite);
   
   // Main panel background
   if(!ObjectCreate(0, UI_PREFIX_MAIN + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print("Failed to create main background");
      return;
   }
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_YDISTANCE, y + 40);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_XSIZE, DASHBOARD_WIDTH);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_YSIZE, DASHBOARD_HEIGHT - 40);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_BGCOLOR, COLOR_BG);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Status labels and value fields (5 rows x 3 columns)
   string labels[5] = {"Signal:", "Status:", "Strength:", "Bars:", "Today Buy:"};
   for(int i = 0; i < 5; i++) {
      int row_y = y + 50 + i * 30;
      
      // Label
      if(!ObjectCreate(0, UI_PREFIX_MAIN + "LBL_" + i, OBJ_LABEL, 0, 0, 0)) continue;
      ObjectSetInteger(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_XDISTANCE, x + 10);
      ObjectSetInteger(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_YDISTANCE, row_y);
      ObjectSetString(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_TEXT, labels[i]);
      ObjectSetInteger(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, UI_PREFIX_MAIN + "LBL_" + i, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      
      // Value field
      if(!ObjectCreate(0, UI_PREFIX_MAIN + "VAL_" + i, OBJ_LABEL, 0, 0, 0)) continue;
      ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_XDISTANCE, x + 120);
      ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_YDISTANCE, row_y);
      ObjectSetString(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_TEXT, "---");
      ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_" + i, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
}

//+------------------------------------------------------------------+
//| UpdateGUI - Refresh Dashboard Display                            |
//+------------------------------------------------------------------+
void UpdateGUI(const SignalStats &stats, const AlertState &alerts, 
               const string &condition, double strength)
{
   int x = Inp_X_Offset;
   int y = Inp_Y_Offset;
   
   // Signal: BUY/SELL/NONE
   string signalText = g_LastSignalActive ? (g_LastSignalIsBuy ? "BUY ↑" : "SELL ↓") : "IDLE";
   color signalColor = g_LastSignalActive ? (g_LastSignalIsBuy ? COLOR_BUY : COLOR_SELL) : COLOR_NEUTRAL;
   ObjectSetString(0, UI_PREFIX_MAIN + "VAL_0", OBJPROP_TEXT, signalText);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_0", OBJPROP_COLOR, signalColor);
   
   // Status: Market condition
   ObjectSetString(0, UI_PREFIX_MAIN + "VAL_1", OBJPROP_TEXT, condition);
   ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_1", OBJPROP_COLOR, clrYellow);
   
   // Strength: Signal strength %
   ObjectSetString(0, UI_PREFIX_MAIN + "VAL_2", OBJPROP_TEXT, 
                   StringFormat("%.1f%%", strength * 100));
   ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_2", OBJPROP_COLOR, clrYellow);
   
   // Consecutive bars
   ObjectSetString(0, UI_PREFIX_MAIN + "VAL_3", OBJPROP_TEXT, 
                   StringFormat("%d", stats.consecBars));
   ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_3", OBJPROP_COLOR, clrYellow);
   
   // Today buy signals
   ObjectSetString(0, UI_PREFIX_MAIN + "VAL_4", OBJPROP_TEXT, 
                   StringFormat("B:%d S:%d", alerts.totalBuyToday, alerts.totalSellToday));
   ObjectSetInteger(0, UI_PREFIX_MAIN + "VAL_4", OBJPROP_COLOR, clrYellow);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Inp_MA_Fast <= 0 || Inp_MA_Slow <= 0 || Inp_MA_Major <= 0) {
      Print("❌ Error: Moving average periods must be positive");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   g_MA_Fast = MathMax(1, MathMin(500, Inp_MA_Fast));
   g_MA_Slow = MathMax(2, MathMin(1000, Inp_MA_Slow));
   g_MA_Major = Inp_MA_Major;
   g_RSI_OB = MathMax(51.0, MathMin(99.0, Inp_RSI_OB));
   g_RSI_OS = MathMax(1.0, MathMin(49.0, Inp_RSI_OS));
   g_Alert_MinBars = MathMax(1, MathMin(100, Inp_Alert_MinBars));
   g_Update_Interval = MathMax(0, MathMin(60, Inp_Update_Interval));
   g_MaxSpread = Inp_Max_Spread;
   g_MaxSpreadATRRatio = Inp_Max_Spread_ATR_Ratio;
   g_StartHour = Inp_Start_Hour;
   g_EndHour = Inp_End_Hour;

   // Broker profile presets for XAUUSD scalping
   switch(Inp_Broker_Profile) {
      case BROKER_TIGHT:
         g_MaxSpread = 300;
         g_MaxSpreadATRRatio = 0.05;
         g_StartHour = 8;
         g_EndHour = 18;
         break;
      case BROKER_WIDE:
         g_MaxSpread = 650;
         g_MaxSpreadATRRatio = 0.09;
         g_StartHour = 9;
         g_EndHour = 17;
         break;
      case BROKER_STANDARD:
      default:
         g_MaxSpread = 450;
         g_MaxSpreadATRRatio = 0.06;
         g_StartHour = 8;
         g_EndHour = 17;
         break;
   }

   // Allow manual overrides when inputs are stricter than profile defaults
   g_MaxSpread = MathMin(g_MaxSpread, MathMax(1, Inp_Max_Spread));
   g_MaxSpreadATRRatio = MathMin(g_MaxSpreadATRRatio, MathMax(0.001, Inp_Max_Spread_ATR_Ratio));
   g_StartHour = MathMax(0, MathMin(23, Inp_Start_Hour));
   g_EndHour = MathMax(0, MathMin(23, Inp_End_Hour));
   
   if(g_MA_Fast != Inp_MA_Fast)
      PrintFormat("⚠️ Auto-corrected MA_Fast from %d to %d", Inp_MA_Fast, g_MA_Fast);
   if(g_MA_Slow != Inp_MA_Slow)
      PrintFormat("⚠️ Auto-corrected MA_Slow from %d to %d", Inp_MA_Slow, g_MA_Slow);
   if(g_RSI_OB != Inp_RSI_OB)
      PrintFormat("⚠️ Auto-corrected RSI_OB from %.1f to %.1f", Inp_RSI_OB, g_RSI_OB);
   if(g_RSI_OS != Inp_RSI_OS)
      PrintFormat("⚠️ Auto-corrected RSI_OS from %.1f to %.1f", Inp_RSI_OS, g_RSI_OS);

   if(g_MA_Fast >= g_MA_Slow) {
      Print("⚠️ Warning: MA_Fast should be < MA_Slow. Please adjust parameters.");
   }

   if(g_RSI_OB >= 100 || g_RSI_OB <= 50) {
      Print("⚠️ Warning: RSI OB level should be 50-99. Adjust input parameters.");
   }
   if(g_RSI_OS <= 0 || g_RSI_OS >= 50) {
      Print("⚠️ Warning: RSI OS level should be 1-50. Adjust input parameters.");
   }
   if(g_RSI_OB <= g_RSI_OS)
      Print("⚠️ Warning: RSI OB level should be above OS level");

   if(g_MaxSpreadATRRatio <= 0.0 || g_MaxSpreadATRRatio > 1.0) {
      Print("❌ Error: Effective Max_Spread_ATR_Ratio must be > 0 and <= 1.0");
      return(INIT_PARAMETERS_INCORRECT);
   }

   h_MA_Fast      = iMA(NULL, 0, g_MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h_MA_Slow      = iMA(NULL, 0, g_MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   h_MA_Major     = iMA(NULL, 0, g_MA_Major, 0, MODE_EMA, PRICE_CLOSE);
   h_MA_Major_HTF = iMA(NULL, Inp_MA_Major_TF, g_MA_Major, 0, MODE_EMA, PRICE_CLOSE);
   h_RSI          = iRSI(NULL, 0, Inp_RSI_Period, PRICE_CLOSE);
   h_Stoch        = iStochastic(NULL, 0, Inp_Stoch_K, Inp_Stoch_D, Inp_Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   h_MACD         = iMACD(NULL, 0, Inp_MACD_Fast, Inp_MACD_Slow, Inp_MACD_Signal, PRICE_CLOSE);
   h_BB           = iBands(NULL, 0, Inp_BB_Period, 0, Inp_BB_Dev, PRICE_CLOSE);
   h_ADX          = iADX(NULL, 0, Inp_ADX_Period);
   h_WPR          = iWPR(NULL, 0, Inp_WPR_Period);
   h_CCI          = iCCI(NULL, 0, Inp_CCI_Period, PRICE_CLOSE);
   h_ATR          = iATR(NULL, 0, Inp_ATR_Period);

   string failed = "";
   if(h_MA_Fast      == INVALID_HANDLE) failed += "FastMA ";
   if(h_MA_Slow      == INVALID_HANDLE) failed += "SlowMA ";
   if(h_MA_Major     == INVALID_HANDLE) failed += "MajorMA ";
   if(h_MA_Major_HTF == INVALID_HANDLE) failed += "HTF_MA ";
   if(h_RSI          == INVALID_HANDLE) failed += "RSI ";
   if(h_Stoch        == INVALID_HANDLE) failed += "Stoch ";
   if(h_MACD         == INVALID_HANDLE) failed += "MACD ";
   if(h_BB           == INVALID_HANDLE) failed += "BB ";
   if(h_ADX          == INVALID_HANDLE) failed += "ADX ";
   if(h_WPR          == INVALID_HANDLE) failed += "WPR ";
   if(h_CCI          == INVALID_HANDLE) failed += "CCI ";
   if(h_ATR          == INVALID_HANDLE) failed += "ATR ";

   if(failed != "") {
      PrintFormat("❌ Error creating handles: %s | LastError: %d", failed, GetLastError());
      return(INIT_FAILED);
   }

   ArraySetAsSeries(buf_ma_fast,     true);
   ArraySetAsSeries(buf_ma_slow,     true);
   ArraySetAsSeries(buf_ma_major,    true);
   ArraySetAsSeries(buf_ma_major_htf,true);
   ArraySetAsSeries(buf_rsi,         true);
   ArraySetAsSeries(buf_stoch_k,     true);
   ArraySetAsSeries(buf_stoch_d,     true);
   ArraySetAsSeries(buf_macd_main,   true);
   ArraySetAsSeries(buf_macd_sig,    true);
   ArraySetAsSeries(buf_bb_upper,    true);
   ArraySetAsSeries(buf_bb_lower,    true);
   ArraySetAsSeries(buf_adx,         true);
   ArraySetAsSeries(buf_wpr,         true);
   ArraySetAsSeries(buf_cci,         true);
   ArraySetAsSeries(buf_atr,         true);

   ArrayResize(buf_ma_fast,      BUFFER_LOOKBACK);
   ArrayResize(buf_ma_slow,      BUFFER_LOOKBACK);
   ArrayResize(buf_ma_major,     BUFFER_LOOKBACK);
   ArrayResize(buf_ma_major_htf, BUFFER_LOOKBACK);
   ArrayResize(buf_rsi,          BUFFER_LOOKBACK);
   ArrayResize(buf_stoch_k,      BUFFER_LOOKBACK);
   ArrayResize(buf_stoch_d,      BUFFER_LOOKBACK);
   ArrayResize(buf_macd_main,    BUFFER_LOOKBACK);
   ArrayResize(buf_macd_sig,     BUFFER_LOOKBACK);
   ArrayResize(buf_bb_upper,     BUFFER_LOOKBACK);
   ArrayResize(buf_bb_lower,     BUFFER_LOOKBACK);
   ArrayResize(buf_adx,          BUFFER_LOOKBACK);
   ArrayResize(buf_wpr,          BUFFER_LOOKBACK);
   ArrayResize(buf_cci,          BUFFER_LOOKBACK);
   ArrayResize(buf_atr,          BUFFER_LOOKBACK);

   g_TodayDate = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_AlertState.lastBuyBar = -999;
   g_AlertState.lastSellBar = -999;
   g_AlertState.totalBuyToday = 0;
   g_AlertState.totalSellToday = 0;
   
   g_Stats.totalSignals = 0;
   g_Stats.buySignals = 0;
   g_Stats.sellSignals = 0;
   g_Stats.avgStrength = 0.0;
   g_Stats.avgConfidence = 0.0;
   g_Stats.lastSignalTime = 0;
   g_Stats.consecBars = 0;
   g_Stats.lastDirWasBuy = false;
   g_Stats.signalDecay = 0.0;
   
   g_AvgTickVolume = 0;
   s_tickVolCount = 0;
   s_tickVolSum = 0;

   // FIXED v3.14: Call CreateGUI to build UI
   CreateGUI();
   
   int objCount = ObjectsTotal(0, 0, OBJ_LABEL) + ObjectsTotal(0, 0, OBJ_RECTANGLE_LABEL);
   if(objCount < 10) {
      PrintFormat("⚠️ Warning: Only %d UI objects created. Check for errors above.", objCount);
   } else {
      PrintFormat("✅ Dashboard created with %d UI objects", objCount);
   }
   
   ChartRedraw();

   Print("✅ NR-Scalping Dashboard v3.14 Initialized");
   Print("   Symbol: ", _Symbol, " | Timeframe: ", EnumToString(_Period));
   PrintFormat("   RSI Levels: OS=%.0f, OB=%.0f | v3.14", g_RSI_OS, g_RSI_OB);
   PrintFormat("   Dashboard Position: X=%d, Y=%d", Inp_X_Offset, Inp_Y_Offset);
   PrintFormat("   Update Interval: %d seconds", g_Update_Interval);
   string profileName = "STANDARD";
   if(Inp_Broker_Profile == BROKER_TIGHT) profileName = "TIGHT";
   else if(Inp_Broker_Profile == BROKER_WIDE) profileName = "WIDE";
   PrintFormat("   Broker Profile: %s | MaxSpread:%d | Spread/ATR:%.3f | Session:%02d-%02d UTC",
               profileName, g_MaxSpread, g_MaxSpreadATRRatio, g_StartHour, g_EndHour);
   PrintFormat("   Total Objects Created: %d", ObjectsTotal(0));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, UI_PREFIX_MAIN);
   ObjectsDeleteAll(0, UI_PREFIX_HEADER);

   IndicatorRelease(h_MA_Fast);  IndicatorRelease(h_MA_Slow);
   IndicatorRelease(h_MA_Major); IndicatorRelease(h_MA_Major_HTF);
   IndicatorRelease(h_RSI);      IndicatorRelease(h_Stoch);
   IndicatorRelease(h_MACD);     IndicatorRelease(h_BB);
   IndicatorRelease(h_ADX);      IndicatorRelease(h_WPR);
   IndicatorRelease(h_CCI);      IndicatorRelease(h_ATR);

   ChartRedraw();
   
   Print("✅ NR-Scalping Dashboard v3.14 Deinitialized");
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   if(g_Update_Interval > 0) {
      datetime now = TimeCurrent();
      if(now - s_lastUpdateTime < g_Update_Interval)
         return(prev_calculated);
      s_lastUpdateTime = now;
   } else {
      s_lastUpdateTime = TimeCurrent();
   }
   
   static bool init_logged = false;
   if(rates_total < 50) {
      if(!init_logged && rates_total % 20 == 0) {
         PrintFormat("⏳ Waiting for data... %d/50 bars loaded", rates_total);
         init_logged = true;
      }
      if(rates_total >= 50) init_logged = false;
      return(0);
   }

   int count = BUFFER_LOOKBACK;

   if(CopyBuffer(h_MA_Fast,      0, 0, count, buf_ma_fast)      < count) return(prev_calculated);
   if(CopyBuffer(h_MA_Slow,      0, 0, count, buf_ma_slow)      < count) return(prev_calculated);
   if(CopyBuffer(h_MA_Major,     0, 0, count, buf_ma_major)     < count) return(prev_calculated);
   if(CopyBuffer(h_MA_Major_HTF, 0, 0, count, buf_ma_major_htf) < count) return(prev_calculated);
   if(CopyBuffer(h_RSI,          0, 0, count, buf_rsi)          < count) return(prev_calculated);
   if(CopyBuffer(h_Stoch,        0, 0, count, buf_stoch_k)      < count) return(prev_calculated);
   if(CopyBuffer(h_Stoch,        1, 0, count, buf_stoch_d)      < count) return(prev_calculated);
   if(CopyBuffer(h_MACD,         0, 0, count, buf_macd_main)    < count) return(prev_calculated);
   if(CopyBuffer(h_MACD,         1, 0, count, buf_macd_sig)     < count) return(prev_calculated);
   if(CopyBuffer(h_BB,           1, 0, count, buf_bb_upper)     < count) return(prev_calculated);
   if(CopyBuffer(h_BB,           2, 0, count, buf_bb_lower)     < count) return(prev_calculated);
   if(CopyBuffer(h_ADX,          0, 0, count, buf_adx)          < count) return(prev_calculated);
   if(CopyBuffer(h_WPR,          0, 0, count, buf_wpr)          < count) return(prev_calculated);
   if(CopyBuffer(h_CCI,          0, 0, count, buf_cci)          < count) return(prev_calculated);
   if(CopyBuffer(h_ATR,          0, 0, count, buf_atr)          < count) return(prev_calculated);

   uint t0 = GetTickCount();

   bool uiNeeded = (g_Update_Interval <= 0) ||
                   (TimeCurrent() - s_lastUpdateTime >= g_Update_Interval);

   AnalyzeMarket(rates_total - 1, open, high, low, close,
                 tick_volume, spread[rates_total - 1], rates_total, t0, uiNeeded);

   if(g_LastSignalActive && uiNeeded) {
      int barsAgo = rates_total - (g_LastSignalIsBuy ? g_AlertState.lastBuyBar : g_AlertState.lastSellBar);
      if(barsAgo > 0 && barsAgo <= (int)SIGNAL_DECAY_BARS) {
         g_Stats.signalDecay = MathPow(DECAY_FACTOR, barsAgo);
      } else {
         g_Stats.signalDecay = 0.0;
      }
   }

   // FIXED v3.14: Update UI when needed
   if(uiNeeded) {
      UpdateGUI(g_Stats, g_AlertState, g_CurrentCondition, g_CurrentStrength);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Pattern Recognition                                              |
//+------------------------------------------------------------------+
string DetectPattern(int idx,
                     const double &open[], const double &high[],
                     const double &low[],  const double &close[],
                     double currentAtr)
{
   if(idx < 1 || currentAtr <= 0) return "";

   double O = open[idx];  double C = close[idx];
   double H = high[idx];  double L = low[idx];
   double pO= open[idx-1];double pC= close[idx-1];

   double body      = MathAbs(C - O);
   double prevBody  = MathAbs(pC - pO);
   double upperWick = H - MathMax(O, C);
   double lowerWick = MathMin(O, C) - L;
   double range     = H - L;

   if(range == 0 || prevBody == 0) return "";

   bool bull     = C > O;
   bool bear     = C < O;
   bool prevBull = pC > pO;
   bool prevBear = pC < pO;

   if(bull && prevBear && O <= pC && C >= pO &&
      body > prevBody * ENGULF_SIZE_MULT && body > currentAtr * BODY_TO_ATRATIO_MIN)
      return "BULL_ENGULF";

   if(bear && prevBull && O >= pC && C <= pO &&
      body > prevBody * ENGULF_SIZE_MULT && body > currentAtr * BODY_TO_ATRATIO_MIN)
      return "BEAR_ENGULF";

   if(lowerWick > body * WICK_TO_BODY_RATIO_HAMMER && upperWick < body * 0.3 && lowerWick > currentAtr * 0.4)
      return "HAMMER";

   if(upperWick > body * WICK_TO_BODY_RATIO_STAR && lowerWick < body * 0.3 && upperWick > currentAtr * 0.4)
      return "SHOOTING_STAR";

   if(body < range * 0.1 && range > currentAtr * 0.5)
      return "DOJI";

   return "";
}

//+------------------------------------------------------------------+
//| Core Market Analysis                                             |
//+------------------------------------------------------------------+
void AnalyzeMarket(int idx,
                   const double &open[], const double &high[],
                   const double &low[],  const double &close[],
                   const long &tick_volume[],
                   int spread, int rates_total, uint t0, bool uiUpdateNeeded)
{
   if(idx < BUFFER_LOOKBACK) return;

   double maFast      = buf_ma_fast[0];
   double maSlow      = buf_ma_slow[0];
   double maMajor     = buf_ma_major[0];
   double maMajorHTF  = buf_ma_major_htf[0];
   double adx         = buf_adx[0];
   double atr         = buf_atr[0];
   double rsi         = buf_rsi[0];
   double wpr         = buf_wpr[0];
   double cci         = buf_cci[0];
   double tickVol     = (idx < rates_total && idx >= 0) ? (double)tick_volume[idx] : 0;

   if(atr <= 0 || maFast == 0 || maSlow == 0) return;

   double trendDiff   = maFast - maSlow;
   double maSlowSlope = buf_ma_slow[0] - buf_ma_slow[5];

   double prevAtr        = buf_atr[10];
   double volatilityRatio = (prevAtr > 0) ? atr / prevAtr : 1.0;

   double macdHist     = buf_macd_main[0] - buf_macd_sig[0];
   double macdHistPrev = buf_macd_main[1] - buf_macd_sig[1];

   double bbWidth     = buf_bb_upper[0] - buf_bb_lower[0];
   double bbWidthPrev = buf_bb_upper[10] - buf_bb_lower[10];
   bool   isSqueeze   = (bbWidthPrev > 0) && (bbWidth < bbWidthPrev * BB_SQUEEZE_FACTOR);

   double stochK      = buf_stoch_k[0];
   double stochD      = buf_stoch_d[0];
   double stochKPrev  = buf_stoch_k[1];
   double stochDPrev  = buf_stoch_d[1];

   double price       = close[idx];

   // v3.13: Tick volume spike detection
   if(Inp_Avg_Tick_Vol_Period > 0 && idx < rates_total) {
      s_tickVolCount++;
      s_tickVolSum += tickVol;
      if(s_tickVolCount >= Inp_Avg_Tick_Vol_Period) {
         g_AvgTickVolume = s_tickVolSum / s_tickVolCount;
         s_tickVolCount = 0;
         s_tickVolSum = 0;
      }
   }
   bool tickVolSpike = (g_AvgTickVolume > 0 && tickVol > g_AvgTickVolume * 2.5);

   // v3.13: Consecutive trend bar counter
   bool currentBull = close[idx] > open[idx];
   bool prevBull = (idx >= 1) ? (close[idx-1] > open[idx-1]) : currentBull;
   if(currentBull == prevBull) {
      g_Stats.consecBars++;
   } else {
      g_Stats.consecBars = 1;
   }
   g_Stats.lastDirWasBuy = currentBull;
   int consecBoost = MathMin(g_Stats.consecBars, 5) - 1;

   // ── 2. Market Condition ───────────────────────────────────────
   string condition  = "RANGING";
   string majorTrend = "FLAT";
   double threshold  = Point() * MA_THRESHOLD_MULTIPLIER;

   if(price > maMajor + threshold && price > maMajorHTF)
      majorTrend = "BULLISH";
   else if(price < maMajor - threshold && price < maMajorHTF)
      majorTrend = "BEARISH";
   else
      majorTrend = "MIXED";

   if(adx > 20) {
      if(trendDiff > 0 && maSlowSlope > 0) condition = "TRENDING_UP";
      else if(trendDiff < 0 && maSlowSlope < 0) condition = "TRENDING_DOWN";
   }

   g_CurrentCondition = condition;

   // ── 3. Scalping Safety ────────────────────────────────────────
   bool safeSpread   = (spread <= g_MaxSpread) &&
                       (!Inp_Use_Adaptive_Spread || spread <= atr * g_MaxSpreadATRRatio);

   MqlDateTime dt;
   TimeCurrent(dt);
   bool safeSession;
   if(g_StartHour < g_EndHour) {
      safeSession = (dt.hour >= g_StartHour && dt.hour <= g_EndHour);
   } else {
      safeSession = (dt.hour >= g_StartHour || dt.hour <= g_EndHour);
   }

   double wickBodyRatio = (MathMax(high[idx] - close[idx], close[idx] - low[idx])) /
                          MathMax(0.0001, MathAbs(close[idx] - open[idx]));

   bool safeWick     = (wickBodyRatio <= Inp_Max_Wick_Body_Ratio);

   bool safeRR       = (ATR_TP_MULT_BASE / ATR_SL_MULT_BASE >= Inp_Min_RR_Ratio);

   bool safeBody     = (MathAbs(close[idx] - open[idx]) > atr * BODY_TO_ATRATIO_MIN);

   bool safeSignal   = safeSpread && safeSession && safeWick && safeRR && safeBody;

   string scalpStatus = safeSignal ? "OK" : "FILTERED";

   if(!safeSignal) {
      g_LastSignalActive = false;
   }

   // ── 4. Adaptive SL/TP Framework ───────────────────────────────
   // FIXED v3.14: Removed duplicate calculation - using single set
   double atrSlMult = ATR_SL_MULT_BASE;
   double atrTpMult = ATR_TP_MULT_BASE;

   if(Inp_Vol_Adapt_SL) {
      if(volatilityRatio >= VOL_RATIO_HIGH) {
         atrSlMult = ATR_SL_MULT_VOL_HIGH;
         atrTpMult = ATR_TP_MULT_VOL_HIGH;
      } else if(volatilityRatio <= VOL_RATIO_LOW) {
         atrSlMult = ATR_SL_MULT_VOL_LOW;
         atrTpMult = ATR_TP_MULT_VOL_LOW;
      }
   }

   double stopLossPips = atr * atrSlMult;
   double takeProfitPips = atr * atrTpMult;

   // Risk-to-Reward validation
   double rrRatio = (stopLossPips > 0) ? (takeProfitPips / stopLossPips) : 0.0;

   if(!safeRR) {
      g_LastSignalActive = false;
      g_LastCondition = "RR_FILTERED";
      scalpStatus = "RR_FILTERED";
   }

   if(scalpStatus != "FILTERED" && scalpStatus != "RR_FILTERED") {
      if(volatilityRatio > VOL_RATIO_EXTREME) {
         condition  = "VOLATILE";
         scalpStatus = "VOLATILE";
      } else if(isSqueeze) {
         scalpStatus = "SQUEEZE";
      } else if(adx <= 15) {
         scalpStatus = "WEAK_TREND";
      }

      if(spread > g_MaxSpread) scalpStatus = "HIGH_SPREAD";
   }

   if(Inp_Use_Adaptive_Spread && atr > 0) {
      double spreadValue = spread * Point();
      double spreadAtrRatio = spreadValue / atr;
      if(spreadAtrRatio > g_MaxSpreadATRRatio)
         scalpStatus = "HIGH_SPREAD";
   }

   bool isScalpingFriendly = (scalpStatus == "OK");

   g_CurrentStatus = scalpStatus;

   // ── 4. Indicator Voting ───────────────────────────────────────
   IndicatorResult inds[8];

   inds[0].name = "Trend"; inds[0].value = trendDiff;
   inds[0].weight = W_TREND; inds[0].vote = 0; inds[0].confidence = 0;
   if(condition == "TRENDING_UP") {
      inds[0].vote = 1;
      inds[0].confidence = MathMin(0.95, 0.7 + (adx - 20) * 0.02 + consecBoost * 0.03);
   } else if(condition == "TRENDING_DOWN") {
      inds[0].vote = -1;
      inds[0].confidence = MathMin(0.95, 0.7 + (adx - 20) * 0.02 + consecBoost * 0.03);
   } else if(majorTrend == "BULLISH" && trendDiff > 0) {
      inds[0].vote = 1; inds[0].confidence = 0.4;
   } else if(majorTrend == "BEARISH" && trendDiff < 0) {
      inds[0].vote = -1; inds[0].confidence = 0.4;
   }

   inds[1].name = "MACD"; inds[1].value = macdHist;
   inds[1].weight = W_MACD; inds[1].vote = 0; inds[1].confidence = 0;
   if(macdHist > 0 && macdHistPrev <= 0) { inds[1].vote =  1; inds[1].confidence = 0.85; }
   else if(macdHist < 0 && macdHistPrev >= 0) { inds[1].vote = -1; inds[1].confidence = 0.85; }
   else if(MathAbs(macdHist) > 0.00001) {
      if(macdHist > 0 && macdHist > macdHistPrev) { inds[1].vote =  1; inds[1].confidence = 0.6; }
      if(macdHist < 0 && macdHist < macdHistPrev) { inds[1].vote = -1; inds[1].confidence = 0.6; }
   }

   inds[2].name = "RSI"; inds[2].value = rsi;
   inds[2].weight = W_RSI; inds[2].vote = 0; inds[2].confidence = 0;
   if(rsi >= 0) {
      if(condition == "TRENDING_UP") {
         if(rsi >= RSI_TREND_UP_PULLBACK_LOW && rsi <= RSI_TREND_UP_PULLBACK_HIGH)
            { inds[2].vote =  1; inds[2].confidence = MathMin(0.85, 0.75 + consecBoost * 0.02); }
         double rsi_extreme_up = MathMin(RSI_MAX_SAFE, Inp_RSI_OB + RSI_EXTREME_BUFFER);
         if(rsi > rsi_extreme_up)
            { inds[2].vote = -1; inds[2].confidence = 0.6; }
      } else if(condition == "TRENDING_DOWN") {
         if(rsi >= RSI_TREND_DN_BOUNCE_LOW && rsi <= RSI_TREND_DN_BOUNCE_HIGH)
            { inds[2].vote = -1; inds[2].confidence = MathMin(0.85, 0.75 + consecBoost * 0.02); }
         double rsi_extreme_dn = MathMax(RSI_MIN_SAFE, Inp_RSI_OS - RSI_EXTREME_BUFFER);
         if(rsi < rsi_extreme_dn)
            { inds[2].vote =  1; inds[2].confidence = 0.6; }
      } else {
         if(rsi > Inp_RSI_OB)
            { inds[2].vote = -1; inds[2].confidence = 0.8; }
         if(rsi < Inp_RSI_OS)
            { inds[2].vote =  1; inds[2].confidence = 0.8; }
      }
   }

   inds[3].name = "BB"; inds[3].value = bbWidth;
   inds[3].weight = W_BB; inds[3].vote = 0; inds[3].confidence = 0;
   if(price > buf_bb_upper[0]) { inds[3].vote = -1; inds[3].confidence = 0.65; }
   if(price < buf_bb_lower[0]) { inds[3].vote =  1; inds[3].confidence = 0.65; }

   inds[4].name = "Stoch"; inds[4].value = stochK;
   inds[4].weight = W_STOCH; inds[4].vote = 0; inds[4].confidence = 0;
   bool kCrossUpD   = (stochK > stochD && stochKPrev <= stochDPrev);
   bool kCrossDownD = (stochK < stochD && stochKPrev >= stochDPrev);

   if(kCrossUpD && stochK < 20)           { inds[4].vote =  1; inds[4].confidence = 0.8;  }
   else if(stochK < 20 && !kCrossDownD)   { inds[4].vote =  1; inds[4].confidence = 0.55; }
   else if(kCrossDownD && stochK > 80)    { inds[4].vote = -1; inds[4].confidence = 0.8;  }
   else if(stochK > 80 && !kCrossUpD)     { inds[4].vote = -1; inds[4].confidence = 0.55; }

   inds[5].name = "ADX"; inds[5].value = adx;
   inds[5].weight = W_ADX; inds[5].vote = 0; inds[5].confidence = 0;
   if(adx > 25) {
      if(condition == "TRENDING_UP")   { inds[5].vote =  1; inds[5].confidence = MathMin(0.7, 0.5 + (adx-25)*0.01); }
      if(condition == "TRENDING_DOWN") { inds[5].vote = -1; inds[5].confidence = MathMin(0.7, 0.5 + (adx-25)*0.01); }
   } else if(adx < 15) {
      inds[5].confidence = 0.3;
   }

   inds[6].name = "WPR"; inds[6].value = wpr;
   inds[6].weight = W_WPR; inds[6].vote = 0; inds[6].confidence = 0;
   if(wpr < -80) { inds[6].vote =  1; inds[6].confidence = 0.5; }
   if(wpr > -20) { inds[6].vote = -1; inds[6].confidence = 0.5; }

   inds[7].name = "CCI"; inds[7].value = cci;
   inds[7].weight = W_CCI; inds[7].vote = 0; inds[7].confidence = 0;
   if(cci < -100) { inds[7].vote =  1; inds[7].confidence = 0.5; }
   if(cci >  100) { inds[7].vote = -1; inds[7].confidence = 0.5; }

   // ── 5. Weighted Confluence ────────────────────────────────────
   double buySum = 0, sellSum = 0, totalMaxWeight = 0;
   int    activeCount = 0;

   for(int k = 0; k < 8; k++) {
      totalMaxWeight += inds[k].weight;
      if(inds[k].vote != 0) {
         activeCount++;
         if(inds[k].vote ==  1) buySum  += inds[k].weight * inds[k].confidence;
         if(inds[k].vote == -1) sellSum += inds[k].weight * inds[k].confidence;
      }
   }

   if(activeCount < 3) { buySum *= 0.5; sellSum *= 0.5; }

   double globalTotal  = (totalMaxWeight > 0) ? totalMaxWeight : 1.0;
   double activeWeight = buySum + sellSum;

   bool   isBuy       = false;
   double baseStrength = 0;
   double consensus   = 0;

   if(buySum >= sellSum && buySum > 0) {
      isBuy       = true;
      baseStrength = buySum / globalTotal;
      consensus   = (activeWeight > 0) ? buySum / activeWeight : 0;
   } else if(sellSum > 0) {
      isBuy       = false;
      baseStrength = sellSum / globalTotal;
      consensus   = (activeWeight > 0) ? sellSum / activeWeight : 0;
   }

   // ── 6. Pattern + Context Boosts ───────────────────────────────
   string pattern       = DetectPattern(idx, open, high, low, close, atr);
   double boostedStr    = baseStrength;

   if(baseStrength > 0.1) {
      if(majorTrend == "BULLISH" &&  isBuy) boostedStr *= 1.25;
      if(majorTrend == "BEARISH" && !isBuy) boostedStr *= 1.25;
      if(majorTrend == "BULLISH" && !isBuy) boostedStr *= 0.70;
      if(majorTrend == "BEARISH" &&  isBuy) boostedStr *= 0.70;

      if( isBuy && (pattern == "BULL_ENGULF" || pattern == "HAMMER"))
         boostedStr = MathMin(1.0, boostedStr + 0.15);
      if(!isBuy && (pattern == "BEAR_ENGULF" || pattern == "SHOOTING_STAR"))
         boostedStr = MathMin(1.0, boostedStr + 0.15);

      boostedStr = MathMin(1.0, boostedStr + consecBoost * 0.02);

      if(tickVolSpike && baseStrength > 0.6) boostedStr = MathMin(1.0, boostedStr + 0.05);

      if(!isScalpingFriendly) boostedStr *= 0.5;
   }

   // v3.13: Signal freshness decay
   if(g_Stats.lastSignalTime > 0) {
      int barsSinceSignal = rates_total - (g_LastSignalIsBuy ? g_AlertState.lastBuyBar : g_AlertState.lastSellBar);
      if(barsSinceSignal > 0 && barsSinceSignal <= (int)SIGNAL_DECAY_BARS) {
         boostedStr *= MathPow(DECAY_FACTOR, barsSinceSignal);
      }
   }

   if(boostedStr > 1.0) boostedStr = 1.0;

   g_CurrentStrength = boostedStr;

   // v3.13: Swing High/Low S/R proximity check (FIXED v3.14: Better initialization)
   double swingHigh = -1, swingLow = DBL_MAX;
   if(idx >= 10) {
      for(int i = 1; i <= 10; i++) {
         if(idx - i >= 0 && idx + i <= rates_total - 1) {
            if(high[idx - i] > swingHigh) swingHigh = high[idx - i];
            if(low[idx - i] < swingLow) swingLow = low[idx - i];
         }
      }
   }
   double swingRange = (swingHigh > 0 && swingLow < DBL_MAX) ? (swingHigh - swingLow) : atr * 10;
   bool nearSwingHigh = (swingHigh > 0 && MathAbs(price - swingHigh) < swingRange * 0.1);
   bool nearSwingLow = (swingLow < DBL_MAX && MathAbs(price - swingLow) < swingRange * 0.1);
   if(nearSwingHigh) { if(!isBuy) boostedStr = MathMin(1.0, boostedStr + 0.05); }
   if(nearSwingLow) { if(isBuy) boostedStr = MathMin(1.0, boostedStr + 0.05); }

   // ── 6.1 Scalping Specific Filters ───────────────────────────
   TimeCurrent(dt);
   bool inSession = true;
   if(g_StartHour != g_EndHour) {
      if(g_StartHour < g_EndHour) inSession = (dt.hour >= g_StartHour && dt.hour < g_EndHour);
      else inSession = (dt.hour >= g_StartHour || dt.hour < g_EndHour);
   }
   if(!inSession) scalpStatus = "OFF_SESSION";

   double candleBody = MathAbs(close[idx] - open[idx]);
   double totalWick  = (high[idx] - MathMax(open[idx], close[idx])) + (MathMin(open[idx], close[idx]) - low[idx]);
   if(candleBody > 0 && (totalWick / candleBody) > Inp_Max_Wick_Body_Ratio) scalpStatus = "LARGE_WICKS";

   if(Inp_Min_Consec_Bars > 0 && g_Stats.consecBars < Inp_Min_Consec_Bars && scalpStatus == "OK") {
      scalpStatus = "WEAK_MOMENTUM";
   }

   // ── 7. Signal Activation ──────────────────────────────────────
   bool active = false;
   if(boostedStr >= MIN_BASESTRENGTH_FOR_SIGNAL && consensus >= MIN_CONSENSUS_FOR_SIGNAL)
      active = true;
   else if(boostedStr >= MIN_BASESTRENGTH_MEDIUM && consensus >= MIN_CONSENSUS_MEDIUM)
      active = true;

   if(scalpStatus != "OK") active = false;

   // Enforce risk/reward quality before activation
   double expectedRR = (atrSlMult > 0) ? (atrTpMult / atrSlMult) : 0.0;
   if(active && expectedRR < Inp_Min_RR_Ratio)
      active = false;

   if(active && Inp_Signal_Dir != SIG_DIR_BOTH) {
      if((Inp_Signal_Dir == SIG_DIR_BUY && !isBuy) || (Inp_Signal_Dir == SIG_DIR_SELL && isBuy))
         active = false;
   }

   // ── 8. Alert Logic ─────────────────────────────────────────
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_TodayDate) {
      g_TodayDate = today;
      g_AlertState.totalBuyToday = 0;
      g_AlertState.totalSellToday = 0;
   }

   int minBarsSinceBuy  = rates_total - g_AlertState.lastBuyBar;
   int minBarsSinceSell = rates_total - g_AlertState.lastSellBar;

   bool isNewBuyAlert  = active && isBuy &&
                         !(g_LastSignalActive && g_LastSignalIsBuy) &&
                         minBarsSinceBuy >= g_Alert_MinBars;

   bool isNewSellAlert = active && !isBuy &&
                         !(g_LastSignalActive && !g_LastSignalIsBuy) &&
                         minBarsSinceSell >= g_Alert_MinBars;

   if(isNewBuyAlert || isNewSellAlert) {
      string alertMsg = StringFormat(
         "NR-Scalping %s | %s | Str: %.2f | Agr: %.0f%%",
         _Symbol, isBuy ? "BUY" : "SELL", boostedStr, consensus * 100);

      if(Inp_Alert_Popup) Alert(alertMsg);

      if(Inp_Alert_Sound) {
         if(!PlaySound(Inp_Alert_Sound_File)) {
            int err = GetLastError();
            PrintFormat("PlaySound('%s') failed. Error: %d", Inp_Alert_Sound_File, err);
         }
      }

      if(Inp_Alert_Push) {
         if(!SendNotification(alertMsg)) {
            int err = GetLastError();
            PrintFormat("SendNotification failed. Error: %d", err);
         }
      }
      if(Inp_Alert_Email) {
         if(!SendMail("NR-Scalping Alert: " + _Symbol, alertMsg)) {
            int err = GetLastError();
            PrintFormat("SendMail failed. Error: %d", err);
         }
      }

      if(isBuy) {
         g_AlertState.lastBuyBar = rates_total;
         g_AlertState.totalBuyToday++;
      } else {
         g_AlertState.lastSellBar = rates_total;
         g_AlertState.totalSellToday++;
      }
      
      g_Stats.totalSignals++;
      if(isBuy) g_Stats.buySignals++; else g_Stats.sellSignals++;
      g_Stats.avgStrength = (g_Stats.avgStrength * (g_Stats.totalSignals - 1) + boostedStr) / g_Stats.totalSignals;
      g_Stats.avgConfidence = (g_Stats.avgConfidence * (g_Stats.totalSignals - 1) + consensus) / g_Stats.totalSignals;
      g_Stats.lastSignalTime = TimeCurrent();
   }

   g_LastSignalActive = active;
   g_LastSignalIsBuy  = isBuy;

   // ── 9. Performance Tracking ──────────────────────────────────
   uint calcTime = GetTickCount() - t0;
   g_TotalCalcTimeMs += calcTime;
   g_CalcCount++;
   if(g_CalcCount > 0)
      g_AvgCalcMs = (double)g_TotalCalcTimeMs / g_CalcCount;
}

//+------------------------------------------------------------------+
//| END OF FILE                                                      |
//+------------------------------------------------------------------+
