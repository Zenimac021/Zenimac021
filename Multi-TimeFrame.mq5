//+------------------------------------------------------------------+
//|                Multi-TimeFrame.mq5                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
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
#define OBJ_PREFIX "MTF_Dash_"

//---- Timeframes ----
const ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
const string timeframeLabels[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1"};

enum CornerPosition
{
   TOP_LEFT = 0,
   TOP_RIGHT,
   BOTTOM_LEFT,
   BOTTOM_RIGHT
};

enum AlertMode
{
   ALERT_NONE = 0,     // No alerts
   ALERT_POPUP,        // Popup only
   ALERT_SOUND,        // Sound only
   ALERT_PUSH,         // Push notification only
   ALERT_ALL           // All alert types
};

//---- Inputs ----
input group "Timeframe Display"
input bool Show_M1  = true;
input bool Show_M5  = true;
input bool Show_M15 = true;
input bool Show_M30 = true;
input bool Show_H1  = true;
input bool Show_H4  = true;
input bool Show_D1  = true;
input bool Show_W1  = true;

input group "Visual Settings"
input color UptrendColor         = clrGreen;
input color DowntrendColor       = clrRed;
input color NeutralColor         = clrGray;
input color StrongUptrendColor   = clrLime;
input color StrongDowntrendColor = clrCrimson;
input color ErrorColor           = clrDarkGray;
input color DisabledColor        = clrBlack;
input int   BoxWidth             = 27;
input int   BoxHeight            = 27;
input int   HorizontalSpacing    = 5;

input group "Position Settings"
input CornerPosition PositionCorner = TOP_LEFT;
input int X_Offset = 600;   // X Distance from Corner
input int Y_Offset = 20;    // Y Distance from Corner

input string DashboardTitle  = "MTF Trend Dashboard";
input int    TitleFontSize   = 12;
input color  TitleColor      = clrBlack;
input color  BackgroundColor = clrDarkGray;

input group "Trend Settings"
input ENUM_MA_METHOD TrendMAMethod   = MODE_EMA;
input int    FastMAPeriod            = 5;
input int    SlowMAPeriod            = 13;
input bool   UseClosedBarSignals      = true;  // Use closed bars for stable dashboard signals
input bool   UseRSIFilter           = true;
input int    RSIPeriod               = 10;
input double RSIOverbought           = 70.0;
input double RSIOversold             = 30.0;
input int    ADXPeriod               = 12;
input double ADXThreshold            = 20.0;
input double StrongTrendThreshold    = 0.005;
input bool   UseMACDFilter          = true;  // Use MACD histogram as extra confirmation
input int    MACDFastEMA            = 4;
input int    MACDSlowEMA            = 9;
input int    MACDSignalSMA          = 3;
input double MinStrongScore          = 70.0;   // Signal score required for strong trend color

input group "Confluence"
input bool   ShowConfluenceBar      = true;   // Show overall bias summary bar
input color  ConfluenceBullColor    = clrLime;
input color  ConfluenceBearColor    = clrCrimson;
input color  ConfluenceNeutralColor = clrGray;
input bool   AlertOnConfluence      = false;  // Alert when enough timeframes align
input int    ConfluenceThreshold    = 5;      // Aligned timeframes required for confluence alert

input group "Refresh & Alerts"
input bool      OptimizeRefresh  = true;
input int       RefreshSeconds   = 30;
input AlertMode AlertType        = ALERT_NONE;
input string    AlertSoundFile   = "alert.wav"; // Sound file for ALERT_SOUND / ALERT_ALL
input int       AlertCooldownSeconds = 300;      // Minimum seconds between repeated alerts

//---- Structures ----
struct TimeframeData
{
   bool     enabled;
   bool     available;
   int      fastHandle;
   int      slowHandle;
   int      rsiHandle;
   int      adxHandle;
   int      macdHandle;
   datetime lastUpdate;
   datetime lastAlert;
   color    lastColor;
   int      lastDir;          // last trend direction for confluence
   double   lastStrength;     // last computed strength %
   double   lastScore;        // signal quality score 0-100
   bool     hasSignal;
   string   boxName;
   string   labelName;
   string   rsiDotName;
};

TimeframeData tfData[NUM_TIMEFRAMES];
int StartX, StartY, BackgroundWidth, BackgroundHeight;
datetime lastRefresh  = 0;
bool     isFirstCalc  = true;   // ensures first-tick update with OptimizeRefresh
bool     isMinimized  = false;  // toggle collapse/expand
ENUM_BASE_CORNER BaseCorner = CORNER_LEFT_UPPER;
int      lastConfluenceDir = 0;
datetime lastConfluenceAlert = 0;

double indicatorBuffer[];

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, indicatorBuffer, INDICATOR_DATA);
   ArraySetAsSeries(indicatorBuffer, true);

   // --- Input validation ---
   if(ValidatePeriod(FastMAPeriod, "Fast MA Period") != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
   if(ValidatePeriod(SlowMAPeriod, "Slow MA Period") != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
   if(ValidatePeriod(RSIPeriod,    "RSI Period")     != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
   if(ValidatePeriod(ADXPeriod,    "ADX Period")     != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
   ValidateMAPeriods(FastMAPeriod, SlowMAPeriod, "Fast MA", "Slow MA");

   if(MinStrongScore < 0.0 || MinStrongScore > 100.0)
   {
      Print("Error: MinStrongScore must be between 0 and 100");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(AlertCooldownSeconds < 0)
   {
      Print("Error: AlertCooldownSeconds must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(ConfluenceThreshold < 1 || ConfluenceThreshold > NUM_TIMEFRAMES)
   {
      Print("Error: ConfluenceThreshold must be between 1 and ", NUM_TIMEFRAMES);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(RSIOverbought <= RSIOversold)
      Print("WARNING: RSI Overbought (", RSIOverbought, ") should be greater than Oversold (", RSIOversold, ")");

   if(UseMACDFilter)
   {
      if(ValidatePeriod(MACDFastEMA,   "MACD Fast EMA")   != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
      if(ValidatePeriod(MACDSlowEMA,   "MACD Slow EMA")   != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
      if(ValidatePeriod(MACDSignalSMA, "MACD Signal SMA") != INIT_SUCCEEDED) return INIT_PARAMETERS_INCORRECT;
      if(MACDFastEMA >= MACDSlowEMA)
         Print("WARNING: MACD Fast EMA should be less than Slow EMA");
   }

   bool show[] = {Show_M1, Show_M5, Show_M15, Show_M30, Show_H1, Show_H4, Show_D1, Show_W1};
   int successCount = 0;

   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      tfData[i].enabled   = show[i];
      tfData[i].available = false;
      tfData[i].fastHandle = tfData[i].slowHandle = tfData[i].rsiHandle = tfData[i].adxHandle = tfData[i].macdHandle = INVALID_HANDLE;
      tfData[i].lastColor    = NeutralColor;
      tfData[i].lastDir      = 0;
      tfData[i].lastStrength = 0.0;
      tfData[i].lastScore    = 0.0;
      tfData[i].lastAlert    = 0;
      tfData[i].lastUpdate   = 0;
      tfData[i].hasSignal    = false;
      tfData[i].boxName      = OBJ_PREFIX + timeframeLabels[i] + "_Box";
      tfData[i].labelName    = OBJ_PREFIX + timeframeLabels[i] + "_Label";
      tfData[i].rsiDotName   = OBJ_PREFIX + timeframeLabels[i] + "_RSIDot";

      if(!tfData[i].enabled) continue;

      tfData[i].fastHandle = iMA(_Symbol, timeframes[i], FastMAPeriod, 0, TrendMAMethod, PRICE_CLOSE);
      tfData[i].slowHandle = iMA(_Symbol, timeframes[i], SlowMAPeriod, 0, TrendMAMethod, PRICE_CLOSE);
      tfData[i].rsiHandle  = iRSI(_Symbol, timeframes[i], RSIPeriod, PRICE_CLOSE);
      tfData[i].adxHandle  = iADX(_Symbol, timeframes[i], ADXPeriod);

      bool handlesOk =
         ValidateHandle(tfData[i].fastHandle, "Fast MA " + timeframeLabels[i]) == INIT_SUCCEEDED &&
         ValidateHandle(tfData[i].slowHandle, "Slow MA " + timeframeLabels[i]) == INIT_SUCCEEDED &&
         ValidateHandle(tfData[i].rsiHandle,  "RSI "     + timeframeLabels[i]) == INIT_SUCCEEDED &&
         ValidateHandle(tfData[i].adxHandle,  "ADX "     + timeframeLabels[i]) == INIT_SUCCEEDED;

      if(UseMACDFilter)
      {
         tfData[i].macdHandle = iMACD(_Symbol, timeframes[i], MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE);
         handlesOk = handlesOk && ValidateHandle(tfData[i].macdHandle, "MACD " + timeframeLabels[i]) == INIT_SUCCEEDED;
      }

      if(handlesOk)
      {
         tfData[i].available = true;
         successCount++;
      }
   }

   if(successCount == 0)
   {
      Print("ERROR: No timeframes successfully initialized");
      return INIT_FAILED;
   }

   isFirstCalc = true;
   isMinimized = false;
   lastConfluenceDir = 0;
   lastConfluenceAlert = 0;
   CalcPositions();
   DeleteObjectsByPrefix(OBJ_PREFIX);
   CreateObjects();
   ChartRedraw();

   if(OptimizeRefresh)
   {
      int effectiveRefresh = MathMax(RefreshSeconds, 1);
      if(RefreshSeconds <= 0)
         Print("WARNING: RefreshSeconds must be >0 when OptimizeRefresh is enabled. Using 1.");
      if(!EventSetTimer(effectiveRefresh))
         Print("WARNING: Failed to set timer, using OnCalculate refresh only");
   }

   Print("MTF Dashboard v2.0 initialized with ", successCount, "/", NUM_TIMEFRAMES, " timeframes");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| De-initialisation                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      ReleaseHandle(tfData[i].fastHandle);
      ReleaseHandle(tfData[i].slowHandle);
      ReleaseHandle(tfData[i].rsiHandle);
      ReleaseHandle(tfData[i].adxHandle);
      ReleaseHandle(tfData[i].macdHandle);

      ObjectDelete(0, tfData[i].boxName);
      ObjectDelete(0, tfData[i].labelName);
      ObjectDelete(0, tfData[i].rsiDotName);
   }
   ObjectDelete(0, OBJ_PREFIX + "BG");
   ObjectDelete(0, OBJ_PREFIX + "Title");
   ObjectDelete(0, OBJ_PREFIX + "ConfBG");
   ObjectDelete(0, OBJ_PREFIX + "ConfLabel");
   ObjectDelete(0, OBJ_PREFIX + "ConfArrow");
   EventKillTimer();
   Print("MTF Dashboard deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Layout calculations                                              |
//+------------------------------------------------------------------+
void CalcPositions()
{
   int count = 0;
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
      if(tfData[i].enabled) count++;

   BackgroundWidth  = count * (BoxWidth + HorizontalSpacing) - HorizontalSpacing + 20;
   BackgroundHeight = BoxHeight + 50;
   if(ShowConfluenceBar)
      BackgroundHeight += 22;

   switch(PositionCorner)
   {
      case TOP_LEFT:     BaseCorner = CORNER_LEFT_UPPER;  break;
      case TOP_RIGHT:    BaseCorner = CORNER_RIGHT_UPPER; break;
      case BOTTOM_LEFT:  BaseCorner = CORNER_LEFT_LOWER;  break;
      case BOTTOM_RIGHT: BaseCorner = CORNER_RIGHT_LOWER; break;
   }

   StartX = X_Offset;
   StartY = Y_Offset;
}

//+------------------------------------------------------------------+
//| Create all dashboard objects                                     |
//+------------------------------------------------------------------+
void CreateObjects()
{
   bool isBottom = (BaseCorner == CORNER_LEFT_LOWER || BaseCorner == CORNER_RIGHT_LOWER);
   bool isRight  = (BaseCorner == CORNER_RIGHT_UPPER || BaseCorner == CORNER_RIGHT_LOWER);

   // --- Background ---
   ObjectCreate(0, OBJ_PREFIX + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_CORNER, BaseCorner);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_XDISTANCE, isRight ? StartX + BackgroundWidth : StartX);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_YDISTANCE, StartY);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_XSIZE, BackgroundWidth);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_YSIZE, BackgroundHeight);
   ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_BGCOLOR, BackgroundColor);

   // --- Title ---
   // For bottom corners the title should appear at the far end of the BG
   // (visually at the top of the dashboard), not near the corner edge.
   int titleY = isBottom ? StartY + BackgroundHeight - 20 : StartY + 20;
   int titleX = isRight  ? StartX + BackgroundWidth / 2   : StartX + BackgroundWidth / 2;

   ObjectCreate(0, OBJ_PREFIX + "Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_CORNER, BaseCorner);
   ObjectSetString (0, OBJ_PREFIX + "Title", OBJPROP_TEXT, DashboardTitle);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_XDISTANCE, titleX);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_YDISTANCE, titleY);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_COLOR, TitleColor);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_FONTSIZE, TitleFontSize);
   ObjectSetInteger(0, OBJ_PREFIX + "Title", OBJPROP_ANCHOR, ANCHOR_CENTER);

   // --- Timeframe boxes ---
   // For bottom corners, boxes are closer to the corner edge; title is farther.
   int boxBaseY = isBottom ? StartY + 10 : StartY + 43;
   if(ShowConfluenceBar && isBottom)
      boxBaseY += 22;

   int idx = 0;
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled) continue;

      int x_pos;
      if(!isRight)
         x_pos = StartX + 9 + idx * (BoxWidth + HorizontalSpacing);
      else
         x_pos = StartX + BackgroundWidth - 9 - BoxWidth - idx * (BoxWidth + HorizontalSpacing);

      int y_pos = boxBaseY;

      // Box
      ObjectCreate(0, tfData[i].boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_CORNER, BaseCorner);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_XDISTANCE, x_pos);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_YDISTANCE, y_pos);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_XSIZE, BoxWidth);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_YSIZE, BoxHeight);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, tfData[i].available ? NeutralColor : DisabledColor);

      // Label
      ObjectCreate(0, tfData[i].labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_CORNER, BaseCorner);
      ObjectSetString (0, tfData[i].labelName, OBJPROP_TEXT, timeframeLabels[i]);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_XDISTANCE, x_pos + BoxWidth / 2);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_YDISTANCE, y_pos + BoxHeight / 2);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, tfData[i].labelName, OBJPROP_FONTSIZE, 8);

      // RSI dot
      int dotY;
      ENUM_ANCHOR_POINT dotAnchor;
      if(isBottom)
      {
         dotY = y_pos + BoxHeight + 5;
         dotAnchor = ANCHOR_UPPER;
      }
      else
      {
         dotY = y_pos - 5;
         dotAnchor = ANCHOR_LOWER;
      }

      ObjectCreate(0, tfData[i].rsiDotName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_CORNER, BaseCorner);
      ObjectSetString (0, tfData[i].rsiDotName, OBJPROP_TEXT, "\x25CF");
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_XDISTANCE, x_pos + BoxWidth / 2);
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_YDISTANCE, dotY);
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_COLOR, clrNONE);
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_ANCHOR, dotAnchor);
      ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_FONTSIZE, 8);

      idx++;
   }

   // --- Confluence summary bar ---
   if(ShowConfluenceBar)
      CreateConfluenceObjects(isBottom, isRight);
}

//+------------------------------------------------------------------+
//| Create confluence bar objects                                    |
//+------------------------------------------------------------------+
void CreateConfluenceObjects(bool isBottom, bool isRight)
{
   int confY = isBottom ? StartY + 2 : StartY + BackgroundHeight - 20;
   int confX = isRight  ? StartX + BackgroundWidth : StartX;

   ObjectCreate(0, OBJ_PREFIX + "ConfBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_CORNER, BaseCorner);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_XDISTANCE, confX);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_YDISTANCE, confY);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_XSIZE, BackgroundWidth);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_YSIZE, 18);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfBG", OBJPROP_BGCOLOR, clrBlack);

   int labelX = isRight ? StartX + BackgroundWidth / 2 : StartX + BackgroundWidth / 2;
   ObjectCreate(0, OBJ_PREFIX + "ConfLabel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_CORNER, BaseCorner);
   ObjectSetString (0, OBJ_PREFIX + "ConfLabel", OBJPROP_TEXT, "Confluence: ---");
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_YDISTANCE, confY + 9);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_FONTSIZE, 8);

   int arrowX = isRight ? StartX + BackgroundWidth - 8 : StartX + 10;
   ObjectCreate(0, OBJ_PREFIX + "ConfArrow", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_CORNER, BaseCorner);
   ObjectSetString (0, OBJ_PREFIX + "ConfArrow", OBJPROP_TEXT, "-");
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_XDISTANCE, arrowX);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_YDISTANCE, confY + 9);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(ArraySize(indicatorBuffer) > 0)
      indicatorBuffer[0] = 0.0;

   if(!OptimizeRefresh || isFirstCalc)
   {
      UpdateAll();
      isFirstCalc = false;
   }
   return rates_total;
}

//+------------------------------------------------------------------+
void OnTimer() { UpdateAll(); }

//+------------------------------------------------------------------+
//| Master update routine                                            |
//+------------------------------------------------------------------+
void UpdateAll()
{
   if(isMinimized) return;

   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(tfData[i].enabled && tfData[i].available)
         UpdateBox(i);
   }

   if(ShowConfluenceBar)
      UpdateConfluence();

   lastRefresh = TimeCurrent();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update a single timeframe box                                    |
//+------------------------------------------------------------------+
void UpdateBox(int i)
{
   // First check how many bars we have available
   int barsTotal = iBars(_Symbol, timeframes[i]);
   if(barsTotal <= 0) return;

   // Determine which bar to use, fallback to bar 0 if bar 1 isn't available
   int signalBar = UseClosedBarSignals ? 1 : 0;
   if(signalBar >= barsTotal)
      signalBar = 0;

   datetime currentBarTime = iTime(_Symbol, timeframes[i], signalBar);
   if(currentBarTime == 0) return;

   double buf[];

   if(tfData[i].fastHandle == INVALID_HANDLE || tfData[i].slowHandle == INVALID_HANDLE ||
      tfData[i].rsiHandle  == INVALID_HANDLE || tfData[i].adxHandle  == INVALID_HANDLE)
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, ErrorColor);
      return;
   }

   int copyErr = 0;
   if(!SafeCopyBuffer(tfData[i].fastHandle, 0, signalBar, 1, buf, "Fast MA " + timeframeLabels[i], copyErr))
   { SetBoxCopyError(i, copyErr); return; }
   double fast = buf[0];

   if(!SafeCopyBuffer(tfData[i].slowHandle, 0, signalBar, 1, buf, "Slow MA " + timeframeLabels[i], copyErr))
   { SetBoxCopyError(i, copyErr); return; }
   double slow = buf[0];

   if(!SafeCopyBuffer(tfData[i].rsiHandle, 0, signalBar, 1, buf, "RSI " + timeframeLabels[i], copyErr))
   { SetBoxCopyError(i, copyErr); return; }
   double rsi = buf[0];

   if(!SafeCopyBuffer(tfData[i].adxHandle, 0, signalBar, 1, buf, "ADX " + timeframeLabels[i], copyErr))
   { SetBoxCopyError(i, copyErr); return; }
   double adx = buf[0];

   // Optional MACD histogram
   double macdHist = 0.0;
   if(UseMACDFilter && tfData[i].macdHandle != INVALID_HANDLE)
   {
      // buffer 0 = MACD line, buffer 1 = signal line
      double macdLine[], signalLine[];
      if(!SafeCopyBuffer(tfData[i].macdHandle, 0, signalBar, 1, macdLine, "MACD Line " + timeframeLabels[i], copyErr))
      { SetBoxCopyError(i, copyErr); return; }
      if(!SafeCopyBuffer(tfData[i].macdHandle, 1, signalBar, 1, signalLine, "MACD Signal " + timeframeLabels[i], copyErr))
      { SetBoxCopyError(i, copyErr); return; }
      macdHist = macdLine[0] - signalLine[0];
   }

   // --- Tooltip (use symbol digits for proper formatting) ---
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string maFmt = "%." + IntegerToString(digits) + "f";
   string tooltip = StringFormat("%s Details:\nBar: %s\nRSI: %.2f\nADX: %.2f\nFast MA: " + maFmt + "\nSlow MA: " + maFmt,
                                 timeframeLabels[i], UseClosedBarSignals ? "Closed" : "Live", rsi, adx, fast, slow);
   if(UseMACDFilter)
      tooltip += StringFormat("\nMACD Hist: " + maFmt, macdHist);
   ObjectSetString(0, tfData[i].boxName, OBJPROP_TOOLTIP, tooltip);

   // --- Highlight current chart timeframe ---
   if(timeframes[i] == Period())
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BORDER_COLOR, clrWhite);
   }
   else
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BORDER_COLOR, clrNONE);
   }

   // --- Division-by-zero guard (instrument-adaptive) ---
   if(slow == 0.0)
   {
      ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, ErrorColor);
      return;
   }

   int dir = (fast > slow) ? 1 : (fast < slow) ? -1 : 0;
   double strength = MathAbs((fast - slow) / slow);

   // --- MACD confirmation ---
   bool macdConfirm = true;
   if(UseMACDFilter)
      macdConfirm = (dir > 0 && macdHist > 0) || (dir < 0 && macdHist < 0) || dir == 0;

   // --- RSI filter ---
   bool rsiConfirm      = true;
   bool notOverExtended = true;
   bool rsiFilterPassing = true;
   if(UseRSIFilter)
   {
      rsiConfirm      = (dir > 0 && rsi > 50) || (dir < 0 && rsi < 50) || dir == 0;
      notOverExtended = (dir > 0 && rsi < RSIOverbought) || (dir < 0 && rsi > RSIOversold) || dir == 0;
      rsiFilterPassing = rsiConfirm && notOverExtended;
   }

   // --- RSI dot ---
   color dotColor = clrNONE;
   if(rsiFilterPassing)
   {
      if(dir > 0) dotColor = StrongUptrendColor;
      else if(dir < 0) dotColor = StrongDowntrendColor;
   }
   ObjectSetInteger(0, tfData[i].rsiDotName, OBJPROP_COLOR, dotColor);

   // --- Strength classification ---
   bool strong = strength > StrongTrendThreshold &&
                 adx > ADXThreshold &&
                 rsiConfirm && notOverExtended && macdConfirm;

   double score = CalculateSignalScore(dir, strength, adx, rsi, macdHist, rsiConfirm, notOverExtended, macdConfirm);
   strong = strong && score >= MinStrongScore;
   tooltip += StringFormat("\nScore: %.0f/100", score);
   ObjectSetString(0, tfData[i].boxName, OBJPROP_TOOLTIP, tooltip);

   color newColor;
   if(dir > 0)
      newColor = strong ? StrongUptrendColor : UptrendColor;
   else if(dir < 0)
      newColor = strong ? StrongDowntrendColor : DowntrendColor;
   else
      newColor = NeutralColor;

   // --- Alerts on trend change ---
   if(tfData[i].hasSignal && newColor != tfData[i].lastColor && AlertType != ALERT_NONE && CanFireAlert(tfData[i].lastAlert))
   {
      string msg = _Symbol + " " + timeframeLabels[i] + " trend: " +
                   (dir > 0 ? "UP" : dir < 0 ? "DOWN" : "NEUTRAL") +
                   " | Strength: " + DoubleToString(strength * 100, 1) + "%" +
                   " | ADX: " + DoubleToString(adx, 1) +
                   " | Score: " + DoubleToString(score, 0);
      FireAlert(msg);
      tfData[i].lastAlert = TimeCurrent();
   }

   ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, newColor);
   tfData[i].lastColor    = newColor;
   tfData[i].lastDir      = dir;
   tfData[i].lastStrength = strength;
   tfData[i].lastScore    = score;
   tfData[i].lastUpdate   = currentBarTime;
   tfData[i].hasSignal    = true;
}

//+------------------------------------------------------------------+
//| Update confluence summary bar                                    |
//+------------------------------------------------------------------+
void UpdateConfluence()
{
   int bullish = 0, bearish = 0, neutral = 0, total = 0;
   double scoreTotal = 0.0;
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled || !tfData[i].available) continue;
      total++;
      scoreTotal += tfData[i].lastScore;
      if(tfData[i].lastDir > 0)      bullish++;
      else if(tfData[i].lastDir < 0) bearish++;
      else                           neutral++;
   }
   if(total == 0) return;

   double bullPct = bullish * 100.0 / total;
   double bearPct = bearish * 100.0 / total;
   double avgScore = scoreTotal / total;

   string biasText;
   color  biasColor;
   string arrow;
   int biasDir = 0;
   int aligned = 0;
   if(bullish > bearish)
   {
      biasText  = StringFormat("Bias: %d/%d UP (%.0f%%) S%.0f", bullish, total, bullPct, avgScore);
      biasColor = ConfluenceBullColor;
      arrow     = "\x25B2"; // up triangle
      biasDir   = 1;
      aligned   = bullish;
   }
   else if(bearish > bullish)
   {
      biasText  = StringFormat("Bias: %d/%d DOWN (%.0f%%) S%.0f", bearish, total, bearPct, avgScore);
      biasColor = ConfluenceBearColor;
      arrow     = "\x25BC"; // down triangle
      biasDir   = -1;
      aligned   = bearish;
   }
   else
   {
      biasText  = StringFormat("Bias: MIXED (%d/%d) S%.0f", bullish, total, avgScore);
      biasColor = ConfluenceNeutralColor;
      arrow     = "\x25C6"; // diamond
   }

   ObjectSetString (0, OBJ_PREFIX + "ConfLabel", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfLabel", OBJPROP_COLOR, biasColor);
   ObjectSetString (0, OBJ_PREFIX + "ConfArrow", OBJPROP_TEXT, arrow);
   ObjectSetInteger(0, OBJ_PREFIX + "ConfArrow", OBJPROP_COLOR, biasColor);

   // --- Add Tooltip for detailed breakdown ---
   string tooltip = StringFormat("Confluence Breakdown:\nBullish: %d (%.1f%%)\nBearish: %d (%.1f%%)\nNeutral: %d\nAverage Score: %.1f",
                                 bullish, bullPct, bearish, bearPct, neutral, avgScore);
   ObjectSetString(0, OBJ_PREFIX + "ConfBG", OBJPROP_TOOLTIP, tooltip);
   ObjectSetString(0, OBJ_PREFIX + "ConfLabel", OBJPROP_TOOLTIP, tooltip);

   if(AlertOnConfluence && AlertType != ALERT_NONE && biasDir != 0 &&
      aligned >= ConfluenceThreshold && biasDir != lastConfluenceDir &&
      CanFireAlert(lastConfluenceAlert))
   {
      string msg = StringFormat("%s MTF confluence: %d/%d %s | Avg Score: %.0f",
                                _Symbol, aligned, total, biasDir > 0 ? "UP" : "DOWN", avgScore);
      FireAlert(msg);
      lastConfluenceAlert = TimeCurrent();
   }
   lastConfluenceDir = biasDir;
}

//+------------------------------------------------------------------+
//| ChartEvent handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // --- Minimize / expand toggle ---
   if(sparam == OBJ_PREFIX + "Title")
   {
      ToggleMinimize();
      return;
   }

   // --- Click box to switch timeframe ---
   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(sparam == tfData[i].boxName || sparam == tfData[i].labelName)
      {
         ChartSetSymbolPeriod(0, _Symbol, timeframes[i]);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Collapse / expand the dashboard                                  |
//+------------------------------------------------------------------+
void ToggleMinimize()
{
   isMinimized = !isMinimized;

   for(int i = 0; i < NUM_TIMEFRAMES; i++)
   {
      if(!tfData[i].enabled) continue;
      SetObjVisible(tfData[i].boxName,    !isMinimized);
      SetObjVisible(tfData[i].labelName,  !isMinimized);
      SetObjVisible(tfData[i].rsiDotName, !isMinimized);
   }

   SetObjVisible(OBJ_PREFIX + "ConfBG",    !isMinimized && ShowConfluenceBar);
   SetObjVisible(OBJ_PREFIX + "ConfLabel", !isMinimized && ShowConfluenceBar);
   SetObjVisible(OBJ_PREFIX + "ConfArrow", !isMinimized && ShowConfluenceBar);

   // Shrink BG when minimised
   if(isMinimized)
   {
      ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_YSIZE, 28);
      ObjectSetString (0, OBJ_PREFIX + "Title", OBJPROP_TEXT, DashboardTitle + "  [+]");
   }
   else
   {
      ObjectSetInteger(0, OBJ_PREFIX + "BG", OBJPROP_YSIZE, BackgroundHeight);
      ObjectSetString (0, OBJ_PREFIX + "Title", OBJPROP_TEXT, DashboardTitle);
      UpdateAll();
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: show/hide an object via OBJPROP_COLOR / TIMEFRAMES       |
//+------------------------------------------------------------------+
void SetObjVisible(string name, bool visible)
{
   if(ObjectFind(0, name) < 0) return;
   long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
   if(type == OBJ_RECTANGLE_LABEL)
   {
      int width = BoxWidth;
      int height = BoxHeight;
      if(name == OBJ_PREFIX + "ConfBG")
      {
         width = BackgroundWidth;
         height = 18;
      }
      ObjectSetInteger(0, name, OBJPROP_XSIZE, visible ? width : 0);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, visible ? height : 0);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
   }
}

//+------------------------------------------------------------------+
//| Helper: delete stale dashboard objects by prefix                 |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   for(int idx = ObjectsTotal(0, 0, -1) - 1; idx >= 0; idx--)
   {
      string name = ObjectName(0, idx, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Helper: score trend quality                                      |
//+------------------------------------------------------------------+
double CalculateSignalScore(int dir, double strength, double adx, double rsi, double macdHist,
                            bool rsiConfirm, bool notOverExtended, bool macdConfirm)
{
   if(dir == 0)
      return 0.0;

   double strengthScore = 0.0;
   if(StrongTrendThreshold > 0.0)
      strengthScore = MathMin(25.0, (strength / (StrongTrendThreshold * 2.0)) * 25.0);

   double adxScore = 0.0;
   if(ADXThreshold > 0.0)
      adxScore = MathMin(30.0, (adx / (ADXThreshold * 1.5)) * 30.0);

   double rsiScore = 0.0;
   if(!UseRSIFilter)
      rsiScore = 25.0;
   else if(rsiConfirm)
      rsiScore = notOverExtended ? 25.0 : 12.0;

   double macdScore = 0.0;
   if(!UseMACDFilter)
      macdScore = 20.0;
   else if(macdConfirm)
      macdScore = 20.0;
   else if(MathAbs(macdHist) <= DBL_EPSILON)
      macdScore = 8.0;

   return MathMin(100.0, MathMax(0.0, strengthScore + adxScore + rsiScore + macdScore));
}

//+------------------------------------------------------------------+
//| Helper: alert cooldown gate                                      |
//+------------------------------------------------------------------+
bool CanFireAlert(datetime lastAlertTime)
{
   if(AlertCooldownSeconds <= 0 || lastAlertTime == 0)
      return true;
   return (TimeCurrent() - lastAlertTime) >= AlertCooldownSeconds;
}

//+------------------------------------------------------------------+
//| Alert dispatcher                                                 |
//+------------------------------------------------------------------+
void FireAlert(string msg)
{
   switch(AlertType)
   {
      case ALERT_POPUP: Alert(msg); break;
      case ALERT_SOUND: PlaySound(AlertSoundFile); break;
      case ALERT_PUSH:  SendNotification(msg); break;
      case ALERT_ALL:
         Alert(msg);
         PlaySound(AlertSoundFile);
         SendNotification(msg);
         break;
      default: break;
   }
}

//+------------------------------------------------------------------+
//| Helper: set box colour on copy error                             |
//+------------------------------------------------------------------+
void SetBoxCopyError(int i, int err)
{
   ObjectSetInteger(0, tfData[i].boxName, OBJPROP_BGCOLOR, (err == 4806 ? DisabledColor : ErrorColor));
}

//+------------------------------------------------------------------+
//| Helper: safely release an indicator handle                       |
//+------------------------------------------------------------------+
void ReleaseHandle(int &handle)
{
   if(handle != INVALID_HANDLE)
   {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Input validation helpers                                         |
//+------------------------------------------------------------------+
int ValidatePeriod(int period, string name)
{
   if(period <= 0) { Print("Error: ", name, " must be > 0"); return INIT_PARAMETERS_INCORRECT; }
   return INIT_SUCCEEDED;
}

void ValidateMAPeriods(int fast, int slow, string name1, string name2)
{
   if(fast >= slow) Print("Warning: ", name1, " should be less than ", name2);
}

int ValidateHandle(int handle, string name)
{
   if(handle == INVALID_HANDLE) { Print("Error: Failed to create handle for ", name); return INIT_FAILED; }
   return INIT_SUCCEEDED;
}

bool SafeCopyBuffer(int handle, int buf_index, int start, int count, double &buffer[], string name, int &outError)
{
   outError = 0;
   if(handle == INVALID_HANDLE)
   {
      Print("SafeCopyBuffer: invalid handle for ", name);
      return false;
   }
   int copied = CopyBuffer(handle, buf_index, start, count, buffer);
   if(copied != count)
   {
      outError = GetLastError();
      // Don't spam the log with error 4806 (indicator data not found), which is common temporary issue
      if(outError != 4806)
         PrintFormat("SafeCopyBuffer: failed to copy %s (requested %d, got %d) error=%d", name, count, copied, outError);
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
