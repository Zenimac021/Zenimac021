//+------------------------------------------------------------------+
//|                Chandelier Exit Scalper EA v1.10                  |
//|                       Corrected & improved by Copilot            |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024, Centaur"
#property link      "forex-station.com/memberlist.php?mode=viewprofile&u=4948703"
#property version   "1.10"
#property description "Chandelier Exit Scalper EA - Automated Gold Scalping"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_MODE
{
   SIGNAL_CLOSED_BAR = 0,
   SIGNAL_CURRENT_BAR = 1
};

enum ENUM_SESSION_FILTER
{
   SESSION_NONE = 0,
   SESSION_LONDON = 1,
   SESSION_NEWYORK = 2,
   SESSION_ASIA = 3,
   SESSION_LONDON_NY = 4,
   SESSION_ALL = 5
};

enum ENUM_MONEY_MANAGEMENT
{
   MM_FIXED_LOT = 0,
   MM_RISK_PERCENT = 1,
   MM_FIXED_MONEY = 2
};

enum ENUM_EXIT_MODE
{
   EXIT_CHANDELIER = 0,
   EXIT_FIXED_TP_SL = 1,
   EXIT_HYBRID = 2
};

//+------------------------------------------------------------------+
//| Input Parameters - Core Settings                                 |
//+------------------------------------------------------------------+
input group "=== Core Chandelier Settings ==="
input int      inp_atr_period            = 10;
input double   inp_atr_multiplier        = 0.3;
input bool     inp_use_close             = true;

//+------------------------------------------------------------------+
//| Input Parameters - Signal Settings                               |
//+------------------------------------------------------------------+
input group "=== Signal Settings ==="
input ENUM_SIGNAL_MODE inp_signal_mode   = SIGNAL_CLOSED_BAR;
input bool     inp_show_current_signal   = true;
input bool     inp_filter_consecutive    = true;
input int      inp_signal_bars_valid     = 3;
input bool     inp_one_trade_per_bar     = true;
input int      inp_trade_cooldown_sec    = 0;

//+------------------------------------------------------------------+
//| Input Parameters - Scalping Filters                              |
//+------------------------------------------------------------------+
input group "=== Scalping Filters ==="
input ENUM_SESSION_FILTER inp_session_filter = SESSION_NONE;
input bool     inp_use_spread_filter     = true;
input int      inp_max_spread_points     = 80;
input bool     inp_use_atr_filter        = false;
input double   inp_min_atr_pips          = 3.0;
input double   inp_max_atr_pips          = 50.0;
input bool     inp_use_trend_filter      = false;
input int      inp_min_trend_strength    = 1;
input int      inp_gmt_offset_hours      = 0;

//+------------------------------------------------------------------+
//| Input Parameters - Money Management                              |
//+------------------------------------------------------------------+
input group "=== Money Management ==="
input ENUM_MONEY_MANAGEMENT inp_mm_mode  = MM_RISK_PERCENT;
input double   inp_fixed_lot             = 0.01;
input double   inp_risk_percent          = 1.0;
input double   inp_fixed_money           = 100.0;
input double   inp_max_lot               = 5.0;
input double   inp_min_lot               = 0.01;
input int      inp_max_positions         = 1;
input bool     inp_reverse_on_signal     = false;

//+------------------------------------------------------------------+
//| Input Parameters - Exit Strategy                                 |
//+------------------------------------------------------------------+
input group "=== Exit Strategy ==="
input ENUM_EXIT_MODE inp_exit_mode       = EXIT_CHANDELIER;
input double   inp_tp_multiplier         = 2.0;
input double   inp_sl_multiplier         = 1.5;
input bool     inp_use_trailing_stop     = true;
input double   inp_trailing_atr_mult     = 0.5;
input bool     inp_use_breakeven         = true;
input double   inp_breakeven_atr_mult    = 0.8;
input double   inp_breakeven_profit      = 2.0;

//+------------------------------------------------------------------+
//| Input Parameters - Trade Filters                                 |
//+------------------------------------------------------------------+
input group "=== Trade Filters ==="
input bool     inp_use_max_daily_loss    = true;
input double   inp_max_daily_loss_pct    = 3.0;
input bool     inp_use_max_daily_trades  = true;
input int      inp_max_daily_trades      = 10;
input int      inp_magic_number          = 4948703;
input string   inp_trade_comment         = "CE Scalper";

//+------------------------------------------------------------------+
//| Input Parameters - Time Filters                                  |
//+------------------------------------------------------------------+
input group "=== Time Filters ==="
input bool     inp_use_friday_filter     = true;
input int      inp_friday_close_hour     = 20;
input bool     inp_use_news_filter       = false;

//+------------------------------------------------------------------+
//| Input Parameters - Alert Settings                                |
//+------------------------------------------------------------------+
input group "=== Alert Settings ==="
input bool     inp_alert_on              = true;
input bool     inp_alert_sound           = true;
input bool     inp_alert_push            = false;
input bool     inp_alert_email           = false;
input string   inp_sound_file            = "alert.wav";

//+------------------------------------------------------------------+
//| Input Parameters - Visual Settings                               |
//+------------------------------------------------------------------+
input group "=== Visual Settings ==="
input bool     inp_show_panel            = true;
input int      inp_panel_x               = 10;
input int      inp_panel_y               = 100;
input bool     inp_show_arrows           = true;
input color    inp_buy_color             = clrLime;
input color    inp_sell_color            = clrRed;
input int      inp_arrow_size            = 2;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
double         BuySignal[];
double         SellSignal[];
double         atr[];
double         longStop[];
double         shortStop[];
double         dir[];
double         trendStrength[];

int            atr_period;
double         atr_multiplier;
datetime       last_alert_time = 0;
int            g_spread_points = 0;
double         g_point_value = 0;
double         g_tick_size = 0;
double         g_tick_value = 0;
datetime       g_last_bar_time = 0;

bool           use_spread_filter;
int            max_spread_points;
bool           use_atr_filter;
double         min_atr_range;
double         max_atr_range;
bool           use_trend_filter;
int            min_trend_strength;

CTrade         m_trade;
CPositionInfo  m_position;
COrderInfo     m_order;

struct STradeState
{
   datetime     last_buy_signal;
   datetime     last_sell_signal;
   datetime     last_processed_signal_bar;
   datetime     last_executed_buy_bar;
   datetime     last_executed_sell_bar;
   int          daily_trades;
   datetime     daily_reset_time;
   double       daily_pnl;
   int          last_signal_direction;
   datetime     last_trade_time;
};
STradeState    g_trade_state;

#define PANEL_PREFIX "CE_EA_"
#define PANEL_BG     PANEL_PREFIX "BG"
#define PANEL_TITLE  PANEL_PREFIX "Title"
#define PANEL_SEP    PANEL_PREFIX "Sep"
#define PANEL_DIR    PANEL_PREFIX "Dir"
#define PANEL_ATR    PANEL_PREFIX "ATR"
#define PANEL_TREND  PANEL_PREFIX "Trend"
#define PANEL_LONG   PANEL_PREFIX "LongStop"
#define PANEL_SHORT  PANEL_PREFIX "ShortStop"
#define PANEL_SPRD   PANEL_PREFIX "Spread"
#define PANEL_SESS   PANEL_PREFIX "Session"
#define PANEL_POS    PANEL_PREFIX "Pos"
#define PANEL_PNL    PANEL_PREFIX "PnL"
#define PANEL_TRADES PANEL_PREFIX "Trades"
#define PANEL_STATUS PANEL_PREFIX "Status"

//+------------------------------------------------------------------+
int OnInit()
{
   atr_period = MathMax(1, MathMin(50, inp_atr_period));
   atr_multiplier = MathMax(0.1, NormalizeDouble(inp_atr_multiplier, 2));

   g_point_value = (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
   if(g_point_value <= 0) g_point_value = _Point;

   g_tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   use_spread_filter = inp_use_spread_filter;
   max_spread_points = MathMax(1, inp_max_spread_points);
   use_atr_filter = inp_use_atr_filter;
   min_atr_range = inp_min_atr_pips * g_point_value;
   max_atr_range = (inp_max_atr_pips > 0.0) ? inp_max_atr_pips * g_point_value : 0.0;
   use_trend_filter = inp_use_trend_filter;
   min_trend_strength = MathMax(0, MathMin(3, inp_min_trend_strength));

   if(use_atr_filter && max_atr_range > 0.0 && min_atr_range >= max_atr_range)
   {
      Print("Warning: Min ATR >= Max ATR. Disabling ATR filter.");
      use_atr_filter = false;
   }

   m_trade.SetExpertMagicNumber(inp_magic_number);
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   m_trade.SetAsyncMode(false);

   ArraySetAsSeries(BuySignal, true);
   ArraySetAsSeries(SellSignal, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(longStop, true);
   ArraySetAsSeries(shortStop, true);
   ArraySetAsSeries(dir, true);
   ArraySetAsSeries(trendStrength, true);

   ResetDailyStats();
   ZeroMemory(g_trade_state);
   ResetDailyStats();

   Print("Chandelier Exit Scalper EA v1.10 initialized. Magic: ", inp_magic_number);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllPanelObjects();
   Print("Chandelier Exit Scalper EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   CheckDailyReset();
   UpdateDailyPnL();

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, atr_period + 100, rates);
   if(copied < atr_period + 5)
      return;

   int rates_total = copied;

   double open[], high[], low[], close[];
   ArrayResize(open, rates_total);
   ArrayResize(high, rates_total);
   ArrayResize(low, rates_total);
   ArrayResize(close, rates_total);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   for(int i = 0; i < rates_total; i++)
   {
      open[i] = rates[i].open;
      high[i] = rates[i].high;
      low[i] = rates[i].low;
      close[i] = rates[i].close;
   }

   ArrayResize(BuySignal, rates_total);
   ArrayResize(SellSignal, rates_total);
   ArrayResize(atr, rates_total);
   ArrayResize(longStop, rates_total);
   ArrayResize(shortStop, rates_total);
   ArrayResize(dir, rates_total);
   ArrayResize(trendStrength, rates_total);

   CalculateATRSeries(rates_total, atr_period, high, low, close, atr);
   CalculateChandelierExit(rates_total, high, low, close, rates);

   g_spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   ManagePositions(rates[0].close, 0);

   bool is_new_bar = (rates[0].time != g_last_bar_time);
   if(is_new_bar)
      g_last_bar_time = rates[0].time;

   CheckForSignals(rates_total, rates, is_new_bar);

   if(inp_show_panel)
      UpdatePanel(0, rates[0].time);

   if(inp_show_arrows)
      DrawSignalArrows(rates);
}

//+------------------------------------------------------------------+
void CalculateATRSeries(const int rates_total,
                        const int period,
                        const double &high[],
                        const double &low[],
                        const double &close[],
                        double &result[])
{
   if(rates_total <= 0 || period <= 0)
      return;

   ArrayInitialize(result, 0.0);

   for(int i = rates_total - 1; i >= 0; i--)
   {
      double tr = high[i] - low[i];
      if(i < rates_total - 1)
      {
         double prev_close = close[i + 1];
         tr = MathMax(tr, MathAbs(high[i] - prev_close));
         tr = MathMax(tr, MathAbs(low[i] - prev_close));
      }

      if(i == rates_total - 1)
      {
         result[i] = tr;
      }
      else
      {
         result[i] = ((result[i + 1] * (period - 1)) + tr) / period;
      }
   }
}

//+------------------------------------------------------------------+
void CalculateChandelierExit(int rates_total, const double &high[], const double &low[],
                             const double &close[], const MqlRates &rates[])
{
   for(int i = rates_total - 1; i >= 0 && !IsStopped(); i--)
   {
      BuySignal[i] = EMPTY_VALUE;
      SellSignal[i] = EMPTY_VALUE;
      longStop[i] = 0.0;
      shortStop[i] = 0.0;
      dir[i] = 0.0;
      trendStrength[i] = 0.0;

      if(i > rates_total - atr_period - 2)
         continue;

      double current_atr = MathMax(atr[i], _Point);
      double atr_offset = atr_multiplier * current_atr;

      double highest_high = -DBL_MAX;
      double lowest_low = DBL_MAX;

      for(int k = 0; k < atr_period; k++)
      {
         int idx = i + k;
         if(idx >= rates_total)
            continue;

         double h_val = inp_use_close ? close[idx] : high[idx];
         double l_val = inp_use_close ? close[idx] : low[idx];
         if(h_val > highest_high) highest_high = h_val;
         if(l_val < lowest_low) lowest_low = l_val;
      }

      double raw_long_stop = highest_high - atr_offset;
      double raw_short_stop = lowest_low + atr_offset;

      if(i == rates_total - atr_period - 2)
      {
         longStop[i] = raw_long_stop;
         shortStop[i] = raw_short_stop;
         if(close[i] > longStop[i] && close[i] > shortStop[i])
            dir[i] = 1.0;
         else if(close[i] < longStop[i] && close[i] < shortStop[i])
            dir[i] = -1.0;
         else
            dir[i] = (i < rates_total - 1 && close[i] > close[i + 1]) ? 1.0 : -1.0;
      }
      else
      {
         if(close[i + 1] > longStop[i + 1])
            longStop[i] = MathMax(raw_long_stop, longStop[i + 1]);
         else
            longStop[i] = raw_long_stop;

         if(close[i + 1] < shortStop[i + 1])
            shortStop[i] = MathMin(raw_short_stop, shortStop[i + 1]);
         else
            shortStop[i] = raw_short_stop;

         if(close[i] > shortStop[i + 1])
            dir[i] = 1.0;
         else if(close[i] < longStop[i + 1])
            dir[i] = -1.0;
         else
            dir[i] = dir[i + 1];
      }

      trendStrength[i] = CalculateTrendStrength(i, current_atr, close, high, low, rates_total);

      bool bullish_flip = (i < rates_total - 1 && dir[i] == 1.0 && dir[i + 1] == -1.0);
      bool bearish_flip = (i < rates_total - 1 && dir[i] == -1.0 && dir[i + 1] == 1.0);

      if(bullish_flip && PassAllFilters(rates[i].time, current_atr, (int)rates[i].spread, trendStrength[i]))
      {
         if(!inp_filter_consecutive || g_trade_state.last_signal_direction != 1)
            BuySignal[i] = low[i];
      }

      if(bearish_flip && PassAllFilters(rates[i].time, current_atr, (int)rates[i].spread, trendStrength[i]))
      {
         if(!inp_filter_consecutive || g_trade_state.last_signal_direction != -1)
            SellSignal[i] = high[i];
      }
   }
}

//+------------------------------------------------------------------+
void CheckForSignals(int rates_total, const MqlRates &rates[], bool is_new_bar)
{
   if(rates_total < 3)
      return;

   int signal_shift = (inp_signal_mode == SIGNAL_CLOSED_BAR) ? 1 : 0;
   if(signal_shift >= rates_total - 1)
      return;

   if(inp_signal_mode == SIGNAL_CLOSED_BAR && !is_new_bar)
      return;

   if(!CanTrade())
      return;

   datetime signal_bar_time = rates[signal_shift].time;
   if(inp_one_trade_per_bar && g_trade_state.last_processed_signal_bar == signal_bar_time)
      return;

   bool buy_signal = (dir[signal_shift] == 1.0 && dir[signal_shift + 1] == -1.0);
   bool sell_signal = (dir[signal_shift] == -1.0 && dir[signal_shift + 1] == 1.0);

   if(!buy_signal && !sell_signal)
      return;

   if(!PassAllFilters(signal_bar_time, atr[signal_shift], (int)rates[signal_shift].spread, trendStrength[signal_shift]))
      return;

   if(inp_trade_cooldown_sec > 0 && g_trade_state.last_trade_time > 0)
   {
      if((TimeCurrent() - g_trade_state.last_trade_time) < inp_trade_cooldown_sec)
         return;
   }

   int buy_positions = 0;
   int sell_positions = 0;
   CountPositions(buy_positions, sell_positions);
   int total_positions = buy_positions + sell_positions;

   if(buy_signal)
   {
      g_trade_state.last_buy_signal = signal_bar_time;
      if(signal_shift > 0)
         TriggerAlert("BUY", signal_bar_time, rates[signal_shift].close);

      if(inp_one_trade_per_bar && g_trade_state.last_executed_buy_bar == signal_bar_time)
         return;

      if(inp_reverse_on_signal && sell_positions > 0)
      {
         CloseAllPositions(ORDER_TYPE_SELL);
         CountPositions(buy_positions, sell_positions);
         total_positions = buy_positions + sell_positions;
      }

      if(buy_positions == 0 && total_positions < inp_max_positions)
      {
         if(OpenBuyOrder(signal_bar_time, atr[signal_shift]))
         {
            g_trade_state.last_executed_buy_bar = signal_bar_time;
            g_trade_state.last_processed_signal_bar = signal_bar_time;
            g_trade_state.last_signal_direction = 1;
         }
      }
      return;
   }

   if(sell_signal)
   {
      g_trade_state.last_sell_signal = signal_bar_time;
      if(signal_shift > 0)
         TriggerAlert("SELL", signal_bar_time, rates[signal_shift].close);

      if(inp_one_trade_per_bar && g_trade_state.last_executed_sell_bar == signal_bar_time)
         return;

      if(inp_reverse_on_signal && buy_positions > 0)
      {
         CloseAllPositions(ORDER_TYPE_BUY);
         CountPositions(buy_positions, sell_positions);
         total_positions = buy_positions + sell_positions;
      }

      if(sell_positions == 0 && total_positions < inp_max_positions)
      {
         if(OpenSellOrder(signal_bar_time, atr[signal_shift]))
         {
            g_trade_state.last_executed_sell_bar = signal_bar_time;
            g_trade_state.last_processed_signal_bar = signal_bar_time;
            g_trade_state.last_signal_direction = -1;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool OpenBuyOrder(datetime signal_time, double current_atr)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double lot = CalculateLotSize(ask, current_atr, ORDER_TYPE_BUY);
   if(lot <= 0.0)
      return false;

   double sl = 0.0, tp = 0.0;
   CalculateTPSL(ask, current_atr, ORDER_TYPE_BUY, sl, tp);

   if(!m_trade.Buy(lot, _Symbol, ask, sl, tp, inp_trade_comment))
   {
      Print("Buy order failed. Error: ", GetLastError(), " Retcode: ", m_trade.ResultRetcode());
      return false;
   }

   Print("Buy order executed. Lot: ", lot, " SL: ", sl, " TP: ", tp);
   g_trade_state.daily_trades++;
   g_trade_state.last_trade_time = TimeCurrent();
   return true;
}

//+------------------------------------------------------------------+
bool OpenSellOrder(datetime signal_time, double current_atr)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = CalculateLotSize(bid, current_atr, ORDER_TYPE_SELL);
   if(lot <= 0.0)
      return false;

   double sl = 0.0, tp = 0.0;
   CalculateTPSL(bid, current_atr, ORDER_TYPE_SELL, sl, tp);

   if(!m_trade.Sell(lot, _Symbol, bid, sl, tp, inp_trade_comment))
   {
      Print("Sell order failed. Error: ", GetLastError(), " Retcode: ", m_trade.ResultRetcode());
      return false;
   }

   Print("Sell order executed. Lot: ", lot, " SL: ", sl, " TP: ", tp);
   g_trade_state.daily_trades++;
   g_trade_state.last_trade_time = TimeCurrent();
   return true;
}

//+------------------------------------------------------------------+
double CalculateLotSize(double entry_price, double current_atr, ENUM_ORDER_TYPE order_type)
{
   double lot = 0.0;
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot_sym = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot_sym = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lot_step <= 0.0 || min_lot_sym <= 0.0 || max_lot_sym <= 0.0)
      return 0.0;

   switch(inp_mm_mode)
   {
      case MM_FIXED_LOT:
         lot = inp_fixed_lot;
         break;

      case MM_RISK_PERCENT:
      {
         double sl_distance = current_atr * inp_sl_multiplier;
         if(sl_distance <= 0.0 || g_tick_size <= 0.0 || g_tick_value <= 0.0)
            return 0.0;

         double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * inp_risk_percent / 100.0;
         double ticks_at_risk = sl_distance / g_tick_size;
         if(ticks_at_risk <= 0.0)
            return 0.0;

         lot = risk_amount / (ticks_at_risk * g_tick_value);
         break;
      }

      case MM_FIXED_MONEY:
      {
         double sl_distance = current_atr * inp_sl_multiplier;
         if(sl_distance <= 0.0 || g_tick_size <= 0.0 || g_tick_value <= 0.0)
            return 0.0;

         double ticks_at_risk = sl_distance / g_tick_size;
         if(ticks_at_risk <= 0.0)
            return 0.0;

         lot = inp_fixed_money / (ticks_at_risk * g_tick_value);
         break;
      }
   }

   lot = MathMax(lot, MathMax(min_lot_sym, inp_min_lot));
   lot = MathMin(lot, MathMin(max_lot_sym, inp_max_lot));
   lot = MathFloor(lot / lot_step) * lot_step;

   if(lot < min_lot_sym)
      return 0.0;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
void CalculateTPSL(double entry_price, double current_atr, ENUM_ORDER_TYPE order_type,
                   double &sl, double &tp)
{
   double sl_distance = current_atr * inp_sl_multiplier;
   double tp_distance = current_atr * inp_tp_multiplier;

   double stop_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freeze_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double min_distance = MathMax(stop_level, freeze_level) + 5.0 * _Point;

   sl_distance = MathMax(sl_distance, min_distance);
   tp_distance = MathMax(tp_distance, min_distance);

   if(order_type == ORDER_TYPE_BUY)
   {
      sl = entry_price - sl_distance;
      tp = entry_price + tp_distance;
   }
   else
   {
      sl = entry_price + sl_distance;
      tp = entry_price - tp_distance;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
void ManagePositions(double current_price, int current_i)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != inp_magic_number) continue;
      if(m_position.Symbol() != _Symbol) continue;

      double pos_sl = m_position.StopLoss();
      double pos_tp = m_position.TakeProfit();
      double pos_open = m_position.PriceOpen();
      ulong pos_ticket = m_position.Ticket();
      bool is_buy = (m_position.PositionType() == POSITION_TYPE_BUY);
      double current_atr = atr[current_i];

      if(inp_exit_mode == EXIT_CHANDELIER || inp_exit_mode == EXIT_HYBRID)
      {
         if(is_buy && dir[current_i] == -1.0 && dir[current_i + 1] == 1.0)
         {
            m_trade.PositionClose(pos_ticket);
            continue;
         }
         if(!is_buy && dir[current_i] == 1.0 && dir[current_i + 1] == -1.0)
         {
            m_trade.PositionClose(pos_ticket);
            continue;
         }
      }

      if(inp_use_trailing_stop && current_atr > 0.0)
      {
         double trail_distance = MathMax(current_atr * inp_trailing_atr_mult,
                                         (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point + 5.0 * _Point);

         if(is_buy)
         {
            double new_sl = NormalizeDouble(current_price - trail_distance, _Digits);
            if(new_sl > pos_sl && new_sl > pos_open)
               m_trade.PositionModify(pos_ticket, new_sl, pos_tp);
         }
         else
         {
            double new_sl = NormalizeDouble(current_price + trail_distance, _Digits);
            if((pos_sl == 0.0 || new_sl < pos_sl) && new_sl < pos_open)
               m_trade.PositionModify(pos_ticket, new_sl, pos_tp);
         }
      }

      if(inp_use_breakeven && current_atr > 0.0)
      {
         double be_trigger = current_atr * inp_breakeven_atr_mult;
         double be_profit = inp_breakeven_profit * g_point_value;

         if(is_buy)
         {
            double be_sl = NormalizeDouble(pos_open + be_profit, _Digits);
            if(current_price - pos_open >= be_trigger && pos_sl < be_sl)
               m_trade.PositionModify(pos_ticket, be_sl, pos_tp);
         }
         else
         {
            double be_sl = NormalizeDouble(pos_open - be_profit, _Digits);
            if(pos_open - current_price >= be_trigger && (pos_sl == 0.0 || pos_sl > be_sl))
               m_trade.PositionModify(pos_ticket, be_sl, pos_tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_ORDER_TYPE type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != inp_magic_number) continue;
      if(m_position.Symbol() != _Symbol) continue;

      bool is_buy = (m_position.PositionType() == POSITION_TYPE_BUY);
      if((type == ORDER_TYPE_BUY && is_buy) || (type == ORDER_TYPE_SELL && !is_buy))
         m_trade.PositionClose(m_position.Ticket());
   }
}

//+------------------------------------------------------------------+
void CountPositions(int &buy_positions, int &sell_positions)
{
   buy_positions = 0;
   sell_positions = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != inp_magic_number) continue;
      if(m_position.Symbol() != _Symbol) continue;

      if(m_position.PositionType() == POSITION_TYPE_BUY)
         buy_positions++;
      else
         sell_positions++;
   }
}

//+------------------------------------------------------------------+
bool CanTrade()
{
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;

   if(inp_use_max_daily_loss)
   {
      double max_loss = AccountInfoDouble(ACCOUNT_BALANCE) * inp_max_daily_loss_pct / 100.0;
      if(g_trade_state.daily_pnl <= -max_loss)
         return false;
   }

   if(inp_use_max_daily_trades && g_trade_state.daily_trades >= inp_max_daily_trades)
      return false;

   if(inp_use_friday_filter)
   {
      MqlDateTime dt;
      TimeToStruct(ToGMT(TimeCurrent()), dt);
      if(dt.day_of_week == 5 && dt.hour >= inp_friday_close_hour)
         return false;
   }

   if(use_spread_filter && g_spread_points > max_spread_points)
      return false;

   return true;
}

//+------------------------------------------------------------------+
datetime ToGMT(datetime source_time)
{
   return source_time - (inp_gmt_offset_hours * 3600);
}

//+------------------------------------------------------------------+
void ResetDailyStats()
{
   g_trade_state.daily_trades = 0;
   g_trade_state.daily_pnl = 0.0;
   datetime gmt_now = ToGMT(TimeCurrent());
   string date_str = TimeToString(gmt_now, TIME_DATE);
   g_trade_state.daily_reset_time = StringToTime(date_str);
}

//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime gmt_now = ToGMT(TimeCurrent());
   datetime current_date = StringToTime(TimeToString(gmt_now, TIME_DATE));
   if(current_date > g_trade_state.daily_reset_time)
      ResetDailyStats();
}

//+------------------------------------------------------------------+
void UpdateDailyPnL()
{
   g_trade_state.daily_pnl = 0.0;
   datetime from = g_trade_state.daily_reset_time + (inp_gmt_offset_hours * 3600);
   datetime to = TimeCurrent() + 60;

   if(!HistorySelect(from, to))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != inp_magic_number) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                    + HistoryDealGetDouble(ticket, DEAL_SWAP)
                    + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      g_trade_state.daily_pnl += profit;
   }
}

//+------------------------------------------------------------------+
double CalculateTrendStrength(int i, double current_atr, const double &close[],
                              const double &high[], const double &low[], int rates_total)
{
   if(i + atr_period >= rates_total) return 0.0;

   double price_change = MathAbs(close[i] - close[i + atr_period]);
   double volatility = current_atr * atr_period;
   if(volatility <= 0.0) return 0.0;

   double efficiency = price_change / volatility;
   int up_bars = 0, down_bars = 0;

   for(int k = 0; k < atr_period && (i + k + 1) < rates_total; k++)
   {
      if(close[i + k] > close[i + k + 1]) up_bars++;
      else if(close[i + k] < close[i + k + 1]) down_bars++;
   }

   double consistency = (double)MathMax(up_bars, down_bars) / atr_period;
   double strength = efficiency * consistency;

   if(strength > 0.7) return 3.0;
   if(strength > 0.45) return 2.0;
   if(strength > 0.25) return 1.0;
   return 0.0;
}

//+------------------------------------------------------------------+
bool PassAllFilters(datetime bar_time, double current_atr, int spread_points, double trend_str)
{
   if(inp_session_filter != SESSION_NONE && !IsSessionActive(bar_time))
      return false;

   if(use_spread_filter)
   {
      int check_spread = (g_spread_points > 0) ? g_spread_points : spread_points;
      if(check_spread > max_spread_points)
         return false;
   }

   if(use_atr_filter)
   {
      double atr_pips = current_atr / g_point_value;
      double min_pips = min_atr_range / g_point_value;
      double max_pips = (max_atr_range > 0.0) ? max_atr_range / g_point_value : 0.0;

      if(atr_pips < min_pips) return false;
      if(max_pips > 0.0 && atr_pips > max_pips) return false;
   }

   if(use_trend_filter && trend_str < min_trend_strength)
      return false;

   return true;
}

//+------------------------------------------------------------------+
bool IsSessionActive(datetime bar_time)
{
   MqlDateTime dt;
   TimeToStruct(ToGMT(bar_time), dt);
   int hour = dt.hour;

   switch(inp_session_filter)
   {
      case SESSION_LONDON:    return (hour >= 8 && hour < 17);
      case SESSION_NEWYORK:   return (hour >= 13 && hour < 22);
      case SESSION_ASIA:      return (hour >= 0 && hour < 9);
      case SESSION_LONDON_NY: return (hour >= 8 && hour < 22);
      case SESSION_ALL:       return (hour >= 0 && hour < 22);
      default:                return true;
   }
}

//+------------------------------------------------------------------+
string GetSessionName()
{
   switch(inp_session_filter)
   {
      case SESSION_LONDON:    return "London";
      case SESSION_NEWYORK:   return "New York";
      case SESSION_ASIA:      return "Asia";
      case SESSION_LONDON_NY: return "London+NY";
      case SESSION_ALL:       return "Active";
      default:                return "All";
   }
}

string GetTrendStrengthText(double strength)
{
   if(strength >= 3.0) return "Strong";
   if(strength >= 2.0) return "Moderate";
   if(strength >= 1.0) return "Weak";
   return "Chop";
}

color GetTrendStrengthColor(double strength)
{
   if(strength >= 3.0) return clrLime;
   if(strength >= 2.0) return clrGreen;
   if(strength >= 1.0) return clrYellow;
   return clrGray;
}

//+------------------------------------------------------------------+
void TriggerAlert(string signal_type, datetime signal_time, double price)
{
   if(!inp_alert_on) return;
   if(signal_time == last_alert_time) return;
   last_alert_time = signal_time;

   string msg = StringFormat("CE Scalper EA: %s %s @ %s",
                             _Symbol, signal_type, DoubleToString(price, _Digits));

   if(inp_alert_sound) PlaySound(inp_sound_file);
   if(inp_alert_push)  SendNotification(msg);
   if(inp_alert_email) SendMail("CE Scalper EA Signal", msg);
   Alert(msg);
}

//+------------------------------------------------------------------+
double GetCurrentPnL()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != inp_magic_number) continue;
      if(m_position.Symbol() != _Symbol) continue;
      pnl += m_position.Profit() + m_position.Swap() + m_position.Commission();
   }
   return pnl;
}

//+------------------------------------------------------------------+
string GetPositionInfo()
{
   int buy_count = 0, sell_count = 0;
   double buy_lots = 0.0, sell_lots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != inp_magic_number) continue;
      if(m_position.Symbol() != _Symbol) continue;

      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         buy_count++;
         buy_lots += m_position.Volume();
      }
      else
      {
         sell_count++;
         sell_lots += m_position.Volume();
      }
   }

   if(buy_count > 0 && sell_count > 0)
      return StringFormat("BUY x%d (%.2f) | SELL x%d (%.2f)", buy_count, buy_lots, sell_count, sell_lots);
   if(buy_count > 0)
      return StringFormat("BUY x%d (%.2f)", buy_count, buy_lots);
   if(sell_count > 0)
      return StringFormat("SELL x%d (%.2f)", sell_count, sell_lots);
   return "None";
}

//+------------------------------------------------------------------+
void UpdatePanel(int last_bar, datetime bar_time)
{
   int x = inp_panel_x;
   int y = inp_panel_y;
   int panel_width = 260;
   int line_height = 16;
   int padding = 6;
   int num_lines = 14;
   int panel_height = line_height * num_lines + padding * 2;

   CreateOrUpdateRect(PANEL_BG, x, y, panel_width, panel_height, C'20,20,25', C'70,70,80');

   string dir_text = (dir[last_bar] > 0) ? "LONG  ▲" : "SHORT ▼";
   color dir_color = (dir[last_bar] > 0) ? clrLime : clrRed;

   double atr_pips = (atr[last_bar] > 0) ? atr[last_bar] / g_point_value : 0;
   string atr_text = StringFormat("%.1f pips", atr_pips);

   string long_text = (longStop[last_bar] > 0) ? DoubleToString(longStop[last_bar], _Digits) : "N/A";
   string short_text = (shortStop[last_bar] > 0) ? DoubleToString(shortStop[last_bar], _Digits) : "N/A";

   string spread_text = StringFormat("%d pts", g_spread_points);
   color spread_color = (use_spread_filter && g_spread_points > max_spread_points) ? clrOrangeRed : clrWhite;

   string session_text = GetSessionName();
   bool session_active = IsSessionActive(bar_time);
   color session_color = session_active ? clrWhite : clrGray;
   string session_status = session_active ? " [ON]" : " [OFF]";

   double t_strength = trendStrength[last_bar];
   string trend_text = GetTrendStrengthText(t_strength);
   color trend_color = GetTrendStrengthColor(t_strength);

   string pos_info = GetPositionInfo();
   color pos_color = (StringFind(pos_info, "BUY") >= 0) ? clrLime :
                    (StringFind(pos_info, "SELL") >= 0) ? clrRed : clrGray;

   double current_pnl = GetCurrentPnL();
   color pnl_color = (current_pnl > 0) ? clrLime : (current_pnl < 0) ? clrRed : clrWhite;
   string pnl_text = StringFormat("%.2f %s", current_pnl, AccountInfoString(ACCOUNT_CURRENCY));

   string trades_text = StringFormat("%d/%d", g_trade_state.daily_trades, inp_max_daily_trades);
   color trades_color = (g_trade_state.daily_trades >= inp_max_daily_trades) ? clrOrangeRed : clrWhite;

   bool can_trade = CanTrade();
   string status_text = can_trade ? "ACTIVE" : "PAUSED";
   color status_color = can_trade ? clrLime : clrOrangeRed;

   int ly = y + padding;
   int lx = x + padding;

   CreateOrUpdateLabel(PANEL_TITLE, "CE SCALPER EA v1.10", lx, ly, clrGold, 10); ly += line_height;
   CreateOrUpdateLabel(PANEL_SEP, "─────────────────────────", lx, ly, clrDimGray, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_STATUS, "Status: " + status_text, lx, ly, status_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_DIR, "Dir: " + dir_text, lx, ly, dir_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_ATR, "ATR: " + atr_text, lx, ly, clrWhite, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_TREND, "Trend: " + trend_text, lx, ly, trend_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_LONG, "Long: " + long_text, lx, ly, clrLime, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_SHORT, "Short: " + short_text, lx, ly, clrRed, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_SPRD, "Spread: " + spread_text, lx, ly, spread_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_SESS, "Session: " + session_text + session_status, lx, ly, session_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_POS, "Pos: " + pos_info, lx, ly, pos_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_PNL, "PnL: " + pnl_text, lx, ly, pnl_color, 9); ly += line_height;
   CreateOrUpdateLabel(PANEL_TRADES, "Trades: " + trades_text, lx, ly, trades_color, 9);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DrawSignalArrows(const MqlRates &rates[])
{
   static datetime last_drawn = 0;
   if(rates[0].time == last_drawn) return;
   last_drawn = rates[0].time;

   string prefix = "CE_EA_Arrow_";

   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
      {
         datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         if(rates[0].time - obj_time > PeriodSeconds(PERIOD_CURRENT) * 50)
            ObjectDelete(0, name);
      }
   }

   for(int i = 1; i < ArraySize(BuySignal) && i < 100; i++)
   {
      if(BuySignal[i] != EMPTY_VALUE)
      {
         string name = prefix + "Buy_" + IntegerToString((int)rates[i].time);
         if(ObjectFind(0, name) < 0)
         {
            ObjectCreate(0, name, OBJ_ARROW_BUY, 0, rates[i].time, rates[i].low);
            ObjectSetInteger(0, name, OBJPROP_COLOR, inp_buy_color);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, inp_arrow_size);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }

      if(SellSignal[i] != EMPTY_VALUE)
      {
         string name = prefix + "Sell_" + IntegerToString((int)rates[i].time);
         if(ObjectFind(0, name) < 0)
         {
            ObjectCreate(0, name, OBJ_ARROW_SELL, 0, rates[i].time, rates[i].high);
            ObjectSetInteger(0, name, OBJPROP_COLOR, inp_sell_color);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, inp_arrow_size);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }
   }
}

//+------------------------------------------------------------------+
void DeleteAllPanelObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PANEL_PREFIX) == 0)
         ObjectDelete(0, name);
   }

   string arrow_prefix = "CE_EA_Arrow_";
   total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, arrow_prefix) == 0)
         ObjectDelete(0, name);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void CreateOrUpdateRect(string name, int x, int y, int width, int height, color bg_color, color border_color)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("Failed to create panel background: ", name, " Error: ", GetLastError());
         return;
      }
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border_color);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, string text, int x, int y, color txt_color, int font_size)
{
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      {
         Print("Failed to create panel label: ", name, " Error: ", GetLastError());
         return;
      }
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt_color);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+
