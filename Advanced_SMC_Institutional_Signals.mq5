//+------------------------------------------------------------------+
//| Advanced_SMC_Institutional_Signals.mq5                           |
//| Institutional-style Smart Money Concepts arrow indicator         |
//+------------------------------------------------------------------+
#property copyright "Trading Pro Plus"
#property version   "2.10"
#property description "Simplified SMC signal indicator with buy/sell arrows - Shows only essential zones, FVG, and swing HL"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "SMC Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "SMC Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_width2  2

//--- Enums
enum ENUM_SMC_PRESET
{
   SMC_PRESET_CUSTOM          = 0,
   SMC_PRESET_AGGRESSIVE      = 1,
   SMC_PRESET_BALANCED        = 2,
   SMC_PRESET_CONSERVATIVE    = 3,
   SMC_PRESET_GOLD_SCALPING   = 4,
   SMC_PRESET_FOREX_INTRADAY  = 5,
   SMC_PRESET_INDICES_MOMENTUM= 6
};

//--- Buffers
double BuyBuffer[];
double SellBuffer[];

//--- Global variables
int      g_atrHandle   = INVALID_HANDLE;
int      g_biasHandle  = INVALID_HANDLE;
datetime g_lastBuyAlertTime  = 0;
datetime g_lastSellAlertTime = 0;

string   g_statusObjectName = "ASMC_Status";
string   g_contextPrefix    = "ASMC_CTX_";
string   g_lastSignalDescriptor = "";

datetime g_lastSwingHighTime = 0;
double   g_lastSwingHighPrice = 0.0;
datetime g_lastSwingLowTime = 0;
double   g_lastSwingLowPrice = 0.0;

// Track previous swing highs/lows for structure analysis
datetime g_prevSwingHighTime = 0;
double   g_prevSwingHighPrice = 0.0;
datetime g_prevSwingLowTime = 0;
double   g_prevSwingLowPrice = 0.0;

// Market structure bias
int      g_structureBias = 0;  // 1 = bullish, -1 = bearish, 0 = neutral
datetime g_lastBOS_Time = 0;
double   g_lastBOS_Price = 0.0;

// Advanced SMC structures
struct OrderBlock
{
   datetime time;
   double   price;
   double   high;
   double   low;
   bool     isBullish;
   int      strength;
   bool     tested;
   bool     mitigated;
};

struct BreakerBlock
{
   datetime time;
   double   price;
   double   high;
   double   low;
   bool     isBullish;
   int      strength;
};

struct OTEZone
{
   double   upper;
   double   lower;
   datetime startTime;
   datetime endTime;
   bool     isBullish;
   double   fibLevel;
};

struct PropulsionBlock
{
   datetime time;
   double   high;
   double   low;
   double   close;
   bool     isBullish;
   double   strength;
};

// Arrays for advanced SMC elements
OrderBlock      g_orderBlocks[];
BreakerBlock    g_breakerBlocks[];
OTEZone         g_oteZones[];
PropulsionBlock g_propulsionBlocks[];

ENUM_SMC_PRESET g_activePreset = SMC_PRESET_INDICES_MOMENTUM;
ENUM_SMC_PRESET g_lastPreset   = SMC_PRESET_CUSTOM;

// Preset parameters
double   g_displacementATR   = 0.80;
double   g_minBodyToRange    = 0.45;
double   g_minFVGSizeATR     = 0.08;
int      g_minScore          = 30;
int      g_signalCooldownBars= 3;
double   g_minTargetRR       = 1.40;
bool     g_allowContinuation = true;
bool     g_allowReversal     = true;

// HTF Bias tracking
double   g_htfBiasValue = 0.0;
int      g_htfBiasDirection = 0;  // 1 = above MA (bullish), -1 = below MA (bearish)

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== Structure ==="
input int    InpSwingPivot         = 3;           // Swing pivot strength
input int    InpStructureLookback  = 120;         // Structure lookback bars
input int    InpRangeLookback      = 60;          // Dealing range lookback

input group "=== Preset ==="
input ENUM_SMC_PRESET InpPreset = SMC_PRESET_BALANCED; // Signal quality preset

input group "=== Institutional Filters ==="
input int    InpATRPeriod          = 14;          // ATR period
input double InpLiquiditySweepATR  = 0.10;        // Liquidity sweep beyond swing (ATR)
input double InpDisplacementATR    = 0.80;        // Min displacement (ATR)
input double InpMinBodyToRange     = 0.45;        // Min body/range ratio
input double InpMinFVGSizeATR      = 0.08;        // Min FVG size (ATR)
input bool   InpRequireFVGOrDisplacement = true; // Require FVG or displacement
input bool   InpUsePremiumDiscount = true;       // Use premium/discount filter
input bool   InpAllowContinuationSignals = true;  // Allow continuation
input bool   InpAllowReversalSignals     = true;  // Allow reversal
input double InpRetestToleranceATR = 0.20;        // Retest tolerance (ATR)

input group "=== Higher Timeframe Bias ==="
input bool   InpUseHTFBias         = false;       // Enable HTF bias
input ENUM_TIMEFRAMES InpBiasTimeframe = PERIOD_H1;
input int    InpBiasMAPeriod       = 50;          // Bias EMA period
input int    InpHTFStructureLookback = 150;
input int    InpHTFSwingPivot      = 2;

input group "=== Session Filter ==="
input bool   InpUseSessionFilter   = false;
input int    InpLondonStartHour    = 7;
input int    InpLondonEndHour      = 16;
input int    InpNewYorkStartHour   = 13;
input int    InpNewYorkEndHour     = 20;

input group "=== Signal Quality ==="
input int    InpMinScore           = 30;          // Minimum score
input int    InpSignalCooldownBars = 3;           // Same-direction cooldown
input double InpArrowOffsetATR     = 0.35;        // Arrow offset (ATR)
input double InpMinTargetRR        = 1.40;        // Min target/risk ratio
input bool   InpEnableAlerts       = false;       // Enable alerts

input group "=== Visuals ==="
input bool   InpShowStatusPanel    = true;
input bool   InpShowStructureLabels= true;        // Show swing HL labels
input bool   InpShowOrderBlocks    = true;        // Show order blocks (zones)
input bool   InpShowOTEZones       = true;        // Show OTE zones
input bool   InpShowFVGZones       = true;        // Show FVG zones
input int    InpVisualLookbackBars = 180;
input int    InpMaxOrderBlocks     = 8;           // Max order blocks to display

input group "=== Advanced SMC ==="
input double InpOTEMinRetracement  = 0.62;        // OTE minimum retracement (62%)
input double InpOTEMaxRetracement  = 0.79;        // OTE maximum retracement (79%)
input double InpPropulsionMinATR   = 1.2;         // Min propulsion block size (ATR)
input int    InpOrderBlockLookback = 5;           // Bars to look back for order blocks
input double InpBreakerBlockToleranceATR = 0.15; // Breaker block tolerance (ATR)

//+------------------------------------------------------------------+
//| Apply selected preset                                            |
//+------------------------------------------------------------------+
void ApplyPreset()
{
   g_activePreset = InpPreset;
   
   switch(InpPreset)
   {
      case SMC_PRESET_AGGRESSIVE:
         g_displacementATR = 0.65;  g_minBodyToRange = 0.35; g_minFVGSizeATR = 0.05;
         g_minScore = 24; g_signalCooldownBars = 2; g_minTargetRR = 1.05;
         g_allowContinuation = true; g_allowReversal = true;
         break;
         
      case SMC_PRESET_BALANCED:
         g_displacementATR = 0.80;  g_minBodyToRange = 0.45; g_minFVGSizeATR = 0.08;
         g_minScore = 30; g_signalCooldownBars = 3; g_minTargetRR = 1.40;
         g_allowContinuation = true; g_allowReversal = true;
         break;
         
      case SMC_PRESET_CONSERVATIVE:
         g_displacementATR = 1.05;  g_minBodyToRange = 0.60; g_minFVGSizeATR = 0.12;
         g_minScore = 42; g_signalCooldownBars = 5; g_minTargetRR = 1.80;
         g_allowContinuation = true; g_allowReversal = true;
         break;
         
      case SMC_PRESET_GOLD_SCALPING:
         g_displacementATR = 0.72;  g_minBodyToRange = 0.40; g_minFVGSizeATR = 0.06;
         g_minScore = 28; g_signalCooldownBars = 2; g_minTargetRR = 1.15;
         g_allowContinuation = true; g_allowReversal = true;
         break;
         
      case SMC_PRESET_FOREX_INTRADAY:
         g_displacementATR = 0.88;  g_minBodyToRange = 0.50; g_minFVGSizeATR = 0.08;
         g_minScore = 34; g_signalCooldownBars = 3; g_minTargetRR = 1.35;
         g_allowContinuation = true; g_allowReversal = true;
         break;
         
      case SMC_PRESET_INDICES_MOMENTUM:
         g_displacementATR = 0.95;  g_minBodyToRange = 0.55; g_minFVGSizeATR = 0.10;
         g_minScore = 38; g_signalCooldownBars = 4; g_minTargetRR = 1.60;
         g_allowContinuation = true; g_allowReversal = false;
         break;
         
      case SMC_PRESET_CUSTOM:
      default:
         g_displacementATR   = InpDisplacementATR;
         g_minBodyToRange    = InpMinBodyToRange;
         g_minFVGSizeATR     = InpMinFVGSizeATR;
         g_minScore          = InpMinScore;
         g_signalCooldownBars= InpSignalCooldownBars;
         g_minTargetRR       = InpMinTargetRR;
         g_allowContinuation = InpAllowContinuationSignals;
         g_allowReversal     = InpAllowReversalSignals;
   }
}

//+------------------------------------------------------------------+
//| Session filter                                                   |
//+------------------------------------------------------------------+
bool IsTradingSession(datetime barTime)
{
   if(!InpUseSessionFilter) return true;
   
   MqlDateTime tm;
   TimeToStruct(barTime, tm);
   int h = tm.hour;
   
   bool london = false;
   if(InpLondonStartHour < InpLondonEndHour)
      london = (h >= InpLondonStartHour && h < InpLondonEndHour);
   else
      london = (h >= InpLondonStartHour || h < InpLondonEndHour); // crosses midnight

   bool ny = false;
   if(InpNewYorkStartHour < InpNewYorkEndHour)
      ny = (h >= InpNewYorkStartHour && h < InpNewYorkEndHour);
   else
      ny = (h >= InpNewYorkStartHour || h < InpNewYorkEndHour);
   
   return (london || ny);
}

//+------------------------------------------------------------------+
//| Swing detection helpers                                          |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int rates_total, int index, int pivot)
{
   if(index - pivot < 0 || index + pivot >= rates_total) return false;
   double val = high[index];
   for(int i = 1; i <= pivot; i++)
   {
      if(val <= high[index - i] || val <= high[index + i]) 
         return false;
   }
   return true;
}

bool IsSwingLow(const double &low[], int rates_total, int index, int pivot)
{
   if(index - pivot < 0 || index + pivot >= rates_total) return false;
   double val = low[index];
   for(int i = 1; i <= pivot; i++)
   {
      if(val >= low[index - i] || val >= low[index + i]) 
         return false;
   }
   return true;
}

// Find last swing high before current bar (exclusive of current bar for non-repainting)
int FindLastSwingHigh(const double &high[], int rates_total, int fromIndex)
{
   // Start from the bar before fromIndex to avoid using current bar
   int start = MathMax(InpSwingPivot, fromIndex - InpStructureLookback);
   int end   = MathMin(fromIndex - InpSwingPivot - 1, rates_total - InpSwingPivot - 1);
   
   if(end < start) return -1;
   
   for(int i = end; i >= start; i--)
   {
      if(IsSwingHigh(high, rates_total, i, InpSwingPivot))
         return i;
   }
   return -1;
}

int FindLastSwingLow(const double &low[], int rates_total, int fromIndex)
{
   int start = MathMax(InpSwingPivot, fromIndex - InpStructureLookback);
   int end   = MathMin(fromIndex - InpSwingPivot - 1, rates_total - InpSwingPivot - 1);
   
   if(end < start) return -1;
   
   for(int i = end; i >= start; i--)
   {
      if(IsSwingLow(low, rates_total, i, InpSwingPivot))
         return i;
   }
   return -1;
}

// Find previous swing high (second most recent)
int FindPrevSwingHigh(const double &high[], int rates_total, int fromIndex, int excludeIndex)
{
   int start = MathMax(InpSwingPivot, fromIndex - InpStructureLookback * 2);
   int end   = MathMin(excludeIndex - InpSwingPivot - 1, rates_total - InpSwingPivot - 1);
   
   if(end < start) return -1;
   
   for(int i = end; i >= start; i--)
   {
      if(IsSwingHigh(high, rates_total, i, InpSwingPivot))
         return i;
   }
   return -1;
}

// Find previous swing low (second most recent)
int FindPrevSwingLow(const double &low[], int rates_total, int fromIndex, int excludeIndex)
{
   int start = MathMax(InpSwingPivot, fromIndex - InpStructureLookback * 2);
   int end   = MathMin(excludeIndex - InpSwingPivot - 1, rates_total - InpSwingPivot - 1);
   
   if(end < start) return -1;
   
   for(int i = end; i >= start; i--)
   {
      if(IsSwingLow(low, rates_total, i, InpSwingPivot))
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Advanced SMC Detection Functions                                 |
//+------------------------------------------------------------------+

// Detect Order Blocks - candlesticks preceding strong momentum moves
void DetectOrderBlocks(const datetime &time[], const double &open[], const double &high[], const double &low[], 
                       const double &close[], const double &atr[], int rates_total, int currentIndex)
{
   ArrayResize(g_orderBlocks, 0);
   int foundCount = 0;
   
   for(int i = currentIndex - 2; i >= MathMax(0, currentIndex - InpVisualLookbackBars) && foundCount < InpMaxOrderBlocks; i--)
   {
      if(i < InpOrderBlockLookback + 2) continue;
      
      double bodySize = MathAbs(close[i] - open[i]);
      double rangeSize = high[i] - low[i];
      if(rangeSize <= 0) continue;
      
      double bodyRatio = bodySize / rangeSize;
      
      // Strong momentum criteria
      if(bodyRatio < g_minBodyToRange) continue; // Weak candle
      
      bool isBullishMomentum = close[i] > open[i] && (close[i] - open[i]) >= atr[i] * g_displacementATR;
      bool isBearishMomentum = close[i] < open[i] && (open[i] - close[i]) >= atr[i] * g_displacementATR;
      
      if(!isBullishMomentum && !isBearishMomentum) continue;
      
      // Check preceding candle for order block
      int obIndex = i - 1;
      if(obIndex < 0) continue;
      
      double obBody = MathAbs(close[obIndex] - open[obIndex]);
      double obRange = high[obIndex] - low[obIndex];
      if(obRange <= 0) continue;
      double obBodyRatio = obBody / obRange;
      
      // Order block criteria: opposite direction or consolidation before momentum
      bool isValidOrderBlock = false;
      bool isBullishOB = false;
      
      if(isBullishMomentum && close[obIndex] <= open[obIndex]) // Bearish or doji before bullish
      {
         isValidOrderBlock = true;
         isBullishOB = true;
      }
      else if(isBearishMomentum && close[obIndex] >= open[obIndex]) // Bullish or doji before bearish
      {
         isValidOrderBlock = true;
         isBullishOB = false;
      }
      else if(obBodyRatio < 0.3) // Consolidation before momentum
      {
         isValidOrderBlock = true;
         isBullishOB = isBullishMomentum;
      }
      
      if(isValidOrderBlock)
      {
         OrderBlock ob;
         ob.time = time[obIndex];
         ob.price = close[obIndex];
         ob.high = high[obIndex];
         ob.low = low[obIndex];
         ob.isBullish = isBullishOB;
         ob.strength = (int)(bodyRatio * 100);
         ob.tested = false;
         ob.mitigated = false;
         
         // Check if already tested/mitigated
         for(int j = i + 1; j < currentIndex && j < rates_total; j++)
         {
            if(isBullishOB && low[j] <= ob.high && low[j] >= ob.low)
            {
               ob.tested = true;
               if(close[j] >= ob.high) ob.mitigated = true;
               break;
            }
            if(!isBullishOB && high[j] >= ob.low && high[j] <= ob.high)
            {
               ob.tested = true;
               if(close[j] <= ob.low) ob.mitigated = true;
               break;
            }
         }
         
         int size = ArraySize(g_orderBlocks);
         ArrayResize(g_orderBlocks, size + 1);
         g_orderBlocks[size] = ob;
         foundCount++;
      }
   }
}

// Detect Breaker Blocks - failed order blocks that become new S/R
void DetectBreakerBlocks(const datetime &time[], const double &high[], const double &low[], const double &close[], 
                         const double &atr[], int rates_total, int currentIndex)
{
   ArrayResize(g_breakerBlocks, 0);
   int foundCount = 0;
   
   for(int i = currentIndex - 2; i >= MathMax(0, currentIndex - InpVisualLookbackBars) && foundCount < 6; i--)
   {
      if(i < 5) continue;
      
      double range = high[i] - low[i];
      if(range <= 0) continue;
      
      // Look for strong break of structure followed by failure
      bool strongBreak = range >= atr[i] * g_displacementATR * 1.2;
      if(!strongBreak) continue;
      
      // Check if this broke previous structure
      int prevSH = FindLastSwingHigh(high, rates_total, i);
      int prevSL = FindLastSwingLow(low, rates_total, i);
      
      bool brokeUp = (prevSH >= 0 && high[i] > high[prevSH] && close[i] < high[prevSH]);
      bool brokeDown = (prevSL >= 0 && low[i] < low[prevSL] && close[i] > low[prevSL]);
      
      if(!brokeUp && !brokeDown) continue;
      
      // Check for failure in next few bars
      bool failed = false;
      for(int j = i + 1; j < MathMin(i + 5, rates_total); j++)
      {
         if(brokeUp && close[j] < low[i])
         {
            failed = true;
            break;
         }
         if(brokeDown && close[j] > high[i])
         {
            failed = true;
            break;
         }
      }
      
      if(failed)
      {
         BreakerBlock bb;
         bb.time = time[i];
         bb.price = close[i];
         bb.high = high[i];
         bb.low = low[i];
         bb.isBullish = brokeDown; // breaker after failed down-break is bullish
         bb.strength = (int)(range / atr[i] * 50);
         
         int size = ArraySize(g_breakerBlocks);
         ArrayResize(g_breakerBlocks, size + 1);
         g_breakerBlocks[size] = bb;
         foundCount++;
      }
   }
}

// Calculate Premium/Discount zones using Fibonacci
void CalculatePremiumDiscount(const datetime &time[], const double &high[], const double &low[], int rates_total, int currentIndex)
{
   ArrayResize(g_oteZones, 0);
   
   // Find recent range
   int lookback = MathMin(InpRangeLookback, currentIndex);
   if(lookback < 2) return;
   
   double highest = high[currentIndex];
   double lowest = low[currentIndex];
   int highIndex = currentIndex;
   int lowIndex = currentIndex;
   
   for(int i = currentIndex; i >= MathMax(0, currentIndex - lookback); i--)
   {
      if(high[i] > highest)
      {
         highest = high[i];
         highIndex = i;
      }
      if(low[i] < lowest)
      {
         lowest = low[i];
         lowIndex = i;
      }
   }
   
   double range = highest - lowest;
   if(range <= 0) return;
   
   // Determine trend direction for proper premium/discount
   bool uptrend = (highIndex < lowIndex); // High came after low
   
   if(uptrend)
   {
      // In uptrend: discount zone is lower (buying opportunity), premium is higher (selling opportunity)
      OTEZone discountZone;
      discountZone.startTime = time[currentIndex - lookback];
      discountZone.endTime = time[currentIndex];
      discountZone.isBullish = true;
      discountZone.fibLevel = 0.5;
      
      // Discount: 50-62% retracement (buying zone in uptrend)
      discountZone.upper = lowest + range * 0.62;
      discountZone.lower = lowest + range * 0.50;
      
      int size = ArraySize(g_oteZones);
      ArrayResize(g_oteZones, size + 1);
      g_oteZones[size] = discountZone;
      
      // Premium: 62-79% extension or above
      OTEZone premiumZone;
      premiumZone.startTime = time[currentIndex - lookback];
      premiumZone.endTime = time[currentIndex];
      premiumZone.isBullish = false;
      premiumZone.fibLevel = 0.62;
      
      premiumZone.upper = lowest + range * 0.79;
      premiumZone.lower = lowest + range * 0.62;
      
      ArrayResize(g_oteZones, size + 2);
      g_oteZones[size + 1] = premiumZone;
   }
   else
   {
      // In downtrend: premium zone is higher (selling opportunity), discount is lower
      OTEZone premiumZone;
      premiumZone.startTime = time[currentIndex - lookback];
      premiumZone.endTime = time[currentIndex];
      premiumZone.isBullish = false;
      premiumZone.fibLevel = 0.5;
      
      // Premium: 50-62% retracement (selling zone in downtrend)
      premiumZone.upper = highest - range * 0.50;
      premiumZone.lower = highest - range * 0.62;
      
      int size = ArraySize(g_oteZones);
      ArrayResize(g_oteZones, size + 1);
      g_oteZones[size] = premiumZone;
      
      // Discount: below 62%
      OTEZone discountZone;
      discountZone.startTime = time[currentIndex - lookback];
      discountZone.endTime = time[currentIndex];
      discountZone.isBullish = true;
      discountZone.fibLevel = 0.62;
      
      discountZone.upper = highest - range * 0.62;
      discountZone.lower = highest - range * 0.79;
      
      ArrayResize(g_oteZones, size + 2);
      g_oteZones[size + 1] = discountZone;
   }
}

// Detect Propulsion Blocks - aggressive expansion markers
void DetectPropulsionBlocks(const datetime &time[], const double &open[], const double &high[], const double &low[], 
                            const double &close[], const double &atr[], int rates_total, int currentIndex)
{
   ArrayResize(g_propulsionBlocks, 0);
   
   for(int i = currentIndex - 2; i >= MathMax(0, currentIndex - InpVisualLookbackBars); i--)
   {
      if(i < 2) continue;
      if(atr[i] <= 0) continue;
      
      double range = high[i] - low[i];
      double body = MathAbs(close[i] - open[i]);
      if(range <= 0) continue;
      
      // Propulsion block criteria: very strong move
      if(range < atr[i] * InpPropulsionMinATR) continue;
      if(body / range < 0.6) continue; // Strong body required
      
      // Check if this breaks previous structure aggressively
      bool isBullish = close[i] > open[i];
      bool aggressiveBreak = false;
      
      if(isBullish)
      {
         int prevSH = FindLastSwingHigh(high, rates_total, i);
         if(prevSH >= 0 && close[i] > high[prevSH] + atr[i] * 0.3)
            aggressiveBreak = true;
      }
      else
      {
         int prevSL = FindLastSwingLow(low, rates_total, i);
         if(prevSL >= 0 && close[i] < low[prevSL] - atr[i] * 0.3)
            aggressiveBreak = true;
      }
      
      if(!aggressiveBreak) continue;
      
      PropulsionBlock pb;
      pb.time = time[i];
      pb.high = high[i];
      pb.low = low[i];
      pb.close = close[i];
      pb.isBullish = isBullish;
      pb.strength = range / atr[i];
      
      int size = ArraySize(g_propulsionBlocks);
      ArrayResize(g_propulsionBlocks, size + 1);
      g_propulsionBlocks[size] = pb;
   }
}

//+------------------------------------------------------------------+
//| Update HTF Bias                                                  |
//+------------------------------------------------------------------+
void UpdateHTFBias(const double &close[], int currentIndex)
{
   if(!InpUseHTFBias || g_biasHandle == INVALID_HANDLE)
   {
      g_htfBiasDirection = 0;
      return;
   }
   
   double biasBuffer[];
   if(CopyBuffer(g_biasHandle, 0, 0, 3, biasBuffer) <= 0)
   {
      g_htfBiasDirection = 0;
      return;
   }
   
   ArraySetAsSeries(biasBuffer, false);
   
   double currentPrice = close[currentIndex];
   double maValue = biasBuffer[0];
   
   g_htfBiasValue = maValue;
   
   // Determine bias direction
   double threshold = maValue * 0.001; // 0.1% threshold
   if(currentPrice > maValue + threshold)
      g_htfBiasDirection = 1;  // Bullish
   else if(currentPrice < maValue - threshold)
      g_htfBiasDirection = -1; // Bearish
   else
      g_htfBiasDirection = 0;  // Neutral
}

//+------------------------------------------------------------------+
//| Update Market Structure Bias                                     |
//+------------------------------------------------------------------+
void UpdateStructureBias(const datetime &time[], const double &high[], const double &low[], const double &close[], int rates_total, int currentIndex)
{
   int lastSH = FindLastSwingHigh(high, rates_total, currentIndex);
   int lastSL = FindLastSwingLow(low, rates_total, currentIndex);
   
   if(lastSH >= 0 && lastSL >= 0)
   {
      double swingHigh = high[lastSH];
      double swingLow = low[lastSL];
      
      // Check for BOS (Break of Structure)
      if(close[currentIndex] > swingHigh && g_lastBOS_Price <= swingHigh)
      {
         g_structureBias = 1; // Bullish BOS
         g_lastBOS_Time = time[currentIndex];
         g_lastBOS_Price = close[currentIndex];
      }
      else if(close[currentIndex] < swingLow && g_lastBOS_Price >= swingLow)
      {
         g_structureBias = -1; // Bearish BOS
         g_lastBOS_Time = time[currentIndex];
         g_lastBOS_Price = close[currentIndex];
      }
      
      // Check for CHOCH (Change of Character)
      if(g_prevSwingHighTime > 0 && g_prevSwingLowTime > 0)
      {
         bool bullishCHOCH = (close[currentIndex] > g_prevSwingHighPrice) && (g_structureBias <= 0);
         bool bearishCHOCH = (close[currentIndex] < g_prevSwingLowPrice) && (g_structureBias >= 0);
         
         if(bullishCHOCH) g_structureBias = 1;
         if(bearishCHOCH) g_structureBias = -1;
      }
   }
   
   // Update previous swings
   if(lastSH >= 0 && lastSH != g_lastSwingHighTime)
   {
      g_prevSwingHighTime = g_lastSwingHighTime;
      g_prevSwingHighPrice = g_lastSwingHighPrice;
   }
   if(lastSL >= 0 && lastSL != g_lastSwingLowTime)
   {
      g_prevSwingLowTime = g_lastSwingLowTime;
      g_prevSwingLowPrice = g_lastSwingLowPrice;
   }
}

//+------------------------------------------------------------------+
//| Check if price is in Premium or Discount zone                    |
//+------------------------------------------------------------------+
bool IsInPremium(const double &high[], const double &low[], int rates_total, int currentIndex, double price)
{
   if(!InpUsePremiumDiscount) return false;
   
   int lookback = MathMin(InpRangeLookback, currentIndex);
   double highest = high[currentIndex];
   double lowest = low[currentIndex];
   
   for(int i = currentIndex; i >= MathMax(0, currentIndex - lookback); i--)
   {
      highest = MathMax(highest, high[i]);
      lowest = MathMin(lowest, low[i]);
   }
   
   double range = highest - lowest;
   if(range <= 0) return false;
   
   double fib50 = lowest + range * 0.5;
   return price > fib50;
}

bool IsInDiscount(const double &high[], const double &low[], int rates_total, int currentIndex, double price)
{
   if(!InpUsePremiumDiscount) return false;
   
   int lookback = MathMin(InpRangeLookback, currentIndex);
   double highest = high[currentIndex];
   double lowest = low[currentIndex];
   
   for(int i = currentIndex; i >= MathMax(0, currentIndex - lookback); i--)
   {
      highest = MathMax(highest, high[i]);
      lowest = MathMin(lowest, low[i]);
   }
   
   double range = highest - lowest;
   if(range <= 0) return false;
   
   double fib50 = lowest + range * 0.5;
   return price < fib50;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   
   ApplyPreset();
   g_lastPreset = g_activePreset;
   
   g_atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle. Error: ", GetLastError());
      return INIT_FAILED;
   }
   
   if(InpUseHTFBias)
   {
      g_biasHandle = iMA(_Symbol, InpBiasTimeframe, InpBiasMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_biasHandle == INVALID_HANDLE)
      {
         Print("Failed to create HTF bias MA handle. Error: ", GetLastError());
         return INIT_FAILED;
      }
   }
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Advanced SMC Institutional Signals");
   
   // Arrays are initialized by ArrayResize in detection functions
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)   IndicatorRelease(g_atrHandle);
   if(g_biasHandle != INVALID_HANDLE)  IndicatorRelease(g_biasHandle);
   
   if(ObjectFind(0, g_statusObjectName) != -1)
      ObjectDelete(0, g_statusObjectName);
      
   // Clear all context objects and SMC objects from this indicator
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, g_contextPrefix) == 0 || StringFind(name, "SMC_") == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Main calculation function                                        |
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
   int minBars = MathMax(InpRangeLookback, InpStructureLookback) + InpSwingPivot * 2 + InpATRPeriod + 10;
   if(rates_total < minBars) 
   {
      UpdateStatusPanel("Waiting for more bars...", clrSilver);
      return 0;
   }

   if(InpPreset != g_lastPreset)
   {
      ApplyPreset();
      g_lastPreset = InpPreset;
   }

   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 0, rates_total, atr) <= 0)
   {
      UpdateStatusPanel("ATR not ready", clrTomato);
      return prev_calculated;
   }

   ArraySetAsSeries(atr, false);

   int start = (prev_calculated > 0) ? prev_calculated - 100 : minBars;
   start = MathMax(start, minBars);

   // Capture last structure swings for optional labels
   int latestSH = FindLastSwingHigh(high, rates_total, rates_total - 2);
   int latestSL = FindLastSwingLow(low, rates_total, rates_total - 2);
   if(latestSH >= 0)
   {
      g_lastSwingHighTime = time[latestSH];
      g_lastSwingHighPrice = high[latestSH];
   }
   if(latestSL >= 0)
   {
      g_lastSwingLowTime = time[latestSL];
      g_lastSwingLowPrice = low[latestSL];
   }

   // Clear future arrows
   for(int i = start; i < rates_total; i++)
   {
      BuyBuffer[i]  = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
   }

   int buySignals = 0, sellSignals = 0;
   int bestBuyScore = 0, bestSellScore = 0;
   datetime lastSignalTime = 0;

   // Detect essential SMC elements for current bar
   int currentBar = rates_total - 1;
   DetectOrderBlocks(time, open, high, low, close, atr, rates_total, currentBar);
   CalculatePremiumDiscount(time, high, low, rates_total, currentBar);
   
   // Update HTF bias
   UpdateHTFBias(close, currentBar);
   
   // Update structure bias
   UpdateStructureBias(time, high, low, close, rates_total, currentBar);

   for(int i = start; i < rates_total - 1 && !IsStopped(); i++)   // -1 to avoid repainting on current bar
   {
      if(!IsTradingSession(time[i])) continue;
      if(atr[i] <= 0) continue;

      int lastSH = FindLastSwingHigh(high, rates_total, i);
      int lastSL = FindLastSwingLow(low, rates_total, i);
      if(lastSH < 0 || lastSL < 0) continue;

      double swingHigh = high[lastSH];
      double swingLow  = low[lastSL];
      double atrVal    = atr[i];

      // Core conditions
      bool bullishSweep = low[i]  < swingLow  - atrVal * InpLiquiditySweepATR && close[i] > swingLow;
      bool bearishSweep = high[i] > swingHigh + atrVal * InpLiquiditySweepATR && close[i] < swingHigh;

      bool bullishBOS   = close[i] > swingHigh && close[i-1] <= swingHigh;
      bool bearishBOS   = close[i] < swingLow  && close[i-1] >= swingLow;

      bool bullishCHOCH = close[i] > high[i-1] && close[i-1] > open[i-1];
      bool bearishCHOCH = close[i] < low[i-1]  && close[i-1] < open[i-1];

      bool displacement = (high[i] - low[i]) >= atrVal * g_displacementATR && 
                         MathAbs(close[i] - open[i]) / (high[i] - low[i]) >= g_minBodyToRange;

      bool bullishFVG = (i >= 2) && low[i] > high[i-2] && (low[i] - high[i-2]) >= atrVal * g_minFVGSizeATR;
      bool bearishFVG = (i >= 2) && high[i] < low[i-2] && (low[i-2] - high[i]) >= atrVal * g_minFVGSizeATR;

      // Essential SMC conditions
      bool nearOrderBlock = false;
      bool inOTEZone = false;
      bool orderBlockBullish = false;
      bool orderBlockBearish = false;

      // Check proximity to advanced SMC elements
      for(int j = 0; j < ArraySize(g_orderBlocks); j++)
      {
         double obTolerance = atrVal * 0.5;
         if(MathAbs(close[i] - g_orderBlocks[j].price) <= obTolerance)
         {
            nearOrderBlock = true;
            if(g_orderBlocks[j].isBullish) orderBlockBullish = true;
            else orderBlockBearish = true;
            break;
         }
      }

      for(int j = 0; j < ArraySize(g_oteZones); j++)
      {
         if(close[i] >= g_oteZones[j].lower && close[i] <= g_oteZones[j].upper)
         {
            inOTEZone = true;
            break;
         }
      }

      // Enhanced scoring logic with advanced SMC concepts
      int buyScore  = 0, sellScore = 0;
      bool buySignal  = false, sellSignal = false;

      // Reversal signals
      if(g_allowReversal)
      {
         if(bullishSweep && (bullishBOS || bullishCHOCH)) 
         {
            buyScore += 50;
            if(nearOrderBlock && orderBlockBullish) buyScore += 15;
         }
         if(bearishSweep && (bearishBOS || bearishCHOCH)) 
         {
            sellScore += 50;
            if(nearOrderBlock && orderBlockBearish) sellScore += 15;
         }
      }

      // Continuation signals
      if(g_allowContinuation)
      {
         if(bullishBOS && (bullishFVG || displacement)) 
         {
            buyScore += 40;
         }
         if(bearishBOS && (bearishFVG || displacement)) 
         {
            sellScore += 40;
         }
      }

      // Advanced SMC scoring - directional
      if(nearOrderBlock)
      {
         if(orderBlockBullish) buyScore += 25;
         if(orderBlockBearish) sellScore += 25;
      }

      if(inOTEZone)
      {
         for(int j = 0; j < ArraySize(g_oteZones); j++)
         {
            if(close[i] >= g_oteZones[j].lower && close[i] <= g_oteZones[j].upper)
            {
               if(g_oteZones[j].isBullish) buyScore += 30;
               else sellScore += 30;
               break;
            }
         }
      }

      if(bullishFVG) buyScore += 12;
      if(bearishFVG) sellScore += 12;

      if(displacement)
      {
         if(close[i] > open[i]) buyScore += 15;
         else                   sellScore += 15;
      }

      // Premium/Discount filter
      if(InpUsePremiumDiscount)
      {
         if(IsInDiscount(high, low, rates_total, i, close[i]))
            buyScore += 10;
         if(IsInPremium(high, low, rates_total, i, close[i]))
            sellScore += 10;
      }

      // HTF Bias filter
      if(InpUseHTFBias && g_htfBiasDirection != 0)
      {
         if(g_htfBiasDirection == 1) // HTF bullish
         {
            buyScore += 15;
            sellScore = MathMin(sellScore, 20); // Reduce sell score
         }
         else // HTF bearish
         {
            sellScore += 15;
            buyScore = MathMin(buyScore, 20); // Reduce buy score
         }
      }

      // Structure bias filter
      if(g_structureBias == 1) // Bullish structure
      {
         buyScore += 10;
      }
      else if(g_structureBias == -1) // Bearish structure
      {
         sellScore += 10;
      }

      // FVG + Displacement requirement
      if(InpRequireFVGOrDisplacement)
      {
         if(!bullishFVG && !displacement && buyScore > 0)
            buyScore = MathMax(0, buyScore - 15);
         if(!bearishFVG && !displacement && sellScore > 0)
            sellScore = MathMax(0, sellScore - 15);
      }

      // Avoid both buy and sell on same bar by keeping stronger signal only
      if(buyScore >= g_minScore && sellScore >= g_minScore)
      {
         if(buyScore > sellScore) 
            sellScore = 0;
         else if(sellScore > buyScore) 
            buyScore = 0;
         else
         {
            // Equal strength - suppress both to avoid conflicting arrows
            buyScore = 0;
            sellScore = 0;
         }
      }

      if(buyScore >= g_minScore && !HasRecentSignal(BuyBuffer, i, g_signalCooldownBars))
      {
         BuyBuffer[i] = low[i] - atrVal * InpArrowOffsetATR;
         buySignals++;
         bestBuyScore = MathMax(bestBuyScore, buyScore);
         lastSignalTime = time[i];
         buySignal = true;
      }

      if(sellScore >= g_minScore && !HasRecentSignal(SellBuffer, i, g_signalCooldownBars))
      {
         SellBuffer[i] = high[i] + atrVal * InpArrowOffsetATR;
         sellSignals++;
         bestSellScore = MathMax(bestSellScore, sellScore);
         lastSignalTime = time[i];
         sellSignal = true;
      }

      if(buySignal || sellSignal)
         SendSignalAlert(buySignal, time[i], buySignal ? buyScore : sellScore, close[i]);
   }

   // Status panel
   string biasStr = "";
   if(g_structureBias == 1) biasStr = " | Bias: BULL";
   else if(g_structureBias == -1) biasStr = " | Bias: BEAR";
   
   if(InpUseHTFBias)
   {
      if(g_htfBiasDirection == 1) biasStr += " | HTF: +";
      else if(g_htfBiasDirection == -1) biasStr += " | HTF: -";
   }

   string status = buySignals || sellSignals ?
                   StringFormat("SMC | Buy:%d(%d) Sell:%d(%d)%s | Last: %s", 
                                buySignals, bestBuyScore, sellSignals, bestSellScore, biasStr,
                                TimeToString(lastSignalTime, TIME_DATE | TIME_MINUTES)) :
                   "SMC | No signals" + biasStr;

   UpdateStatusPanel(status, (buySignals >= sellSignals) ? clrLime : clrTomato);

   // Draw essential SMC elements
   DrawEssentialSMCElements(time, high, low, atr, rates_total, currentBar);

   return rates_total;
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool HasRecentSignal(const double &buffer[], int index, int cooldown)
{
   for(int i = MathMax(0, index - cooldown); i < index; i++)
      if(buffer[i] != EMPTY_VALUE) return true;
   return false;
}

void UpdateStatusPanel(string text, color clr)
{
   if(!InpShowStatusPanel)
   {
      if(ObjectFind(0, g_statusObjectName) != -1) ObjectDelete(0, g_statusObjectName);
      return;
   }
   
   if(ObjectFind(0, g_statusObjectName) == -1)
   {
      ObjectCreate(0, g_statusObjectName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_statusObjectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_statusObjectName, OBJPROP_XDISTANCE, 12);
      ObjectSetInteger(0, g_statusObjectName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, g_statusObjectName, OBJPROP_FONTSIZE, 9);
   }
   
   ObjectSetString(0, g_statusObjectName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_statusObjectName, OBJPROP_COLOR, clr);
}

void SendSignalAlert(bool isBuy, datetime time, int score, double price)
{
   if(!InpEnableAlerts) return;
   
   if(isBuy && g_lastBuyAlertTime == time) return;
   if(!isBuy && g_lastSellAlertTime == time) return;
   
   if(isBuy) g_lastBuyAlertTime = time;
   else      g_lastSellAlertTime = time;
   
   string biasInfo = "";
   if(g_structureBias == 1) biasInfo = " [Bullish Structure]";
   else if(g_structureBias == -1) biasInfo = " [Bearish Structure]";
   
   if(InpUseHTFBias)
   {
      if(g_htfBiasDirection == 1) biasInfo += " [HTF Bullish]";
      else if(g_htfBiasDirection == -1) biasInfo += " [HTF Bearish]";
   }
   
   Alert(_Symbol, " ", EnumToString(_Period), " | SMC ", isBuy ? "BUY" : "SELL",
         " | Score: ", score, " | Price: ", DoubleToString(price, _Digits), biasInfo);
}

//+------------------------------------------------------------------+
//| Visual Drawing Functions                                          |
//+------------------------------------------------------------------+

// FVG structure for drawing
struct FVGZone
{
   datetime startTime;
   datetime endTime;
   double top;
   double bottom;
   bool isBullish;
};

void DrawEssentialSMCElements(const datetime &time[], const double &high[], const double &low[], 
                              const double &atr[], int rates_total, int currentIndex)
{
   // Clear previous SMC objects (but not status panel)
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SMC_") == 0 && name != g_statusObjectName)
         ObjectDelete(0, name);
   }

   // Detect and draw FVG zones
   if(InpShowFVGZones)
   {
      FVGZone fvgZones[];
      int fvgCount = 0;
      int maxFVG = 12; // Limit FVG zones for performance
      
      for(int i = MathMax(2, currentIndex - InpVisualLookbackBars); i < currentIndex && fvgCount < maxFVG; i++)
      {
         if(atr[i] <= 0) continue;
         
         // Bullish FVG
         if(low[i] > high[i-2] && (low[i] - high[i-2]) >= atr[i] * g_minFVGSizeATR)
         {
            FVGZone fvg;
            fvg.startTime = time[i-2];
            fvg.endTime = time[i];
            fvg.top = low[i];
            fvg.bottom = high[i-2];
            fvg.isBullish = true;
            
            int size = ArraySize(fvgZones);
            ArrayResize(fvgZones, size + 1);
            fvgZones[size] = fvg;
            fvgCount++;
         }
         
         // Bearish FVG
         if(high[i] < low[i-2] && (low[i-2] - high[i]) >= atr[i] * g_minFVGSizeATR)
         {
            FVGZone fvg;
            fvg.startTime = time[i-2];
            fvg.endTime = time[i];
            fvg.top = low[i-2];
            fvg.bottom = high[i];
            fvg.isBullish = false;
            
            int size = ArraySize(fvgZones);
            ArrayResize(fvgZones, size + 1);
            fvgZones[size] = fvg;
            fvgCount++;
         }
      }
      
      // Draw FVG zones
      for(int i = 0; i < ArraySize(fvgZones); i++)
      {
         string objName = StringFormat("SMC_FVG_%d_%d", fvgZones[i].startTime, i);
         color fvgColor = fvgZones[i].isBullish ? C'220,255,220' : C'255,220,220'; // Light green/red
         
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                      fvgZones[i].startTime, fvgZones[i].bottom,
                      fvgZones[i].endTime, fvgZones[i].top);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, fvgColor);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
         ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, fvgColor);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         
         // Add FVG label
         string labelName = StringFormat("SMC_FVG_LABEL_%d_%d", fvgZones[i].startTime, i);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, fvgZones[i].startTime, fvgZones[i].top);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "FVG");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, fvgZones[i].isBullish ? clrGreen : clrRed);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
      }
   }

   // Draw Order Blocks (zones)
   if(InpShowOrderBlocks && ArraySize(g_orderBlocks) > 0)
   {
      for(int i = 0; i < ArraySize(g_orderBlocks); i++)
      {
         string objName = StringFormat("SMC_OB_%d_%d", g_orderBlocks[i].time, i);
         color borderColor = g_orderBlocks[i].isBullish ? clrGreen : clrRed;
         color fillColor = g_orderBlocks[i].isBullish ? C'200,255,200' : C'255,200,200'; // Light green/red
         
         // Use OBJ_RECTANGLE for zone display
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                      g_orderBlocks[i].time, g_orderBlocks[i].low,
                      g_orderBlocks[i].time + PeriodSeconds() * 3, g_orderBlocks[i].high);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
         ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, fillColor);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         
         // Add zone label
         string labelName = StringFormat("SMC_OB_LABEL_%d_%d", g_orderBlocks[i].time, i);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, g_orderBlocks[i].time, g_orderBlocks[i].high);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "Zone");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, borderColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
      }
   }

   // Draw OTE Zones
   if(InpShowOTEZones && ArraySize(g_oteZones) > 0)
   {
      for(int i = 0; i < ArraySize(g_oteZones); i++)
      {
         string objName = StringFormat("SMC_OTE_%d_%d", g_oteZones[i].startTime, i);
         color fillColor = g_oteZones[i].isBullish ? C'200,255,200' : C'255,200,200'; // Light green/red
         color borderColor = g_oteZones[i].isBullish ? clrGreen : clrRed;
         
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                      g_oteZones[i].startTime, g_oteZones[i].lower,
                      g_oteZones[i].endTime, g_oteZones[i].upper);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, borderColor);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
         ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, fillColor);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         
         // Add zone label
         string labelName = StringFormat("SMC_OTE_LABEL_%d_%d", g_oteZones[i].startTime, i);
         ObjectCreate(0, labelName, OBJ_TEXT, 0, g_oteZones[i].startTime, g_oteZones[i].upper);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "OTE");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, borderColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
      }
   }

   // Draw swing high/low labels
   if(InpShowStructureLabels)
   {
      if(g_lastSwingHighTime > 0)
      {
         string highLabel = "SMC_SWING_HIGH";
         if(ObjectFind(0, highLabel) != -1) ObjectDelete(0, highLabel);
         ObjectCreate(0, highLabel, OBJ_TEXT, 0, g_lastSwingHighTime, g_lastSwingHighPrice);
         ObjectSetString(0, highLabel, OBJPROP_TEXT, "SH");
         ObjectSetInteger(0, highLabel, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, highLabel, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, highLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
      if(g_lastSwingLowTime > 0)
      {
         string lowLabel = "SMC_SWING_LOW";
         if(ObjectFind(0, lowLabel) != -1) ObjectDelete(0, lowLabel);
         ObjectCreate(0, lowLabel, OBJ_TEXT, 0, g_lastSwingLowTime, g_lastSwingLowPrice);
         ObjectSetString(0, lowLabel, OBJPROP_TEXT, "SL");
         ObjectSetInteger(0, lowLabel, OBJPROP_COLOR, clrOrangeRed);
         ObjectSetInteger(0, lowLabel, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lowLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      }
   }
}
//+------------------------------------------------------------------+