//+------------------------------------------------------------------+
//|                                       TradePanelEA_GoldScalp.mq5 |
//|           GOLD Scalping Edition – EXNESS STANDARD OPTIMIZED v8.0 |
//+------------------------------------------------------------------+
#property copyright "GoldScalp Exness Edition"
#property version   "8.00"
#property description "GOLD Scalping Trade Panel – Exness Standard v8.0"
#property strict

//--- input parameters
input group "=== Trading (Exness Standard Optimized) ==="
input double   LotSize               = 0.01;
input bool     UseAutoLot            = true;
input double   RiskPercent           = 0.5;
input int      StopLossPoints        = 1000;
input int      TakeProfitPoints      = 1500;
input int      AutoLotSLPoints       = 1000;
input ulong    MagicNumber           = 33345233;
input string   TradeComment          = "GoldScalp_Std";
input bool     UseTradeConfirmation  = false;
input int      MaxSlippage           = 50;
input int      MaxOpenPositions      = 3;           // NEW: Max simultaneous positions

input group "=== Scalping Trend (Fast) ==="
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_M5;
input int      MA_Fast               = 5;
input int      MA_Slow               = 13;
input int      MA_Trend              = 50;
input bool     UseADX                = true;
input int      ADX_Period            = 14;
input double   ADX_Threshold         = 20.0;

input group "=== Scalping Signals ==="
input bool     UseRSI                = true;
input int      RSI_Period            = 5;
input int      RSI_Oversold          = 30;
input int      RSI_Overbought        = 70;
input bool     UseMACD               = true;
input int      MACD_Fast             = 5;
input int      MACD_Slow             = 17;
input int      MACD_Signal           = 3;
input bool     UseBollingerBands     = true;
input int      BB_Period             = 20;
input double   BB_Deviation          = 2.0;
input bool     RequireBBTouch        = false;
input bool     UseRSIDivergence      = true;       // NEW: RSI divergence detection

input group "=== Pending Orders (DISABLED) ==="
input bool     AllowPendingOrders    = false;
input double   PendingDistancePoints = 50.0;
input bool     UseATRforPending      = false;
input double   ATR_PendingMultiplier = 0.5;

input group "=== Scalping Risk Management ==="
input bool     UseTrailingStop       = true;
input int      TrailingStopPoints    = 750;
input int      TrailingStepPoints    = 250;
input int      TrailingActivationPts = 600;
input bool     UseATRTrailing        = true;       // NEW: ATR-based trailing
input double   ATRTrailingMultiplier = 2.0;        // NEW: ATR multiplier for trailing
input bool     UseBreakEven          = true;
input int      BreakEvenPoints       = 500;
input int      BreakEvenProfitPts    = 150;
input int      MaxDailyTrades        = 15;
input double   MaxDailyLoss          = 250.0;
input bool     CloseOnOppositeSignal = true;
input bool     UsePartialClose       = true;
input double   PartialClosePercent   = 50.0;
input int      PartialCloseAtProfit  = 500;
input bool     UseMultiLevelPartial  = true;       // NEW: Multiple partial close levels
input int      Partial2AtProfit      = 1000;       // NEW: Second partial close level
input double   Partial2Percent       = 30.0;       // NEW: Second partial close %
input int      MaxConsecutiveLosses  = 3;
input int      CooldownBars          = 3;
input double   MaxDrawdownPercent    = 5.0;        // NEW: Max account drawdown %

input group "=== ATR (Defensive Multipliers) ==="
input bool     UseATRforSLTP         = true;
input int      ATR_Period            = 10;
input ENUM_TIMEFRAMES ATR_Timeframe  = PERIOD_M5;
input double   ATR_SL_Multiplier     = 2.5;      
input double   ATR_TP_Multiplier     = 4.0;      
input double   ATR_MinSLPoints       = 300;        // NEW: Minimum SL in points
input double   ATR_MaxSLPoints       = 2000;       // NEW: Maximum SL in points

input group "=== Exness STANDARD GOLD Filters ==="
input bool     UseMarketHoursFilter  = true;
input int      MarketOpenHour        = 7;
input int      MarketCloseHour       = 20;
input bool     UseMaxSpreadFilter    = true;
input double   MaxSpreadTicks        = 3.0;        // FIX: Changed from 0.0
input bool     UseDynamicSpread      = true;     
input double   DynamicSpreadMax      = 1.5;      
input int      SpreadSampleBars      = 20;       
input int      SpreadCooldownSec     = 60;
input bool     UseNewsFilter         = true;
input int      NewsMinutesBefore     = 10;
input int      NewsMinutesAfter      = 15;
input bool     UseSessionOverlapOnly = false;
input bool     AvoidFridayEvening    = true;
input int      FridayStopHour        = 20;
input int      FridayStopMin         = 30;
input int      GMTOffset             = 2;          // NEW: GMT offset for broker

input group "=== News Windows (Server Time) ==="  // FIX: Clarified it's server time
input bool     UseCustomNewsWindows  = true;
input int      News1_StartHour = 8;  input int News1_StartMin = 15; input int News1_EndHour = 8;  input int News1_EndMin = 45;
input int      News2_StartHour = 12; input int News2_StartMin = 30; input int News2_EndHour = 13; input int News2_EndMin = 0;
input int      News3_StartHour = 13; input int News3_StartMin = 30; input int News3_EndHour = 14; input int News3_EndMin = 0;
input int      News4_StartHour = 14; input int News4_StartMin = 0;  input int News4_EndHour = 14; input int News4_EndMin = 30;
input int      News5_StartHour = 18; input int News5_StartMin = 0;  input int News5_EndHour = 18; input int News5_EndMin = 30;
input int      News6_StartHour = 19; input int News6_StartMin = 0;  input int News6_EndHour = 19; input int News6_EndMin = 30;

input group "=== Exness STANDARD Account Settings ==="
input double   CommissionPerLot      = 3.5;        // FIX: Realistic Exness commission
input bool     TrackNetProfit        = true;
input double   MaxLotSize            = 20.0;
input double   MinMarginLevel        = 150.0;

input group "=== Panel & Alerts ==="
input int      PanelCorner           = CORNER_LEFT_UPPER;
input color    PanelBgColor          = clrWhiteSmoke;
input int      FontSize              = 9;
input bool     EnableSoundAlerts     = true;
input string   BuySoundFile          = "alert.wav";
input string   SellSoundFile         = "alert2.wav";
input bool     MinimizePanel         = false;

input group "=== Journal ==="
input bool     EnableTradeJournal    = true;
input string   JournalFileName       = "GoldScalp_Std_Journal.csv";

input group "=== Initial Stats ==="
input double   DefaultSignalStrength = 55.0;
input double   DefaultProfitFactor   = 2.0;
input double   DefaultWinRate        = 55.0;
input bool     CalculateRealStats    = true;

//--- enums
enum ENUM_TREND_DIRECTION { TREND_UP, TREND_DOWN, TREND_SIDEWAYS, TREND_UNKNOWN };
enum ENUM_SESSION { SESSION_ASIA, SESSION_LONDON, SESSION_NY, SESSION_OVERLAP, SESSION_CLOSED };
enum ENUM_PARTIAL_LEVEL { PARTIAL_NONE, PARTIAL_1_DONE, PARTIAL_2_DONE, PARTIAL_ALL_DONE };

//--- structures
struct NewsWindow {
   int startHour; 
   int startMin; 
   int endHour; 
   int endMin;
};

struct MarketAnalysis
{
   ENUM_TREND_DIRECTION trend;
   double trendStrength;
   bool   buySignal; 
   bool   sellSignal;
   double buyScore; 
   double sellScore;
   string recommendation;
   double rsiValue; 
   double macdValue; 
   double adxValue; 
   double adxPlus; 
   double adxMinus; 
   double atrValue;
   double bbUpper; 
   double bbLower; 
   double bbMiddle; 
   double price;
   bool   marketOpen; 
   bool   spreadOk; 
   bool   newsOk; 
   bool   sessionOk;
   ENUM_SESSION currentSession;
   double spreadTicks;
   bool   rsiDivergenceBuy;           // NEW
   bool   rsiDivergenceSell;          // NEW
};

// FIX: New structure to track partial close state per position
struct PositionState
{
   ulong   ticket;
   ENUM_PARTIAL_LEVEL partialLevel;
   double  originalVolume;
   datetime openTime;
};

//--- indicator handles & buffers
int maFastH = INVALID_HANDLE; 
int maSlowH = INVALID_HANDLE; 
int maTrendH = INVALID_HANDLE;
int adxH = INVALID_HANDLE; 
int rsiH = INVALID_HANDLE; 
int macdH = INVALID_HANDLE;
int bbH = INVALID_HANDLE; 
int atrH = INVALID_HANDLE;

double maFast[]; 
double maSlow[]; 
double maTrend[];
double adx[]; 
double adxPlus[]; 
double adxMinus[];
double rsi[]; 
double macdMain[]; 
double macdSignal[];
double bbUpperBuf[]; 
double bbMiddleBuf[]; 
double bbLowerBuf[];
double atrBuf[];

//--- state variables
datetime lastBarTime = 0; 
datetime lastTradeDay = 0; 
datetime lastSpreadSpike = 0;
int dailyTradeCount = 0; 
int consecutiveLosses = 0; 
int cooldownBarsLeft = 0;
double dailyProfit = 0; 
double dailyLoss = 0; 
double dailyCommission = 0;
double peakBalance = 0;                           // NEW: For drawdown calculation
bool panelMinimized = false;
MarketAnalysis currentAnalysis; 
MarketAnalysis previousAnalysis;
double signalStrength = 50.0; 
double profitFactor = 2.5; 
double winRate = 60.0;
string panelPrefix = "GS_"; 
bool newsBlockActive = false;

// FIX: Position state tracking
PositionState g_positionStates[];
int g_positionStateCount = 0;

//--- GOLD symbol cache
double g_pointValue = 0; 
double g_tickSize = 0; 
double g_tickValue = 0;
double g_volumeMin = 0; 
double g_volumeMax = 0; 
double g_volumeStep = 0;
int    g_digits = 0; 
int    g_stopsLevel = 0;

//--- Exness specific cache
double g_exnessCommission = 0; 
bool g_isTripleSwapDay = false;
NewsWindow g_newsWindows[6]; 
int g_journalHandle = INVALID_HANDLE;
double g_realAverageSpread = 0;                    // FIX: Renamed for clarity

//--- Spread history for TRUE average calculation
double g_spreadHistory[];
int g_spreadHistoryCount = 0;
int g_spreadHistoryMax = 100;

//--- Mutable flags for indicator settings
bool g_useBollingerBands = true;
bool g_useATRforSLTP = true;
bool g_useATRTrailing = true;

//+------------------------------------------------------------------+
//| Initialization                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   signalStrength = DefaultSignalStrength; 
   profitFactor = DefaultProfitFactor; 
   winRate = DefaultWinRate;
   panelMinimized = MinimizePanel;
   peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);  // NEW
   
   // Initialize mutable flags from inputs
   g_useBollingerBands = UseBollingerBands;
   g_useATRforSLTP = UseATRforSLTP;
   g_useATRTrailing = UseATRTrailing;

   // Cache symbol properties
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_volumeMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   // Validate critical values
   if(g_tickSize <= 0 || g_tickValue <= 0)
   {
      Print("ERROR: Invalid symbol properties - TickSize: ", g_tickSize, " TickValue: ", g_tickValue);
      return INIT_FAILED;
   }

   g_exnessCommission = CommissionPerLot;
   MqlDateTime dt; 
   TimeCurrent(dt);
   g_isTripleSwapDay = (dt.day_of_week == 3);

   InitNewsWindows();
   ArrayResize(g_spreadHistory, g_spreadHistoryMax);
   ArrayInitialize(g_spreadHistory, 0);
   g_spreadHistoryCount = 0;

   Print("=== EXNESS STANDARD GOLD Scalp v8.0 ===");
   Print("  Symbol: ", _Symbol);
   Print("  TickSize: ", g_tickSize, " | Point: ", g_pointValue);
   Print("  TickValue: ", g_tickValue, " | Commission: $", g_exnessCommission, "/lot");
   Print("  StopsLevel: ", g_stopsLevel, " | Digits: ", g_digits);

   if(!InitIndicators()) 
   {
      Print("ERROR: Failed to initialize indicators");
      return INIT_FAILED;
   }

   EventSetMillisecondTimer(250);
   ZeroMemory(currentAnalysis); 
   ZeroMemory(previousAnalysis);
   currentAnalysis.trend = TREND_UNKNOWN;
   currentAnalysis.marketOpen = true; 
   currentAnalysis.spreadOk = true;
   currentAnalysis.newsOk = true; 
   currentAnalysis.sessionOk = true;

   MqlDateTime dtNow; 
   TimeCurrent(dtNow);
   lastTradeDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dtNow.year, dtNow.mon, dtNow.day));

   if(CalculateRealStats) CalculateRealStatistics();
   if(EnableTradeJournal) InitJournal();
   if(!CreateTradePanel()) return INIT_FAILED;
   
   lastBarTime = iTime(_Symbol, TrendTimeframe, 0);
   
   Print("Initialization complete - Ready to trade");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| News Windows Initialization                                       |
//+------------------------------------------------------------------+
void InitNewsWindows()
{
   g_newsWindows[0].startHour = News1_StartHour; g_newsWindows[0].startMin = News1_StartMin; 
   g_newsWindows[0].endHour = News1_EndHour; g_newsWindows[0].endMin = News1_EndMin;
   g_newsWindows[1].startHour = News2_StartHour; g_newsWindows[1].startMin = News2_StartMin; 
   g_newsWindows[1].endHour = News2_EndHour; g_newsWindows[1].endMin = News2_EndMin;
   g_newsWindows[2].startHour = News3_StartHour; g_newsWindows[2].startMin = News3_StartMin; 
   g_newsWindows[2].endHour = News3_EndHour; g_newsWindows[2].endMin = News3_EndMin;
   g_newsWindows[3].startHour = News4_StartHour; g_newsWindows[3].startMin = News4_StartMin; 
   g_newsWindows[3].endHour = News4_EndHour; g_newsWindows[3].endMin = News4_EndMin;
   g_newsWindows[4].startHour = News5_StartHour; g_newsWindows[4].startMin = News5_StartMin; 
   g_newsWindows[4].endHour = News5_EndHour; g_newsWindows[4].endMin = News5_EndMin;
   g_newsWindows[5].startHour = News6_StartHour; g_newsWindows[5].startMin = News6_StartMin; 
   g_newsWindows[5].endHour = News6_EndHour; g_newsWindows[5].endMin = News6_EndMin;
   
   Print("News windows initialized - Using SERVER time (adjust GMTOffset if needed)");
}

//+------------------------------------------------------------------+
//| Deinitialization                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ReleaseIndicator(maFastH); 
   ReleaseIndicator(maSlowH); 
   ReleaseIndicator(maTrendH);
   ReleaseIndicator(adxH); 
   ReleaseIndicator(rsiH); 
   ReleaseIndicator(macdH);
   ReleaseIndicator(bbH); 
   ReleaseIndicator(atrH);
   EventKillTimer(); 
   DeletePanelObjects();
   if(g_journalHandle != INVALID_HANDLE) 
   {
      FileClose(g_journalHandle);
      g_journalHandle = INVALID_HANDLE;
   }
   Print("GoldScalp v8.0 deinitialized. Reason: ", reason);
}

void ReleaseIndicator(int &h) 
{ 
   if(h != INVALID_HANDLE) 
   { 
      IndicatorRelease(h); 
      h = INVALID_HANDLE; 
   } 
}

//+------------------------------------------------------------------+
//| Indicator Initialization                                          |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   maFastH = iMA(_Symbol, TrendTimeframe, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   maSlowH = iMA(_Symbol, TrendTimeframe, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   maTrendH = iMA(_Symbol, TrendTimeframe, MA_Trend, 0, MODE_SMA, PRICE_CLOSE);
   adxH = iADX(_Symbol, TrendTimeframe, ADX_Period);
   rsiH = iRSI(_Symbol, TrendTimeframe, RSI_Period, PRICE_CLOSE);
   macdH = iMACD(_Symbol, TrendTimeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   
   if(maFastH==INVALID_HANDLE || maSlowH==INVALID_HANDLE || maTrendH==INVALID_HANDLE ||
      adxH==INVALID_HANDLE || rsiH==INVALID_HANDLE || macdH==INVALID_HANDLE)
   {
      Print("ERROR: Core indicator creation failed");
      return false;
   }

   if(g_useBollingerBands) 
   {
      bbH = iBands(_Symbol, TrendTimeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
      if(bbH == INVALID_HANDLE)
      {
         Print("WARNING: Bollinger Bands creation failed - disabling");
         g_useBollingerBands = false;
      }
   }
   
   if(g_useATRforSLTP || UseATRforPending || g_useATRTrailing) 
   {
      atrH = iATR(_Symbol, ATR_Timeframe, ATR_Period);
      if(atrH == INVALID_HANDLE)
      {
         Print("WARNING: ATR creation failed - using fixed values");
         g_useATRforSLTP = false;
         g_useATRTrailing = false;
      }
   }

   // FIX: Set as series AFTER indicator creation
   ArraySetAsSeries(maFast, true); 
   ArraySetAsSeries(maSlow, true); 
   ArraySetAsSeries(maTrend, true);
   ArraySetAsSeries(adx, true); 
   ArraySetAsSeries(adxPlus, true); 
   ArraySetAsSeries(adxMinus, true);
   ArraySetAsSeries(rsi, true); 
   ArraySetAsSeries(macdMain, true); 
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(bbUpperBuf, true); 
   ArraySetAsSeries(bbMiddleBuf, true); 
   ArraySetAsSeries(bbLowerBuf, true);
   ArraySetAsSeries(atrBuf, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| Event Handlers                                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == panelPrefix + "Minimize") 
      { 
         panelMinimized = !panelMinimized; 
         CreateTradePanel(); 
         ChartRedraw(); 
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         return; 
      }
      if(sparam == panelPrefix + "BuyBtn") 
      { 
         ExecuteBuy(); 
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         return; 
      }
      if(sparam == panelPrefix + "SellBtn") 
      { 
         ExecuteSell(); 
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         return; 
      }
      if(sparam == panelPrefix + "CloseAllBtn") 
      { 
         CloseAllTrades(); 
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         return; 
      }
      if(sparam == panelPrefix + "PartialBtn") 
      { 
         ManualPartialClose(); 
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         return; 
      }
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
}

void OnTick()
{
   // Update spread history for TRUE average calculation
   UpdateSpreadHistory();
   
   // Update peak balance for drawdown
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > peakBalance) peakBalance = currentBalance;
   
   if(!IsMarginSafe()) return;
   if(!IsDrawdownSafe()) return;  // NEW: Drawdown check
   
   if(UseBreakEven) ApplyBreakEven();
   if(UseTrailingStop) ApplyTrailingStop();
   if(UsePartialClose && PartialCloseAtProfit > 0) AutoPartialClose();

   datetime currentBar = iTime(_Symbol, TrendTimeframe, 0);
   if(currentBar != lastBarTime) 
   { 
      lastBarTime = currentBar; 
      OnNewBar(); 
   }
}

void OnTrade() 
{ 
   CalculateDailyPnL(); 
   SyncPositionStates();  // NEW: Keep position states in sync
}

void OnTimer() 
{ 
   AnalyzeMarket(); 
   UpdatePanel(); 
   CheckSignalChange(); 
}

void OnNewBar()
{
   MqlDateTime dtNow; 
   TimeCurrent(dtNow);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dtNow.year, dtNow.mon, dtNow.day));
   
   if(today != lastTradeDay) 
   { 
      lastTradeDay = today; 
      ResetDailyCounters(); 
      g_isTripleSwapDay = (dtNow.day_of_week == 3); 
   }
   
   if(cooldownBarsLeft > 0) 
      cooldownBarsLeft--;
      
   if(CloseOnOppositeSignal) 
      CheckCloseOnOppositeSignal();
}

void ResetDailyCounters() 
{ 
   dailyTradeCount = 0; 
   dailyProfit = 0; 
   dailyLoss = 0; 
   dailyCommission = 0; 
   consecutiveLosses = 0; 
   cooldownBarsLeft = 0; 
}

//+------------------------------------------------------------------+
//| Spread History Management (TRUE average)                          |
//+------------------------------------------------------------------+
void UpdateSpreadHistory()
{
   double currentSpread = GetSpreadTicks();
   
   // Add to circular buffer
   if(g_spreadHistoryCount < g_spreadHistoryMax)
   {
      g_spreadHistory[g_spreadHistoryCount] = currentSpread;
      g_spreadHistoryCount++;
   }
   else
   {
      // Shift array left
   for(int i = 0; i < g_spreadHistoryMax - 1; i++)
      g_spreadHistory[i] = g_spreadHistory[i + 1];
      g_spreadHistory[g_spreadHistoryMax - 1] = currentSpread;
   }
   
   // Calculate TRUE average
   if(g_spreadHistoryCount > 0)
   {
      double sum = 0;
      for(int i = 0; i < g_spreadHistoryCount; i++)
         sum += g_spreadHistory[i];
      g_realAverageSpread = sum / g_spreadHistoryCount;
   }
}

//+------------------------------------------------------------------+
//| P&L & Stats Calculation (FIXED)                                  |
//+------------------------------------------------------------------+
void CalculateDailyPnL()
{
   dailyProfit = 0; 
   dailyLoss = 0;
   
   MqlDateTime dtNow; 
   TimeCurrent(dtNow);
   datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dtNow.year, dtNow.mon, dtNow.day));
   HistorySelect(todayStart, TimeCurrent());
   
   // FIX: Properly track CONSECUTIVE losses by processing in order
   int tempConsecutive = 0;
   int maxConsecutive = 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      double netProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + 
                         HistoryDealGetDouble(dealTicket, DEAL_COMMISSION) + 
                         HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      
      if(netProfit >= 0) 
      { 
         dailyProfit += netProfit; 
         tempConsecutive = 0;  // Reset on win
      }
      else 
      { 
         dailyLoss += MathAbs(netProfit); 
         tempConsecutive++;
         if(tempConsecutive > maxConsecutive)
            maxConsecutive = tempConsecutive;
      }
   }
   
   // Use maximum consecutive losses seen today
   consecutiveLosses = maxConsecutive;
   if(maxConsecutive > 0)
      cooldownBarsLeft = CooldownBars;
}

void CalculateRealStatistics()
{
   // Select more history for better stats
   datetime fromTime = TimeCurrent() - 30 * 24 * 60 * 60;  // Last 30 days
   HistorySelect(fromTime, TimeCurrent()); 
   
   int wins = 0, losses = 0; 
   double totalProfit = 0, totalLoss = 0;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      if(profit >= 0) 
      { 
         wins++; 
         totalProfit += profit; 
      } 
      else 
      { 
         losses++; 
         totalLoss += MathAbs(profit); 
      }
      
      if(wins + losses >= 200) break;  // More samples
   }
   
   int total = wins + losses;
   if(total > 0) 
   { 
      winRate = (double)wins / (double)total * 100.0; 
      profitFactor = (totalLoss > 0) ? totalProfit / totalLoss : 0; 
      Print("Stats calculated from ", total, " trades - WR: ", DoubleToString(winRate, 1), "% PF: ", DoubleToString(profitFactor, 2));
   }
}

//+------------------------------------------------------------------+
//| Position State Management (NEW)                                  |
//+------------------------------------------------------------------+
void SyncPositionStates()
{
   // Remove closed positions from state array
   for(int i = g_positionStateCount - 1; i >= 0; i--)
   {
      bool found = false;
      for(int j = 0; j < PositionsTotal(); j++)
      {
         if(PositionGetTicket(j) == g_positionStates[i].ticket)
         {
            found = true;
            break;
         }
      }
      if(!found)
      {
         // Remove this entry by shifting
         for(int k = i; k < g_positionStateCount - 1; k++)
            g_positionStates[k] = g_positionStates[k + 1];
         g_positionStateCount--;
      }
   }
   
   // Add new positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      bool found = false;
      for(int j = 0; j < g_positionStateCount; j++)
      {
         if(g_positionStates[j].ticket == ticket)
         {
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         // Add new position
         if(g_positionStateCount < ArraySize(g_positionStates))
         {
            g_positionStates[g_positionStateCount].ticket = ticket;
            g_positionStates[g_positionStateCount].partialLevel = PARTIAL_NONE;
            g_positionStates[g_positionStateCount].originalVolume = PositionGetDouble(POSITION_VOLUME);
            g_positionStates[g_positionStateCount].openTime = (datetime)PositionGetInteger(POSITION_TIME);
            g_positionStateCount++;
         }
      }
   }
}

ENUM_PARTIAL_LEVEL GetPositionPartialLevel(ulong ticket)
{
   for(int i = 0; i < g_positionStateCount; i++)
   {
      if(g_positionStates[i].ticket == ticket)
         return g_positionStates[i].partialLevel;
   }
   return PARTIAL_NONE;
}

void SetPositionPartialLevel(ulong ticket, ENUM_PARTIAL_LEVEL level)
{
   for(int i = 0; i < g_positionStateCount; i++)
   {
      if(g_positionStates[i].ticket == ticket)
      {
         g_positionStates[i].partialLevel = level;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Market Analysis Engine (FIXED)                                   |
//+------------------------------------------------------------------+
void AnalyzeMarket()
{
   previousAnalysis = currentAnalysis;
   
   // FIX: Set array as series BEFORE each CopyBuffer
   ArraySetAsSeries(maFast, true);
   ArraySetAsSeries(maSlow, true);
   ArraySetAsSeries(maTrend, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(adxPlus, true);
   ArraySetAsSeries(adxMinus, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(bbUpperBuf, true);
   ArraySetAsSeries(bbMiddleBuf, true);
   ArraySetAsSeries(bbLowerBuf, true);
   ArraySetAsSeries(atrBuf, true);
   
   bool ok = true;
   ok &= (CopyBuffer(maFastH, 0, 0, 10, maFast) >= 10); 
   ok &= (CopyBuffer(maSlowH, 0, 0, 10, maSlow) >= 10); 
   ok &= (CopyBuffer(maTrendH, 0, 0, 10, maTrend) >= 10);
   ok &= (CopyBuffer(adxH, 0, 0, 10, adx) >= 10); 
   ok &= (CopyBuffer(adxH, 1, 0, 10, adxPlus) >= 10); 
   ok &= (CopyBuffer(adxH, 2, 0, 10, adxMinus) >= 10);
   ok &= (CopyBuffer(rsiH, 0, 0, 10, rsi) >= 10); 
   ok &= (CopyBuffer(macdH, 0, 0, 10, macdMain) >= 10); 
   ok &= (CopyBuffer(macdH, 1, 0, 10, macdSignal) >= 10);
   
   if(g_useBollingerBands && bbH != INVALID_HANDLE) 
   { 
      ok &= (CopyBuffer(bbH, 1, 0, 10, bbUpperBuf) >= 10); 
      ok &= (CopyBuffer(bbH, 0, 0, 10, bbMiddleBuf) >= 10); 
      ok &= (CopyBuffer(bbH, 2, 0, 10, bbLowerBuf) >= 10); 
   }
   if((g_useATRforSLTP || UseATRforPending || g_useATRTrailing) && atrH != INVALID_HANDLE) 
      ok &= (CopyBuffer(atrH, 0, 0, 10, atrBuf) >= 10);
      
   if(!ok) 
   { 
      currentAnalysis.trend = TREND_UNKNOWN; 
      return; 
   }

   currentAnalysis.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   currentAnalysis.rsiValue = rsi[0]; 
   currentAnalysis.macdValue = macdMain[0] - macdSignal[0];
   currentAnalysis.adxValue = adx[0]; 
   currentAnalysis.adxPlus = adxPlus[0]; 
   currentAnalysis.adxMinus = adxMinus[0];
   currentAnalysis.atrValue = (ArraySize(atrBuf) >= 1) ? atrBuf[0] : 0;
   currentAnalysis.bbUpper = (ArraySize(bbUpperBuf) >= 1) ? bbUpperBuf[0] : 0;
   currentAnalysis.bbLower = (ArraySize(bbLowerBuf) >= 1) ? bbLowerBuf[0] : 0;
   currentAnalysis.bbMiddle = (ArraySize(bbMiddleBuf) >= 1) ? bbMiddleBuf[0] : 0;

   currentAnalysis.spreadTicks = GetSpreadTicks();
   currentAnalysis.marketOpen = IsMarketOpen();
   currentAnalysis.spreadOk = IsSpreadAcceptable(); 
   currentAnalysis.newsOk = IsNewsSafe();
   currentAnalysis.sessionOk = IsSessionValid();
   currentAnalysis.currentSession = GetCurrentSession();

   currentAnalysis.trend = DetermineTrend();
   currentAnalysis.trendStrength = UseADX ? currentAnalysis.adxValue : CalculateTrendStrength();
   
   // NEW: RSI Divergence detection
   if(UseRSIDivergence)
   {
      currentAnalysis.rsiDivergenceBuy = DetectRSIDivergence(true);
      currentAnalysis.rsiDivergenceSell = DetectRSIDivergence(false);
   }
   
   currentAnalysis.buySignal = GenerateBuySignal();
   currentAnalysis.sellSignal = GenerateSellSignal();
   currentAnalysis.buyScore = CalculateBuyScore();
   currentAnalysis.sellScore = CalculateSellScore();
   currentAnalysis.recommendation = GenerateRecommendation();
}

//+------------------------------------------------------------------+
//| RSI Divergence Detection (NEW)                                   |
//+------------------------------------------------------------------+
bool DetectRSIDivergence(bool lookForBuy)
{
   if(ArraySize(rsi) < 10) return false;
   
   // Find last two price swings
   double priceHigh1 = 0, priceHigh2 = 0;
   double priceLow1 = 99999, priceLow2 = 99999;
   double rsiHigh1 = 0, rsiHigh2 = 0;
   double rsiLow1 = 100, rsiLow2 = 100;
   int idx1 = -1, idx2 = -1;
   
   // Find recent swing high/low
   for(int i = 2; i < 8; i++)
   {
      // For buy divergence: price makes lower low, RSI makes higher low
      if(lookForBuy)
      {
         if(rsi[i] < rsiLow1) 
         {
            if(idx1 >= 0) { rsiLow2 = rsiLow1; priceLow2 = priceLow1; idx2 = idx1; }
            rsiLow1 = rsi[i]; priceLow1 = iLow(_Symbol, TrendTimeframe, i); idx1 = i;
         }
      }
      // For sell divergence: price makes higher high, RSI makes lower high
      else
      {
         if(rsi[i] > rsiHigh1) 
         {
            if(idx1 >= 0) { rsiHigh2 = rsiHigh1; priceHigh2 = priceHigh1; idx2 = idx1; }
            rsiHigh1 = rsi[i]; priceHigh1 = iHigh(_Symbol, TrendTimeframe, i); idx1 = i;
         }
      }
   }
   
   if(lookForBuy && idx1 >= 0 && idx2 >= 0)
   {
      // Price lower low, RSI higher low = bullish divergence
      return (priceLow1 < priceLow2 && rsiLow1 > rsiLow2 && rsiLow1 < 40);
   }
   else if(!lookForBuy && idx1 >= 0 && idx2 >= 0)
   {
      // Price higher high, RSI lower high = bearish divergence
      return (priceHigh1 > priceHigh2 && rsiHigh1 < rsiHigh2 && rsiHigh1 > 60);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Utility Functions (FIXED)                                        |
//+------------------------------------------------------------------+
double GetSpreadTicks() 
{ 
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return 0;
   double s = ask - bid;
   return (g_tickSize > 0) ? s / g_tickSize : s / g_pointValue; 
}

// FIX: Now accepts double for precision
double TicksToPrice(double ticks) 
{ 
   return (g_tickSize > 0) ? ticks * g_tickSize : ticks * g_pointValue; 
}

double PriceToTicks(double price) 
{ 
   return (g_tickSize > 0) ? price / g_tickSize : price / g_pointValue; 
}

bool IsMarginSafe() 
{ 
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); 
   double mu = AccountInfoDouble(ACCOUNT_MARGIN); 
   if(mu <= 0) return true; 
   if(ml > 0 && ml < MinMarginLevel) 
   {
      Print("MARGIN WARNING: Level ", DoubleToString(ml, 0), "% below ", MinMarginLevel, "%");
      return false; 
   }
   return true; 
}

// NEW: Drawdown protection
bool IsDrawdownSafe()
{
   if(MaxDrawdownPercent <= 0) return true;
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(peakBalance <= 0) return true;
   
   double drawdown = (peakBalance - currentEquity) / peakBalance * 100.0;
   
   if(drawdown >= MaxDrawdownPercent)
   {
      if(TimeCurrent() - lastSpreadSpike > 60)  // Throttle warnings
      {
         Print("DRAWDOWN WARNING: ", DoubleToString(drawdown, 2), "% exceeds max ", MaxDrawdownPercent, "%");
         lastSpreadSpike = TimeCurrent();
      }
      return false;
   }
   return true;
}

// FIX: Corrected session logic
ENUM_SESSION GetCurrentSession() 
{ 
   MqlDateTime dt; 
   TimeCurrent(dt); 
   int h = dt.hour;
   
   // London/NY overlap (13:00-17:00 server time typical)
   if(h >= 13 && h < 17) return SESSION_OVERLAP;
   // London session (08:00-17:00)
   if(h >= 8 && h < 13) return SESSION_LONDON;
   // New York session (13:00-22:00)
   if(h >= 17 && h < 22) return SESSION_NY;
   // Asia session (00:00-08:00)
   if(h >= 0 && h < 8) return SESSION_ASIA;
   
   return SESSION_CLOSED; 
}

bool IsSessionValid() 
{ 
   if(!UseSessionOverlapOnly) return true; 
   ENUM_SESSION s = GetCurrentSession(); 
   return (s == SESSION_OVERLAP || s == SESSION_LONDON || s == SESSION_NY); 
}

//+------------------------------------------------------------------+
//| FILTERS (FIXED)                                                  |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   if(!UseMarketHoursFilter) return true;
   
   MqlDateTime dt; 
   TimeCurrent(dt);
   
   // Weekend check
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   
   // Friday evening early close
   if(AvoidFridayEvening && dt.day_of_week == 5 && 
      (dt.hour > FridayStopHour || (dt.hour == FridayStopHour && dt.min >= FridayStopMin))) 
      return false;
   
   // FIX: Consistent market hours check
   if(MarketOpenHour < MarketCloseHour)
   {
      // Normal hours (e.g., 7-20)
      return (dt.hour >= MarketOpenHour && dt.hour < MarketCloseHour);
   }
   else
   {
      // Overnight hours (e.g., 22-6)
      return (dt.hour >= MarketOpenHour || dt.hour < MarketCloseHour);
   }
}

bool IsSpreadAcceptable()
{
   if(!UseMaxSpreadFilter) return true;
   
   double currentSpread = GetSpreadTicks();
   
   // FIX: If MaxSpreadTicks is 0, only use dynamic spread
   if(MaxSpreadTicks > 0 && currentSpread > MaxSpreadTicks) 
   { 
      lastSpreadSpike = TimeCurrent(); 
      return false; 
   }
   
   // FIX: Use TRUE average spread from actual tick data
   if(UseDynamicSpread && g_realAverageSpread > 0)
   {
      if(currentSpread > (g_realAverageSpread * DynamicSpreadMax))
      {
         lastSpreadSpike = TimeCurrent();
         static datetime lastDynLog = 0;
         if(TimeCurrent() - lastDynLog > 60) 
         { 
            Print("DYNAMIC SPREAD BLOCK: ", DoubleToString(currentSpread, 1), " > Avg ", 
                  DoubleToString(g_realAverageSpread, 1), " (", DynamicSpreadMax, "x)"); 
            lastDynLog = TimeCurrent(); 
         }
         return false;
      }
   }
   
   if(lastSpreadSpike > 0 && TimeCurrent() - lastSpreadSpike < SpreadCooldownSec) 
      return false;
      
   lastSpreadSpike = 0; 
   return true;
}

bool IsNewsSafe()
{
   if(!UseNewsFilter) return true;
   
   MqlDateTime dt; 
   TimeCurrent(dt);
   
   // Weekend handled by IsMarketOpen()
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return true;
   
   // Monday early open (potential gap)
   if(dt.day_of_week == 1 && dt.hour < 2) return false;
   
   if(UseCustomNewsWindows)
   {
      int cm = dt.hour * 60 + dt.min;
      for(int i = 0; i < 6; i++)
      {
         int ws = g_newsWindows[i].startHour * 60 + g_newsWindows[i].startMin;
         int we = g_newsWindows[i].endHour * 60 + g_newsWindows[i].endMin;
         
         // Handle overnight windows
         if(we < ws)
         {
            if(cm >= ws - NewsMinutesBefore || cm <= we + NewsMinutesAfter)
            {
               newsBlockActive = true; 
               return false; 
            }
         }
         else
         {
            if(cm >= ws - NewsMinutesBefore && cm <= we + NewsMinutesAfter)
            {
               newsBlockActive = true; 
               return false; 
            }
         }
      }
   }
   
   newsBlockActive = false; 
   return true;
}

//+------------------------------------------------------------------+
//| Signals (ENHANCED)                                               |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION DetermineTrend()
{
   double p = currentAnalysis.price;
   bool bullish = (maFast[0] > maSlow[0] && maSlow[0] > maTrend[0] && p > maFast[0]);
   bool bearish = (maFast[0] < maSlow[0] && maSlow[0] < maTrend[0] && p < maFast[0]);
   
   if(UseADX && adx[0] > ADX_Threshold) 
   { 
      if(bullish && adxPlus[0] > adxMinus[0]) return TREND_UP; 
      if(bearish && adxMinus[0] > adxPlus[0]) return TREND_DOWN; 
   }
   if(bullish) return TREND_UP; 
   if(bearish) return TREND_DOWN; 
   return TREND_SIDEWAYS;
}

double CalculateTrendStrength() 
{ 
   double d = MathAbs(currentAnalysis.price - maTrend[0]) / maTrend[0] * 100.0; 
   double sp = MathAbs(maFast[0] - maSlow[0]) / maSlow[0] * 100.0; 
   double sl = MathAbs(maFast[0] - maFast[1]) / maFast[1] * 100.0; 
   return MathMin(100.0, d * 10.0 + sp * 20.0 + sl * 50.0); 
}

bool GenerateBuySignal()
{
   if(!currentAnalysis.marketOpen || !currentAnalysis.spreadOk || 
      !currentAnalysis.newsOk || !currentAnalysis.sessionOk) return false;
   if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses) return false;
   if(cooldownBarsLeft > 0) return false;
   if(CountOpenPositions() >= MaxOpenPositions) return false;  // NEW: Position limit
   
   int score = 0;
   
   // Trend alignment
   if(currentAnalysis.trend == TREND_UP) score += 30; 
   else if(currentAnalysis.trend == TREND_SIDEWAYS) score += 5; 
   else return false;
   
   // RSI analysis
   if(UseRSI) 
   {
      if(rsi[0] < RSI_Oversold && rsi[0] > rsi[1]) score += 25;
      else if(rsi[0] >= RSI_Oversold && rsi[0] <= 50 && rsi[0] > rsi[1] && rsi[1] < rsi[2]) score += 20;
      else if(rsi[0] > 50 && rsi[0] < RSI_Overbought && rsi[0] > rsi[1]) score += 15;
      if(rsi[0] > RSI_Overbought) score -= 15;
   }
   
   // NEW: RSI Divergence bonus
   if(UseRSIDivergence && currentAnalysis.rsiDivergenceBuy) score += 20;
   
   // MACD analysis
   if(UseMACD) 
   {
      if(macdMain[0] > macdSignal[0] && macdMain[1] <= macdSignal[1]) score += 20;  // Cross up
      else if(macdMain[0] > macdSignal[0] && macdMain[0] > macdMain[1]) score += 15;  // Rising
      else if(macdMain[0] < macdSignal[0]) score -= 10;
   }
   
   // MA alignment
   if(maFast[0] > maSlow[0]) score += 10;
   if(currentAnalysis.price > maTrend[0]) score += 5;
   
   // Bollinger Bands
   if(g_useBollingerBands && RequireBBTouch) 
   {
      if(currentAnalysis.price <= currentAnalysis.bbLower) score += 15;
      else if(currentAnalysis.price >= currentAnalysis.bbUpper) score -= 25;
   }
   
   // ADX filter
   if(UseADX && currentAnalysis.adxValue < ADX_Threshold) score -= 15;
   
   // NEW: Session bonus
   if(currentAnalysis.currentSession == SESSION_OVERLAP) score += 5;
   
   return (score >= 55);
}

bool GenerateSellSignal()
{
   if(!currentAnalysis.marketOpen || !currentAnalysis.spreadOk || 
      !currentAnalysis.newsOk || !currentAnalysis.sessionOk) return false;
   if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses) return false;
   if(cooldownBarsLeft > 0) return false;
   if(CountOpenPositions() >= MaxOpenPositions) return false;  // NEW: Position limit
   
   int score = 0;
   
   // Trend alignment
   if(currentAnalysis.trend == TREND_DOWN) score += 30; 
   else if(currentAnalysis.trend == TREND_SIDEWAYS) score += 5; 
   else return false;
   
   // RSI analysis
   if(UseRSI) 
   {
      if(rsi[0] > RSI_Overbought && rsi[0] < rsi[1]) score += 25;
      else if(rsi[0] >= 50 && rsi[0] <= RSI_Overbought && rsi[0] < rsi[1] && rsi[1] > rsi[2]) score += 20;
      else if(rsi[0] < 50 && rsi[0] > RSI_Oversold && rsi[0] < rsi[1]) score += 15;
      if(rsi[0] < RSI_Oversold) score -= 15;
   }
   
   // NEW: RSI Divergence bonus
   if(UseRSIDivergence && currentAnalysis.rsiDivergenceSell) score += 20;
   
   // MACD analysis
   if(UseMACD) 
   {
      if(macdMain[0] < macdSignal[0] && macdMain[1] >= macdSignal[1]) score += 20;  // Cross down
      else if(macdMain[0] < macdSignal[0] && macdMain[0] < macdMain[1]) score += 15;  // Falling
      else if(macdMain[0] > macdSignal[0]) score -= 10;
   }
   
   // MA alignment
   if(maFast[0] < maSlow[0]) score += 10;
   if(currentAnalysis.price < maTrend[0]) score += 5;
   
   // Bollinger Bands
   if(g_useBollingerBands && RequireBBTouch) 
   {
      if(currentAnalysis.price >= currentAnalysis.bbUpper) score += 15;
      else if(currentAnalysis.price <= currentAnalysis.bbLower) score -= 25;
   }
   
   // ADX filter
   if(UseADX && currentAnalysis.adxValue < ADX_Threshold) score -= 15;
   
   // NEW: Session bonus
   if(currentAnalysis.currentSession == SESSION_OVERLAP) score += 5;
   
   return (score >= 55);
}

// NEW: Count open positions
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      count++;
   }
   return count;
}

double CalculateBuyScore() 
{ 
   double s = 50.0; 
   if(currentAnalysis.trend == TREND_UP) s += 20.0; 
   if(currentAnalysis.buySignal) s += 25.0; 
   if(currentAnalysis.sessionOk && currentAnalysis.spreadOk) s += 5.0;
   if(UseRSIDivergence && currentAnalysis.rsiDivergenceBuy) s += 10.0;  // NEW
   if(cooldownBarsLeft > 0) s -= 30.0; 
   return MathMin(100.0, MathMax(0.0, s)); 
}

double CalculateSellScore() 
{ 
   double s = 50.0; 
   if(currentAnalysis.trend == TREND_DOWN) s += 20.0; 
   if(currentAnalysis.sellSignal) s += 25.0; 
   if(currentAnalysis.sessionOk && currentAnalysis.spreadOk) s += 5.0;
   if(UseRSIDivergence && currentAnalysis.rsiDivergenceSell) s += 10.0;  // NEW
   if(cooldownBarsLeft > 0) s -= 30.0; 
   return MathMin(100.0, MathMax(0.0, s)); 
}

string GenerateRecommendation()
{
   if(cooldownBarsLeft > 0) return "COOLDOWN " + IntegerToString(cooldownBarsLeft);
   if(currentAnalysis.buySignal && !currentAnalysis.sellSignal) return "BUY";
   if(currentAnalysis.sellSignal && !currentAnalysis.buySignal) return "SELL";
   if(currentAnalysis.buySignal && currentAnalysis.sellSignal) return "CONFLICT";
   if(!currentAnalysis.spreadOk) return "HIGH SPREAD";
   if(!currentAnalysis.newsOk) return "NEWS BLOCK";
   if(!currentAnalysis.sessionOk) return "WAIT SESSION";
   if(!currentAnalysis.marketOpen) return "CLOSED";
   if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses) return "LOSS LIMIT";
   if(CountOpenPositions() >= MaxOpenPositions) return "MAX POSITIONS";  // NEW
   if(!IsDrawdownSafe()) return "DRAWDOWN";  // NEW
   return "WAIT";
}

void CheckSignalChange()
{
   static string lastSignal = ""; 
   string curr = currentAnalysis.recommendation;
   
   if(curr != lastSignal && curr != "WAIT" && curr != "CONFLICT")
   {
      if(EnableSoundAlerts) 
      { 
         if(curr == "BUY") PlaySound(BuySoundFile); 
         else if(curr == "SELL") PlaySound(SellSoundFile); 
      }
      if(curr == "BUY" || curr == "SELL") 
         Alert("GoldScalp: ", curr, " @ ", DoubleToString(currentAnalysis.price, _Digits));
      lastSignal = curr;
   }
}

//+------------------------------------------------------------------+
//| Trade Execution (FIXED)                                          |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   if(!TradeAllowed()) return;
   
   // FIX: Get FRESH price AFTER any confirmation
   if(UseTradeConfirmation && MessageBox("Confirm BUY at current price?", "Trade Confirmation", MB_YESNO) != IDYES) 
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0) { Print("ERROR: Invalid ASK price"); return; }
   
   double lot = UseAutoLot ? CalculateAutoLot() : NormalizeVolume(LotSize);
   if(lot > MaxLotSize) lot = MaxLotSize;
   
   double slTicks = 0, tpTicks = 0; 
   GetATRBasedSLTP(slTicks, tpTicks);
   
   // FIX: Use double precision
   double slP = (slTicks > 0) ? NormalizeDouble(ask - TicksToPrice(slTicks), _Digits) : 0;
   double tpP = (tpTicks > 0) ? NormalizeDouble(ask + TicksToPrice(tpTicks), _Digits) : 0;
   
   if(!CheckStopLevel(ask, slP, tpP, ORDER_TYPE_BUY)) 
   {
      Print("SL/TP too close to price - adjust or disable stops level check");
      return;
   }
   
   if(SendInstantOrder(ORDER_TYPE_BUY, lot, ask, slP, tpP))
   {
      if(EnableSoundAlerts) PlaySound(BuySoundFile);
   }
}

void ExecuteSell()
{
   if(!TradeAllowed()) return;
   
   // FIX: Get FRESH price AFTER any confirmation
   if(UseTradeConfirmation && MessageBox("Confirm SELL at current price?", "Trade Confirmation", MB_YESNO) != IDYES) 
      return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0) { Print("ERROR: Invalid BID price"); return; }
   
   double lot = UseAutoLot ? CalculateAutoLot() : NormalizeVolume(LotSize);
   if(lot > MaxLotSize) lot = MaxLotSize;
   
   double slTicks = 0, tpTicks = 0; 
   GetATRBasedSLTP(slTicks, tpTicks);
   
   // FIX: Use double precision
   double slP = (slTicks > 0) ? NormalizeDouble(bid + TicksToPrice(slTicks), _Digits) : 0;
   double tpP = (tpTicks > 0) ? NormalizeDouble(bid - TicksToPrice(tpTicks), _Digits) : 0;
   
   if(!CheckStopLevel(bid, slP, tpP, ORDER_TYPE_SELL)) 
   {
      Print("SL/TP too close to price - adjust or disable stops level check");
      return;
   }
   
   if(SendInstantOrder(ORDER_TYPE_SELL, lot, bid, slP, tpP))
   {
      if(EnableSoundAlerts) PlaySound(SellSoundFile);
   }
}

bool TradeAllowed() 
{ 
   if(!IsMarginSafe()) return false; 
   if(!IsDrawdownSafe()) return false;  // NEW
   if(MaxDailyTrades > 0 && dailyTradeCount >= MaxDailyTrades) return false; 
   if(MaxDailyLoss > 0 && dailyLoss >= MaxDailyLoss) return false; 
   if(cooldownBarsLeft > 0) return false; 
   if(CountOpenPositions() >= MaxOpenPositions) return false;  // NEW
   return true; 
}

double NormalizeVolume(double lot) 
{ 
   if(g_volumeStep > 0) 
      lot = MathFloor(lot / g_volumeStep) * g_volumeStep; 
   lot = MathMax(g_volumeMin, MathMin(lot, g_volumeMax)); 
   return NormalizeDouble(lot, 2); 
}

double CalculateAutoLot()
{
   if(g_tickValue <= 0 || g_tickSize <= 0) return g_volumeMin;
   
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double slPriceDist = TicksToPrice(AutoLotSLPoints); 
   double ticksInSL = slPriceDist / g_tickSize;
   
   if(ticksInSL <= 0) return g_volumeMin;
   
   double riskPerLot = ticksInSL * g_tickValue; 
   if(riskPerLot <= 0) return g_volumeMin;
   
   double lot = riskAmount / riskPerLot;
   
   // Account for commission
   if(g_exnessCommission > 0) 
   { 
      double comm = g_exnessCommission * lot * 2.0; 
      lot = MathMax(0.0, riskAmount - comm) / riskPerLot; 
   }
   
   lot = NormalizeVolume(lot); 
   if(lot > MaxLotSize) lot = MaxLotSize; 
   return lot; 
}

// FIX: Returns double ticks for precision
void GetATRBasedSLTP(double &slTicks, double &tpTicks)
{
   if(g_useATRforSLTP && currentAnalysis.atrValue > 0 && g_tickSize > 0) 
   { 
      slTicks = MathMax(ATR_MinSLPoints, MathMin(ATR_MaxSLPoints, 
                 currentAnalysis.atrValue * ATR_SL_Multiplier / g_tickSize)); 
      tpTicks = MathMax(0.0, currentAnalysis.atrValue * ATR_TP_Multiplier / g_tickSize); 
   } 
   else 
   { 
      slTicks = (double)StopLossPoints; 
      tpTicks = (double)TakeProfitPoints; 
   }
}

bool CheckStopLevel(double entry, double sl, double tp, ENUM_ORDER_TYPE type)
{
   g_stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); 
   int fl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL); 
   int ml = MathMax(g_stopsLevel, fl);
   
   double minDist = (double)ml * g_tickSize; 
   if(minDist <= 0) return true;
   
   if(type == ORDER_TYPE_BUY) 
   { 
      if(sl > 0 && (entry - sl) < minDist) return false; 
      if(tp > 0 && (tp - entry) < minDist) return false; 
   }
   else 
   { 
      if(sl > 0 && (sl - entry) < minDist) return false; 
      if(tp > 0 && (entry - tp) < minDist) return false; 
   }
   return true;
}

ENUM_ORDER_TYPE_FILLING GetFillingMode() 
{ 
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE); 
   if((f & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK; 
   if((f & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC; 
   return ORDER_FILLING_RETURN; 
}

// FIX: Returns bool for success/failure tracking
bool SendInstantOrder(ENUM_ORDER_TYPE type, double lot, double price, double sl, double tp)
{
   MqlTradeRequest req = {}; 
   MqlTradeResult res = {};
   
   req.action = TRADE_ACTION_DEAL; 
   req.symbol = _Symbol; 
   req.volume = lot; 
   req.type = type; 
   req.price = price;
   req.sl = sl; 
   req.tp = tp; 
   req.deviation = MaxSlippage; 
   req.magic = MagicNumber; 
   req.comment = TradeComment; 
   req.type_filling = GetFillingMode();
   
   if(!OrderSend(req, res))
   {
      Print("OrderSend FAILED: Error ", GetLastError(), " | Retcode: ", res.retcode, " | ", res.comment);
      return false;
   }
   
   if(res.retcode != TRADE_RETCODE_DONE)
   {
      Print("Order REJECTED: Retcode ", res.retcode, " | ", res.comment);
      
      // Handle requote
      if(res.retcode == TRADE_RETCODE_REQUOTE)
      {
         Print("Requote detected - price may have moved");
      }
      return false;
   }
   
   dailyTradeCount++; 
   double comm = g_exnessCommission * lot; 
   dailyCommission += comm;
   
   Print("ORDER EXECUTED: ", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), 
         " Lot:", DoubleToString(lot, 2), 
         " Price:", DoubleToString(price, _Digits),
         " SL:", DoubleToString(sl, _Digits), 
         " TP:", DoubleToString(tp, _Digits),
         " Ticket:", res.order);
   
   if(EnableTradeJournal) 
      LogToFile("Trade", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), 
                "Lot:" + DoubleToString(lot, 2) + " Price:" + DoubleToString(price, _Digits));
   
   return true;
}

//+------------------------------------------------------------------+
//| Risk Management (ENHANCED)                                       |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   double td, sd, ad;
   
   // NEW: ATR-based trailing
   if(g_useATRTrailing && currentAnalysis.atrValue > 0 && g_tickSize > 0)
   {
      td = currentAnalysis.atrValue * ATRTrailingMultiplier;
      sd = td * 0.3;
      ad = td * 0.8;
   }
   else
   {
      td = TicksToPrice(TrailingStopPoints);
      sd = TicksToPrice(TrailingStepPoints);
      ad = TicksToPrice(TrailingActivationPts);
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double cSL = PositionGetDouble(POSITION_SL); 
      double cTP = PositionGetDouble(POSITION_TP); 
      double nSL = 0; 
      bool mod = false;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
      { 
         if((bid - op) > ad) 
         { 
            nSL = NormalizeDouble(bid - td, _Digits); 
            if(cSL == 0 || nSL > cSL + sd) mod = true; 
         } 
      }
      else 
      { 
         if((op - ask) > ad) 
         { 
            nSL = NormalizeDouble(ask + td, _Digits); 
            if(cSL == 0 || nSL < cSL - sd) mod = true; 
         } 
      }
      
      if(mod && nSL > 0) 
         ModifySLTP(t, nSL, cTP);
   }
}

void ApplyBreakEven()
{
   double bd = TicksToPrice(BreakEvenPoints); 
   double bp = TicksToPrice(BreakEvenProfitPts); 
   double td = TicksToPrice(TrailingActivationPts);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double cSL = PositionGetDouble(POSITION_SL); 
      double cTP = PositionGetDouble(POSITION_TP); 
      double nSL = 0; 
      bool mod = false;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
      { 
         double p = bid - op; 
         if(p >= bd && p < td) 
         { 
            nSL = NormalizeDouble(op + bp, _Digits); 
            if(cSL == 0 || cSL < nSL) mod = true; 
         } 
      }
      else 
      { 
         double p = op - ask; 
         if(p >= bd && p < td) 
         { 
            nSL = NormalizeDouble(op - bp, _Digits); 
            if(cSL == 0 || cSL > nSL) mod = true; 
         } 
      }
      
      if(mod && nSL > 0) 
         ModifySLTP(t, nSL, cTP);
   }
}

// ENHANCED: Multi-level partial close
void AutoPartialClose()
{
   double pd1 = TicksToPrice(PartialCloseAtProfit);
   double pd2 = TicksToPrice(Partial2AtProfit);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double tv = PositionGetDouble(POSITION_VOLUME);
      
      ENUM_PARTIAL_LEVEL pLevel = GetPositionPartialLevel(t);
      double profit = 0;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         profit = bid - op;
      else
         profit = op - ask;
      
      // First partial close
      if(pLevel == PARTIAL_NONE && profit >= pd1)
      {
         double cv = NormalizeVolume(tv * PartialClosePercent / 100.0);
         if(cv >= g_volumeMin && cv < tv)
         {
            if(ClosePosition(t, cv))
            {
               SetPositionPartialLevel(t, PARTIAL_1_DONE);
               Print("Partial close 1 executed: ", DoubleToString(cv, 2), " lots at profit ", DoubleToString(profit / g_pointValue, 0), " points");
            }
         }
      }
      // Second partial close (NEW)
      else if(UseMultiLevelPartial && pLevel == PARTIAL_1_DONE && profit >= pd2)
      {
         double cv = NormalizeVolume(tv * Partial2Percent / 100.0);
         if(cv >= g_volumeMin && cv < tv)
         {
            if(ClosePosition(t, cv))
            {
               SetPositionPartialLevel(t, PARTIAL_2_DONE);
               Print("Partial close 2 executed: ", DoubleToString(cv, 2), " lots at profit ", DoubleToString(profit / g_pointValue, 0), " points");
            }
         }
      }
   }
}

bool ModifySLTP(ulong ticket, double sl, double tp) 
{ 
   MqlTradeRequest req = {}; 
   MqlTradeResult res = {}; 
   
   req.action = TRADE_ACTION_SLTP; 
   req.position = ticket; 
   req.symbol = _Symbol; 
   req.sl = sl; 
   req.tp = tp; 
   
   if(!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
   {
      // Silent fail for trailing - don't spam journal
      return false;
   }
   return true;
}

void CloseAllTrades() 
{ 
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   { 
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue; 
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) 
         ClosePosition(t, PositionGetDouble(POSITION_VOLUME)); 
   } 
}

void ManualPartialClose()  // RENAMED for clarity
{ 
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   { 
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue; 
      
      double tv = PositionGetDouble(POSITION_VOLUME); 
      double cv = NormalizeVolume(tv * PartialClosePercent / 100.0); 
      if(cv >= g_volumeMin && cv < tv) 
         ClosePosition(t, cv); 
   } 
}

bool ClosePosition(ulong ticket, double volume)
{
   MqlTradeRequest req = {}; 
   MqlTradeResult res = {};
   
   if(!PositionSelectByTicket(ticket)) return false;
   
   req.action = TRADE_ACTION_DEAL; 
   req.position = ticket; 
   req.symbol = _Symbol; 
   req.volume = NormalizeVolume(volume);
   req.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price = (req.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   req.deviation = MaxSlippage; 
   req.magic = MagicNumber; 
   req.comment = TradeComment + "_CLOSE"; 
   req.type_filling = GetFillingMode();
   
   if(!OrderSend(req, res) || res.retcode != TRADE_RETCODE_DONE)
   {
      Print("Close failed for ticket ", ticket, ": ", res.retcode, " ", res.comment);
      return false;
   }
   return true;
}

void CheckCloseOnOppositeSignal() 
{ 
   if(currentAnalysis.buySignal) CloseAllByType(POSITION_TYPE_SELL); 
   if(currentAnalysis.sellSignal) CloseAllByType(POSITION_TYPE_BUY); 
}

void CloseAllByType(ENUM_POSITION_TYPE type) 
{ 
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   { 
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue; 
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetInteger(POSITION_TYPE) == type) 
         ClosePosition(t, PositionGetDouble(POSITION_VOLUME)); 
   } 
}

//+------------------------------------------------------------------+
//| Journal & UI Helpers                                              |
//+------------------------------------------------------------------+
void InitJournal() 
{ 
   g_journalHandle = FileOpen(JournalFileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ","); 
   if(g_journalHandle != INVALID_HANDLE) 
      FileWrite(g_journalHandle, "Time", "Type", "Action", "Details"); 
}

void LogToFile(string type, string action, string details) 
{ 
   if(g_journalHandle == INVALID_HANDLE) return; 
   MqlDateTime dt; 
   TimeCurrent(dt); 
   FileWrite(g_journalHandle, 
             StringFormat("%04d.%02d.%02d %02d:%02d:%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec), 
             type, action, details); 
   FileFlush(g_journalHandle); 
}

void CreateRect(string name, int x, int y, int w, int h, color clr) 
{ 
   string n = panelPrefix + name; 
   ObjectDelete(0, n); 
   ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0); 
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y); 
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w); 
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h); 
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, clr); 
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT); 
   ObjectSetInteger(0, n, OBJPROP_CORNER, PanelCorner); 
   ObjectSetInteger(0, n, OBJPROP_BACK, false); 
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); 
}

void CreateLabel(string name, string text, int x, int y, color clr) 
{ 
   string n = panelPrefix + name; 
   ObjectDelete(0, n); 
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0); 
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y); 
   ObjectSetString(0, n, OBJPROP_TEXT, text); 
   ObjectSetString(0, n, OBJPROP_FONT, "Consolas"); 
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, FontSize); 
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr); 
   ObjectSetInteger(0, n, OBJPROP_CORNER, PanelCorner); 
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER); 
   ObjectSetInteger(0, n, OBJPROP_BACK, false); 
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); 
}

void CreateButton(string name, string text, int x, int y, int w, int h, color bg, color txt) 
{ 
   string n = panelPrefix + name; 
   ObjectDelete(0, n); 
   ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0); 
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y); 
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w); 
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h); 
   ObjectSetString(0, n, OBJPROP_TEXT, text); 
   ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold"); 
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, FontSize + 1); 
   ObjectSetInteger(0, n, OBJPROP_COLOR, txt); 
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg); 
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrWhite); 
   ObjectSetInteger(0, n, OBJPROP_CORNER, PanelCorner); 
   ObjectSetInteger(0, n, OBJPROP_BACK, false); 
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); 
   ObjectSetInteger(0, n, OBJPROP_STATE, false); 
}

void ObjSetText(string name, string text, color clr) 
{ 
   string n = panelPrefix + name; 
   if(ObjectFind(0, n) >= 0) 
   { 
      ObjectSetString(0, n, OBJPROP_TEXT, text); 
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr); 
   } 
}

//+------------------------------------------------------------------+
//| Panel Creation & Updates (FIXED - Complete)                       |
//+------------------------------------------------------------------+
bool CreateTradePanel()
{
   DeletePanelObjects(); 
   int x = 5, y = 5, w = panelMinimized ? 220 : 420, h = panelMinimized ? 45 : 530;
   
   CreateRect("Bg", x, y, w, h, PanelBgColor); 
   CreateLabel("Title", "Gold Scalp v8.0 [STD]", x + 10, y + 6, clrDarkOrange);
   CreateButton("Minimize", panelMinimized ? "[+]" : "[-]", panelMinimized ? 180 : 380, y + 8, 30, 22, clrDimGray, clrWhite);
   
   if(!panelMinimized)
   {
      CreateLabel("SessionLbl", "Session: --", x + 10, y + 32, clrBlack); 
      CreateLabel("TrendLbl", "Trend: --", x + 10, y + 52, clrBlack);
      
      CreateButton("BuyBtn", "BUY", x + 10, y + 78, 120, 42, clrForestGreen, clrWhite); 
      CreateButton("SellBtn", "SELL", x + 140, y + 78, 120, 42, clrCrimson, clrWhite); 
      CreateButton("CloseAllBtn", "CLOSE ALL", x + 270, y + 78, 120, 42, clrDarkRed, clrWhite);
      
      if(UsePartialClose) 
         CreateButton("PartialBtn", "PARTIAL 50%", x + 270, y + 125, 120, 28, clrOrange, clrBlack);
      
      CreateLabel("SigLbl", "Scalp Score", x + 10, y + 160, clrDarkGray); 
      CreateRect("StrengthBg", x + 10, y + 178, 380, 18, clrLightGray); 
      CreateRect("StrengthFill", x + 10, y + 178, 0, 18, clrLime);
      
      CreateLabel("StatsLbl", "Account Stats", x + 10, y + 205, clrDarkOrange); 
      CreateLabel("BalanceLbl", "Balance: --", x + 10, y + 223, clrBlack); 
      CreateLabel("EquityLbl", "Equity: --", x + 10, y + 241, clrBlack);
      CreateLabel("DailyPnLLbl", "Daily P/L: --", x + 10, y + 259, clrBlack); 
      CreateLabel("DailyLossLbl", "Daily Risk: --", x + 200, y + 259, clrBlack);
      CreateLabel("WinRateLbl", "Win Rate: --", x + 10, y + 277, clrBlack); 
      CreateLabel("PFLabel", "PF: --", x + 200, y + 277, clrBlack);
      CreateLabel("ConsecLbl", "Consec Loss: --", x + 10, y + 295, clrBlack); 
      CreateLabel("CommLbl", "Comm: --", x + 200, y + 295, clrDarkGray);
      CreateLabel("SwapLbl", "Swap: --", x + 10, y + 313, clrDarkGray); 
      CreateLabel("MarginLbl", "Margin: --", x + 200, y + 313, clrBlack);
      CreateLabel("DrawdownLbl", "Drawdown: --", x + 10, y + 331, clrDarkGray);  // NEW
      
      CreateLabel("MktLbl", "Market Data", x + 10, y + 354, clrDarkOrange); 
      CreateLabel("RecLbl", "Signal: --", x + 10, y + 372, clrBlack);
      CreateLabel("PosInfoLbl", "Positions: --", x + 10, y + 390, clrBlack); 
      CreateLabel("ATRLbl", "ATR: --", x + 10, y + 408, clrBlack);
      CreateLabel("SpreadLbl", "Spread: --", x + 200, y + 408, clrBlack); 
      CreateLabel("CooldownLbl", "Status: --", x + 10, y + 426, clrBlack);
      CreateLabel("BBLbl", "BB: --", x + 10, y + 444, clrBlack); 
      CreateLabel("VolLbl", "Vol: --", x + 200, y + 444, clrBlack);
      CreateLabel("ExnessWarn", "Exness: OK", x + 10, y + 462, clrLimeGreen); 
      CreateLabel("DivergenceLbl", "Div: --", x + 200, y + 462, clrDarkGray);  // NEW
      CreateLabel("VersionLbl", "v8.0 STD", x + 350, y + 510, clrDarkGray);
   }
   
   ChartRedraw(); 
   return true;
}

void DeletePanelObjects() 
{ 
   string n[36] = {
      "Bg", "Title", "Minimize", "SessionLbl", "TrendLbl", "BuyBtn", "SellBtn", 
      "CloseAllBtn", "PartialBtn", "SigLbl", "StrengthBg", "StrengthFill", "StatsLbl", 
      "BalanceLbl", "EquityLbl", "DailyPnLLbl", "DailyLossLbl", "WinRateLbl", "PFLabel", 
      "ConsecLbl", "CommLbl", "SwapLbl", "MarginLbl", "MktLbl", "RecLbl", "PosInfoLbl", 
      "ATRLbl", "SpreadLbl", "CooldownLbl", "BBLbl", "VolLbl", "ExnessWarn", "VersionLbl",
      "DrawdownLbl", "DivergenceLbl"
   }; 
   for(int i = 0; i < 36; i++) 
      ObjectDelete(0, panelPrefix + n[i]); 
}

void UpdatePanel() 
{ 
   if(!panelMinimized) 
   { 
      UpdateSession(); 
      UpdateTrend(); 
      UpdateSignalBar(); 
      UpdateStats(); 
      UpdateRecommendation(); 
      UpdatePositionInfo(); 
      UpdateMarketData(); 
      UpdateExnessInfo(); 
   } 
}

void UpdateSession() 
{ 
   string t = "Session: "; 
   color c = clrBlack; 
   
   switch(currentAnalysis.currentSession) 
   { 
      case SESSION_ASIA: t += "ASIA"; c = clrDarkGray; break; 
      case SESSION_LONDON: t += "LONDON"; c = clrDarkOrange; break; 
      case SESSION_NY: t += "NEW YORK"; c = clrDarkBlue; break; 
      case SESSION_OVERLAP: t += "LON/NY OVERLAP"; c = clrForestGreen; break; 
      default: t += "CLOSED"; c = clrDarkRed; 
   } 
   
   ObjSetText("SessionLbl", t, c); 
}

void UpdateTrend() 
{ 
   string t = "Trend: "; 
   color c = clrBlack; 
   
   switch(currentAnalysis.trend) 
   { 
      case TREND_UP: t += "UP"; c = clrForestGreen; break; 
      case TREND_DOWN: t += "DOWN"; c = clrDarkRed; break; 
      case TREND_SIDEWAYS: t += "SIDEWAYS"; c = clrGoldenrod; break; 
      default: t += "UNKNOWN"; c = clrDarkGray; 
   } 
   
   t += " (" + DoubleToString(currentAnalysis.trendStrength, 1) + ")"; 
   ObjSetText("TrendLbl", t, c); 
}

void UpdateSignalBar() 
{ 
   double s = 0; 
   if(currentAnalysis.buySignal) 
      s = currentAnalysis.buyScore; 
   else if(currentAnalysis.sellSignal) 
      s = currentAnalysis.sellScore; 
   else 
      s = MathMax(currentAnalysis.buyScore, currentAnalysis.sellScore); 
   
   int w = MathMax(0, MathMin((int)(s / 100.0 * 380.0), 380)); 
   ObjectSetInteger(0, panelPrefix + "StrengthFill", OBJPROP_XSIZE, w); 
   
   color c = (s > 75) ? clrLime : (s > 50) ? clrYellow : (s > 30) ? clrOrange : clrRed; 
   ObjectSetInteger(0, panelPrefix + "StrengthFill", OBJPROP_BGCOLOR, c); 
}

void UpdateStats()
{
   ObjSetText("BalanceLbl", "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), clrBlack);
   ObjSetText("EquityLbl", "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), clrBlack);
   
   double np = dailyProfit - dailyCommission; 
   ObjSetText("DailyPnLLbl", "Net P/L: $" + DoubleToString(np, 2), (np >= 0) ? clrForestGreen : clrDarkRed);
   
   double rr = MathMax(0.0, MaxDailyLoss - dailyLoss); 
   ObjSetText("DailyLossLbl", "Risk Left: $" + DoubleToString(rr, 2), (rr < MaxDailyLoss * 0.2) ? clrDarkRed : clrBlack);
   
   ObjSetText("WinRateLbl", "Win Rate: " + DoubleToString(winRate, 1) + "%", clrBlack); 
   ObjSetText("PFLabel", "PF: " + DoubleToString(profitFactor, 2), clrBlack);
   
   string ct = "Consec: " + IntegerToString(consecutiveLosses); 
   if(MaxConsecutiveLosses > 0) ct += "/" + IntegerToString(MaxConsecutiveLosses);
   ObjSetText("ConsecLbl", ct, (consecutiveLosses >= MaxConsecutiveLosses) ? clrDarkRed : clrBlack); 
   
   ObjSetText("CommLbl", "Comm: $" + DoubleToString(dailyCommission, 2), clrDarkGray);
   ObjSetText("SwapLbl", g_isTripleSwapDay ? "TRIPLE SWAP!" : "Swap: Normal", g_isTripleSwapDay ? clrDarkRed : clrDarkGray);
   
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); 
   string mt = "Margin: "; 
   color mc = clrBlack;
   if(ml <= 0) { mt += "N/A"; mc = clrDarkGray; }
   else { mt += DoubleToString(ml, 0) + "%"; mc = (ml > 300) ? clrForestGreen : (ml > MinMarginLevel) ? clrGoldenrod : clrDarkRed; } 
   ObjSetText("MarginLbl", mt, mc);
   
   // NEW: Drawdown display
   double drawdown = 0;
   if(peakBalance > 0)
      drawdown = (peakBalance - AccountInfoDouble(ACCOUNT_EQUITY)) / peakBalance * 100.0;
   color ddClr = (drawdown > MaxDrawdownPercent * 0.8) ? clrDarkRed : (drawdown > MaxDrawdownPercent * 0.5) ? clrGoldenrod : clrDarkGray;
   ObjSetText("DrawdownLbl", "DD: " + DoubleToString(drawdown, 2) + "%", ddClr);
}

void UpdateRecommendation() 
{ 
   color c = clrBlack; 
   string r = currentAnalysis.recommendation; 
   
   if(r == "BUY") c = clrForestGreen; 
   else if(r == "SELL") c = clrDarkRed; 
   else if(r == "HIGH SPREAD" || r == "NEWS BLOCK") c = clrDarkMagenta; 
   else if(StringFind(r, "COOLDOWN") >= 0) c = clrDarkOrange; 
   else if(r == "LOSS LIMIT" || r == "DRAWDOWN" || r == "MAX POSITIONS") c = clrDarkRed; 
   
   ObjSetText("RecLbl", "Signal: " + r, c); 
}

void UpdatePositionInfo()
{
   int b = 0, s = 0; 
   double l = 0, u = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   { 
      ulong t = PositionGetTicket(i); 
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue; 
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) b++; 
      else s++; 
      
      l += PositionGetDouble(POSITION_VOLUME); 
      u += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); 
   }
   
   ObjSetText("PosInfoLbl", 
              "Pos: " + IntegerToString(b + s) + 
              " (B:" + IntegerToString(b) + " S:" + IntegerToString(s) + 
              ") Lot:" + DoubleToString(l, 2) + 
              " P/L:$" + DoubleToString(u, 2), 
              (u >= 0) ? clrForestGreen : clrDarkRed);
}

void UpdateMarketData()
{
   double at = (currentAnalysis.atrValue > 0 && g_tickSize > 0) ? currentAnalysis.atrValue / g_tickSize : 0;
   ObjSetText("ATRLbl", "ATR: " + DoubleToString(at, 0) + " ticks", clrBlack);

   double spread = currentAnalysis.spreadTicks;
   color spreadClr = clrForestGreen;
   string spreadTxt = "Spread: " + DoubleToString(spread, 1) + " ticks";
   
   if(UseDynamicSpread && g_realAverageSpread > 0)
   {
      double ratio = spread / g_realAverageSpread;
      spreadTxt += " (Avg:" + DoubleToString(g_realAverageSpread, 1) + ")";
      if(ratio > DynamicSpreadMax) spreadClr = clrDarkRed;
      else if(ratio > DynamicSpreadMax * 0.8) spreadClr = clrGoldenrod;
   }
   else if(MaxSpreadTicks > 0)
   {
      if(spread > MaxSpreadTicks) spreadClr = clrDarkRed;
      else if(spread > MaxSpreadTicks * 0.8) spreadClr = clrGoldenrod;
   }
   
   ObjSetText("SpreadLbl", spreadTxt, spreadClr);

   // FIX: Completed cooldown status display
   string st = "READY"; 
   color sc = clrForestGreen;
   
   if(cooldownBarsLeft > 0) 
   { 
      st = "COOLDOWN " + IntegerToString(cooldownBarsLeft) + " bars"; 
      sc = clrDarkOrange; 
   }
   else if(!currentAnalysis.marketOpen) 
   { 
      st = "MARKET CLOSED"; 
      sc = clrDarkRed; 
   }
   else if(!currentAnalysis.spreadOk) 
   { 
      st = "SPREAD HIGH"; 
      sc = clrDarkMagenta; 
   }
   else if(!currentAnalysis.newsOk) 
   { 
      st = "NEWS BLOCK"; 
      sc = clrDarkMagenta; 
   }
   else if(consecutiveLosses >= MaxConsecutiveLosses && MaxConsecutiveLosses > 0) 
   { 
      st = "LOSS LIMIT"; 
      sc = clrDarkRed; 
   }
   else if(!IsDrawdownSafe()) 
   { 
      st = "DRAWDOWN"; 
      sc = clrDarkRed; 
   }
   
   ObjSetText("CooldownLbl", "Status: " + st, sc);
   
   // BB info
   if(g_useBollingerBands && currentAnalysis.bbUpper > 0)
   {
      double bbWidth = (currentAnalysis.bbUpper - currentAnalysis.bbLower) / g_pointValue;
      ObjSetText("BBLbl", "BB Width: " + DoubleToString(bbWidth, 0) + " pts", clrBlack);
   }
   else
   {
      ObjSetText("BBLbl", "BB: Disabled", clrDarkGray);
   }
   
   // Volume info
   ObjSetText("VolLbl", "Min Lot: " + DoubleToString(g_volumeMin, 2), clrDarkGray);
}

void UpdateExnessInfo()
{
   string exnessStatus = "Exness: ";
   color ec = clrLimeGreen;
   
   if(g_exnessCommission <= 0) 
   { 
      exnessStatus += "Zero Comm"; 
      ec = clrGoldenrod; 
   }
   else 
   { 
      exnessStatus += "$" + DoubleToString(g_exnessCommission, 1) + "/lot"; 
   }
   
   if(g_isTripleSwapDay) 
   { 
      exnessStatus += " [3xSWAP]"; 
      ec = clrDarkOrange; 
   }
   
   ObjSetText("ExnessWarn", exnessStatus, ec);
   
   // NEW: Divergence display
   string divText = "Div: ";
   color divClr = clrDarkGray;
   
   if(UseRSIDivergence)
   {
      if(currentAnalysis.rsiDivergenceBuy) 
      { 
         divText += "BULL"; 
         divClr = clrForestGreen; 
      }
      else if(currentAnalysis.rsiDivergenceSell) 
      { 
         divText += "BEAR"; 
         divClr = clrDarkRed; 
      }
      else 
      { 
         divText += "None"; 
      }
   }
   else
   {
      divText += "Off";
   }
   
   ObjSetText("DivergenceLbl", divText, divClr);
}
//+------------------------------------------------------------------+