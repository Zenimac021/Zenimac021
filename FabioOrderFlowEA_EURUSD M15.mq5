//+------------------------------------------------------------------+
//|                                             FabioOrderFlowEA.mq5 |
//| Backtestable EA version of the FabioOrderFlow indicator.         |
//| Order-flow PROXIES only (tick volume + bar close location).      |
//| Strategy tester: use "1 minute OHLC" or "Every tick" model;      |
//| run on M1 or M5 (M1 history is read for the volume profile).     |
//| Uses its own magic number - does not touch other EAs' trades.    |
//+------------------------------------------------------------------+
#property copyright "zenix"
#property version   "1.01"
#property strict

#include <Trade/Trade.mqh>

//--- strategy inputs (same meaning as the indicator)
input int    InpSessionStartHour = 0;
input double InpBinSize          = 0.50;
input double InpValueAreaPct     = 70.0;
input double InpLvnFactor        = 0.40;
input int    InpMaxLvn           = 6;
input int    InpAvgLen           = 20;
input double InpAggression       = 1.5;
input int    InpBreakLen         = 20;
input int    InpCvdLen           = 30;
input double InpTolerance        = 1.00;
input bool   InpUseTrendModel    = true;
input bool   InpUseRevertModel   = true;

//--- trade management
input double InpRiskPercent      = 0.50;
input double InpStopBuffer       = 0.50;
input double InpMinStop          = 1.50;
input double InpMaxStop          = 15.0;
input double InpRR               = 2.0;
input bool   InpPartialAtOneR    = true;
input double InpPartialFraction  = 0.5;
input bool   InpUseBE            = true;   // Move SL to breakeven
input double InpBEStartPips      = 5.0;    // Trigger BE after this many pips profit, defined at M5, auto-stretched for other TFs (0 = use R instead)
input double InpBELockPips       = 1.0;    // Pips locked beyond entry in pips mode, defined at M5 (covers spread/commission)
input int    InpPointsPerPip     = 0;      // Points per pip (0 = auto: 10 for 3/5-digit FX & gold, 1 otherwise)
input double InpBEStartR         = 0.6;    // R mode: trigger once profit >= this many R
input double InpBEOffsetR        = 0.10;   // R mode: lock this much beyond entry, in R
input bool   InpUseTrail         = true;   // Continuous trailing stop
input double InpTrailStartR      = 0.5;    // Start trailing once profit >= this many R
input double InpTrailDistR       = 0.5;    // Trail distance behind price, in R
input double InpTrailStepR       = 0.02;   // Min SL improvement per modify, in R

//--- filters / risk limits
input int    InpTradeStartHour   = 0;      // Trading window start (0 = all day, use for 24/7 synthetics)
input int    InpTradeEndHour     = 24;     // Trading window end (24 = all day, use for 24/7 synthetics)
input int    InpMaxSpreadPoints  = 0;      // Max spread in points (0 = off; V75 spread >> 150 so 150 blocks everything)
input int    InpMaxTradesPerDay  = 6;
input double InpDailyLossPct     = 2.0;
input ulong  InpMagic            = 20261002;
input int    InpDeviation        = 30;
//--- robustness / diagnostics (fix for no trades)
input bool   InpAutoScale        = true;   // Auto-scale price-unit inputs to the symbol
input int    InpScaleMode        = 1;      // 1 = scale by chart-timeframe ATR (works on any symbol/TF), 0 = scale by price (legacy)
input double InpRefATR           = 2.0;    // M5 ATR (price units) at which the price-unit inputs apply as written (~gold); auto-rescaled for other TFs
input int    InpATRPeriod        = 14;     // ATR period for scaling
input bool   InpClampSmallStops  = true;   // Widen tiny stops to MinStop instead of skipping
input bool   InpUseFallback      = true;   // Relaxed momentum fallback when strict model fails
input bool   InpVerbose          = true;   // Extra Print diagnostics
input double InpFallbackMult     = 2.2;    // Fallback needs |delta| >= avgD * this (stricter than entry)
input double InpMinBodyFrac      = 0.35;   // Fallback needs |body|/range >= this (avoid doji noise)
input double InpMinStopXSpread   = 2.5;    // Skip if SL distance < spread * this (spread would eat the trade)

//--- profile
struct Profile
  {
   bool   ok;
   double poc, vah, val, lo, hi;
   double lvn[16];
   int    nlvn;
   double cvd, cvdSlope;
  };

CTrade   trade;
Profile  g_cur, g_prev;
datetime g_prevSession = 0;
datetime g_lastBar = 0;
int      g_tradesToday = 0;
int      g_dayKey = -1;
double   g_dayStartEquity = 0;
int      g_rej[32];
ulong    g_partialDone[];
int      g_barsSeen = 0;
int      g_sigTrend = 0, g_sigRevert = 0, g_sigFall = 0;
datetime g_lastSignalBar = 0;
int      g_atrH = INVALID_HANDLE;

//--- latest completed ATR on the chart timeframe, or 0 if not available yet
double CurrentATR()
  {
   if(g_atrH == INVALID_HANDLE) return(0.0);
   double b[1];
   if(CopyBuffer(g_atrH, 0, 1, 1, b) != 1) return(0.0);
   return(b[0]);
  }

//--- timeframe factor relative to M5 (ATR grows ~sqrt(time)); 1.0 on M5
double TfFactor()
  {
   int sec = PeriodSeconds(_Period);
   return(sec > 0 ? MathSqrt((double)sec / 300.0) : 1.0);
  }

//--- chart-timeframe length in minutes (>= 1)
double TfMinutes()
  {
   return(MathMax(PeriodSeconds(_Period) / 60.0, 1.0));
  }

//--- one pip in price units
double PipSize()
  {
   int ppp = InpPointsPerPip;
   if(ppp <= 0)
     {
      string s = _Symbol;
      StringToUpper(s);
      if(_Digits == 3 || _Digits == 5 || StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) ppp = 10;
      else ppp = 1;
     }
   return(_Point * ppp);
  }

double PriceScale()
  {
   double px = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(px <= 0.0) px = iClose(_Symbol, _Period, 1);
   if(px <= 0.0) return(1.0);
   if(!InpAutoScale) return(1.0);
   if(InpScaleMode == 1 && InpRefATR > 0.0)
     {
      double atr = CurrentATR();
      if(atr > 0.0)
        {
         //--- InpRefATR is defined at M5; ATR grows ~sqrt(time), so rescale it to the chart timeframe
         double ref = InpRefATR * TfFactor();
         double a = atr / ref;
         if(a < 0.0002) a = 0.0002;
         if(a > 50.0)   a = 50.0;
         return(a);
        }
     }
   double f = px / 2500.0;
   if(f < 0.0002) f = 0.0002;
   if(f > 20.0)   f = 20.0;
   return(f);
  }
double EffBin()     { return(InpBinSize   * PriceScale()); }
double EffTol()     { return(InpTolerance  * PriceScale()); }
double EffBuf()     { return(InpStopBuffer * PriceScale()); }
double EffMinStop() { return(InpMinStop    * PriceScale()); }
double EffMaxStop() { return(InpMaxStop    * PriceScale()); }

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_atrH = iATR(_Symbol, _Period, MathMax(InpATRPeriod, 1));
   Print("FOF init ", _Symbol, " scale=", DoubleToString(PriceScale(), 6),
         " pip=", DoubleToString(PipSize(), _Digits));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_atrH != INVALID_HANDLE) IndicatorRelease(g_atrH);
   string n[] = {"dailyLoss","maxTradesDay","outsideHours","spread","ownPositionOpen","notEnoughBars","noProfile",
                 "notAggressive","noSignal","buyStopOutOfRange","sellStopOutOfRange","stopsLevel","lotsTooSmall"};
   for(int i = 0; i < ArraySize(n) && i < 32; i++) if(g_rej[i] > 0) Print("FOF reject[", i, "] ", n[i], " = ", g_rej[i]);
   Print("FOF summary bars=", g_barsSeen, " trend=", g_sigTrend, " revert=", g_sigRevert, " fall=", g_sigFall);
  }

double BarDelta(double o, double h, double l, double c, double tv)
  {
   double rng = h - l;
   if(rng <= 0.0) return(0.0);
   return(tv * (c - o) / rng);
  }
bool BuildProfileFromRates(MqlRates &r[], int n, Profile &p, double bin)
  {
   p.ok = false; p.nlvn = 0; p.cvd = 0; p.cvdSlope = 0;
   if(n < 30 || bin <= 0.0) return(false);
   double lo = r[0].low, hi = r[0].high;
   for(int i = 1; i < n; i++)
     {
      if(r[i].low  < lo) lo = r[i].low;
      if(r[i].high > hi) hi = r[i].high;
     }
   double range = hi - lo;
   if(range <= 0.0) return(false);
   int nb = (int)MathCeil(range / bin) + 1;
   if(nb < 5 || nb > 20000)
     {
      bin = range / 80.0;
      if(bin <= 0.0) return(false);
      nb = (int)MathCeil(range / bin) + 1;
     }
   if(nb < 5 || nb > 20000) return(false);
   double vol[];
   ArrayResize(vol, nb);
   ArrayInitialize(vol, 0.0);
   double total = 0.0, cum = 0.0;
   double cvdArr[];
   ArrayResize(cvdArr, n);
   for(int i = 0; i < n; i++)
     {
      int b0 = (int)((r[i].low  - lo) / bin);
      int b1 = (int)((r[i].high - lo) / bin);
      if(b0 < 0) b0 = 0;
      if(b1 >= nb) b1 = nb - 1;
      if(b1 < b0) b1 = b0;
      double share = (double)r[i].tick_volume / (double)(b1 - b0 + 1);
      for(int b = b0; b <= b1; b++) vol[b] += share;
      total += (double)r[i].tick_volume;
      cum += BarDelta(r[i].open, r[i].high, r[i].low, r[i].close, (double)r[i].tick_volume);
      cvdArr[i] = cum;
     }
   p.cvd = cum;
   //--- InpCvdLen is defined at M5 (M1 bars); stretch it with the chart timeframe
   int cvdBars = (int)MathMax(5.0, MathRound(InpCvdLen * TfMinutes() / 5.0));
   int back = MathMin(cvdBars, n - 1);
   p.cvdSlope = cvdArr[n - 1] - cvdArr[n - 1 - back];
   int poc = 0;
   for(int b = 1; b < nb; b++) if(vol[b] > vol[poc]) poc = b;
   double target = total * InpValueAreaPct / 100.0;
   double acc = vol[poc];
   int up = poc, dn = poc;
   while(acc < target && (up < nb - 1 || dn > 0))
     {
      double vUp = 0.0, vDn = 0.0;
      if(up + 1 < nb) vUp = vol[up + 1] + ((up + 2 < nb) ? vol[up + 2] : 0.0);
      if(dn - 1 >= 0) vDn = vol[dn - 1] + ((dn - 2 >= 0) ? vol[dn - 2] : 0.0);
      if(vUp == 0.0 && vDn == 0.0) break;
      if(vUp >= vDn)
        { up++; acc += vol[up]; if(up + 1 < nb && acc < target) { up++; acc += vol[up]; } }
      else
        { dn--; acc += vol[dn]; if(dn - 1 >= 0 && acc < target) { dn--; acc += vol[dn]; } }
     }
   p.poc = lo + (poc + 0.5) * bin;
   p.vah = lo + (up + 1) * bin;
   p.val = lo + dn * bin;
   p.lo = lo; p.hi = hi;
   double sum = 0.0; int cnt = 0;
   for(int b = 0; b < nb; b++) if(vol[b] > 0.0) { sum += vol[b]; cnt++; }
   double avg = (cnt > 0) ? sum / cnt : 0.0;
   for(int b = 2; b < nb - 2 && p.nlvn < MathMin(InpMaxLvn, 16); b++)
     {
      if(vol[b] <= 0.0 || vol[b] >= avg * InpLvnFactor) continue;
      bool isMin = true;
      for(int k = -2; k <= 2; k++)
         if(k != 0 && vol[b + k] < vol[b]) { isMin = false; break; }
      if(!isMin) continue;
      p.lvn[p.nlvn++] = lo + (b + 0.5) * bin;
     }
   p.ok = true;
   return(true);
  }

bool BuildProfile(datetime from, datetime to, Profile &p)
  {
   p.ok = false;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, PERIOD_M1, from, to, r);
   if(n >= 30 && BuildProfileFromRates(r, n, p, EffBin())) return(true);
   ArraySetAsSeries(r, true);
   int want = (int)MathMax(400.0, 80.0 * TfMinutes());   // fallback window: ~80 chart bars of M1 history
   n = CopyRates(_Symbol, PERIOD_M1, 0, want, r);
   if(n >= 30)
     {
      MqlRates f[];
      ArrayResize(f, n);
      for(int i = 0; i < n; i++) f[i] = r[n - 1 - i];
      if(BuildProfileFromRates(f, n, p, EffBin())) return(true);
     }
   return(false);
  }

datetime SessionStart(datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = InpSessionStartHour; dt.min = 0; dt.sec = 0;
   datetime s = StructToTime(dt);
   if(s > now) s -= 86400;
   return(s);
  }

void RefreshProfiles()
  {
   datetime now = TimeCurrent();
   datetime s = SessionStart(now);
   BuildProfile(s, now + 60, g_cur);
   if(s != g_prevSession)
     {
      g_prevSession = s;
      g_prev.ok = false;
      for(int k = 1; k <= 7; k++)
        {
         datetime ps = s - (datetime)(k * 86400);
         if(BuildProfile(ps, ps + 86400, g_prev)) break;
        }
     }
  }

int MarketState(double price)
  {
   if(g_prev.ok)
     {
      if(price > g_prev.vah) return(1);
      if(price < g_prev.val) return(-1);
      return(0);
     }
   if(g_cur.ok)
     {
      if(price > g_cur.vah) return(1);
      if(price < g_cur.val) return(-1);
     }
   return(0);
  }

bool TrendConfirmed(int dir, const MqlRates &r[], int lookback, double tol, double avgD)
  {
   if(dir == 0) return(false);
   int maxIdx = MathMin(lookback + 1, ArraySize(r) - 1);
   int wins = 0;
   int losses = 0;
   for(int k = 2; k <= maxIdx; k++)
     {
      double dK = BarDelta(r[k].open, r[k].high, r[k].low, r[k].close, (double)r[k].tick_volume);
      if(dir > 0)
        {
         if(r[k].close > r[k - 1].close) wins++;
         else losses++;
         if(r[k].close > g_cur.poc && r[k].close > r[k].open) wins++;
         if(dK > avgD * 0.35) wins++;
         if(r[k].close >= r[1].close - tol) wins++;
        }
      else
        {
         if(r[k].close < r[k - 1].close) wins++;
         else losses++;
         if(r[k].close < g_cur.poc && r[k].close < r[k].open) wins++;
         if(dK < -avgD * 0.35) wins++;
         if(r[k].close <= r[1].close + tol) wins++;
        }
     }
   return(wins >= losses + 2);
  }

bool RevertConfirmed(int dir, const MqlRates &r[], double tol, double avgD)
  {
   if(dir == 0) return(false);
   double d1 = BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume);
   double d2 = BarDelta(r[2].open, r[2].high, r[2].low, r[2].close, (double)r[2].tick_volume);
   if(dir > 0)
     {
      bool nearVal = (r[1].close > g_cur.val && r[1].close < g_cur.poc + tol * 2.0);
      bool candleConfirm = (r[1].close > r[1].open && r[1].close >= r[2].close && d1 > avgD * 0.5);
      return(nearVal && candleConfirm && d1 > 0.0);
     }
   bool nearVah = (r[1].close < g_cur.vah && r[1].close > g_cur.poc - tol * 2.0);
   bool candleConfirm = (r[1].close < r[1].open && r[1].close <= r[2].close && d1 < -avgD * 0.5);
   return(nearVah && candleConfirm && d1 < 0.0);
  }

double CalcLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
   if(riskMoney <= 0.0) return(0.0);
   double profit = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) || profit == 0.0) return(0.0);
   double lossPerLot = MathAbs(profit);
   if(lossPerLot <= 1e-12) return(0.0);
   double lots = riskMoney / lossPerLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   int vd = 0;                                   // volume decimals from step (0.001 -> 3, 1 -> 0)
   for(double s = step; vd < 8 && MathAbs(s - MathRound(s)) > 1e-9; s *= 10.0) vd++;
   lots = MathFloor(lots / step + 1e-9) * step;
   if(lots < vmin)
     {
      if(InpUseFallback && vmin > 0.0)
        {
         double lossMin = lossPerLot * vmin;
         if(lossMin <= riskMoney * 3.0) return(NormalizeDouble(vmin, vd));
        }
      return(0.0);
     }
   if(lots > vmax) lots = vmax;
   return(NormalizeDouble(lots, vd));
  }

bool HasOwnPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic) return(true);
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC) == InpMagic)
        {
         int type = (int)OrderGetInteger(ORDER_TYPE);
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL ||
            type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
            type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
            type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT)
            return(true);
        }
     }
   return(false);
  }

bool WasPartialed(ulong ticket)
  {
   for(int i = 0; i < ArraySize(g_partialDone); i++)
      if(g_partialDone[i] == ticket) return(true);
   return(false);
  }

void ManagePosition()
  {
   if(!InpPartialAtOneR) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(WasPartialed(t)) continue;
      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      if(sl <= 0.0) continue;
      double risk = MathAbs(open - sl);
      double px = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double moved = (type == POSITION_TYPE_BUY) ? px - open : open - px;
      if(moved < risk) continue;
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double part = MathFloor(vol * InpPartialFraction / step) * step;
      if(part <= 0.0 || part >= vol)
         part = 0.0;
      else if(vol - part < vmin)
         part = MathMax(0.0, vol - vmin);
      if(part >= vmin && vol - part >= vmin)
         trade.PositionClosePartial(t, part);
      if(PositionSelectByTicket(t))
         trade.PositionModify(t, NormalizeDouble(open, _Digits), tp);
      int n = ArraySize(g_partialDone);
      ArrayResize(g_partialDone, n + 1);
      g_partialDone[n] = t;
     }
  }



//--- continuous trailing stop. Initial risk (1R) is recovered from the TP distance
//--- (TP = entry +/- R * InpRR) so it stays valid after SL has been moved.
void TrailPositions()
  {
   if(!InpUseTrail) return;
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double oneR = (tp > 0.0 && InpRR > 0.0) ? MathAbs(tp - open) / InpRR : 0.0;
      if(oneR <= 0.0) oneR = (sl > 0.0) ? MathAbs(open - sl) : 0.0;
      if(oneR <= 0.0) continue;
      bool   isBuy = (type == POSITION_TYPE_BUY);
      double px    = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_BID : SYMBOL_ASK);
      double moved = isBuy ? px - open : open - px;
      if(moved < oneR * InpTrailStartR) continue;
      double newSL = isBuy ? px - oneR * InpTrailDistR : px + oneR * InpTrailDistR;
      newSL = NormalizeDouble(newSL, _Digits);
      //--- only tighten, and only by a meaningful step (avoids modify spam)
      double minStep = oneR * InpTrailStepR;
      if(sl > 0.0 && (isBuy ? newSL - sl : sl - newSL) < MathMax(minStep, _Point)) continue;
      //--- respect broker stops level
      if(isBuy ? (px - newSL) < minDist : (newSL - px) < minDist) continue;
      if(!trade.PositionModify(t, newSL, tp) && InpVerbose)
         Print("FOF trail modify failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
  }

//--- breakeven: once profit >= InpBEStartR, move SL to entry (+ small locked offset)
void BreakEvenPositions()
  {
   if(!InpUseBE) return;
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double oneR = (tp > 0.0 && InpRR > 0.0) ? MathAbs(tp - open) / InpRR : 0.0;
      if(oneR <= 0.0) oneR = (sl > 0.0) ? MathAbs(open - sl) : 0.0;
      bool   pipMode = (InpBEStartPips > 0.0);
      if(!pipMode && oneR <= 0.0) continue;
      double pip   = PipSize();
      double px    = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_BID : SYMBOL_ASK);
      double moved = isBuy ? px - open : open - px;
      double tf    = TfFactor();   // pip inputs are defined at M5; stretch with the chart timeframe
      double trig  = pipMode ? InpBEStartPips * pip * tf : oneR * InpBEStartR;
      if(moved < trig) continue;
      double lock  = pipMode ? InpBELockPips * pip * tf : oneR * InpBEOffsetR;
      double be = NormalizeDouble(isBuy ? open + lock : open - lock, _Digits);
      if(sl > 0.0 && (isBuy ? sl >= be : sl <= be)) continue;   // already at/beyond BE
      if(isBuy ? (px - be) < minDist : (be - px) < minDist) continue;
      if(!trade.PositionModify(t, be, tp) && InpVerbose)
         Print("FOF BE modify failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
  }

bool TrendConfirmedByStructure(int dir, const MqlRates &r[], int lookback, double tol, double avgD)
  {
   if(dir == 0) return(false);
   int maxIdx = MathMin(lookback + 1, ArraySize(r) - 1);
   int wins = 0;
   int losses = 0;
   for(int k = 2; k <= maxIdx; k++)
     {
      double dK = BarDelta(r[k].open, r[k].high, r[k].low, r[k].close, (double)r[k].tick_volume);
      if(dir > 0)
        {
         if(r[k].close > r[k - 1].close) wins++;
         else losses++;
         if(r[k].close > g_cur.poc && r[k].close > r[k].open) wins++;
         if(dK > avgD * 0.35) wins++;
         if(r[k].close >= r[1].close - tol) wins++;
        }
      else
        {
         if(r[k].close < r[k - 1].close) wins++;
         else losses++;
         if(r[k].close < g_cur.poc && r[k].close < r[k].open) wins++;
         if(dK < -avgD * 0.35) wins++;
         if(r[k].close <= r[1].close + tol) wins++;
        }
     }
   return(wins >= losses + 2);
  }

bool RevertConfirmedByStructure(int dir, const MqlRates &r[], double tol, double avgD)
  {
   if(dir == 0) return(false);
   double d1 = BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume);
   double d2 = BarDelta(r[2].open, r[2].high, r[2].low, r[2].close, (double)r[2].tick_volume);
   if(dir > 0)
     {
      bool nearVal = (r[1].close > g_cur.val && r[1].close < g_cur.poc + tol * 2.0);
      bool candleConfirm = (r[1].close > r[1].open && r[1].close >= r[2].close && d1 > avgD * 0.5);
      return(nearVal && candleConfirm && d1 > 0.0);
     }
   bool nearVah = (r[1].close < g_cur.vah && r[1].close > g_cur.poc - tol * 2.0);
   bool candleConfirm = (r[1].close < r[1].open && r[1].close <= r[2].close && d1 < -avgD * 0.5);
   return(nearVah && candleConfirm && d1 < 0.0);
  }

void EvaluateSignalDirection(const MqlRates &r[], int state, double avgD, double avgV, int &dir, string &how)
  {
   dir = 0; how = "";
   if(InpUseTrendModel && state != 0)
     {
      double hh = r[2].high, ll = r[2].low;
      for(int k = 2; k <= InpBreakLen + 1; k++)
        { if(r[k].high > hh) hh = r[k].high; if(r[k].low < ll) ll = r[k].low; }
      int scoreL = 0, scoreS = 0;
      double tol = EffTol();
      if(state > 0)
        {
         if(BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume) > 0) scoreL++;
         if(r[1].close >= hh - tol * 0.25) scoreL++;
         if(r[1].close > g_cur.poc) scoreL++;
         if(g_cur.cvdSlope >= 0.0) scoreL++;
         if(r[1].close > r[2].close) scoreL++;
         if(r[1].tick_volume >= avgV * 1.15) scoreL++;
         if(scoreL >= 4 && TrendConfirmedByStructure(1, r, InpBreakLen, tol, avgD)) { dir = 1; how = "trend"; }
        }
      if(state < 0 && dir == 0)
        {
         if(BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume) < 0) scoreS++;
         if(r[1].close <= ll + tol * 0.25) scoreS++;
         if(r[1].close < g_cur.poc) scoreS++;
         if(g_cur.cvdSlope <= 0.0) scoreS++;
         if(r[1].close < r[2].close) scoreS++;
         if(r[1].tick_volume >= avgV * 1.15) scoreS++;
         if(scoreS >= 4 && TrendConfirmedByStructure(-1, r, InpBreakLen, tol, avgD)) { dir = -1; how = "trend"; }
        }
     }
   if(dir == 0 && InpUseRevertModel && state == 0)
     {
      double tol = EffTol();
      double d = BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume);
      if(d > 0 && r[1].close > r[1].open && r[1].low <= g_cur.val + tol && r[1].close > g_cur.val)
        {
         if(r[1].close < g_cur.poc + tol && RevertConfirmedByStructure(1, r, tol, avgD)) { dir = 1; how = "revert-VAL"; }
        }
      else if(d < 0 && r[1].close < r[1].open && r[1].high >= g_cur.vah - tol && r[1].close < g_cur.vah)
        {
         if(r[1].close > g_cur.poc - tol && RevertConfirmedByStructure(-1, r, tol, avgD)) { dir = -1; how = "revert-VAH"; }
        }
      else
        {
         for(int j = 0; j < g_cur.nlvn && dir == 0; j++)
           {
            double L = g_cur.lvn[j];
            if(MathAbs(r[1].close - L) <= tol)
              {
               if(d > 0 && r[1].close > L && RevertConfirmedByStructure(1, r, tol, avgD)) { dir = 1; how = "revert-LVN"; }
               else if(d < 0 && r[1].close < L && RevertConfirmedByStructure(-1, r, tol, avgD)) { dir = -1; how = "revert-LVN"; }
              }
           }
        }
     }
   if(dir == 0 && InpUseFallback)
     {
      double bodyFrac = 0.0;
      double rng1 = r[1].high - r[1].low;
      if(rng1 > 0.0) bodyFrac = MathAbs(r[1].close - r[1].open) / rng1;
      double d = BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume);
      bool strong = (MathAbs(d) >= avgD * InpFallbackMult) && (bodyFrac >= InpMinBodyFrac) &&
                    (r[1].tick_volume >= avgV * 1.1);
      double spreadPx = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      if(spreadPx > 0.0 && MathAbs(r[1].close - r[1].open) < spreadPx * 1.5) strong = false;
      if(r[1].close > r[2].close && d > 0 && r[1].close > r[1].open) strong = strong && (r[1].close > g_cur.poc || g_cur.cvdSlope >= 0.0);
      if(r[1].close < r[2].close && d < 0 && r[1].close < r[1].open) strong = strong && (r[1].close < g_cur.poc || g_cur.cvdSlope <= 0.0);
      if(strong)
        {
         if(d > 0 && r[1].close > r[1].open) { dir = 1; how = "fallback"; }
         else if(d < 0 && r[1].close < r[1].open) { dir = -1; how = "fallback"; }
        }
     }
  }

void OnTick()
  {
   ManagePosition();
   BreakEvenPositions();
   TrailPositions();
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == g_lastBar) return;
   g_lastBar = barTime;
   g_barsSeen++;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int key = dt.year * 1000 + dt.day_of_year;
   if(key != g_dayKey)
     {
      g_dayKey = key;
      g_tradesToday = 0;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
     }
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= g_dayStartEquity * (1.0 - InpDailyLossPct / 100.0)) { g_rej[0]++; return; }
   if(g_tradesToday >= InpMaxTradesPerDay) { g_rej[1]++; return; }
   //--- trading window: Start==End means all-day; supports overnight wrap (e.g. 20->7)
   if(InpTradeStartHour != InpTradeEndHour)
     {
      bool inWin;
      if(InpTradeStartHour < InpTradeEndHour)
         inWin = (dt.hour >= InpTradeStartHour && dt.hour < InpTradeEndHour);
      else
         inWin = (dt.hour >= InpTradeStartHour || dt.hour < InpTradeEndHour);
      if(!inWin)
        {
         g_rej[2]++;
         if(InpVerbose && g_rej[2] <= 3)
            Print("FOF outside hours: server hour=", dt.hour, " window=", InpTradeStartHour, "-", InpTradeEndHour);
         return;
        }
     }
   if(InpMaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
     {
      g_rej[3]++;
      if(InpVerbose && g_rej[3] <= 3)
         Print("FOF spread blocked: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), " pts > max ", InpMaxSpreadPoints);
      return;
     }
   if(InpVerbose && g_barsSeen == 1)
      Print("FOF first bar: server hour=", dt.hour, " spread=", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
            " pts, stopsLevel=", SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
   if(HasOwnPosition()) { g_rej[4]++; return; }
   int need = MathMax(InpAvgLen, InpBreakLen) + 5;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, _Period, 0, need, r) < need) { g_rej[5]++; return; }
   RefreshProfiles();
   if(!g_cur.ok) { g_rej[6]++; if(InpVerbose && g_barsSeen <= 5) Print("FOF no profile yet"); return; }
   double d = BarDelta(r[1].open, r[1].high, r[1].low, r[1].close, (double)r[1].tick_volume);
   double sumD = 0.0, sumV = 0.0;
   for(int k = 2; k <= InpAvgLen + 1; k++)
     {
      sumD += MathAbs(BarDelta(r[k].open, r[k].high, r[k].low, r[k].close, (double)r[k].tick_volume));
      sumV += (double)r[k].tick_volume;
     }
   double avgD = sumD / InpAvgLen, avgV = sumV / InpAvgLen;
   if(avgD <= 0.0) avgD = MathAbs(d);
   if(avgV <= 0.0) avgV = (double)r[1].tick_volume;
   bool aggressive = (MathAbs(d) >= avgD * InpAggression) && ((double)r[1].tick_volume + 1e-9 >= avgV);
   if(InpVerbose && g_barsSeen <= 8)
      Print("FOF bar d=", d, " avgD=", avgD, " aggr=", aggressive);
   if(!aggressive) { g_rej[7]++; return; }
   int state = MarketState(r[1].close);
   int dir = 0;
   string how = "";
   EvaluateSignalDirection(r, state, avgD, avgV, dir, how);
   if(dir == 0) { g_rej[8]++; return; }
   if(dir != 0 && StringFind(how, "trend") >= 0) g_sigTrend++;
   else if(StringFind(how, "revert") >= 0) g_sigRevert++;
   else g_sigFall++;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry, sl, tp;
   ENUM_ORDER_TYPE ot;
   double buf = EffBuf(), mn = EffMinStop(), mx = EffMaxStop();
   if(dir > 0)
     {
      ot = ORDER_TYPE_BUY; entry = ask;
      sl = r[1].low - buf;
      double risk = entry - sl;
      if(risk < mn)
        { if(InpClampSmallStops) { sl = entry - mn; risk = mn; } else { g_rej[9]++; return; } }
      if(risk > mx) { g_rej[9]++; return; }
      tp = entry + risk * InpRR;
     }
   else
     {
      ot = ORDER_TYPE_SELL; entry = bid;
      sl = r[1].high + buf;
      double risk = sl - entry;
      if(risk < mn)
        { if(InpClampSmallStops) { sl = entry + mn; risk = mn; } else { g_rej[10]++; return; } }
      if(risk > mx) { g_rej[10]++; return; }
      tp = entry - risk * InpRR;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * _Point + SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(MathAbs(entry - sl) < minDist)
     {
      if(InpClampSmallStops)
        {
         double need2 = minDist + 2 * _Point;
         if(dir > 0) sl = NormalizeDouble(entry - MathMax(need2, mn), _Digits);
         else        sl = NormalizeDouble(entry + MathMax(need2, mn), _Digits);
         double rk = MathAbs(entry - sl);
         tp = NormalizeDouble(dir > 0 ? entry + rk * InpRR : entry - rk * InpRR, _Digits);
        }
      else { g_rej[11]++; return; }
     }
   double lots = CalcLots(ot, entry, sl);
   if(lots <= 0.0) { g_rej[12]++; return; }
   //--- spread guard: if SL is tighter than spread * X, costs alone bleed the equity curve
   double sprPx = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(sprPx > 0.0 && InpMinStopXSpread > 0.0 && MathAbs(entry - sl) < sprPx * InpMinStopXSpread)
     {
      if(InpVerbose && g_rej[11] < 5)
         Print("FOF skip: SL ", DoubleToString(MathAbs(entry - sl), _Digits),
               " < spread*", DoubleToString(InpMinStopXSpread, 1),
               " (spread=", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), "pts)");
      g_rej[11]++;
      return;
     }
   if(InpVerbose) Print("FOF signal ", how, " dir=", dir, " lots=", lots);
   datetime barTimeNow = iTime(_Symbol, _Period, 0);
   if(g_lastSignalBar == barTimeNow)
     {
      if(InpVerbose) Print("FOF suppress duplicate signal on same bar:", barTimeNow);
      return;
     }
   bool ok = (dir > 0) ? trade.Buy(lots, _Symbol, 0.0, sl, tp, "FOF")
                       : trade.Sell(lots, _Symbol, 0.0, sl, tp, "FOF");
   if(ok)
     {
      g_lastSignalBar = barTimeNow;
      g_tradesToday++;
     }
   else   Print("FOF order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
  }





