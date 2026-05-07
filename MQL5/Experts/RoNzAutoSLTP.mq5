//+------------------------------------------------------------------+
//|                                             Gold-Optimized       |
//|                             RoNz Auto SL n TP.mq5                 |
//|                                   Copyright 2025, Rony Nofrianto  |
//|                                                Version 3.1        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property description "Gold-Optimized AutoSL-TP with Breakeven, Lock Profit, and Trailing Stop"
#property version   "3.1"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// ATR handles - one per symbol for multi-symbol support
struct ATRHandleEntry {
   string symbol;
   int handle;
   datetime lastUpdate;
};

ATRHandleEntry g_atrHandles[];
int g_maxSymbols = 10;

CTrade trade;
CPositionInfo positionInfo;

// Enums for settings
enum ENUM_CHARTSYMBOL {
   CURRENT_CHART_SYMBOL = 0, // Current Chart Only
   ALL_OPEN_ORDERS = 1       // All Opened Orders
};

enum ENUM_SLTP_MODE {
   SERVER = 0, // Place SL & TP on Server
   CLIENT = 1  // Hidden SL & TP (Virtual)
};

enum ENUM_LOCKPROFIT_ENABLE {
   LP_DISABLE = 0, // Disable Lock Profit
   LP_ENABLE = 1   // Enable Lock Profit
};

enum ENUM_TRAILINGSTOP_METHOD {
   TS_NONE = 0,            // No Trailing Stop
   TS_CLASSIC = 1,         // Classic Trailing Stop
   TS_STEP_DISTANCE = 2,   // Step Keeping Distance
   TS_STEP_BY_STEP = 3,    // Step By Step
   TS_GOLD_ADAPTIVE = 4    // Gold Adaptive (Volatility-Based)
};

enum ENUM_LOG_LEVEL {
   LOG_NONE = 0,           // No Logging
   LOG_OPERATIONS = 1,     // Log Operations
   LOG_ERRORS = 2,         // Log Errors Only
   LOG_VERBOSE = 3         // Verbose Logging
};

// Input parameters - Gold-optimized defaults
input const string SLTP_SETTINGS = "-=[ SL & TP SETTINGS ]=-";
input int TakeProfit = 8000;                  // Take Profit in points
input int StopLoss   = 5000;                  // Stop Loss in points
input ENUM_SLTP_MODE SLnTPMode = SERVER;     // SL & TP Mode
input bool IncludeSpreadInSL = true;         // Include spread in SL calculation
input bool IncludeSpreadInTP = false;        // Include spread in TP calculation

input const string LOCK_PROFIT_SETTINGS = "-=[ LOCK PROFIT SETTINGS ]=-";
input ENUM_LOCKPROFIT_ENABLE LockProfitEnable = LP_ENABLE; // Enable/Disable Profit Lock
input int LockProfitAfter = 45;                          // Target point to Lock Profit
input int ProfitLock      = 25;                           // Profit To Lock

input const string TRAILING_STOP_SETTINGS = "-=[ TRAILING STOP SETTINGS ]=-";
input ENUM_TRAILINGSTOP_METHOD TrailingStopMethod = TS_GOLD_ADAPTIVE; // Trailing Method
input int TrailingStop = 50;                                  // Trailing Stop in points
input int TrailingStep = 35;                                  // Trailing Stop Step in points

input const string BREAKEVEN_SETTINGS = "-=[ BREAKEVEN SETTINGS ]=-";
input bool EnableBreakeven = true;                           // Enable Breakeven
input int BreakevenTrigger = 25;                             // Points to trigger Breakeven

input const string GOLD_SETTINGS = "-=[ GOLD SETTINGS ]=-";
input bool EnableGoldAdjustments = true;                     // Apply Gold-specific adjustments
input string GoldSymbolKeywords  = "XAU,GOLD,GLD";           // CSV keywords (case-insensitive) used to detect gold
input string GoldSymbolOverrides = "";                       // CSV explicit gold symbol names (broker-specific)

input const string RISK_SETTINGS = "-=[ RISK SETTINGS ]=-";
input double MaxDrawdownPct = 0.0;                           // Max drawdown vs initial balance (%, 0=disable)

input const string GENERAL_SETTINGS = "-=[ GENERAL SETTINGS ]=-";
input ulong ExpertMagicNumber = 18745;                      // Magic Number
input int Slippage = 15;                                     // Slippage in points
input ENUM_CHARTSYMBOL ChartSymbolSelection = CURRENT_CHART_SYMBOL;  // Symbol Selection
input bool EnableAlert = false;                              // Enable Alert
input bool EnableTest = false;                               // Open test trades in Strategy Tester
input ENUM_LOG_LEVEL LogLevel = LOG_OPERATIONS;              // Logging Level
input int ProcessingInterval = 1000;                         // Processing interval (ms)
input int MaxSpreadPoints = 500;                             // Maximum spread in points (0=disable)

// Global variables
int g_ModifiedPositions = 0;
int g_ClosedPositions = 0;
double g_initialBalance = 0.0;
int g_ProcessingCounter = 0;
bool g_drawdownGuardTripped = false;

// Cache structures for performance optimization
struct SymbolInfoCache {
   string name;
   double point;
   int digits;
   int spread;
   double ask;
   double bid;
   long stopsLevel;
   long freezeLevel;
   double tickSize;
   datetime lastUpdate;
   double atr14;
   bool isGold;
};

struct PositionInfoCache {
   ulong ticket;
   string symbol;
   double priceOpen;
   double sl;
   double tp;
   double profit;
   ENUM_POSITION_TYPE type;
   datetime lastUpdate;
   double volume;
};

// Adjusted levels per processing iteration - avoids duplicating gold-multiplier code
struct AdjustedLevels {
   int stopLoss;
   int takeProfit;
   int lockProfitAfter;
   int profitLock;
   int trailingStop;
   int trailingStep;
   int breakevenTrigger;
   double multiplier;
};

// Cache arrays
SymbolInfoCache g_symbolCache[];
PositionInfoCache g_positionCache[];

// Forward declarations
bool StringArrayContains(const string &values[], const string value);
bool ShouldManagePosition(const ulong positionMagic);
double NormalizePriceToTick(const double price, const SymbolInfoCache &sym);
double GetMinimumStopDistance(const SymbolInfoCache &sym);
bool IsValidStopLevel(const PositionInfoCache &pos, const SymbolInfoCache &sym, const double level, const bool isStopLoss);
bool IsRetriableTradeRetcode(const uint retcode);
bool ApplyPositionModify(const ulong ticket, const PositionInfoCache &pos, const SymbolInfoCache &sym,
                         double desiredSL, double desiredTP, const string reason, const bool countAsModification = false);
AdjustedLevels GetAdjustedLevels(const SymbolInfoCache &sym);
bool IsGoldSymbol(const string symbol);
string StringToUpperCopy(const string s);
void RunScheduledMaintenance();
bool DrawdownGuardActive();
void CloseAllManagedPositions(const string reason);

//+------------------------------------------------------------------+
//| Get ATR value for a specific symbol                              |
//+------------------------------------------------------------------+
int GetOrCreateATRHandle(const string symbol, int period = 14) {
   for(int i = 0; i < ArraySize(g_atrHandles); i++) {
      if(g_atrHandles[i].symbol == symbol) {
         if(g_atrHandles[i].handle != INVALID_HANDLE) {
            g_atrHandles[i].lastUpdate = TimeCurrent();
            return g_atrHandles[i].handle;
         }
         g_atrHandles[i].handle = iATR(symbol, PERIOD_CURRENT, period);
         g_atrHandles[i].lastUpdate = TimeCurrent();
         return g_atrHandles[i].handle;
      }
   }

   int index = ArraySize(g_atrHandles);
   if(index >= g_maxSymbols) {
      int oldestIdx = 0;
      datetime oldestTime = g_atrHandles[0].lastUpdate;
      for(int i = 1; i < index; i++) {
         if(g_atrHandles[i].lastUpdate < oldestTime) {
            oldestTime = g_atrHandles[i].lastUpdate;
            oldestIdx = i;
         }
      }
      if(g_atrHandles[oldestIdx].handle != INVALID_HANDLE) {
         IndicatorRelease(g_atrHandles[oldestIdx].handle);
      }
      g_atrHandles[oldestIdx].symbol = symbol;
      g_atrHandles[oldestIdx].handle = iATR(symbol, PERIOD_CURRENT, period);
      g_atrHandles[oldestIdx].lastUpdate = TimeCurrent();
      return g_atrHandles[oldestIdx].handle;
   }

   ArrayResize(g_atrHandles, index + 1);
   g_atrHandles[index].symbol = symbol;
   g_atrHandles[index].handle = iATR(symbol, PERIOD_CURRENT, period);
   g_atrHandles[index].lastUpdate = TimeCurrent();
   return g_atrHandles[index].handle;
}

double GetATR(const string symbol, int period = 14, int shift = 0) {
   int atrHandle = GetOrCreateATRHandle(symbol, period);
   if(atrHandle == INVALID_HANDLE) return 0;

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if(CopyBuffer(atrHandle, 0, shift, 1, atrBuffer) > 0) {
      return atrBuffer[0];
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);
   trade.SetExpertMagicNumber(ExpertMagicNumber);

   ArrayResize(g_atrHandles, 0);

   if(!SymbolSelect(_Symbol, true)) {
      Print("Failed to select symbol: ", _Symbol);
      return INIT_FAILED;
   }

   long tradeStopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(StopLoss < tradeStopsLevel) {
      Print("Warning: Stop Loss (", StopLoss, ") is less than minimum allowed (", tradeStopsLevel, ")");
   }

   if(TakeProfit <= 0 || StopLoss <= 0) {
      Print("Error: TakeProfit and StopLoss must be positive values");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(TrailingStop < 0 || TrailingStep < 0) {
      Print("Error: TrailingStop and TrailingStep cannot be negative");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(LockProfitEnable == LP_ENABLE) {
      if(LockProfitAfter <= 0 || ProfitLock <= 0) {
         Print("Error: LockProfitAfter and ProfitLock must be > 0 when Lock Profit is enabled");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(ProfitLock >= LockProfitAfter) {
         Print("Error: ProfitLock (", ProfitLock, ") must be < LockProfitAfter (", LockProfitAfter, ")");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   if(EnableBreakeven && BreakevenTrigger <= 0) {
      Print("Error: BreakevenTrigger must be > 0 when breakeven is enabled");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(MaxDrawdownPct < 0.0 || MaxDrawdownPct > 100.0) {
      Print("Error: MaxDrawdownPct must be in [0, 100]");
      return INIT_PARAMETERS_INCORRECT;
   }

   ArrayResize(g_symbolCache, 0);
   ArrayResize(g_positionCache, 0);

   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_drawdownGuardTripped = false;

   if(ProcessingInterval > 0) {
      EventSetMillisecondTimer(ProcessingInterval);
   }

   string initMessage = "Gold-Optimized RoNz Auto SL n TP v3.1 initialized with:\n";
   initMessage += "Magic Number: " + IntegerToString(ExpertMagicNumber) + "\n";
   initMessage += "SL: " + IntegerToString(StopLoss) + " points\n";
   initMessage += "TP: " + IntegerToString(TakeProfit) + " points\n";
   initMessage += "Lock Profit After: " + IntegerToString(LockProfitAfter) + " points\n";
   initMessage += "Profit Lock: " + IntegerToString(ProfitLock) + " points\n";
   initMessage += "Trailing Stop: " + IntegerToString(TrailingStop) + " points\n";
   initMessage += "Trailing Step: " + IntegerToString(TrailingStep) + " points\n";
   initMessage += "Breakeven Trigger: " + IntegerToString(BreakevenTrigger) + " points\n";
   initMessage += "Processing Interval: " + IntegerToString(ProcessingInterval) + "ms\n";
   initMessage += "Max Spread: " + IntegerToString(MaxSpreadPoints) + " points\n";
   initMessage += "Gold Adjustments: " + (EnableGoldAdjustments ? "ON" : "OFF") + "\n";
   initMessage += "Gold Keywords: " + GoldSymbolKeywords + "\n";
   initMessage += "Gold Overrides: " + (StringLen(GoldSymbolOverrides) > 0 ? GoldSymbolOverrides : "(none)") + "\n";
   initMessage += "Max Drawdown: " + DoubleToString(MaxDrawdownPct, 2) + "%\n";
   initMessage += "Initial Balance: " + DoubleToString(g_initialBalance, 2);
   Print(initMessage);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   for(int i = 0; i < ArraySize(g_atrHandles); i++) {
      if(g_atrHandles[i].handle != INVALID_HANDLE) {
         IndicatorRelease(g_atrHandles[i].handle);
         g_atrHandles[i].handle = INVALID_HANDLE;
      }
   }
   ArrayResize(g_atrHandles, 0);
   ArrayFree(g_symbolCache);
   ArrayFree(g_positionCache);

   string deinitMessage = "Expert removed. Reason: " + IntegerToString(reason) +
                          " | Modified: " + IntegerToString(g_ModifiedPositions) +
                          " | Closed: " + IntegerToString(g_ClosedPositions);
   Print(deinitMessage);

   if(EnableAlert) {
      Alert(deinitMessage);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function (minimal processing)                        |
//+------------------------------------------------------------------+
void OnTick() {
   // Fallback to tick-driven processing when the timer is disabled
   if(ProcessingInterval > 0) return;

   UpdateSymbolCache();
   UpdatePositionCache();
   ProcessPositions();

   if(EnableTest && MQLInfoInteger(MQL_TESTER)) {
      OrderTest();
   }

   RunScheduledMaintenance();
}

//+------------------------------------------------------------------+
//| Timer function for periodic processing                           |
//+------------------------------------------------------------------+
void OnTimer() {
   UpdateSymbolCache();
   UpdatePositionCache();
   ProcessPositions();

   if(EnableTest && MQLInfoInteger(MQL_TESTER)) {
      OrderTest();
   }

   RunScheduledMaintenance();
}

//+------------------------------------------------------------------+
//| Periodic maintenance (cache cleanup, drawdown guard)             |
//+------------------------------------------------------------------+
void RunScheduledMaintenance() {
   g_ProcessingCounter++;
   if(g_ProcessingCounter >= 1000) {
      CleanupCache();
      g_ProcessingCounter = 0;
   }

   if(MaxDrawdownPct > 0.0 && !g_drawdownGuardTripped && DrawdownGuardActive()) {
      g_drawdownGuardTripped = true;
      LogMessage(StringFormat("Drawdown guard tripped at %.2f%% - closing all managed positions",
                              MaxDrawdownPct), LOG_ERRORS);
      if(EnableAlert) {
         Alert("RoNz Auto SL/TP: drawdown guard tripped, closing managed positions");
      }
      CloseAllManagedPositions("drawdown guard");
   }
}

//+------------------------------------------------------------------+
//| Drawdown guard check                                             |
//+------------------------------------------------------------------+
bool DrawdownGuardActive() {
   if(g_initialBalance <= 0.0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_initialBalance - equity) / g_initialBalance * 100.0;
   return (dd >= MaxDrawdownPct);
}

//+------------------------------------------------------------------+
//| Close all managed positions (drawdown guard helper)              |
//+------------------------------------------------------------------+
void CloseAllManagedPositions(const string reason) {
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(!ShouldManagePosition((ulong)PositionGetInteger(POSITION_MAGIC))) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(trade.PositionClose(ticket, Slippage)) {
         g_ClosedPositions++;
         LogMessage(StringFormat("Closed by %s #%I64u Profit:%.2f", reason, ticket, profit), LOG_OPERATIONS);
      } else {
         LogMessage(StringFormat("Failed to close #%I64u during %s: %s", ticket, reason,
                                 trade.ResultRetcodeDescription()), LOG_ERRORS);
      }
   }
}

//+------------------------------------------------------------------+
//| Update symbol cache with current data                            |
//+------------------------------------------------------------------+
void UpdateSymbolCache() {
   string symbols[];

   int totalPositions = PositionsTotal();
   for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(!ShouldManagePosition((ulong)PositionGetInteger(POSITION_MAGIC))) continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         if(!StringArrayContains(symbols, symbol)) {
            int size = ArraySize(symbols);
            ArrayResize(symbols, size + 1);
            symbols[size] = symbol;
         }
      }
   }

   if(ChartSymbolSelection == CURRENT_CHART_SYMBOL) {
      if(!StringArrayContains(symbols, _Symbol)) {
         int size = ArraySize(symbols);
         ArrayResize(symbols, size + 1);
         symbols[size] = _Symbol;
      }
   }

   for(int i = 0; i < ArraySize(symbols); i++) {
      UpdateSingleSymbolCache(symbols[i]);
   }
}

//+------------------------------------------------------------------+
//| Update single symbol in cache                                    |
//+------------------------------------------------------------------+
void UpdateSingleSymbolCache(const string symbol) {
   int index = -1;

   for(int i = 0; i < ArraySize(g_symbolCache); i++) {
      if(g_symbolCache[i].name == symbol) {
         index = i;
         break;
      }
   }

   if(index == -1) {
      index = ArraySize(g_symbolCache);
      ArrayResize(g_symbolCache, index + 1);
   }

   g_symbolCache[index].name = symbol;
   g_symbolCache[index].point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   g_symbolCache[index].digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   g_symbolCache[index].spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   g_symbolCache[index].ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   g_symbolCache[index].bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   g_symbolCache[index].stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_symbolCache[index].freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   g_symbolCache[index].tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   g_symbolCache[index].lastUpdate = TimeCurrent();
   g_symbolCache[index].isGold = IsGoldSymbol(symbol);

   if(g_symbolCache[index].isGold) {
      g_symbolCache[index].atr14 = GetATR(symbol, 14, 0);
   } else {
      g_symbolCache[index].atr14 = 0;
   }
}

//+------------------------------------------------------------------+
//| Update position cache                                            |
//+------------------------------------------------------------------+
void UpdatePositionCache() {
   int totalPositions = PositionsTotal();
   ArrayResize(g_positionCache, totalPositions);

   int cacheIndex = 0;
   for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         if(!ShouldManagePosition(posMagic)) continue;

         g_positionCache[cacheIndex].ticket = ticket;
         g_positionCache[cacheIndex].symbol = PositionGetString(POSITION_SYMBOL);
         g_positionCache[cacheIndex].priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         g_positionCache[cacheIndex].sl = PositionGetDouble(POSITION_SL);
         g_positionCache[cacheIndex].tp = PositionGetDouble(POSITION_TP);
         g_positionCache[cacheIndex].profit = PositionGetDouble(POSITION_PROFIT);
         g_positionCache[cacheIndex].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         g_positionCache[cacheIndex].volume = PositionGetDouble(POSITION_VOLUME);
         g_positionCache[cacheIndex].lastUpdate = TimeCurrent();
         cacheIndex++;
      }
   }

   if(cacheIndex < totalPositions) {
      ArrayResize(g_positionCache, cacheIndex);
   }
}

//+------------------------------------------------------------------+
//| Clean up old cache entries                                       |
//+------------------------------------------------------------------+
void CleanupCache() {
   datetime currentTime = TimeCurrent();

   int newSize = 0;
   int totalSymbols = ArraySize(g_symbolCache);
   for(int i = 0; i < totalSymbols; i++) {
      if(currentTime - g_symbolCache[i].lastUpdate < 300) {
         if(i != newSize) {
            g_symbolCache[newSize] = g_symbolCache[i];
         }
         newSize++;
      }
   }
   ArrayResize(g_symbolCache, newSize);

   // Force-shrink position cache; it's rebuilt every iteration anyway.
   if(ArraySize(g_positionCache) > 0 && PositionsTotal() == 0) {
      ArrayFree(g_positionCache);
   }
}

//+------------------------------------------------------------------+
//| Check if spread is within limits                                 |
//+------------------------------------------------------------------+
bool IsSpreadWithinLimit(const string symbol) {
   if(MaxSpreadPoints <= 0) return true;

   int currentSpread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   return (currentSpread <= MaxSpreadPoints);
}

bool GetCachedSymbolInfo(const string symbol, SymbolInfoCache &info) {
   for(int i = 0; i < ArraySize(g_symbolCache); i++) {
      if(g_symbolCache[i].name == symbol) {
         info = g_symbolCache[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Main position processing function                                |
//+------------------------------------------------------------------+
void ProcessPositions() {
   int totalPositions = ArraySize(g_positionCache);
   if(totalPositions == 0) return;

   for(int i = totalPositions - 1; i >= 0; i--) {
      ulong ticket = g_positionCache[i].ticket;
      string symbol = g_positionCache[i].symbol;

      if(ChartSymbolSelection == CURRENT_CHART_SYMBOL && symbol != _Symbol) continue;

      if(!IsSpreadWithinLimit(symbol)) {
         if(LogLevel >= LOG_VERBOSE) {
            LogMessage(StringFormat("Skipped #%I64u - spread too high", ticket), LOG_VERBOSE);
         }
         continue;
      }

      SymbolInfoCache symInfo;
      if(!GetCachedSymbolInfo(symbol, symInfo)) {
         UpdateSingleSymbolCache(symbol);
         GetCachedSymbolInfo(symbol, symInfo);
      }

      if(symInfo.point <= 0) continue;

      double currentPrice = (g_positionCache[i].type == POSITION_TYPE_BUY) ? symInfo.bid : symInfo.ask;
      double pips = CalculatePips(g_positionCache[i].priceOpen, currentPrice,
                                   g_positionCache[i].type, symInfo.point);

      if(!PositionSelectByTicket(ticket)) {
         g_ClosedPositions++;
         continue;
      }

      AdjustedLevels lvl = GetAdjustedLevels(symInfo);

      if(SLnTPMode == SERVER) {
         ProcessServerMode(ticket, symbol, g_positionCache[i], symInfo, lvl);
      } else {
         ProcessClientMode(ticket, symbol, g_positionCache[i], symInfo, lvl, pips);
      }

      if(!PositionSelectByTicket(ticket)) {
         g_ClosedPositions++;
         continue;
      }

      if(EnableBreakeven) {
         ProcessBreakeven(ticket, symbol, g_positionCache[i], symInfo, lvl, pips);
      }

      if(!PositionSelectByTicket(ticket)) {
         g_ClosedPositions++;
         continue;
      }

      if(LockProfitEnable == LP_ENABLE) {
         ProcessLockProfit(ticket, symbol, g_positionCache[i], symInfo, lvl, pips);
      }

      if(!PositionSelectByTicket(ticket)) {
         g_ClosedPositions++;
         continue;
      }

      if(TrailingStopMethod != TS_NONE) {
         ProcessTrailingStop(ticket, symbol, g_positionCache[i], symInfo, lvl, pips);
      }
   }
}

//+------------------------------------------------------------------+
//| Compute adjusted levels (gold multiplier applied once)           |
//+------------------------------------------------------------------+
AdjustedLevels GetAdjustedLevels(const SymbolInfoCache &sym) {
   AdjustedLevels out;
   out.stopLoss = StopLoss;
   out.takeProfit = TakeProfit;
   out.lockProfitAfter = LockProfitAfter;
   out.profitLock = ProfitLock;
   out.trailingStop = TrailingStop;
   out.trailingStep = TrailingStep;
   out.breakevenTrigger = BreakevenTrigger;
   out.multiplier = 1.0;

   if(EnableGoldAdjustments && sym.isGold) {
      double mult = GetGoldVolatilityMultiplier(sym.atr14, sym.point);
      out.multiplier = mult;
      out.stopLoss = (int)(StopLoss * mult);
      out.takeProfit = (int)(TakeProfit * mult);
      out.lockProfitAfter = (int)(LockProfitAfter * mult);
      out.profitLock = (int)(ProfitLock * mult);
      out.trailingStop = (int)(TrailingStop * mult);
      out.trailingStep = (int)(TrailingStep * mult);
      out.breakevenTrigger = (int)(BreakevenTrigger * mult);
   }

   return out;
}

//+------------------------------------------------------------------+
//| Process server mode SL/TP - sets initial values only             |
//+------------------------------------------------------------------+
void ProcessServerMode(const ulong ticket, const string symbol,
                       const PositionInfoCache &pos, const SymbolInfoCache &sym,
                       const AdjustedLevels &lvl) {
   if(!PositionSelectByTicket(ticket)) return;

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   // Don't fight Breakeven / LockProfit / Trailing once they've moved SL.
   bool needSL = (currentSL == 0.0);
   bool needTP = (currentTP == 0.0);
   if(!needSL && !needTP) return;

   int adjustedSL = lvl.stopLoss;
   int adjustedTP = lvl.takeProfit;

   if(adjustedSL > 0 && adjustedSL < sym.stopsLevel) {
      adjustedSL = (int)sym.stopsLevel;
   }
   if(adjustedTP > 0 && adjustedTP < sym.stopsLevel) {
      adjustedTP = (int)sym.stopsLevel;
   }

   if(IncludeSpreadInSL) adjustedSL += sym.spread;
   if(IncludeSpreadInTP) adjustedTP += sym.spread;

   double newSL = 0.0, newTP = 0.0;

   if(pos.type == POSITION_TYPE_BUY) {
      newSL = (adjustedSL > 0) ? NormalizeDouble(pos.priceOpen - (adjustedSL * sym.point), sym.digits) : 0.0;
      newTP = (adjustedTP > 0) ? NormalizeDouble(pos.priceOpen + (adjustedTP * sym.point), sym.digits) : 0.0;
   } else {
      newSL = (adjustedSL > 0) ? NormalizeDouble(pos.priceOpen + (adjustedSL * sym.point), sym.digits) : 0.0;
      newTP = (adjustedTP > 0) ? NormalizeDouble(pos.priceOpen - (adjustedTP * sym.point), sym.digits) : 0.0;
   }

   // Preserve any value that the EA isn't placing - never overwrite a manual SL/TP with 0.
   double targetSL = needSL && newSL > 0.0 ? newSL : currentSL;
   double targetTP = needTP && newTP > 0.0 ? newTP : currentTP;

   if(MathAbs(targetSL - currentSL) <= sym.point / 2.0 && MathAbs(targetTP - currentTP) <= sym.point / 2.0) {
      return;
   }

   ApplyPositionModify(ticket, pos, sym, targetSL, targetTP, "initial SL/TP", true);
}

//+------------------------------------------------------------------+
//| Process client mode SL/TP                                        |
//+------------------------------------------------------------------+
void ProcessClientMode(const ulong ticket, const string symbol,
                       const PositionInfoCache &pos, const SymbolInfoCache &sym,
                       const AdjustedLevels &lvl, const double pips) {
   int adjustedSL = lvl.stopLoss;
   int adjustedTP = lvl.takeProfit;

   if(IncludeSpreadInSL) adjustedSL += sym.spread;
   if(IncludeSpreadInTP) adjustedTP += sym.spread;

   bool tpHit = (adjustedTP > 0 && pips >= adjustedTP);
   bool slHit = (adjustedSL > 0 && pips <= -adjustedSL);

   if(tpHit || slHit) {
      string reason = tpHit ? "Virtual TP" : "Virtual SL";
      if(ClosePosition(ticket, reason, pips)) {
         g_ClosedPositions++;
      }
   }
}

//+------------------------------------------------------------------+
//| Process breakeven                                                |
//+------------------------------------------------------------------+
void ProcessBreakeven(const ulong ticket, const string symbol,
                      const PositionInfoCache &pos, const SymbolInfoCache &sym,
                      const AdjustedLevels &lvl, const double pips) {
   if(!PositionSelectByTicket(ticket)) return;
   if(sym.point <= 0 || sym.digits <= 0) return;

   double currentSL = PositionGetDouble(POSITION_SL);
   if((pos.type == POSITION_TYPE_BUY && currentSL >= pos.priceOpen && currentSL > 0) ||
      (pos.type == POSITION_TYPE_SELL && currentSL <= pos.priceOpen && currentSL > 0)) {
      return;
   }

   if(lvl.breakevenTrigger <= 0 || pips < lvl.breakevenTrigger) return;

   double minDist = GetMinimumStopDistance(sym);
   double goldBuffer = 5 * sym.point;
   double buffer = (EnableGoldAdjustments && sym.isGold) ? MathMax(goldBuffer, minDist + sym.point)
                                                         : MathMax(2 * sym.point, minDist + sym.point);
   double newSL = (pos.type == POSITION_TYPE_BUY) ? pos.priceOpen + buffer
                                                  : pos.priceOpen - buffer;
   newSL = NormalizeDouble(newSL, sym.digits);

   bool improved = false;
   if(pos.type == POSITION_TYPE_BUY) {
      improved = (currentSL == 0.0) || (newSL > currentSL);
   } else {
      improved = (currentSL == 0.0) || (newSL < currentSL);
   }

   if(improved) {
      ApplyPositionModify(ticket, pos, sym, newSL, PositionGetDouble(POSITION_TP), "breakeven");
   }
}

//+------------------------------------------------------------------+
//| Process lock profit                                              |
//+------------------------------------------------------------------+
void ProcessLockProfit(const ulong ticket, const string symbol,
                       const PositionInfoCache &pos, const SymbolInfoCache &sym,
                       const AdjustedLevels &lvl, const double pips) {
   if(!PositionSelectByTicket(ticket)) return;
   if(sym.point <= 0 || sym.digits <= 0) return;

   if(lvl.lockProfitAfter <= 0 || lvl.profitLock <= 0 || pips < lvl.lockProfitAfter) return;

   double currentSL = PositionGetDouble(POSITION_SL);

   double lockLevel = (pos.type == POSITION_TYPE_BUY) ?
                      pos.priceOpen + (lvl.profitLock * sym.point) :
                      pos.priceOpen - (lvl.profitLock * sym.point);

   lockLevel = NormalizeDouble(lockLevel, sym.digits);

   bool improved = false;
   if(pos.type == POSITION_TYPE_BUY) {
      improved = (currentSL == 0.0) || (lockLevel > currentSL);
   } else {
      improved = (currentSL == 0.0) || (lockLevel < currentSL);
   }

   if(improved) {
      ApplyPositionModify(ticket, pos, sym, lockLevel, PositionGetDouble(POSITION_TP), "lock profit");
   }
}

//+------------------------------------------------------------------+
//| Process trailing stop                                            |
//+------------------------------------------------------------------+
void ProcessTrailingStop(const ulong ticket, const string symbol,
                         const PositionInfoCache &pos, const SymbolInfoCache &sym,
                         const AdjustedLevels &lvl, const double pips) {
   if(TrailingStopMethod == TS_GOLD_ADAPTIVE && EnableGoldAdjustments && sym.isGold) {
      ApplyGoldAdaptiveTrailing(ticket, pos, sym, lvl, pips);
   } else {
      ApplyStandardTrailing(ticket, pos, sym, lvl, pips);
   }
}

//+------------------------------------------------------------------+
//| Apply gold adaptive trailing stop                                |
//+------------------------------------------------------------------+
void ApplyGoldAdaptiveTrailing(const ulong ticket, const PositionInfoCache &pos,
                               const SymbolInfoCache &sym, const AdjustedLevels &lvl,
                               const double pips) {
   if(sym.point <= 0 || sym.digits <= 0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentPrice = (pos.type == POSITION_TYPE_BUY) ? sym.bid : sym.ask;
   double openPrice = pos.priceOpen;

   int adaptivePoints = lvl.trailingStop;
   int adaptiveStep = lvl.trailingStep;
   int minProfitPoints = adaptivePoints;

   double newSL = 0.0;
   bool shouldModify = false;

   if(pos.type == POSITION_TYPE_BUY) {
      if(pips < minProfitPoints) return;
      newSL = NormalizePriceToTick(currentPrice - (adaptivePoints * sym.point), sym);
      if(newSL <= openPrice) return;

      if(currentSL > 0) {
         if(newSL > currentSL && (newSL - currentSL) / sym.point >= adaptiveStep) {
            shouldModify = true;
         }
      } else {
         shouldModify = true;
      }
   } else {
      if(pips < minProfitPoints) return;
      newSL = NormalizePriceToTick(currentPrice + (adaptivePoints * sym.point), sym);
      if(newSL >= openPrice) return;

      if(currentSL > 0) {
         if(newSL < currentSL && (currentSL - newSL) / sym.point >= adaptiveStep) {
            shouldModify = true;
         }
      } else {
         shouldModify = true;
      }
   }

   if(shouldModify && newSL > 0.0) {
      ApplyPositionModify(ticket, pos, sym, newSL, PositionGetDouble(POSITION_TP),
                          StringFormat("gold adaptive trailing x%.2f", lvl.multiplier));
   }
}

//+------------------------------------------------------------------+
//| Apply standard trailing stop                                     |
//+------------------------------------------------------------------+
void ApplyStandardTrailing(const ulong ticket, const PositionInfoCache &pos,
                           const SymbolInfoCache &sym, const AdjustedLevels &lvl,
                           const double pips) {
   if(sym.point <= 0 || sym.digits <= 0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentPrice = (pos.type == POSITION_TYPE_BUY) ? sym.bid : sym.ask;
   double openPrice = pos.priceOpen;

   int adjustedTS = lvl.trailingStop;
   int adjustedTST = lvl.trailingStep;

   double newSL = 0.0;
   bool shouldModify = false;

   switch(TrailingStopMethod) {
      case TS_GOLD_ADAPTIVE: // Fall back to classic when not on a gold symbol or adjustments disabled.
      case TS_CLASSIC:
         if(pos.type == POSITION_TYPE_BUY) {
            newSL = NormalizeDouble(currentPrice - (adjustedTS * sym.point), sym.digits);
            if(newSL > openPrice && (currentSL == 0.0 || newSL > currentSL)) {
               shouldModify = true;
            }
         } else {
            newSL = NormalizeDouble(currentPrice + (adjustedTS * sym.point), sym.digits);
            if(newSL < openPrice && (currentSL == 0.0 || newSL < currentSL)) {
               shouldModify = true;
            }
         }
         break;

      case TS_STEP_DISTANCE:
         if(pos.type == POSITION_TYPE_BUY) {
            newSL = NormalizeDouble(currentPrice - (adjustedTS * sym.point), sym.digits);
            if(newSL > openPrice && currentSL > 0) {
               if(newSL > currentSL && (newSL - currentSL) / sym.point >= adjustedTST) {
                  shouldModify = true;
               }
            } else if(newSL > openPrice && currentSL == 0.0) {
               shouldModify = true;
            }
         } else {
            newSL = NormalizeDouble(currentPrice + (adjustedTS * sym.point), sym.digits);
            if(newSL < openPrice && currentSL > 0) {
               if(newSL < currentSL && (currentSL - newSL) / sym.point >= adjustedTST) {
                  shouldModify = true;
               }
            } else if(newSL < openPrice && currentSL == 0.0) {
               shouldModify = true;
            }
         }
         break;

      case TS_STEP_BY_STEP:
         if(pos.type == POSITION_TYPE_BUY) {
            if(currentSL == 0.0) {
               newSL = NormalizeDouble(currentPrice - (adjustedTS * sym.point), sym.digits);
               if(newSL > openPrice) shouldModify = true;
            } else if(currentPrice - currentSL > (adjustedTS + adjustedTST) * sym.point) {
               newSL = NormalizeDouble(currentSL + (adjustedTST * sym.point), sym.digits);
               if(newSL > currentSL && newSL > openPrice) shouldModify = true;
            }
         } else {
            if(currentSL == 0.0) {
               newSL = NormalizeDouble(currentPrice + (adjustedTS * sym.point), sym.digits);
               if(newSL < openPrice) shouldModify = true;
            } else if(currentSL - currentPrice > (adjustedTS + adjustedTST) * sym.point) {
               newSL = NormalizeDouble(currentSL - (adjustedTST * sym.point), sym.digits);
               if(newSL < currentSL && newSL < openPrice) shouldModify = true;
            }
         }
         break;

      default:
         return;
   }

   if(shouldModify && newSL > 0.0) {
      ApplyPositionModify(ticket, pos, sym, newSL, PositionGetDouble(POSITION_TP), "trailing stop");
   }
}

//+------------------------------------------------------------------+
//| Close position with retry logic                                  |
//+------------------------------------------------------------------+
bool ClosePosition(const ulong ticket, const string reason, const double pips) {
   uint lastRetcode = 0;

   for(int retry = 0; retry < 3; retry++) {
      if(retry > 0) Sleep(MathMin(500, 100 * retry));
      ResetLastError();
      double profit = 0.0;
      if(PositionSelectByTicket(ticket)) {
         profit = PositionGetDouble(POSITION_PROFIT);
      }

      if(trade.PositionClose(ticket, Slippage)) {
         string msg = StringFormat("Closed by %s #%I64u Profit:%.2f Points:%.1f",
                                   reason, ticket, profit, pips);
         LogMessage(msg, LOG_OPERATIONS);

         if(EnableAlert) {
            Alert(msg);
         }
         return true;
      }

      lastRetcode = trade.ResultRetcode();
      if(!IsRetriableTradeRetcode(lastRetcode)) {
         break;
      }
   }

   LogMessage(StringFormat("Failed to close #%I64u. Retcode: %u %s",
             ticket, lastRetcode, trade.ResultRetcodeDescription()), LOG_ERRORS);
   return false;
}

//+------------------------------------------------------------------+
//| Retry position modification                                      |
//+------------------------------------------------------------------+
bool RetryOperation(const ulong ticket, const double sl, const double tp, int maxRetries = 3) {
   uint lastRetcode = 0;

   for(int retry = 0; retry < maxRetries; retry++) {
      if(retry > 0) Sleep(MathMin(500, 100 * retry));
      ResetLastError();

      if(trade.PositionModify(ticket, sl, tp)) {
         return true;
      }

      lastRetcode = trade.ResultRetcode();
      if(!IsRetriableTradeRetcode(lastRetcode)) {
         break;
      }
   }

   LogMessage(StringFormat("Failed to modify #%I64u. Retcode: %u %s",
             ticket, lastRetcode, trade.ResultRetcodeDescription()), LOG_ERRORS);
   return false;
}

//+------------------------------------------------------------------+
//| Calculate pips from price difference                             |
//+------------------------------------------------------------------+
double CalculatePips(const double priceOpen, const double currentPrice,
                     const ENUM_POSITION_TYPE positionType, const double point) {
   if(point <= 0.0) return 0.0;

   if(positionType == POSITION_TYPE_BUY) {
      return (currentPrice - priceOpen) / point;
   } else {
      return (priceOpen - currentPrice) / point;
   }
}

//+------------------------------------------------------------------+
//| Case-insensitive copy helper                                     |
//+------------------------------------------------------------------+
string StringToUpperCopy(const string s) {
   string copy = s;
   StringToUpper(copy);
   return copy;
}

//+------------------------------------------------------------------+
//| Check if symbol is gold                                          |
//|                                                                  |
//| Recognises any of:                                               |
//|   - Explicit overrides from GoldSymbolOverrides (case-insensitive |
//|     exact match against the broker symbol).                      |
//|   - Keywords from GoldSymbolKeywords (default: XAU,GOLD,GLD)     |
//|     matched anywhere in the symbol after upper-casing both       |
//|     sides. Punctuation (.,-,_,/, space) is ignored to support    |
//|     suffixes/prefixes such as XAUUSD.m, GOLD.cash, gold-pro,     |
//|     XAU/USD, _XAUUSD, etc.                                       |
//+------------------------------------------------------------------+
bool IsGoldSymbol(const string symbol) {
   if(StringLen(symbol) == 0) return false;

   string upperSymbol = StringToUpperCopy(symbol);

   // Strip punctuation that brokers commonly use as separators / suffixes.
   string sanitized = upperSymbol;
   StringReplace(sanitized, ".", "");
   StringReplace(sanitized, "-", "");
   StringReplace(sanitized, "_", "");
   StringReplace(sanitized, "/", "");
   StringReplace(sanitized, " ", "");

   // Explicit per-broker overrides take priority.
   if(StringLen(GoldSymbolOverrides) > 0) {
      string overrides[];
      int n = StringSplit(GoldSymbolOverrides, ',', overrides);
      for(int i = 0; i < n; i++) {
         string entry = overrides[i];
         StringTrimLeft(entry);
         StringTrimRight(entry);
         if(StringLen(entry) == 0) continue;
         if(StringToUpperCopy(entry) == upperSymbol) return true;
      }
   }

   string keywords[];
   string keywordSrc = (StringLen(GoldSymbolKeywords) > 0) ? GoldSymbolKeywords : "XAU,GOLD,GLD";
   int kCount = StringSplit(keywordSrc, ',', keywords);
   for(int i = 0; i < kCount; i++) {
      string kw = keywords[i];
      StringTrimLeft(kw);
      StringTrimRight(kw);
      if(StringLen(kw) == 0) continue;
      string kwUpper = StringToUpperCopy(kw);
      if(StringFind(sanitized, kwUpper) >= 0) return true;
   }

   return false;
}

bool StringArrayContains(const string &values[], const string value) {
   for(int i = 0; i < ArraySize(values); i++) {
      if(values[i] == value) {
         return true;
      }
   }
   return false;
}

bool ShouldManagePosition(const ulong positionMagic) {
   if(positionMagic == ExpertMagicNumber) {
      return true;
   }

   return (ChartSymbolSelection == ALL_OPEN_ORDERS && ExpertMagicNumber == 0);
}

double NormalizePriceToTick(const double price, const SymbolInfoCache &sym) {
   if(sym.tickSize > 0) {
      return NormalizeDouble(MathRound(price / sym.tickSize) * sym.tickSize, sym.digits);
   }

   return NormalizeDouble(price, sym.digits);
}

double GetMinimumStopDistance(const SymbolInfoCache &sym) {
   return MathMax((double)sym.stopsLevel, (double)sym.freezeLevel) * sym.point;
}

bool IsValidStopLevel(const PositionInfoCache &pos, const SymbolInfoCache &sym, const double level, const bool isStopLoss) {
   if(level <= 0.0) {
      return true;
   }

   double minDistance = GetMinimumStopDistance(sym);
   double buyReference = sym.bid;
   double sellReference = sym.ask;

   // Prefer live tick over cache - cache may be stale on long timer intervals.
   MqlTick tick;
   if(SymbolInfoTick(sym.name, tick)) {
      if(tick.bid > 0) buyReference = tick.bid;
      if(tick.ask > 0) sellReference = tick.ask;
   }

   if(pos.type == POSITION_TYPE_BUY) {
      if(isStopLoss) {
         return (level < buyReference - minDistance);
      }
      return (level > buyReference + minDistance);
   }

   if(isStopLoss) {
      return (level > sellReference + minDistance);
   }
   return (level < sellReference - minDistance);
}

bool IsRetriableTradeRetcode(const uint retcode) {
   return (retcode == TRADE_RETCODE_REQUOTE ||
           retcode == TRADE_RETCODE_PRICE_CHANGED ||
           retcode == TRADE_RETCODE_PRICE_OFF ||
           retcode == TRADE_RETCODE_TIMEOUT ||
           retcode == TRADE_RETCODE_CONNECTION ||
           retcode == TRADE_RETCODE_TOO_MANY_REQUESTS);
}

bool ApplyPositionModify(const ulong ticket, const PositionInfoCache &pos, const SymbolInfoCache &sym,
                         double desiredSL, double desiredTP, const string reason, const bool countAsModification = false) {
   if(!PositionSelectByTicket(ticket)) {
      return false;
   }

   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   if(sym.point <= 0 || sym.digits <= 0) {
      return false;
   }

   if(desiredSL > 0.0) desiredSL = NormalizePriceToTick(desiredSL, sym);
   if(desiredTP > 0.0) desiredTP = NormalizePriceToTick(desiredTP, sym);

   if(desiredSL > 0.0 && !IsValidStopLevel(pos, sym, desiredSL, true)) {
      if(LogLevel >= LOG_VERBOSE) {
         LogMessage(StringFormat("Skipped %s for #%I64u - invalid SL %.5f", reason, ticket, desiredSL), LOG_VERBOSE);
      }
      desiredSL = currentSL;
   }

   if(desiredTP > 0.0 && !IsValidStopLevel(pos, sym, desiredTP, false)) {
      if(LogLevel >= LOG_VERBOSE) {
         LogMessage(StringFormat("Skipped %s for #%I64u - invalid TP %.5f", reason, ticket, desiredTP), LOG_VERBOSE);
      }
      desiredTP = currentTP;
   }

   if(MathAbs(currentSL - desiredSL) <= sym.point / 2.0 && MathAbs(currentTP - desiredTP) <= sym.point / 2.0) {
      return false;
   }

   if(RetryOperation(ticket, desiredSL, desiredTP)) {
      if(countAsModification) {
         g_ModifiedPositions++;
      }

      LogMessage(StringFormat("%s #%I64u -> SL=%.5f TP=%.5f", reason, ticket, desiredSL, desiredTP), LOG_OPERATIONS);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get volatility-based multiplier for gold                         |
//+------------------------------------------------------------------+
double GetGoldVolatilityMultiplier(const double atrValue, const double point) {
   double multiplier = 1.0;

   // ATR is reported in price units; convert to raw points before bucketing.
   if(atrValue > 0 && point > 0) {
      double normAtr = atrValue / point;
      if(normAtr > 5000)      multiplier *= 1.30; // very volatile
      else if(normAtr > 3000) multiplier *= 1.15;
      else if(normAtr > 1500) multiplier *= 1.05;
      else if(normAtr < 600)  multiplier *= 0.90; // unusually quiet
   }

   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   if(dt.day_of_week == 4) multiplier *= 1.20;      // Thursday
   else if(dt.day_of_week == 1) multiplier *= 1.15; // Monday

   if((dt.hour >= 8 && dt.hour <= 10) || (dt.hour >= 14 && dt.hour <= 16)) {
      multiplier *= 1.20; // Peak volatility
   } else if(dt.hour >= 0 && dt.hour <= 2) {
      multiplier *= 0.90; // Low volatility
   }

   return MathMax(0.7, MathMin(2.5, multiplier));
}

//+------------------------------------------------------------------+
//| Log message based on log level                                   |
//+------------------------------------------------------------------+
void LogMessage(const string message, const ENUM_LOG_LEVEL level) {
   if(level <= LogLevel) {
      Print(TimeToString(TimeCurrent(), TIME_SECONDS) + " - " + message);
   }
}

//+------------------------------------------------------------------+
//| Test order management in strategy tester                         |
//+------------------------------------------------------------------+
void OrderTest() {
   if(!MQLInfoInteger(MQL_TESTER)) return;

   static datetime lastTestTime = 0;
   datetime currentTime = TimeCurrent();

   if(currentTime - lastTestTime < 10) return;
   lastTestTime = currentTime;

   if(!IsSpreadWithinLimit(_Symbol)) {
      if(LogLevel >= LOG_VERBOSE) {
         LogMessage("Test order skipped - spread too high", LOG_VERBOSE);
      }
      return;
   }

   // Only block on our own test positions; foreign positions shouldn't gate test orders.
   bool hasOwnTestPosition = false;
   int totalPositions = PositionsTotal();
   for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != ExpertMagicNumber) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "Test ") != 0) continue;

      hasOwnTestPosition = true;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(trade.PositionClose(ticket, Slippage)) {
         string closeMsg = StringFormat("Closed test #%I64u with profit %.2f", ticket, profit);
         LogMessage(closeMsg, LOG_OPERATIONS);
         g_ClosedPositions++;
      } else {
         LogMessage(StringFormat("Failed to close test #%I64u: %s",
                    ticket, trade.ResultRetcodeDescription()), LOG_ERRORS);
      }
      break;
   }

   if(hasOwnTestPosition) return;

   static bool buyNext = true;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(minVolume <= 0) minVolume = 0.01;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0 || tick.bid <= 0 || point <= 0) {
      LogMessage("Test order skipped - invalid price data", LOG_ERRORS);
      return;
   }

   double price = buyNext ? tick.ask : tick.bid;
   double testSL = 0.0, testTP = 0.0;

   if(buyNext) {
      testSL = NormalizeDouble(price - (StopLoss * point), digits);
      testTP = NormalizeDouble(price + (TakeProfit * point), digits);
      trade.Buy(minVolume, _Symbol, 0.0, testSL, testTP, "Test Buy");
   } else {
      testSL = NormalizeDouble(price + (StopLoss * point), digits);
      testTP = NormalizeDouble(price - (TakeProfit * point), digits);
      trade.Sell(minVolume, _Symbol, 0.0, testSL, testTP, "Test Sell");
   }

   if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
      LogMessage("Test order failed: " + trade.ResultRetcodeDescription(), LOG_ERRORS);
   } else {
      string openedSide = buyNext ? "Buy" : "Sell";
      buyNext = !buyNext;
      LogMessage(StringFormat("Opened test position: %s at %.5f SL:%.5f TP:%.5f",
                openedSide, price, testSL, testTP), LOG_OPERATIONS);
   }
}
