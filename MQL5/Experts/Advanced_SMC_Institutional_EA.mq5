//+------------------------------------------------------------------+
//|                   Advanced_SMC_Institutional_EA.mq5              |
//| EA wrapper for Advanced_SMC_Institutional_Signals indicator      |
//+------------------------------------------------------------------+
#property copyright "Trading Pro Plus"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

enum ENUM_SMC_PRESET
{
   SMC_PRESET_CUSTOM = 0,            // Custom (use manual inputs)
   SMC_PRESET_AGGRESSIVE = 1,        // Aggressive
   SMC_PRESET_BALANCED = 2,          // Balanced
   SMC_PRESET_CONSERVATIVE = 3,      // Conservative
   SMC_PRESET_GOLD_SCALPING = 4,     // Gold Scalping
   SMC_PRESET_FOREX_INTRADAY = 5,    // Forex Intraday
   SMC_PRESET_INDICES_MOMENTUM = 6   // Indices Momentum
};

input group "Preset"
input ENUM_SMC_PRESET   InpPreset               = SMC_PRESET_CUSTOM;     // Strategy preset (overrides manual inputs)

input group "Trade Settings"
input long              InpMagicNumber          = 20260328;          // EA magic number
input bool              InpEnableBuyTrades      = true;              // Allow buy trades
input bool              InpEnableSellTrades     = true;              // Allow sell trades
input bool              InpUseRiskSizing        = true;              // Use risk-based sizing
input double            InpFixedLot             = 0.10;              // Fixed lot if risk sizing is off
input double            InpRiskPercent          = 1.00;              // Risk per trade (%)
input int               InpMaxSpreadPoints      = 500;               // Maximum spread in points
input bool              InpOnePositionOnly      = true;              // Only one open position
input bool              InpCloseOnReverseSignal = true;              // Close on opposite signal
input int               InpDeviationPoints      = 20;                // Max slippage/deviation

input group "Execution Risk"
input double            InpStopATRBuffer        = 0.25;              // ATR buffer beyond signal bar
input double            InpTakeProfitRR         = 1.80;              // Take profit as risk multiple
input bool              InpUsePartialTakeProfit = true;              // Close partial at RR threshold
input double            InpPartialCloseRR       = 1.00;              // RR level for partial close
input double            InpPartialClosePercent  = 50.0;              // Percent to close on partial
input bool              InpUseBreakEven         = true;              // Move stop to break-even
input double            InpBreakEvenRR          = 1.00;              // RR threshold for break-even
input bool              InpUseTrailingStop      = true;              // Trail after break-even
input double            InpTrailingATRMult      = 1.00;              // ATR trailing distance
input bool              InpUseSwingTrailing     = true;              // Trail behind recent swing
input int               InpSwingTrailLookback   = 8;                 // Swing trailing lookback bars
input int               InpSwingTrailBufferPts  = 150;               // Extra buffer in points for swing trailing
input bool              InpUseTimeExit          = true;              // Close stale trades after N bars
input int               InpMaxBarsInTrade       = 24;                // Maximum bars to hold a trade

input group "Filters"
input bool              InpUseSessionFilter     = true;              // Allow entries only in active sessions
input int               InpLondonStartHour      = 7;                 // London session start
input int               InpLondonEndHour        = 16;                // London session end
input int               InpNewYorkStartHour     = 13;                // New York session start
input int               InpNewYorkEndHour       = 20;                // New York session end
input bool              InpUseNewsSpikeFilter   = true;              // Skip abnormal expansion bars
input double            InpNewsRangeATRMult     = 2.50;              // Range/ATR threshold for news spike
input int               InpBarsToPauseAfterSpike = 3;                // Bars to pause after spike
input bool              InpPrintDiagnostics     = true;              // Print skip reasons on new bars

input group "Cooldown"
input int               InpEntryCooldownBars    = 2;                 // Bars to wait after a position closes

input group "Friday Close"
input bool              InpUseFridayClose       = false;             // Close positions before weekend
input int               InpFridayCloseHour      = 20;                // Hour to close on Friday (server time)

input group "Panel"
input bool              InpShowPanel            = true;              // Show EA panel
input int               InpPanelX               = 12;                // Panel X offset
input int               InpPanelY               = 90;                // Panel Y offset

input group "Daily Risk Lock"
input bool              InpUseDailyRiskLock     = true;              // Stop new entries after daily limits
input double            InpMaxDailyLossPercent  = 3.0;               // Max daily loss percentage
input int               InpMaxDailyLosses       = 3;                 // Max daily losing trades
input int               InpMaxConsecutiveLosses = 2;                 // Max consecutive losses
input double            InpMaxDrawdownPercent   = 10.0;              // Max account drawdown % (0=disabled)

input group "Logging"
input bool              InpEnableCsvLogging     = true;              // Write CSV trade logs
input string            InpLogFileName          = "ASMC_EA_Trades.csv"; // CSV log file name

input group "Indicator Settings"
input string            InpIndicatorName           = "Advanced_SMC_Institutional_Signals"; // Indicator filename
input int               InpATRPeriod               = 14;                                     // EA ATR period

//--- Runtime preset values (set in OnInit from preset selection)
double   rt_StopATRBuffer;
double   rt_TakeProfitRR;
double   rt_PartialCloseRR;
double   rt_BreakEvenRR;
double   rt_TrailingATRMult;
double   rt_RiskPercent;
int      rt_MaxBarsInTrade;
double   rt_NewsRangeATRMult;

CTrade   g_trade;
int      g_signalHandle = INVALID_HANDLE;
int      g_atrHandle    = INVALID_HANDLE;
datetime g_lastProcessedBar = 0;
string   g_lastSkipReason   = "INIT";
string   g_lastAction       = "WAIT";
datetime g_lastSignalBarTime = 0;
int      g_newsPauseBarsRemaining = 0;
string   g_panelPrefix = "ASMC_EA_PANEL_";

ulong    g_partialTickets[];
int      g_partialTicketCount = 0;

datetime g_dayAnchor = 0;
double   g_dayStartBalance  = 0.0;
int      g_dailyLossCount       = 0;
int      g_consecutiveLossCount = 0;
bool     g_dailyLockActive      = false;
ulong    g_lastProcessedDeal    = 0;

datetime g_entryBarTime = 0;
bool     g_breakEvenHit = false;
int      g_cooldownBarsRemaining = 0;

int      g_totalClosedTrades  = 0;
int      g_totalWinningTrades = 0;
int      g_totalLosingTrades  = 0;
double   g_totalNetProfit     = 0.0;
double   g_totalGrossProfit   = 0.0;
double   g_totalGrossLoss     = 0.0;
double   g_peakBalance        = 0.0;

//+------------------------------------------------------------------+
//| Apply preset parameters                                          |
//+------------------------------------------------------------------+
void ApplyPreset()
{
   rt_StopATRBuffer   = InpStopATRBuffer;
   rt_TakeProfitRR    = InpTakeProfitRR;
   rt_PartialCloseRR  = InpPartialCloseRR;
   rt_BreakEvenRR     = InpBreakEvenRR;
   rt_TrailingATRMult = InpTrailingATRMult;
   rt_RiskPercent     = InpRiskPercent;
   rt_MaxBarsInTrade  = InpMaxBarsInTrade;
   rt_NewsRangeATRMult = InpNewsRangeATRMult;

   switch(InpPreset)
   {
      case SMC_PRESET_AGGRESSIVE:
         rt_RiskPercent     = 2.00;
         rt_StopATRBuffer   = 0.15;
         rt_TakeProfitRR    = 2.50;
         rt_PartialCloseRR  = 0.80;
         rt_BreakEvenRR     = 0.80;
         rt_TrailingATRMult = 0.80;
         rt_MaxBarsInTrade  = 16;
         rt_NewsRangeATRMult = 3.00;
         Print("Preset: AGGRESSIVE applied");
         break;

      case SMC_PRESET_BALANCED:
         rt_RiskPercent     = 1.00;
         rt_StopATRBuffer   = 0.25;
         rt_TakeProfitRR    = 1.80;
         rt_PartialCloseRR  = 1.00;
         rt_BreakEvenRR     = 1.00;
         rt_TrailingATRMult = 1.00;
         rt_MaxBarsInTrade  = 24;
         rt_NewsRangeATRMult = 2.50;
         Print("Preset: BALANCED applied");
         break;

      case SMC_PRESET_CONSERVATIVE:
         rt_RiskPercent     = 0.50;
         rt_StopATRBuffer   = 0.40;
         rt_TakeProfitRR    = 1.50;
         rt_PartialCloseRR  = 1.20;
         rt_BreakEvenRR     = 1.20;
         rt_TrailingATRMult = 1.20;
         rt_MaxBarsInTrade  = 36;
         rt_NewsRangeATRMult = 2.00;
         Print("Preset: CONSERVATIVE applied");
         break;

      case SMC_PRESET_GOLD_SCALPING:
         rt_RiskPercent     = 1.50;
         rt_StopATRBuffer   = 0.20;
         rt_TakeProfitRR    = 2.00;
         rt_PartialCloseRR  = 0.80;
         rt_BreakEvenRR     = 0.80;
         rt_TrailingATRMult = 0.70;
         rt_MaxBarsInTrade  = 12;
         rt_NewsRangeATRMult = 2.00;
         Print("Preset: GOLD SCALPING applied");
         break;

      case SMC_PRESET_FOREX_INTRADAY:
         rt_RiskPercent     = 1.00;
         rt_StopATRBuffer   = 0.30;
         rt_TakeProfitRR    = 2.00;
         rt_PartialCloseRR  = 1.00;
         rt_BreakEvenRR     = 1.00;
         rt_TrailingATRMult = 1.00;
         rt_MaxBarsInTrade  = 30;
         rt_NewsRangeATRMult = 2.50;
         Print("Preset: FOREX INTRADAY applied");
         break;

      case SMC_PRESET_INDICES_MOMENTUM:
         rt_RiskPercent     = 1.25;
         rt_StopATRBuffer   = 0.35;
         rt_TakeProfitRR    = 2.50;
         rt_PartialCloseRR  = 1.00;
         rt_BreakEvenRR     = 1.00;
         rt_TrailingATRMult = 1.20;
         rt_MaxBarsInTrade  = 20;
         rt_NewsRangeATRMult = 3.00;
         Print("Preset: INDICES MOMENTUM applied");
         break;

      default:
         break;
   }
}

//+------------------------------------------------------------------+
//| Reset daily statistics                                           |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   g_dayAnchor = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyLossCount = 0;
   g_consecutiveLossCount = 0;
   g_dailyLockActive = false;
}

//+------------------------------------------------------------------+
//| Write a row to the CSV trade log                                 |
//+------------------------------------------------------------------+
void WriteCsvLog(const string eventType, const string side, const ulong ticket,
                 const double volume, const double entryPrice, const double stopLoss,
                 const double takeProfit, const double profit, const string note)
{
   if(!InpEnableCsvLogging)
      return;

   int handle = FileOpen(InpLogFileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("CSV log open failed. Error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      FileWrite(handle, "time", "symbol", "period", "event", "side", "ticket", "volume",
                "entry", "sl", "tp", "profit", "note");
   }

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             _Symbol,
             EnumToString(_Period),
             eventType,
             side,
             (string)ticket,
             DoubleToString(volume, 2),
             DoubleToString(entryPrice, _Digits),
             DoubleToString(stopLoss, _Digits),
             DoubleToString(takeProfit, _Digits),
             DoubleToString(profit, 2),
             note);
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Set and optionally print the skip reason                         |
//+------------------------------------------------------------------+
void SetSkipReason(const string reason)
{
   g_lastSkipReason = reason;
   if(InpPrintDiagnostics)
      Print("ASMC EA skip: ", reason);
}

//+------------------------------------------------------------------+
//| Detect new bar                                                   |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(currentBar == 0)
      return false;

   if(g_lastProcessedBar == 0)
   {
      g_lastProcessedBar = currentBar;
      return false;
   }

   if(currentBar != g_lastProcessedBar)
   {
      g_lastProcessedBar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                 |
//+------------------------------------------------------------------+
double NormalizePrice(const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Normalize volume to symbol lot constraints                       |
//+------------------------------------------------------------------+
double NormalizeVolume(const double volume)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0)
      return minLot;

   double normalized = MathFloor(volume / lotStep) * lotStep;
   normalized = MathMax(minLot, MathMin(maxLot, normalized));
   return NormalizeDouble(normalized, 2);
}

//+------------------------------------------------------------------+
//| Check whether algo trading is permitted                          |
//+------------------------------------------------------------------+
bool IsAlgoTradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| Check session filter                                             |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   if(!InpUseSessionFilter)
      return true;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   bool london  = (hour >= InpLondonStartHour   && hour < InpLondonEndHour);
   bool newYork = (hour >= InpNewYorkStartHour   && hour < InpNewYorkEndHour);
   return (london || newYork);
}

//+------------------------------------------------------------------+
//| Check if it is Friday close time                                 |
//+------------------------------------------------------------------+
bool IsFridayCloseTime()
{
   if(!InpUseFridayClose)
      return false;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return (tm.day_of_week == 5 && tm.hour >= InpFridayCloseHour);
}

//+------------------------------------------------------------------+
//| Update daily risk lock state                                     |
//+------------------------------------------------------------------+
void UpdateDailyLock()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(g_dayAnchor == 0 || today != g_dayAnchor)
      ResetDailyStats();

   if(!InpUseDailyRiskLock)
      return;

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyPnL = currentBalance - g_dayStartBalance;
   double dailyLossPct = (g_dayStartBalance > 0.0) ? ((-dailyPnL / g_dayStartBalance) * 100.0) : 0.0;

   if(dailyPnL < 0.0 && dailyLossPct >= InpMaxDailyLossPercent)
      g_dailyLockActive = true;
   if(g_dailyLossCount >= InpMaxDailyLosses)
      g_dailyLockActive = true;
   if(g_consecutiveLossCount >= InpMaxConsecutiveLosses)
      g_dailyLockActive = true;

   if(InpMaxDrawdownPercent > 0.0 && g_peakBalance > 0.0)
   {
      double drawdown = ((g_peakBalance - currentBalance) / g_peakBalance) * 100.0;
      if(drawdown >= InpMaxDrawdownPercent)
      {
         g_dailyLockActive = true;
         if(InpPrintDiagnostics)
            Print("ASMC EA: Max drawdown reached (", DoubleToString(drawdown, 2), "%)");
      }
   }

   if(currentBalance > g_peakBalance)
      g_peakBalance = currentBalance;
}

//+------------------------------------------------------------------+
//| Scan closed deals and update statistics                          |
//+------------------------------------------------------------------+
void ProcessClosedDeals()
{
   if(!HistorySelect(TimeCurrent() - 86400 * 10, TimeCurrent()))
      return;

   int deals = HistoryDealsTotal();

   // Iterate oldest to newest so g_lastProcessedDeal watermark works correctly
   for(int i = 0; i < deals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0 || dealTicket <= g_lastProcessedDeal)
         continue;

      long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entryType != DEAL_ENTRY_OUT)
         continue;

      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;

      if((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
         continue;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      string side   = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_SELL) ? "SELL_EXIT" : "BUY_EXIT";
      double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double price  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);

      if(profit < 0.0)
      {
         g_dailyLossCount++;
         g_consecutiveLossCount++;
         g_totalLosingTrades++;
         g_totalGrossLoss += profit;
      }
      else if(profit > 0.0)
      {
         g_consecutiveLossCount = 0;
         g_totalWinningTrades++;
         g_totalGrossProfit += profit;
      }

      g_totalClosedTrades++;
      g_totalNetProfit += profit;

      // Activate entry cooldown when a full position close is detected
      g_cooldownBarsRemaining = InpEntryCooldownBars;
      g_breakEvenHit = false;

      WriteCsvLog("EXIT", side, dealTicket, volume, price, 0.0, 0.0, profit, "closed deal");
      g_lastProcessedDeal = dealTicket;
      UpdateDailyLock();
      g_lastAction = "DEAL CLOSED";
   }
}

//+------------------------------------------------------------------+
//| Partial-take tracking helpers (dynamic array)                    |
//+------------------------------------------------------------------+
bool HasPartialTaken(const ulong ticket)
{
   for(int i = 0; i < g_partialTicketCount; i++)
   {
      if(g_partialTickets[i] == ticket)
         return true;
   }
   return false;
}

void MarkPartialTaken(const ulong ticket)
{
   if(ticket == 0 || HasPartialTaken(ticket))
      return;

   int newSize = g_partialTicketCount + 1;
   if(ArrayResize(g_partialTickets, newSize) < newSize)
   {
      Print("Warning: could not resize partial-ticket array");
      return;
   }
   g_partialTickets[g_partialTicketCount] = ticket;
   g_partialTicketCount++;
}

void ClearPartialTicket(const ulong ticket)
{
   for(int i = 0; i < g_partialTicketCount; i++)
   {
      if(g_partialTickets[i] == ticket)
      {
         for(int j = i; j < g_partialTicketCount - 1; j++)
            g_partialTickets[j] = g_partialTickets[j + 1];
         g_partialTicketCount--;
         ArrayResize(g_partialTickets, g_partialTicketCount);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Panel drawing helpers                                            |
//+------------------------------------------------------------------+
void ClearPanelObjects()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, g_panelPrefix) == 0)
         ObjectDelete(0, name);
   }
}

void DrawPanelLabel(const string id, const string text, const int yOffset, const color clr)
{
   string name = g_panelPrefix + id;
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }

   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + yOffset);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Update the on-chart information panel                            |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel)
   {
      ClearPanelObjects();
      return;
   }

   double buySignal = EMPTY_VALUE;
   double sellSignal = EMPTY_VALUE;
   ReadSignalBuffers(buySignal, sellSignal);
   double atrValue = 0.0;
   ReadATR(atrValue);

   ENUM_POSITION_TYPE type;
   ulong ticket;
   double openPrice, stopLoss, takeProfit;
   bool hasPosition = GetManagedPosition(type, ticket, openPrice, stopLoss, takeProfit);

   string signalState   = (buySignal != EMPTY_VALUE) ? "BUY" : ((sellSignal != EMPTY_VALUE) ? "SELL" : "NONE");
   string positionState = hasPosition ? ((type == POSITION_TYPE_BUY) ? "LONG" : "SHORT") : "FLAT";
   double winRate       = (g_totalClosedTrades > 0) ? (100.0 * g_totalWinningTrades / g_totalClosedTrades) : 0.0;

   string presetName = "CUSTOM";
   if(InpPreset == SMC_PRESET_AGGRESSIVE)       presetName = "AGGRESSIVE";
   else if(InpPreset == SMC_PRESET_BALANCED)     presetName = "BALANCED";
   else if(InpPreset == SMC_PRESET_CONSERVATIVE) presetName = "CONSERVATIVE";
   else if(InpPreset == SMC_PRESET_GOLD_SCALPING)    presetName = "GOLD SCALP";
   else if(InpPreset == SMC_PRESET_FOREX_INTRADAY)   presetName = "FOREX INTRA";
   else if(InpPreset == SMC_PRESET_INDICES_MOMENTUM) presetName = "IDX MOMENTUM";

   DrawPanelLabel("TITLE", "Advanced SMC EA v2", 0, clrWhite);
   DrawPanelLabel("PRESET", "Preset: " + presetName, 18, clrGold);
   DrawPanelLabel("SIG",  "Signal: " + signalState + " | Last: " + g_lastAction, 36, clrDeepSkyBlue);
   DrawPanelLabel("SKIP", "Skip: " + g_lastSkipReason, 54, clrSilver);
   DrawPanelLabel("SPR",  "Spread: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD))
                         + " | ATR: " + DoubleToString(atrValue, _Digits), 72, clrKhaki);
   DrawPanelLabel("POS",  "Position: " + positionState + " | Ticket: " + IntegerToString((int)ticket), 90, clrPaleGreen);
   DrawPanelLabel("RISK", "Open: " + DoubleToString(openPrice, _Digits)
                         + " SL: " + DoubleToString(stopLoss, _Digits)
                         + " TP: " + DoubleToString(takeProfit, _Digits), 108, clrLightSteelBlue);
   DrawPanelLabel("FLT",  "Session: " + string(InpUseSessionFilter ? "ON" : "OFF")
                         + " | SpikePause: " + IntegerToString(g_newsPauseBarsRemaining)
                         + " | Cooldown: " + IntegerToString(g_cooldownBarsRemaining), 126, clrMistyRose);
   DrawPanelLabel("DAY",  "DailyLock: " + string(g_dailyLockActive ? "ON" : "OFF")
                         + " | Losses: " + IntegerToString(g_dailyLossCount)
                         + " | Consecutive: " + IntegerToString(g_consecutiveLossCount), 144, clrKhaki);
   DrawPanelLabel("STATS","Closed: " + IntegerToString(g_totalClosedTrades)
                         + " Win: " + IntegerToString(g_totalWinningTrades)
                         + " Loss: " + IntegerToString(g_totalLosingTrades)
                         + " WR: " + DoubleToString(winRate, 1) + "%", 162, clrPaleTurquoise);
   DrawPanelLabel("PNL",  "Net: " + DoubleToString(g_totalNetProfit, 2)
                         + " GP: " + DoubleToString(g_totalGrossProfit, 2)
                         + " GL: " + DoubleToString(g_totalGrossLoss, 2), 180, clrLightGreen);

   double dd = 0.0;
   if(g_peakBalance > 0.0)
      dd = ((g_peakBalance - AccountInfoDouble(ACCOUNT_BALANCE)) / g_peakBalance) * 100.0;
   DrawPanelLabel("DD",   "DD: " + DoubleToString(dd, 2) + "% | Peak: " + DoubleToString(g_peakBalance, 2), 198, clrCoral);
}

//+------------------------------------------------------------------+
//| Calculate position size from risk                                |
//+------------------------------------------------------------------+
double CalculateVolumeByRisk(const double entryPrice, const double stopPrice)
{
   if(!InpUseRiskSizing)
      return NormalizeVolume(InpFixedLot);

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return NormalizeVolume(InpFixedLot);

   double riskAmount   = AccountInfoDouble(ACCOUNT_BALANCE) * (rt_RiskPercent / 100.0);
   double stopDistance = MathAbs(entryPrice - stopPrice);
   if(stopDistance <= 0.0)
      return NormalizeVolume(InpFixedLot);

   double lossPerLot = (stopDistance / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return NormalizeVolume(InpFixedLot);

   return NormalizeVolume(riskAmount / lossPerLot);
}

//+------------------------------------------------------------------+
//| Retrieve the EA's managed position                               |
//+------------------------------------------------------------------+
bool GetManagedPosition(ENUM_POSITION_TYPE &positionType, ulong &ticket,
                        double &openPrice, double &stopLoss, double &takeProfit)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong posTicket = PositionGetTicket(i);
      if(posTicket == 0 || !PositionSelectByTicket(posTicket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket       = posTicket;
      openPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
      stopLoss     = PositionGetDouble(POSITION_SL);
      takeProfit   = PositionGetDouble(POSITION_TP);
      return true;
   }

   ticket     = 0;
   openPrice  = 0.0;
   stopLoss   = 0.0;
   takeProfit = 0.0;
   return false;
}

bool HasManagedPosition()
{
   ENUM_POSITION_TYPE type;
   ulong ticket;
   double openPrice, stopLoss, takeProfit;
   return GetManagedPosition(type, ticket, openPrice, stopLoss, takeProfit);
}

//+------------------------------------------------------------------+
//| Check spread against maximum                                     |
//+------------------------------------------------------------------+
bool SpreadOk()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Detect abnormal expansion (news spike) bar                       |
//+------------------------------------------------------------------+
bool IsNewsSpikeBar(const double atrValue)
{
   if(!InpUseNewsSpikeFilter || atrValue <= 0.0)
      return false;

   double barRange = iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1);
   return (barRange >= atrValue * rt_NewsRangeATRMult);
}

//+------------------------------------------------------------------+
//| Compute swing-based trailing stop                                |
//+------------------------------------------------------------------+
double GetTrailingSwingStop(const ENUM_POSITION_TYPE positionType)
{
   if(InpSwingTrailLookback < 2)
      return 0.0;

   double buffer = InpSwingTrailBufferPts * _Point;
   if(positionType == POSITION_TYPE_BUY)
   {
      int lowIndex = iLowest(_Symbol, _Period, MODE_LOW, InpSwingTrailLookback, 1);
      if(lowIndex < 0)
         return 0.0;
      return NormalizePrice(iLow(_Symbol, _Period, lowIndex) - buffer);
   }

   int highIndex = iHighest(_Symbol, _Period, MODE_HIGH, InpSwingTrailLookback, 1);
   if(highIndex < 0)
      return 0.0;
   return NormalizePrice(iHigh(_Symbol, _Period, highIndex) + buffer);
}

//+------------------------------------------------------------------+
//| Read signal indicator buffers                                    |
//+------------------------------------------------------------------+
bool ReadSignalBuffers(double &buySignal, double &sellSignal)
{
   double buyBuffer[1];
   double sellBuffer[1];

   if(CopyBuffer(g_signalHandle, 0, 1, 1, buyBuffer) != 1)
      return false;
   if(CopyBuffer(g_signalHandle, 1, 1, 1, sellBuffer) != 1)
      return false;

   buySignal  = buyBuffer[0];
   sellSignal = sellBuffer[0];
   return true;
}

//+------------------------------------------------------------------+
//| Read ATR value                                                   |
//+------------------------------------------------------------------+
bool ReadATR(double &atrValue)
{
   double atr[1];
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atr) != 1)
      return false;
   atrValue = atr[0];
   return (atrValue > 0.0);
}

//+------------------------------------------------------------------+
//| Translate trade server retcode to human-readable string          |
//+------------------------------------------------------------------+
string RetcodeDescription(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:        return "requote";
      case TRADE_RETCODE_REJECT:         return "rejected";
      case TRADE_RETCODE_CANCEL:         return "cancelled";
      case TRADE_RETCODE_PLACED:         return "placed";
      case TRADE_RETCODE_DONE:           return "done";
      case TRADE_RETCODE_DONE_PARTIAL:   return "partial fill";
      case TRADE_RETCODE_ERROR:          return "general error";
      case TRADE_RETCODE_TIMEOUT:        return "timeout";
      case TRADE_RETCODE_INVALID:        return "invalid request";
      case TRADE_RETCODE_INVALID_VOLUME: return "invalid volume";
      case TRADE_RETCODE_INVALID_PRICE:  return "invalid price";
      case TRADE_RETCODE_INVALID_STOPS:  return "invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED: return "trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED:  return "market closed";
      case TRADE_RETCODE_NO_MONEY:       return "insufficient funds";
      case TRADE_RETCODE_PRICE_CHANGED:  return "price changed";
      case TRADE_RETCODE_PRICE_OFF:      return "no quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "invalid expiration";
      case TRADE_RETCODE_ORDER_CHANGED:  return "order changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "too many requests";
      case TRADE_RETCODE_LIMIT_ORDERS:   return "order limit reached";
      case TRADE_RETCODE_FROZEN:         return "order/position frozen";
      default:                           return "code " + IntegerToString(retcode);
   }
}

//+------------------------------------------------------------------+
//| Manage open position: trailing, break-even, partial TP, time exit|
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   ENUM_POSITION_TYPE positionType;
   ulong ticket;
   double openPrice, stopLoss, takeProfit;
   if(!GetManagedPosition(positionType, ticket, openPrice, stopLoss, takeProfit))
      return;

   // Friday close protection
   if(IsFridayCloseTime())
   {
      if(CloseManagedPosition())
      {
         g_lastAction = "FRIDAY CLOSE";
         return;
      }
   }

   // Time-based exit
   if(InpUseTimeExit && g_entryBarTime > 0)
   {
      int barsOpen = iBarShift(_Symbol, _Period, g_entryBarTime, false);
      if(barsOpen >= 0 && barsOpen >= rt_MaxBarsInTrade)
      {
         if(CloseManagedPosition())
         {
            g_lastAction = "TIME EXIT";
            return;
         }
      }
   }

   double atrValue;
   if(!ReadATR(atrValue))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (positionType == POSITION_TYPE_BUY) ? bid : ask;
   double risk = (positionType == POSITION_TYPE_BUY)
                 ? (openPrice - stopLoss)
                 : (stopLoss - openPrice);
   if(risk <= 0.0)
      return;

   double currentVolume   = PositionGetDouble(POSITION_VOLUME);
   double rewardDistance   = (positionType == POSITION_TYPE_BUY)
                             ? (currentPrice - openPrice)
                             : (openPrice - currentPrice);

   // Partial take profit
   if(InpUsePartialTakeProfit && !HasPartialTaken(ticket) && rewardDistance >= (risk * rt_PartialCloseRR))
   {
      double closeVolume = NormalizeVolume(currentVolume * (InpPartialClosePercent / 100.0));
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(closeVolume >= minLot && closeVolume < currentVolume)
      {
         if(g_trade.PositionClosePartial(ticket, closeVolume))
         {
            MarkPartialTaken(ticket);
            g_lastAction = "PARTIAL TP";
         }
      }
   }

   // Break-even logic
   if(InpUseBreakEven && !g_breakEvenHit)
   {
      double triggerPrice = (positionType == POSITION_TYPE_BUY)
                            ? openPrice + (risk * rt_BreakEvenRR)
                            : openPrice - (risk * rt_BreakEvenRR);
      double breakevenStop = openPrice;

      if(positionType == POSITION_TYPE_BUY && currentPrice >= triggerPrice && (stopLoss < breakevenStop || stopLoss == 0.0))
      {
         if(g_trade.PositionModify(ticket, NormalizePrice(breakevenStop), takeProfit))
            g_breakEvenHit = true;
      }
      else if(positionType == POSITION_TYPE_SELL && currentPrice <= triggerPrice && (stopLoss > breakevenStop || stopLoss == 0.0))
      {
         if(g_trade.PositionModify(ticket, NormalizePrice(breakevenStop), takeProfit))
            g_breakEvenHit = true;
      }
   }

   // Trailing stop (only after break-even has been triggered)
   if(InpUseTrailingStop && g_breakEvenHit)
   {
      double trailDistance = atrValue * rt_TrailingATRMult;
      double newStop = stopLoss;
      double swingStop = InpUseSwingTrailing ? GetTrailingSwingStop(positionType) : 0.0;

      if(positionType == POSITION_TYPE_BUY)
      {
         double candidate = NormalizePrice(bid - trailDistance);
         if(candidate > stopLoss && candidate < bid)
            newStop = candidate;
         if(swingStop > 0.0 && swingStop > newStop && swingStop < bid)
            newStop = swingStop;
      }
      else
      {
         double candidate = NormalizePrice(ask + trailDistance);
         if((stopLoss == 0.0 || candidate < stopLoss) && candidate > ask)
            newStop = candidate;
         if(swingStop > 0.0 && (newStop == 0.0 || swingStop < newStop) && swingStop > ask)
            newStop = swingStop;
      }

      if(newStop != stopLoss)
         g_trade.PositionModify(ticket, newStop, takeProfit);
   }
}

//+------------------------------------------------------------------+
//| Close the EA's managed position                                  |
//+------------------------------------------------------------------+
bool CloseManagedPosition()
{
   ENUM_POSITION_TYPE positionType;
   ulong ticket;
   double openPrice, stopLoss, takeProfit;
   if(!GetManagedPosition(positionType, ticket, openPrice, stopLoss, takeProfit))
      return false;

   bool result = g_trade.PositionClose(ticket);
   if(result)
   {
      ClearPartialTicket(ticket);
      g_breakEvenHit = false;
      g_entryBarTime = 0;
   }
   else
   {
      uint retcode = g_trade.ResultRetcode();
      Print("Position close failed. Retcode=", retcode, " (", RetcodeDescription(retcode), ")");
   }
   return result;
}

//+------------------------------------------------------------------+
//| Execute a trade signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(const bool isBuy)
{
   if((isBuy && !InpEnableBuyTrades) || (!isBuy && !InpEnableSellTrades))
   {
      SetSkipReason(isBuy ? "buy disabled" : "sell disabled");
      return;
   }

   if(!IsAlgoTradingAllowed())
   {
      SetSkipReason("algo trading not allowed");
      return;
   }

   if(!SpreadOk())
   {
      SetSkipReason("spread too high");
      return;
   }

   if(!IsTradingSession())
   {
      SetSkipReason("outside session");
      return;
   }

   if(IsFridayCloseTime())
   {
      SetSkipReason("Friday close window");
      return;
   }

   if(g_newsPauseBarsRemaining > 0)
   {
      SetSkipReason("news spike pause active");
      return;
   }

   if(g_cooldownBarsRemaining > 0)
   {
      SetSkipReason("entry cooldown active (" + IntegerToString(g_cooldownBarsRemaining) + " bars)");
      return;
   }

   double atrValue;
   if(!ReadATR(atrValue))
   {
      SetSkipReason("ATR unavailable");
      return;
   }

   if(IsNewsSpikeBar(atrValue))
   {
      g_newsPauseBarsRemaining = InpBarsToPauseAfterSpike;
      SetSkipReason("news spike detected");
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double signalHigh = iHigh(_Symbol, _Period, 1);
   double signalLow  = iLow(_Symbol, _Period, 1);
   double entry = isBuy ? ask : bid;
   double stopLoss = isBuy
                     ? NormalizePrice(signalLow  - (atrValue * rt_StopATRBuffer))
                     : NormalizePrice(signalHigh + (atrValue * rt_StopATRBuffer));

   double stopLevelPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(isBuy && (entry - stopLoss) < stopLevelPoints)
      stopLoss = NormalizePrice(entry - stopLevelPoints);
   if(!isBuy && (stopLoss - entry) < stopLevelPoints)
      stopLoss = NormalizePrice(entry + stopLevelPoints);

   double risk = MathAbs(entry - stopLoss);
   if(risk <= 0.0)
   {
      SetSkipReason("invalid stop distance");
      return;
   }

   double takeProfit = isBuy
                       ? NormalizePrice(entry + (risk * rt_TakeProfitRR))
                       : NormalizePrice(entry - (risk * rt_TakeProfitRR));

   double volume = CalculateVolumeByRisk(entry, stopLoss);
   if(volume <= 0.0)
   {
      SetSkipReason("lot too small");
      return;
   }

   if(InpOnePositionOnly && HasManagedPosition())
   {
      SetSkipReason("position already open");
      return;
   }

   bool result = isBuy
                 ? g_trade.Buy(volume, _Symbol, 0.0, stopLoss, takeProfit, "SMC Buy")
                 : g_trade.Sell(volume, _Symbol, 0.0, stopLoss, takeProfit, "SMC Sell");

   if(!result)
   {
      uint retcode = g_trade.ResultRetcode();
      SetSkipReason("execution failed: " + RetcodeDescription(retcode));
      Print("Trade execution failed. Retcode=", retcode,
            " (", RetcodeDescription(retcode), ") Error=", GetLastError());
   }
   else
   {
      uint retcode = g_trade.ResultRetcode();
      if(retcode != TRADE_RETCODE_DONE && retcode != TRADE_RETCODE_DONE_PARTIAL && retcode != TRADE_RETCODE_PLACED)
      {
         Print("Trade sent but retcode=", retcode, " (", RetcodeDescription(retcode), ")");
      }

      g_lastAction       = isBuy ? "BUY OPENED" : "SELL OPENED";
      g_lastSkipReason   = "none";
      g_lastSignalBarTime = iTime(_Symbol, _Period, 1);
      g_entryBarTime      = iTime(_Symbol, _Period, 1);
      g_breakEvenHit      = false;
      WriteCsvLog("ENTRY", isBuy ? "BUY" : "SELL", 0, volume, entry, stopLoss, takeProfit, 0.0, "signal entry");
   }
}

//+------------------------------------------------------------------+
//| Process indicator signals                                        |
//+------------------------------------------------------------------+
void ProcessSignals()
{
   double buySignal  = EMPTY_VALUE;
   double sellSignal = EMPTY_VALUE;
   if(!ReadSignalBuffers(buySignal, sellSignal))
   {
      SetSkipReason("signal buffers unavailable");
      return;
   }

   ENUM_POSITION_TYPE positionType;
   ulong ticket;
   double openPrice, stopLoss, takeProfit;
   bool hasPosition = GetManagedPosition(positionType, ticket, openPrice, stopLoss, takeProfit);

   bool buyActive  = (buySignal  != EMPTY_VALUE);
   bool sellActive = (sellSignal != EMPTY_VALUE);

   if(hasPosition && InpCloseOnReverseSignal)
   {
      if(positionType == POSITION_TYPE_BUY && sellActive)
      {
         CloseManagedPosition();
         hasPosition = false;
         g_lastAction = "BUY CLOSED ON REVERSE";
      }
      else if(positionType == POSITION_TYPE_SELL && buyActive)
      {
         CloseManagedPosition();
         hasPosition = false;
         g_lastAction = "SELL CLOSED ON REVERSE";
      }
   }

   if(hasPosition && InpOnePositionOnly)
   {
      SetSkipReason("managed position active");
      return;
   }

   if(buyActive && !sellActive)
      ExecuteSignal(true);
   else if(sellActive && !buyActive)
      ExecuteSignal(false);
   else
      SetSkipReason("no fresh directional signal");
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   ApplyPreset();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   ArrayResize(g_partialTickets, 0);
   g_partialTicketCount = 0;
   g_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   ResetDailyStats();

   if(!IsAlgoTradingAllowed())
      Print("Warning: Algorithmic trading is currently disabled. EA will not place trades.");

   g_signalHandle = iCustom(_Symbol, _Period, InpIndicatorName);
   if(g_signalHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handle for '", InpIndicatorName, "'. Error=", GetLastError());
      return INIT_FAILED;
   }

   g_atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle. Error=", GetLastError());
      return INIT_FAILED;
   }

   Print("Advanced SMC EA v2.00 initialized | Preset: ", EnumToString(InpPreset),
         " | Risk: ", DoubleToString(rt_RiskPercent, 2), "%",
         " | TP RR: ", DoubleToString(rt_TakeProfitRR, 2));

   UpdatePanel();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_signalHandle != INVALID_HANDLE)
      IndicatorRelease(g_signalHandle);

   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   ClearPanelObjects();
}

//+------------------------------------------------------------------+
//| Expert tick handler                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDailyLock();
   ProcessClosedDeals();
   ManageOpenPosition();
   UpdatePanel();

   if(!IsNewBar())
      return;

   if(g_newsPauseBarsRemaining > 0)
      g_newsPauseBarsRemaining--;

   if(g_cooldownBarsRemaining > 0)
      g_cooldownBarsRemaining--;

   if(g_dailyLockActive)
   {
      SetSkipReason("daily risk lock active");
      UpdatePanel();
      return;
   }

   ProcessSignals();
   UpdatePanel();
}
//+------------------------------------------------------------------+
