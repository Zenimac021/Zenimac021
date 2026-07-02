//+------------------------------------------------------------------+
//|                                              TradePanelEA.mq5    |
//|                      Copyright 2025, GoldScalp v8.0             |
//|        Trend Confirmation & Signal System (Debugged + Enhanced) |
//+------------------------------------------------------------------+
#property strict
#property description "GoldScalp v8.0 – Trade Panel with Trend Confirmation & Signals"
#property description "Fixed: ATR SL/TP bounds, CalculateBuyStrength, buffer retry, RSI divergence"
#property description "Enhanced: Multi-timeframe filter, RSI divergence, Sharpe Ratio, scored signals"

// Input parameters
input group "=== Trading Settings ==="
input double LotSize = 0.1;                    // Lot size for trading
input bool UseAutoLot = false;                 // Use auto lot calculation
input double RiskPercent = 1.0;                // Risk per trade (%)
input int StopLossPips = 50;                   // Stop loss (pips)
input int TakeProfitPips = 100;                // Take profit (pips)
input int AutoLotStopLossPips = 50;            // Auto lot stop loss distance (pips)
input ulong MagicNumber = 33345255;            // Magic number for trades
input string TradeComment = "TradePanel";      // Trade comment
input bool UseTradeConfirmation = true;        // Show trade confirmation dialog
input int MaxSlippage = 20;                    // Maximum slippage (points)

input group "=== Trend Confirmation Settings ==="
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1;      // Trend timeframe
input int MA_Fast = 20;                       // Fast MA period
input int MA_Slow = 50;                       // Slow MA period
input int MA_Trend = 200;                     // Trend MA period
input bool UseADX = true;                     // Use ADX filter
input int ADX_Period = 14;                    // ADX period
input double ADX_Threshold = 25.0;            // ADX threshold for trend strength

input group "=== Signal Settings ==="
input bool UseRSI = true;                     // Use RSI filter
input int RSI_Period = 14;                    // RSI period
input int RSI_Oversold = 30;                  // RSI oversold level
input int RSI_Overbought = 70;                // RSI overbought level
input bool UseMACD = true;                    // Use MACD filter
input int MACD_Fast = 12;                     // MACD fast EMA
input int MACD_Slow = 26;                     // MACD slow EMA
input int MACD_Signal = 9;                    // MACD signal SMA
input bool UseBollingerBands = false;         // Use Bollinger Bands filter
input int BB_Period = 20;                     // Bollinger Bands period
input double BB_Deviation = 2.0;              // Bollinger Bands deviation

input group "=== Panel Settings ==="
input int PanelCorner = CORNER_LEFT_UPPER;     // Panel corner position
input color PanelBgColor = clrWhiteSmoke;      // Panel background color
input int FontSize = 10;                       // Font size for labels
input bool EnableSoundAlerts = true;           // Enable sound alerts
input string BuySoundFile = "alert.wav";       // Buy alert sound
input string SellSoundFile = "alert2.wav";     // Sell alert sound
input bool MinimizePanel = false;              // Start panel minimized

input group "=== Risk Management ==="
input bool UseTrailingStop = true;            // Use trailing stop
input int TrailingStopPips = 30;               // Trailing stop (pips)
input int TrailingStepPips = 10;               // Trailing step (pips)
input int TrailingActivationPips = 0;          // Trailing activation distance (0=immediate)
input bool UseBreakEven = true;               // Use break-even
input int BreakEvenPips = 50;                  // Break-even trigger (pips)
input int BreakEvenProfitPips = 5;             // Break-even profit (pips)
input int MaxDailyTrades = 0;                  // Max daily trades (0=unlimited)
input double MaxDailyLoss = 0;                 // Max daily loss (0=unlimited)
input bool CloseOnOppositeSignal = false;      // Close on opposite signal
input bool UsePartialClose = true;             // Enable partial close feature

input group "=== ATR Settings ==="
input bool UseATRforSLTP = false;             // Use ATR for SL/TP instead of fixed pips
input int ATR_Period = 14;                    // ATR period
input ENUM_TIMEFRAMES ATR_Timeframe = PERIOD_H1; // ATR timeframe
input double ATR_SL_Multiplier = 1.5;         // ATR SL multiplier
input double ATR_TP_Multiplier = 3.0;         // ATR TP multiplier
input int ATR_MinSLPoints = 50;               // ATR minimum SL points (0 = no minimum)
input int ATR_MaxSLPoints = 500;              // ATR maximum SL points (0 = no maximum)

input group "=== Market Filter Settings ==="
input bool UseMarketHoursFilter = false;       // Filter by market session
input int MarketOpenHour = 8;                  // Market open hour (server time, 0-23)
input int MarketCloseHour = 17;                // Market close hour (server time, 0-23)
input bool UseMaxSpreadFilter = false;         // Reject trades if spread too high
input double MaxSpreadPips = 10.0;            // Maximum allowed spread (pips)
input bool UseNewsFilter = false;             // Skip trading near major news
input int NewsMinutesBefore = 30;              // Minutes before news to block
input int NewsMinutesAfter = 30;               // Minutes after news to block
input int MaxConsecutiveLosses = 0;            // Max consecutive losses before pause (0=off)

input group "=== Multi-Timeframe Settings ==="
input bool UseMultiTimeframe = false;          // Use multi-timeframe trend confirmation
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_H1; // Higher timeframe for confirmation

input group "=== RSI Divergence Settings ==="
input bool UseRSIDivergence = false;           // Use RSI divergence as additional signal
input int DivergenceLookback = 20;             // Bars to look back for swing points

input group "=== Partial Close Settings ==="
input double PartialClosePercent = 50.0;       // Percentage for partial close (0-100)

input group "=== Journal Settings ==="
input bool EnableTradeJournal = false;         // Write trade journal to file
input string JournalFileName = "TradePanel_Journal.csv"; // Journal file name

input group "=== Initial Values ==="
input double DefaultSignalStrength = 50.0;     // Initial signal strength (0-100)
input double DefaultProfitFactor = 2.5;        // Initial profit factor
input double DefaultWinRate = 60.0;            // Initial win rate (%)
input bool CalculateRealStats = true;          // Calculate real stats from history

// Global variables
double SignalStrength = 50.0;
double ProfitFactor = 2.5;
double WinRate = 60.0;
bool PanelCreated = false;
datetime LastBarTime = 0;
int DailyTradeCount = 0;
double DailyProfit = 0;
datetime LastTradeDay = 0;
bool PanelMinimized = false;
int ConsecutiveLosses = 0;
int LastLossMagicNumber = 0;
datetime LastTradeTime = 0;
int NewsFilterBlockCounter = 0;
bool InitialDrawComplete = false;
int LastCloseResult = 0; // Track last close operation result

// Trend and signal indicators
double maFast[], maSlow[], maTrend[];
double adx[], adxPlus[], adxMinus[];
double rsi[];
double macdMain[], macdSignal[];
double bbUpper[], bbMiddle[], bbLower[];
double atrBuffer[];
int maFastHandle = INVALID_HANDLE, maSlowHandle = INVALID_HANDLE, maTrendHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE, rsiHandle = INVALID_HANDLE, macdHandle = INVALID_HANDLE, bbHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

// Multi-timeframe confirmation handles and buffers
int mtfMaFastHandle = INVALID_HANDLE, mtfMaSlowHandle = INVALID_HANDLE;
double mtfMaFast[], mtfMaSlow[];

// Performance tracking
double SharpeRatio = 0.0;

// Signal states
enum ENUM_TREND_DIRECTION
{
    TREND_UP,
    TREND_DOWN,
    TREND_SIDEWAYS,
    TREND_UNKNOWN
};

enum ENUM_SIGNAL_STRENGTH
{
    SIGNAL_WEAK,
    SIGNAL_MODERATE,
    SIGNAL_STRONG,
    SIGNAL_VERY_STRONG
};

enum ENUM_DIVERGENCE_TYPE
{
    DIV_NONE,
    DIV_BULLISH,   // Price lower low + RSI higher low  → buy divergence
    DIV_BEARISH    // Price higher high + RSI lower high → sell divergence
};

// Current market analysis
struct MarketAnalysis
{
    ENUM_TREND_DIRECTION trend;
    ENUM_TREND_DIRECTION mtfTrend;       // Higher-timeframe trend for MTF filter
    ENUM_SIGNAL_STRENGTH buyStrength;
    ENUM_SIGNAL_STRENGTH sellStrength;
    ENUM_DIVERGENCE_TYPE divergence;     // Current RSI divergence type
    double trendStrength;
    bool buySignal;
    bool sellSignal;
    string recommendation;
    double rsiValue;
    double macdValue;
    double adxValue;
    double adxPlusValue;
    double adxMinusValue;
    double atrValue;
    bool marketOpen;
    bool spreadOk;
    bool newsOk;
};

MarketAnalysis currentAnalysis;
MarketAnalysis previousAnalysis;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate input parameters
    if(LotSize < 0)
    {
        Print("ERROR: LotSize cannot be negative");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(StopLossPips < 0 || TakeProfitPips < 0)
    {
        Print("ERROR: SL/TP pips cannot be negative");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(RiskPercent < 0 || RiskPercent > 100)
    {
        Print("ERROR: RiskPercent must be between 0 and 100");
        return(INIT_PARAMETERS_INCORRECT);
    }
    // Validate ATR SL/TP bounds (both 0 means no clamping, which is valid)
    if(ATR_MinSLPoints > 0 && ATR_MaxSLPoints > 0 && ATR_MinSLPoints > ATR_MaxSLPoints)
    {
        Print("ERROR: ATR_MinSLPoints (", ATR_MinSLPoints, ") must be <= ATR_MaxSLPoints (", ATR_MaxSLPoints, ")");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Set default values from input parameters
    SignalStrength = DefaultSignalStrength;
    ProfitFactor = DefaultProfitFactor;
    WinRate = DefaultWinRate;
    PanelMinimized = MinimizePanel;
    
    // Initialize indicator handles to invalid first (safety)
    maFastHandle = INVALID_HANDLE;
    maSlowHandle = INVALID_HANDLE;
    maTrendHandle = INVALID_HANDLE;
    adxHandle = INVALID_HANDLE;
    rsiHandle = INVALID_HANDLE;
    macdHandle = INVALID_HANDLE;
    bbHandle = INVALID_HANDLE;
    atrHandle = INVALID_HANDLE;
    
    // Initialize indicators
    if(!InitializeIndicators())
    {
        Print("Failed to initialize indicators");
        CleanupIndicatorHandles(); // Ensure cleanup on failure
        return(INIT_FAILED);
    }
    
    // Set timer for periodic updates (every 500ms for smooth UI)
    EventSetMillisecondTimer(500);
    
    // Initialize market analysis
    ZeroMemory(currentAnalysis);
    ZeroMemory(previousAnalysis);
    currentAnalysis.trend = TREND_UNKNOWN;
    currentAnalysis.marketOpen = true;
    currentAnalysis.spreadOk = true;
    currentAnalysis.newsOk = true;
    
    // Calculate real stats if enabled
    if(CalculateRealStats)
        CalculateRealStatistics();
    
    // Reset daily counters
    ResetDailyCounters();
    
    // Init journal header
    if(EnableTradeJournal)
        InitJournal();
    
    if (!CreateTradePanel())
    {
        Print("Failed to create trade panel.");
        CleanupIndicatorHandles();
        return(INIT_FAILED);
    }
    
    PanelCreated = true;
    Print("GoldScalp v8.0 initialized successfully with Trend Confirmation, MTF & Enhanced Features");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    // Moving Averages
    maFastHandle = iMA(Symbol(), TrendTimeframe, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    if(maFastHandle == INVALID_HANDLE)
    {
        Print("Failed to create Fast MA handle. Error: ", GetLastError());
        return false;
    }
    
    maSlowHandle = iMA(Symbol(), TrendTimeframe, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    if(maSlowHandle == INVALID_HANDLE)
    {
        Print("Failed to create Slow MA handle. Error: ", GetLastError());
        IndicatorRelease(maFastHandle);
        maFastHandle = INVALID_HANDLE;
        return false;
    }
    
    maTrendHandle = iMA(Symbol(), TrendTimeframe, MA_Trend, 0, MODE_SMA, PRICE_CLOSE);
    if(maTrendHandle == INVALID_HANDLE)
    {
        Print("Failed to create Trend MA handle. Error: ", GetLastError());
        IndicatorRelease(maFastHandle);
        IndicatorRelease(maSlowHandle);
        maFastHandle = INVALID_HANDLE;
        maSlowHandle = INVALID_HANDLE;
        return false;
    }
    
    // ADX
    adxHandle = iADX(Symbol(), TrendTimeframe, ADX_Period);
    if(adxHandle == INVALID_HANDLE)
    {
        Print("Failed to create ADX handle. Error: ", GetLastError());
        IndicatorRelease(maFastHandle);
        IndicatorRelease(maSlowHandle);
        IndicatorRelease(maTrendHandle);
        maFastHandle = INVALID_HANDLE;
        maSlowHandle = INVALID_HANDLE;
        maTrendHandle = INVALID_HANDLE;
        return false;
    }
    
    // RSI
    rsiHandle = iRSI(Symbol(), TrendTimeframe, RSI_Period, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Print("Failed to create RSI handle. Error: ", GetLastError());
        IndicatorRelease(maFastHandle);
        IndicatorRelease(maSlowHandle);
        IndicatorRelease(maTrendHandle);
        IndicatorRelease(adxHandle);
        maFastHandle = INVALID_HANDLE;
        maSlowHandle = INVALID_HANDLE;
        maTrendHandle = INVALID_HANDLE;
        adxHandle = INVALID_HANDLE;
        return false;
    }
    
    // MACD
    macdHandle = iMACD(Symbol(), TrendTimeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if(macdHandle == INVALID_HANDLE)
    {
        Print("Failed to create MACD handle. Error: ", GetLastError());
        IndicatorRelease(maFastHandle);
        IndicatorRelease(maSlowHandle);
        IndicatorRelease(maTrendHandle);
        IndicatorRelease(adxHandle);
        IndicatorRelease(rsiHandle);
        maFastHandle = INVALID_HANDLE;
        maSlowHandle = INVALID_HANDLE;
        maTrendHandle = INVALID_HANDLE;
        adxHandle = INVALID_HANDLE;
        rsiHandle = INVALID_HANDLE;
        return false;
    }
    
    // Bollinger Bands (optional)
    if(UseBollingerBands)
    {
        bbHandle = iBands(Symbol(), TrendTimeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
        if(bbHandle == INVALID_HANDLE)
        {
            Print("Warning: Failed to create Bollinger Bands handle. Error: ", GetLastError());
            // BB will be inactive since handle is INVALID_HANDLE
        }
    }
    else
        bbHandle = INVALID_HANDLE;
    
    // ATR (optional)
    if(UseATRforSLTP)
    {
        atrHandle = iATR(Symbol(), ATR_Timeframe, ATR_Period);
        if(atrHandle == INVALID_HANDLE)
        {
            Print("Warning: Failed to create ATR handle. Error: ", GetLastError());
            // ATR will be inactive since handle is INVALID_HANDLE
        }
    }
    else
        atrHandle = INVALID_HANDLE;
    
    // Multi-timeframe MAs (optional)
    if(UseMultiTimeframe)
    {
        mtfMaFastHandle = iMA(Symbol(), MTF_Timeframe, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
        if(mtfMaFastHandle == INVALID_HANDLE)
            Print("Warning: Failed to create MTF Fast MA handle. Error: ", GetLastError());
        
        mtfMaSlowHandle = iMA(Symbol(), MTF_Timeframe, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
        if(mtfMaSlowHandle == INVALID_HANDLE)
            Print("Warning: Failed to create MTF Slow MA handle. Error: ", GetLastError());
        
        ArraySetAsSeries(mtfMaFast, true);
        ArraySetAsSeries(mtfMaSlow, true);
    }
    else
    {
        mtfMaFastHandle = INVALID_HANDLE;
        mtfMaSlowHandle = INVALID_HANDLE;
    }
    
    // Set arrays as series
    ArraySetAsSeries(maFast, true);
    ArraySetAsSeries(maSlow, true);
    ArraySetAsSeries(maTrend, true);
    ArraySetAsSeries(adx, true);
    ArraySetAsSeries(adxPlus, true);
    ArraySetAsSeries(adxMinus, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbMiddle, true);
    ArraySetAsSeries(bbLower, true);
    ArraySetAsSeries(atrBuffer, true);
    
    Print("All indicators initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Cleanup all indicator handles safely                             |
//+------------------------------------------------------------------+
void CleanupIndicatorHandles()
{
    if(maFastHandle != INVALID_HANDLE) { IndicatorRelease(maFastHandle); maFastHandle = INVALID_HANDLE; }
    if(maSlowHandle != INVALID_HANDLE) { IndicatorRelease(maSlowHandle); maSlowHandle = INVALID_HANDLE; }
    if(maTrendHandle != INVALID_HANDLE) { IndicatorRelease(maTrendHandle); maTrendHandle = INVALID_HANDLE; }
    if(adxHandle != INVALID_HANDLE) { IndicatorRelease(adxHandle); adxHandle = INVALID_HANDLE; }
    if(rsiHandle != INVALID_HANDLE) { IndicatorRelease(rsiHandle); rsiHandle = INVALID_HANDLE; }
    if(macdHandle != INVALID_HANDLE) { IndicatorRelease(macdHandle); macdHandle = INVALID_HANDLE; }
    if(bbHandle != INVALID_HANDLE) { IndicatorRelease(bbHandle); bbHandle = INVALID_HANDLE; }
    if(atrHandle != INVALID_HANDLE) { IndicatorRelease(atrHandle); atrHandle = INVALID_HANDLE; }
    if(mtfMaFastHandle != INVALID_HANDLE) { IndicatorRelease(mtfMaFastHandle); mtfMaFastHandle = INVALID_HANDLE; }
    if(mtfMaSlowHandle != INVALID_HANDLE) { IndicatorRelease(mtfMaSlowHandle); mtfMaSlowHandle = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles safely
    CleanupIndicatorHandles();
    
    EventKillTimer();
    DeleteAllObjects();
    PanelCreated = false;
    
    Print("Trade Panel deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Apply trailing stop and break-even on every tick
    if(UseTrailingStop)
        ApplyTrailingStop();
    
    if(UseBreakEven)
        ApplyBreakEven();
    
    // Check for new bar for signal processing
    datetime currentBarTime = iTime(Symbol(), TrendTimeframe, 0);
    if(currentBarTime != LastBarTime)
    {
        LastBarTime = currentBarTime;
        OnNewBar();
    }
}

//+------------------------------------------------------------------+
//| Timer function for UI updates                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!PanelCreated) return;
    
    // Update market analysis
    AnalyzeMarket();
    
    // Update panel displays
    UpdateSignalStrengthBar();
    UpdateTrendIndicator();
    UpdateSignalIndicators();
    UpdateProfitFactor();
    UpdateWinRate();
    UpdateLotSizeDisplay();
    UpdateTradeRecommendation();
    UpdatePositionInfo();
    UpdateDailyStats();
    
    // Check for signal changes and alert
    CheckSignalChange();
}

//+------------------------------------------------------------------+
//| New bar event handler                                            |
//+------------------------------------------------------------------+
void OnNewBar()
{
    // Reset daily counters if new day
    ResetDailyCounters();
    
    // Check for close on opposite signal
    if(CloseOnOppositeSignal)
        CheckCloseOnOppositeSignal();
    
    // Reset consecutive losses if it's a new trading day
    if(TimeCurrent() >= LastTradeDay + 86400 && ConsecutiveLosses > 0)
    {
        ConsecutiveLosses = 0;
        Print("New trading day - consecutive losses reset");
    }
}

//+------------------------------------------------------------------+
//| Reset daily trade counters                                       |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    datetime today = StructToTime(dt);
    
    if(today != LastTradeDay)
    {
        LastTradeDay = today;
        DailyTradeCount = 0;
        DailyProfit = 0;
        
        // Recalculate daily stats from today's trades
        CalculateDailyStats();
    }
}

//+------------------------------------------------------------------+
//| Calculate daily statistics                                       |
//+------------------------------------------------------------------+
void CalculateDailyStats()
{
    DailyTradeCount = 0;
    DailyProfit = 0;
    
    datetime todayStart = LastTradeDay;
    datetime todayEnd = todayStart + 86400;
    
    // Select history deals
    if(HistorySelect(todayStart, todayEnd))
    {
        int totalDeals = HistoryDealsTotal();
        if(totalDeals > 200)
        {
            // Limit to recent deals to improve performance
            totalDeals = 200;
        }
        
        for(int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0)
            {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
                   HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol())
                {
                    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
                    if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
                        DailyTradeCount++;
                    
                    DailyProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    DailyProfit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                    DailyProfit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze market conditions                                        |
//+------------------------------------------------------------------+
void AnalyzeMarket()
{
    // Store previous analysis
    previousAnalysis = currentAnalysis;
    
    // Copy indicator buffers with retry logic (handles slow indicator warm-up)
    bool buffersCopied = true;
    int retries = 2;
    
    for(int attempt = 0; attempt <= retries; attempt++)
    {
        buffersCopied = true;
        if(CopyBuffer(maFastHandle, 0, 0, 3, maFast) < 3)   { buffersCopied = false; }
        if(CopyBuffer(maSlowHandle, 0, 0, 3, maSlow) < 3)   { buffersCopied = false; }
        if(CopyBuffer(maTrendHandle, 0, 0, 3, maTrend) < 3) { buffersCopied = false; }
        if(CopyBuffer(adxHandle, 0, 0, 3, adx) < 3)         { buffersCopied = false; }
        if(CopyBuffer(adxHandle, 1, 0, 3, adxPlus) < 3)     { buffersCopied = false; }
        if(CopyBuffer(adxHandle, 2, 0, 3, adxMinus) < 3)    { buffersCopied = false; }
        if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)         { buffersCopied = false; }
        if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) < 3)   { buffersCopied = false; }
        if(CopyBuffer(macdHandle, 1, 0, 3, macdSignal) < 3) { buffersCopied = false; }
        
        if(buffersCopied || attempt == retries) break;
        Sleep(50); // Brief pause before retry
    }
    
    if(UseBollingerBands && bbHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(bbHandle, 1, 0, 3, bbUpper) < 3)  buffersCopied = false;
        if(CopyBuffer(bbHandle, 0, 0, 3, bbMiddle) < 3) buffersCopied = false;
        if(CopyBuffer(bbHandle, 2, 0, 3, bbLower) < 3)  buffersCopied = false;
    }
    
    if(UseATRforSLTP && atrHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) < 3) buffersCopied = false;
    }
    
    if(!buffersCopied)
    {
        currentAnalysis.trend = TREND_UNKNOWN;
        currentAnalysis.mtfTrend = TREND_UNKNOWN;
        currentAnalysis.trendStrength = 0;
        currentAnalysis.buySignal = false;
        currentAnalysis.sellSignal = false;
        currentAnalysis.buyStrength = SIGNAL_WEAK;
        currentAnalysis.sellStrength = SIGNAL_WEAK;
        currentAnalysis.divergence = DIV_NONE;
        currentAnalysis.recommendation = "No Data";
        return;
    }
    
    // Store indicator values with validation
    currentAnalysis.rsiValue = rsi[0];
    currentAnalysis.macdValue = macdMain[0] - macdSignal[0];
    currentAnalysis.adxValue = adx[0];
    currentAnalysis.adxPlusValue = adxPlus[0];
    currentAnalysis.adxMinusValue = adxMinus[0];
    currentAnalysis.atrValue = (UseATRforSLTP && ArraySize(atrBuffer) >= 3 && atrBuffer[0] != EMPTY_VALUE) ? atrBuffer[0] : 0;
    
    // Apply market filters
    currentAnalysis.marketOpen = IsMarketOpen();
    currentAnalysis.spreadOk = IsSpreadAcceptable();
    currentAnalysis.newsOk = IsNewsSafe();
    
    // Determine trend
    currentAnalysis.trend = DetermineTrend();
    currentAnalysis.trendStrength = UseADX ? currentAnalysis.adxValue : CalculateTrendStrength();
    
    // Multi-timeframe trend
    currentAnalysis.mtfTrend = DetermineMTFTrend();
    
    // RSI divergence
    currentAnalysis.divergence = UseRSIDivergence ? DetectRSIDivergence() : DIV_NONE;
    
    // Generate signals
    currentAnalysis.buySignal = GenerateBuySignal();
    currentAnalysis.sellSignal = GenerateSellSignal();
    
    // Determine signal strengths
    currentAnalysis.buyStrength = CalculateBuyStrength();
    currentAnalysis.sellStrength = CalculateSellStrength();
    
    // Generate recommendation
    currentAnalysis.recommendation = GenerateRecommendation();
}

//+------------------------------------------------------------------+
//| Check if market is open based on server time                     |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
    if(!UseMarketHoursFilter)
        return true;
    
    MqlDateTime dt;
    TimeCurrent(dt);
    
    if(MarketOpenHour < MarketCloseHour)
        return (dt.hour >= MarketOpenHour && dt.hour < MarketCloseHour);
    else
        return (dt.hour >= MarketOpenHour || dt.hour < MarketCloseHour);
}

//+------------------------------------------------------------------+
//| Check if spread is within acceptable range                       |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
    if(!UseMaxSpreadFilter)
        return true;
    
    double spreadPips = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID)) / GetPipValue();
    return (spreadPips <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
//| Check if it's safe to trade near news (improved heuristic)      |
//+------------------------------------------------------------------+
bool IsNewsSafe()
{
    if(!UseNewsFilter)
        return true;
    
    // Refresh news block check every 60 timer ticks (about 30 seconds)
    static int newsCheckCounter = 0;
    newsCheckCounter++;
    
    if(newsCheckCounter < 60)
        return currentAnalysis.newsOk;
    
    newsCheckCounter = 0;
    
    MqlDateTime dt;
    TimeCurrent(dt);
    
    // Improve filter: be more restrictive around high-impact times
    // Monday morning (week start) and Friday afternoon (weekend risk)
    if(dt.day_of_week == 1 && dt.hour < 2) // Monday early hours
        return false;
    
    if(dt.day_of_week == 5 && dt.hour >= 20) // Friday late
        return false;
    
    // Weekend blocking
    if(dt.day_of_week == 0 || dt.day_of_week == 6)
        return false;
    
    // Economic calendar high-impact times (improved)
    int hour = dt.hour;
    int minute = dt.min;
    
    // London session open (high volatility)
    if(hour == 8 && minute >= 0 && minute < 30) return false;
    
    // NY session open (major news window)
    if(hour >= 13 && hour <= 14) return false;
    
    // US economic data releases (usually 8:30am ET = 13:30 GMT)
    if(hour == 13 && minute >= 20 && minute < 40) return false;
    
    // FOMC announcements (roughly 2pm ET = 19:00 GMT)
    if(hour == 19 && minute >= 0 && minute < 30) return false;
    
    // ECB rate decisions (usually 1:45pm CET = 12:45 GMT)
    if(hour == 12 && minute >= 30 && minute < 45) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Determine trend direction                                        |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION DetermineTrend()
{
    // Check if we have valid data
    if(ArraySize(maFast) < 3 || ArraySize(maSlow) < 3 || ArraySize(maTrend) < 3)
        return TREND_UNKNOWN;
    
    if(maFast[0] == EMPTY_VALUE || maSlow[0] == EMPTY_VALUE || maTrend[0] == EMPTY_VALUE)
        return TREND_UNKNOWN;
    
    double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Check MA alignment
    bool maBullishAlign = (maFast[0] > maSlow[0] && maSlow[0] > maTrend[0]);
    bool maBearishAlign = (maFast[0] < maSlow[0] && maSlow[0] < maTrend[0]);
    
    // Check price position
    bool priceAboveFast = (price > maFast[0]);
    bool priceBelowFast = (price < maFast[0]);
    bool priceAboveTrend = (price > maTrend[0]);
    bool priceBelowTrend = (price < maTrend[0]);
    
    // Check MA slopes (comparing current to previous)
    bool maFastRising = (maFast[0] > maFast[1]);
    bool maFastFalling = (maFast[0] < maFast[1]);
    bool maSlowRising = (maSlow[0] > maSlow[1]);
    bool maSlowFalling = (maSlow[0] < maSlow[1]);
    bool maTrendRising = (maTrend[0] > maTrend[1]);
    bool maTrendFalling = (maTrend[0] < maTrend[1]);
    
    // Determine trend direction
    if(maBullishAlign && priceAboveFast && maFastRising && maSlowRising && maTrendRising)
        return TREND_UP;
    else if(maBearishAlign && priceBelowFast && maFastFalling && maSlowFalling && maTrendFalling)
        return TREND_DOWN;
    else
        return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| Calculate trend strength                                         |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
    double trendStrength = 0;
    
    // Calculate trend strength based on MA alignment and price position
    if(currentAnalysis.trend == TREND_UP)
    {
        trendStrength += (maFast[0] - maSlow[0]) / maSlow[0] * 100;
        trendStrength += (maSlow[0] - maTrend[0]) / maTrend[0] * 100;
        trendStrength += (SymbolInfoDouble(Symbol(), SYMBOL_BID) - maFast[0]) / maFast[0] * 100;
    }
    else if(currentAnalysis.trend == TREND_DOWN)
    {
        trendStrength += (maSlow[0] - maFast[0]) / maSlow[0] * 100;
        trendStrength += (maTrend[0] - maSlow[0]) / maTrend[0] * 100;
        trendStrength += (maFast[0] - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / maFast[0] * 100;
    }
    
    return trendStrength;
}

//+------------------------------------------------------------------+
//| Generate buy signal                                              |
//| Requires at least SIGNAL_MODERATE strength to avoid weak alerts |
//+------------------------------------------------------------------+
bool GenerateBuySignal()
{
    // Base condition: uptrend with MACD momentum and RSI not overbought
    if(currentAnalysis.trend != TREND_UP)
    {
        // Allow divergence-based buy even in sideways/unknown trend
        if(UseRSIDivergence && currentAnalysis.divergence == DIV_BULLISH)
        {
            // Still require MACD not strongly bearish
            if(currentAnalysis.macdValue >= 0)
            {
                // Check signal strength - only generate signal if at least MODERATE strength
                return (CalculateBuyStrengthInternal() >= SIGNAL_MODERATE);
            }
        }
        return false;
    }
    
    if(currentAnalysis.macdValue <= 0) return false;
    if(currentAnalysis.rsiValue >= 70) return false;
    
    // Multi-timeframe filter: higher-timeframe trend must agree or be neutral
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_DOWN) return false;
    
    // Check signal strength - only generate signal if at least MODERATE strength
    return (CalculateBuyStrengthInternal() >= SIGNAL_MODERATE);
}

//+------------------------------------------------------------------+
//| Generate sell signal                                             |
//| Requires at least SIGNAL_MODERATE strength to avoid weak alerts |
//+------------------------------------------------------------------+
bool GenerateSellSignal()
{
    // Base condition: downtrend with MACD momentum and RSI not oversold
    if(currentAnalysis.trend != TREND_DOWN)
    {
        // Allow divergence-based sell even in sideways/unknown trend
        if(UseRSIDivergence && currentAnalysis.divergence == DIV_BEARISH)
        {
            if(currentAnalysis.macdValue <= 0)
            {
                // Check signal strength - only generate signal if at least MODERATE strength
                return (CalculateSellStrengthInternal() >= SIGNAL_MODERATE);
            }
        }
        return false;
    }
    
    if(currentAnalysis.macdValue >= 0) return false;
    if(currentAnalysis.rsiValue <= 30) return false;
    
    // Multi-timeframe filter: higher-timeframe trend must agree or be neutral
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_UP) return false;
    
    // Check signal strength - only generate signal if at least MODERATE strength
    return (CalculateSellStrengthInternal() >= SIGNAL_MODERATE);
}

//+------------------------------------------------------------------+
//| Calculate buy signal strength score (internal, no signal guard) |
//+------------------------------------------------------------------+
ENUM_SIGNAL_STRENGTH CalculateBuyStrengthInternal()
{
    if(ArraySize(rsi) < 3 || ArraySize(macdMain) < 3 || ArraySize(macdSignal) < 3 || ArraySize(maFast) < 3 || ArraySize(maSlow) < 3)
        return SIGNAL_WEAK;
    
    int strengthScore = 0;
    double price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Trend alignment (max 3 points)
    if(currentAnalysis.trend == TREND_UP) strengthScore += 3;
    else if(currentAnalysis.trend == TREND_SIDEWAYS) strengthScore += 1;
    
    // RSI analysis (max 3 points): favour oversold recovery zone
    if(UseRSI)
    {
        if(rsi[0] > RSI_Oversold && rsi[0] < 40) strengthScore += 3; // Oversold reversal
        else if(rsi[0] >= 40 && rsi[0] < 50) strengthScore += 2;
        else if(rsi[0] >= 50 && rsi[0] < RSI_Overbought) strengthScore += 1;
    }
    
    // MACD momentum (max 3 points)
    if(UseMACD)
    {
        if(macdMain[0] > macdSignal[0] && macdMain[0] > 0 && macdMain[1] <= macdSignal[1])
            strengthScore += 3; // Bullish crossover above zero
        else if(macdMain[0] > macdSignal[0] && macdMain[0] > 0)
            strengthScore += 2;
        else if(macdMain[0] > macdSignal[0])
            strengthScore += 1;
    }
    
    // ADX strength (max 2 points)
    if(UseADX)
    {
        if(adx[0] > ADX_Threshold && adxPlus[0] > adxMinus[0]) strengthScore += 1;
        if(adx[0] > 40) strengthScore += 1;
    }
    
    // Bollinger Bands (max 2 points)
    if(UseBollingerBands && bbHandle != INVALID_HANDLE && ArraySize(bbLower) >= 3)
    {
        if(price <= bbLower[0]) strengthScore += 2; // Touching lower band
        else if(price > bbLower[0] && price < bbMiddle[0]) strengthScore += 1;
    }
    
    // RSI divergence bonus (max 1 point)
    if(UseRSIDivergence && currentAnalysis.divergence == DIV_BULLISH) strengthScore += 1;
    
    // MTF confirmation bonus (max 1 point)
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_UP) strengthScore += 1;
    
    if(strengthScore >= 9) return SIGNAL_VERY_STRONG;
    if(strengthScore >= 6) return SIGNAL_STRONG;
    if(strengthScore >= 3) return SIGNAL_MODERATE;
    return SIGNAL_WEAK;
}

//+------------------------------------------------------------------+
//| Calculate buy signal strength                                    |
//+------------------------------------------------------------------+
ENUM_SIGNAL_STRENGTH CalculateBuyStrength()
{
    if(!currentAnalysis.buySignal)
        return SIGNAL_WEAK;
    
    return CalculateBuyStrengthInternal();
}

//+------------------------------------------------------------------+
//| Check if position matches our trading criteria                   |
//+------------------------------------------------------------------+
bool IsOurPosition(ulong ticket)
{
    if(ticket <= 0 || !PositionSelectByTicket(ticket))
        return false;
    
    if(PositionGetString(POSITION_SYMBOL) != Symbol())
        return false;
    
    if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Handle chart events                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        // Reset button pressed state
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        
        if (sparam == "BuyButton")
        {
            if(CheckDailyLimits() && CheckMarketFilters() && ConfirmTrade("BUY"))
            {
                ExecuteBuy();
                LogTrade("BUY");
            }
        }
        else if (sparam == "SellButton")
        {
            if(CheckDailyLimits() && CheckMarketFilters() && ConfirmTrade("SELL"))
            {
                ExecuteSell();
                LogTrade("SELL");
            }
        }
        else if (sparam == "CloseAllButton")
        {
            if(ConfirmTrade("CLOSE ALL"))
                CloseAllTrades();
        }
        else if (sparam == "CloseBuysButton")
        {
            if(ConfirmTrade("CLOSE BUYS"))
                ClosePositionsByType(POSITION_TYPE_BUY);
        }
        else if (sparam == "CloseSellsButton")
        {
            if(ConfirmTrade("CLOSE SELLS"))
                ClosePositionsByType(POSITION_TYPE_SELL);
        }
        else if (sparam == "ClosePartialButton")
        {
            if(ConfirmTrade("CLOSE PARTIAL"))
                ClosePartialPositions();
        }
        else if (sparam == "ModifySLButton")
        {
            ModifyAllSL();
        }
        else if (sparam == "ModifyTPButton")
        {
            ModifyAllTP();
        }
        else if (sparam == "MinimizeButton")
        {
            ToggleMinimize();
        }
    }
}

//+------------------------------------------------------------------+
//| Toggle panel minimize/maximize                                   |
//+------------------------------------------------------------------+
void ToggleMinimize()
{
    PanelMinimized = !PanelMinimized;
    CreateTradePanel();
    PanelCreated = true;
    Print("Panel " + (PanelMinimized ? "minimized" : "maximized"));
}

//+------------------------------------------------------------------+
//| Check market filters before trading                              |
//+------------------------------------------------------------------+
bool CheckMarketFilters()
{
    if(UseMarketHoursFilter && !currentAnalysis.marketOpen)
    {
        MessageBox("Market is closed based on configured hours!", 
                  "Market Filter", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    if(UseMaxSpreadFilter && !currentAnalysis.spreadOk)
    {
        double spreadPips = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                            SymbolInfoDouble(Symbol(), SYMBOL_BID)) / GetPipValue();
        MessageBox("Spread too high: " + DoubleToString(spreadPips, 1) + 
                  " pips (max: " + DoubleToString(MaxSpreadPips, 1) + ")", 
                  "Spread Filter", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    if(UseNewsFilter && !currentAnalysis.newsOk)
    {
        MessageBox("Trading blocked near news event!", 
                  "News Filter", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    if(MaxConsecutiveLosses > 0 && ConsecutiveLosses >= MaxConsecutiveLosses)
    {
        MessageBox("Max consecutive losses reached (" + IntegerToString(MaxConsecutiveLosses) + ")!", 
                  "Risk Control", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check daily limits                                               |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
    if(MaxDailyTrades > 0 && DailyTradeCount >= MaxDailyTrades)
    {
        MessageBox("Daily trade limit reached (" + IntegerToString(MaxDailyTrades) + " trades)", 
                  "Daily Limit", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    if(MaxDailyLoss > 0 && DailyProfit <= -MaxDailyLoss)
    {
        MessageBox("Daily loss limit reached ($" + DoubleToString(MaxDailyLoss, 2) + ")", 
                  "Daily Limit", MB_OK | MB_ICONWARNING);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Trade confirmation dialog                                        |
//+------------------------------------------------------------------+
bool ConfirmTrade(string action)
{
    if(!UseTradeConfirmation)
        return true;
        
    double lot = UseAutoLot ? CalculateAutoLot() : LotSize;
    double slPips, tpPips;
    GetATRBasedSLTP(slPips, tpPips);
    
    string msg = StringFormat("Confirm %s order?\n\nLot Size: %.2f\nStop Loss: %.0f pips\nTake Profit: %.0f pips",
                              action, lot, slPips, tpPips);
    
    int response = MessageBox(msg, "Trade Confirmation", MB_YESNO | MB_ICONQUESTION);
    return (response == IDYES);
}

//+------------------------------------------------------------------+
//| Execute a buy order                                              |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
    double currentLot = UseAutoLot ? CalculateAutoLot() : LotSize;
    double pipValue = GetPipValue();
    double slPips, tpPips;
    GetATRBasedSLTP(slPips, tpPips);
    double ask;
    
    // Refresh rates
    if(!SymbolInfoDouble(Symbol(), SYMBOL_ASK, ask))
    {
        Print("Failed to get current ASK price");
        return;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = currentLot;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.deviation = MaxSlippage;
    request.magic = MagicNumber;
    request.comment = TradeComment + " Buy";
    request.type_filling = GetFillingMode();
    
    // Set SL/TP
    if(slPips > 0)
        request.sl = NormalizeDouble(ask - slPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    if(tpPips > 0)
        request.tp = NormalizeDouble(ask + tpPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    
    bool sent = OrderSend(request, result);
    if(!sent)
    {
        Print("Buy Order Failed: ", GetTradeErrorDescription(result.retcode));
        MessageBox("Buy order failed: " + GetTradeErrorDescription(result.retcode), 
                  "Trade Error", MB_OK | MB_ICONERROR);
    }
    else if(result.retcode == TRADE_RETCODE_DONE)
    {
        Print("Buy order executed successfully. Ticket: ", result.order, ", Deal: ", result.deal);
        DailyTradeCount++;
        LastTradeTime = TimeCurrent();
        if(EnableSoundAlerts) PlaySound(BuySoundFile);
        if(EnableTradeJournal)
        {
            string logMsg = StringFormat("BUY executed - Lot: %.2f, Price: %.5f, SL: %.5f, TP: %.5f",
                                         currentLot, ask, request.sl, request.tp);
            LogToFile("Trade", "EXECUTED", logMsg);
        }
    }
    else
    {
        Print("Buy order issue: ", GetTradeErrorDescription(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Execute a sell order                                             |
//+------------------------------------------------------------------+
void ExecuteSell()
{
    double currentLot = UseAutoLot ? CalculateAutoLot() : LotSize;
    double pipValue = GetPipValue();
    double slPips, tpPips;
    GetATRBasedSLTP(slPips, tpPips);
    double bid;
    
    // Refresh rates
    if(!SymbolInfoDouble(Symbol(), SYMBOL_BID, bid))
    {
        Print("Failed to get current BID price");
        return;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = currentLot;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.deviation = MaxSlippage;
    request.magic = MagicNumber;
    request.comment = TradeComment + " Sell";
    request.type_filling = GetFillingMode();
    
    // Set SL/TP
    if(slPips > 0)
        request.sl = NormalizeDouble(bid + slPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    if(tpPips > 0)
        request.tp = NormalizeDouble(bid - tpPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    
    bool sent = OrderSend(request, result);
    if(!sent)
    {
        Print("Sell Order Failed: ", GetTradeErrorDescription(result.retcode));
        MessageBox("Sell order failed: " + GetTradeErrorDescription(result.retcode), 
                  "Trade Error", MB_OK | MB_ICONERROR);
    }
    else if(result.retcode == TRADE_RETCODE_DONE)
    {
        Print("Sell order executed successfully. Ticket: ", result.order, ", Deal: ", result.deal);
        DailyTradeCount++;
        LastTradeTime = TimeCurrent();
        if(EnableSoundAlerts) PlaySound(SellSoundFile);
        if(EnableTradeJournal)
        {
            string logMsg = StringFormat("SELL executed - Lot: %.2f, Price: %.5f, SL: %.5f, TP: %.5f",
                                         currentLot, bid, request.sl, request.tp);
            LogToFile("Trade", "EXECUTED", logMsg);
        }
    }
    else
    {
        Print("Sell order issue: ", GetTradeErrorDescription(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Get appropriate filling mode for symbol                          |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
    uint filling = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
    
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        return ORDER_FILLING_FOK;
    if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        return ORDER_FILLING_IOC;
    
    return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Close all trades for current symbol                              |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    int totalPositions = PositionsTotal();
    int closedCount = 0;
    int failedCount = 0;
    double closeProfit = 0;
    
    for (int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!IsOurPosition(ticket))
            continue;
        
        closeProfit += PositionGetDouble(POSITION_PROFIT);
        
        if(!ClosePosition(ticket))
            failedCount++;
        else
            closedCount++;
    }
    
    // Track consecutive losses based on net P&L of all closed positions
    TrackConsecutiveLosses(closeProfit);
    
    Print("Closed ", closedCount, " positions. Failed: ", failedCount);
}

//+------------------------------------------------------------------+
//| Close positions by type                                          |
//+------------------------------------------------------------------+
void ClosePositionsByType(ENUM_POSITION_TYPE posType)
{
    int totalPositions = PositionsTotal();
    int closedCount = 0;
    double closeProfit = 0;
    
    for (int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!IsOurPosition(ticket))
            continue;
        
        if(PositionGetInteger(POSITION_TYPE) != posType)
            continue;
        
        closeProfit += PositionGetDouble(POSITION_PROFIT);
        
        if(ClosePosition(ticket))
            closedCount++;
    }
    
    // Track consecutive losses based on net P&L of closed positions
    TrackConsecutiveLosses(closeProfit);
    
    Print("Closed ", closedCount, " ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " positions");
}

//+------------------------------------------------------------------+
//| Close a single position by ticket                                |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = MaxSlippage;
    request.magic = MagicNumber;
    request.type_filling = GetFillingMode();
    
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
    }
    else
    {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
    }
    
    if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
    {
        Print("Failed to close position ", ticket, ": ", GetTradeErrorDescription(result.retcode));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Close partial positions (configurable percentage)                |
//+------------------------------------------------------------------+
void ClosePartialPositions()
{
    int totalPositions = PositionsTotal();
    int closedCount = 0;
    double closeProfit = 0;
    
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    if(lotStep <= 0) lotStep = 0.01;
    
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double closePercent = MathMax(10.0, MathMin(90.0, PartialClosePercent)) / 100.0;
    
    for (int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        double currentVolume = PositionGetDouble(POSITION_VOLUME);
        double closeVolume = MathFloor((currentVolume * closePercent) / lotStep) * lotStep;
        double remainingVolume = currentVolume - closeVolume;
        
        // Ensure both close and remaining volumes meet minimum requirements
        if(closeVolume < minLot || remainingVolume < minLot) continue;
        
        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.volume = closeVolume;
        request.deviation = MaxSlippage;
        request.magic = MagicNumber;
        request.type_filling = GetFillingMode();
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
        }
        else
        {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
        }
        
        if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
        {
            closedCount++;
            closeProfit += PositionGetDouble(POSITION_PROFIT);
        }
        else
            Print("Failed to partial close position ", ticket, ": ", GetTradeErrorDescription(result.retcode));
    }
    
    TrackConsecutiveLosses(closeProfit);
    
    Print("Partial closed ", closedCount, " positions (", DoubleToString(closePercent * 100, 0), "%)");
}

//+------------------------------------------------------------------+
//| Track consecutive losses                                         |
//+------------------------------------------------------------------+
void TrackConsecutiveLosses(double profit)
{
    if(profit < -0.01) // Use small threshold to avoid floating point issues
    {
        ConsecutiveLosses++;
        if(EnableTradeJournal)
            LogToFile("ConsecutiveLoss", "INC", IntegerToString(ConsecutiveLosses));
    }
    else if(profit > 0.01)
    {
        if(ConsecutiveLosses > 0)
        {
            if(EnableTradeJournal)
                LogToFile("ConsecutiveLoss", "RESET", IntegerToString(ConsecutiveLosses) + " -> 0");
        }
        ConsecutiveLosses = 0;
    }
}

//+------------------------------------------------------------------+
//| Modify Stop Loss for all open positions                          |
//+------------------------------------------------------------------+
void ModifyAllSL()
{
    int modified = 0;
    double slPips, tpPips;
    GetATRBasedSLTP(slPips, tpPips);
    double pipValue = GetPipValue();
    
    // If user clicks SET SL, apply current ATR/pip SL to all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentTP = PositionGetDouble(POSITION_TP);
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        double newSL = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            newSL = NormalizeDouble(ask - slPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        else
            newSL = NormalizeDouble(bid + slPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        
        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = Symbol();
        request.sl = newSL;
        request.tp = currentTP;
        
        if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
            modified++;
    }
    
    Print("Modified SL for ", modified, " positions");
}

//+------------------------------------------------------------------+
//| Modify Take Profit for all open positions                        |
//+------------------------------------------------------------------+
void ModifyAllTP()
{
    int modified = 0;
    double slPips, tpPips;
    GetATRBasedSLTP(slPips, tpPips);
    double pipValue = GetPipValue();
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        double newTP = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            newTP = NormalizeDouble(ask + tpPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        else
            newTP = NormalizeDouble(bid - tpPips * pipValue, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        
        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.symbol = Symbol();
        request.sl = currentSL;
        request.tp = newTP;
        
        if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
            modified++;
    }
    
    Print("Modified TP for ", modified, " positions");
}

//+------------------------------------------------------------------+
//| Apply trailing stop to open positions                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
    if(TrailingStopPips <= 0 || TrailingStepPips <= 0) return;
    
    double pipValue = GetPipValue();
    double trailingStop = TrailingStopPips * pipValue;
    double trailingStep = TrailingStepPips * pipValue;
    double activationDist = (TrailingActivationPips > 0) ? (TrailingActivationPips * pipValue) : 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        double newSL = 0;
        bool modify = false;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            // If activation distance is set, check if price has moved enough
            if(activationDist > 0 && (bid - openPrice) < activationDist)
                continue;
            
            // Calculate new trailing stop
            newSL = NormalizeDouble(bid - trailingStop, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
            
            // Only modify if new SL is better than current SL by at least trailing step
            if(newSL > currentSL + trailingStep || currentSL == 0)
            {
                modify = true;
            }
        }
        else // SELL
        {
            if(activationDist > 0 && (openPrice - ask) < activationDist)
                continue;
            
            newSL = NormalizeDouble(ask + trailingStop, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
            
            if(newSL < currentSL - trailingStep || currentSL == 0)
            {
                modify = true;
            }
        }
        
        if(modify && newSL > 0)
        {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = Symbol();
            request.sl = newSL;
            request.tp = currentTP;
            
            if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
            {
                Print("Trailing stop failed for position ", ticket, ": ", GetTradeErrorDescription(result.retcode));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply break-even to open positions                               |
//+------------------------------------------------------------------+
void ApplyBreakEven()
{
    if(BreakEvenPips <= 0 || BreakEvenProfitPips <= 0) return;
    
    double pipValue = GetPipValue();
    double breakEvenTrigger = BreakEvenPips * pipValue;
    double breakEvenProfit = BreakEvenProfitPips * pipValue;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        
        double newSL = 0;
        bool modify = false;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            if(bid - openPrice >= breakEvenTrigger)
            {
                newSL = NormalizeDouble(openPrice + breakEvenProfit, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
                
                if(currentSL < newSL)
                {
                    modify = true;
                }
            }
        }
        else // SELL
        {
            if(openPrice - ask >= breakEvenTrigger)
            {
                newSL = NormalizeDouble(openPrice - breakEvenProfit, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
                
                if(currentSL > newSL || currentSL == 0)
                {
                    modify = true;
                }
            }
        }
        
        if(modify && newSL > 0)
        {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = Symbol();
            request.sl = newSL;
            request.tp = currentTP;
            
            if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
            {
                Print("Break-even failed for position ", ticket, ": ", GetTradeErrorDescription(result.retcode));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check and close positions on opposite signal                     |
//+------------------------------------------------------------------+
void CheckCloseOnOppositeSignal()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!IsOurPosition(ticket))
            continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        // If we have a BUY and get a strong SELL signal, close the BUY
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
           currentAnalysis.sellSignal && currentAnalysis.sellStrength >= SIGNAL_STRONG)
        {
            if(ClosePosition(ticket))
            {
                TrackConsecutiveLosses(profit);
                Print("Closed BUY position ", ticket, " due to opposite signal");
            }
        }
        // If we have a SELL and get a strong BUY signal, close the SELL
        else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                currentAnalysis.buySignal && currentAnalysis.buyStrength >= SIGNAL_STRONG)
        {
            if(ClosePosition(ticket))
            {
                TrackConsecutiveLosses(profit);
                Print("Closed SELL position ", ticket, " due to opposite signal");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize trade journal file                                    |
//+------------------------------------------------------------------+
void InitJournal()
{
    int handle = FileOpen(JournalFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(handle != INVALID_HANDLE)
    {
        FileWrite(handle, "Time", "Symbol", "Action", "Lot", "Price", "SL", "TP", 
                  "Magic", "Profit", "Balance", "SignalStrength", "Trend", "Comment");
        FileClose(handle);
        Print("Trade journal initialized: ", JournalFileName);
    }
    else
        Print("Failed to create journal file: ", JournalFileName, " Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Log trade to file journal                                        |
//+------------------------------------------------------------------+
void LogTrade(string action)
{
    if(!EnableTradeJournal) return;
    
    int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open journal file for logging: ", JournalFileName);
        return;
    }
    
    if(FileSeek(handle, 0, SEEK_END))
    {
        // Build a log entry with available data
        string timeStr = TimeToString(TimeCurrent());
        string symbol = Symbol();
        double lot = UseAutoLot ? CalculateAutoLot() : LotSize;
        string trendStr = EnumToString(currentAnalysis.trend);
        double signalVal = SignalStrength;
        
        FileWrite(handle, timeStr, symbol, action, DoubleToString(lot, 2),
                  "", "", "", "0", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
                  DoubleToString(signalVal, 1), trendStr, "manual");
    }
    else
    {
        Print("Failed to seek in journal file");
    }
    
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Write arbitrary info to journal file                             |
//+------------------------------------------------------------------+
void LogToFile(string category, string action, string detail)
{
    if(!EnableTradeJournal) return;
    
    int handle = FileOpen(JournalFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open journal file for logging: ", JournalFileName);
        return;
    }
    
    if(FileSeek(handle, 0, SEEK_END))
    {
        string timeStr = TimeToString(TimeCurrent());
        FileWrite(handle, timeStr, Symbol(), category, "", "", "", "", "", 
                  DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
                  DoubleToString(SignalStrength, 1), action, detail);
    }
    else
    {
        Print("Failed to seek in journal file");
    }
    
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Get trade error description                                      |
//+------------------------------------------------------------------+
string GetTradeErrorDescription(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_REQUOTE:           return "Requote";
        case TRADE_RETCODE_REJECT:            return "Request rejected";
        case TRADE_RETCODE_CANCEL:            return "Request canceled by trader";
        case TRADE_RETCODE_PLACED:            return "Order placed";
        case TRADE_RETCODE_DONE:              return "Request completed";
        case TRADE_RETCODE_DONE_PARTIAL:      return "Only part of the request was completed";
        case TRADE_RETCODE_ERROR:             return "Request processing error";
        case TRADE_RETCODE_TIMEOUT:           return "Request canceled by timeout";
        case TRADE_RETCODE_INVALID:           return "Invalid request";
        case TRADE_RETCODE_INVALID_VOLUME:    return "Invalid volume in the request";
        case TRADE_RETCODE_INVALID_PRICE:     return "Invalid price in the request";
        case TRADE_RETCODE_INVALID_STOPS:     return "Invalid stops in the request";
        case TRADE_RETCODE_TRADE_DISABLED:    return "Trade is disabled";
        case TRADE_RETCODE_MARKET_CLOSED:     return "Market is closed";
        case TRADE_RETCODE_NO_MONEY:          return "There is not enough money to complete the request";
        case TRADE_RETCODE_PRICE_CHANGED:     return "Prices changed";
        case TRADE_RETCODE_PRICE_OFF:         return "There are no quotes to process the request";
        case TRADE_RETCODE_INVALID_EXPIRATION:return "Invalid order expiration date in the request";
        case TRADE_RETCODE_ORDER_CHANGED:     return "Order state changed";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too frequent requests";
        case TRADE_RETCODE_NO_CHANGES:        return "No changes in request";
        case TRADE_RETCODE_SERVER_DISABLES_AT:return "Autotrading disabled by server";
        case TRADE_RETCODE_CLIENT_DISABLES_AT:return "Autotrading disabled by client terminal";
        case TRADE_RETCODE_LOCKED:            return "Request locked for processing";
        case TRADE_RETCODE_FROZEN:            return "Order or position frozen";
        case TRADE_RETCODE_INVALID_FILL:      return "Invalid order filling type";
        case TRADE_RETCODE_CONNECTION:        return "No connection with the trade server";
        case TRADE_RETCODE_ONLY_REAL:         return "Operation is allowed only for live accounts";
        case TRADE_RETCODE_LIMIT_ORDERS:      return "The number of pending orders has reached the limit";
        case TRADE_RETCODE_LIMIT_VOLUME:      return "Volume limit for this symbol has been reached";
        case TRADE_RETCODE_INVALID_ORDER:     return "Incorrect or prohibited order type";
        case TRADE_RETCODE_POSITION_CLOSED:   return "Position already closed";
        default:                              return "Unknown error (" + IntegerToString(retcode) + ")";
    }
}

//+------------------------------------------------------------------+
//| Delete all panel objects                                         |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    string namesToDelete[] = 
    {
        "BackgroundPanel", "TitleLabel",
        "TrendDirectionLabel", "TrendStrengthLabel", "ADXLabel",
        "BuyButton", "SellButton", "CloseAllButton",
        "CloseBuysButton", "CloseSellsButton", "ClosePartialButton",
        "ModifySLButton", "ModifyTPButton", "MinimizeButton",
        "SignalStrengthBar", "SignalStrengthLabel", "SignalStrengthFill",
        "BuySignalLabel", "SellSignalLabel", "RSILabel", "MACDLabel", "ATRLabel",
        "RecommendationLabel",
        "ProfitFactorLabel", "WinRateLabel", "AccountBalanceLabel",
        "LotSizeLabel", "SpreadLabel", "PositionCountLabel", "TotalProfitLabel",
        "DailyTradesLabel", "DailyProfitLabel",
        "TrailingStatusLabel", "BreakEvenStatusLabel", "FilterStatusLabel",
        "ConsecutiveLossLabel", "MarketStatusLabel", "NewsStatusLabel"
    };
    
    for(int i = 0; i < ArraySize(namesToDelete); i++)
    {
        if(ObjectFind(0, namesToDelete[i]) >= 0)
            ObjectDelete(0, namesToDelete[i]);
    }
}

//+------------------------------------------------------------------+
//| Function to create the trade panel                               |
//+------------------------------------------------------------------+
bool CreateTradePanel()
{
    DeleteAllObjects();
    
    if (!CreateBackgroundPanel()) return false;
    if (!CreateTitleLabel()) return false;
    
    if(PanelMinimized)
    {
        // For minimized panel, only show title + minimize button
        if (!CreateMinimizedButton()) return false;
    }
    else
    {
        if (!CreateTrendSection()) return false;
        if (!CreateButtons()) return false;
        if (!CreateSignalStrengthBar()) return false;
        if (!CreateSignalIndicators()) return false;
        if (!CreateLabels()) return false;
        if (!CreateRecommendationLabel()) return false;
        if (!CreateModifyButtons()) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create Background Panel                                  |
//+------------------------------------------------------------------+
bool CreateBackgroundPanel()
{
    string objName = "BackgroundPanel";
    if (!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", objName, ". Error: ", GetLastError());
        return false;
    }
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 5);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, PanelMinimized ? 210 : 400);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, PanelMinimized ? 40 : 370);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, PanelBgColor);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create Title Label                                       |
//+------------------------------------------------------------------+
bool CreateTitleLabel()
{
    string objName = "TitleLabel";
    if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", objName);
        return false;
    }
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 15);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, objName, OBJPROP_TEXT, "GoldScalp v8.0 - " + Symbol());
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkBlue);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FontSize + 1);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 1);
    return true;
}

//+------------------------------------------------------------------+
//| Create trend indicator section                                   |
//+------------------------------------------------------------------+
bool CreateTrendSection()
{
    if (!CreateLabel("TrendDirectionLabel", "Trend: --", 10, 35)) return false;
    if (!CreateLabel("TrendStrengthLabel", "Strength: --", 160, 35)) return false;
    if (!CreateLabel("ADXLabel", "ADX: --", 280, 35)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create Buttons                                           |
//+------------------------------------------------------------------+
bool CreateButtons()
{
    if (!CreateButton("BuyButton", "BUY", 10, 60, 120, 35, clrDarkGray, clrGray)) return false;
    if (!CreateButton("SellButton", "SELL", 140, 60, 120, 35, clrDarkGray, clrGray)) return false;
    if (!CreateButton("CloseAllButton", "CLOSE ALL", 270, 60, 120, 35, clrDarkBlue, clrWhite)) return false;
    if (!CreateButton("CloseBuysButton", "CLOSE BUYS", 10, 100, 120, 25, clrMediumSeaGreen, clrWhite)) return false;
    if (!CreateButton("CloseSellsButton", "CLOSE SELLS", 140, 100, 120, 25, clrIndianRed, clrWhite)) return false;
    if (!CreateButton("ClosePartialButton", "CLOSE %", 270, 100, 120, 25, clrDarkOrange, clrWhite)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Create modify SL/TP buttons                                      |
//+------------------------------------------------------------------+
bool CreateModifyButtons()
{
    if (!CreateButton("ModifySLButton", "SET SL", 10, 335, 90, 25, clrDarkGray, clrWhite)) return false;
    if (!CreateButton("ModifyTPButton", "SET TP", 110, 335, 90, 25, clrDarkGray, clrWhite)) return false;
    if (!CreateButton("MinimizeButton", PanelMinimized ? "[+]" : "[-]", 360, 8, 30, 22, clrDimGray, clrWhite)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Create minimize/maximize button for collapsed view              |
//+------------------------------------------------------------------+
bool CreateMinimizedButton()
{
    if (!CreateButton("MinimizeButton", PanelMinimized ? "[+]" : "[-]", 360, 8, 30, 22, clrDimGray, clrWhite)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create a Button                                          |
//+------------------------------------------------------------------+
bool CreateButton(string name, string text, int x, int y, int width, int height, color bgColor, color textColor)
{
    if (!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
    {
        Print("Failed to create button: ", name);
        return false;
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create Signal Strength Bar                               |
//+------------------------------------------------------------------+
bool CreateSignalStrengthBar()
{
    // Outer bar (background)
    string barName = "SignalStrengthBar";
    if (!ObjectCreate(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", barName);
        return false;
    }
    ObjectSetInteger(0, barName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, barName, OBJPROP_YDISTANCE, 140);
    ObjectSetInteger(0, barName, OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, barName, OBJPROP_YSIZE, 22);
    ObjectSetInteger(0, barName, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, barName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, barName, OBJPROP_ZORDER, 1);
    
    // Signal strength label
    string labelName = "SignalStrengthLabel";
    if (!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", labelName);
        return false;
    }
    ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 270);
    ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 142);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "Signal: 50%");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize - 1);
    ObjectSetInteger(0, labelName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 2);

    // Inner fill (progress)
    string fillName = "SignalStrengthFill";
    if (!ObjectCreate(0, fillName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", fillName);
        return false;
    }
    ObjectSetInteger(0, fillName, OBJPROP_XDISTANCE, 11);
    ObjectSetInteger(0, fillName, OBJPROP_YDISTANCE, 141);
    ObjectSetInteger(0, fillName, OBJPROP_XSIZE, (int)(SignalStrength * 2.48));
    ObjectSetInteger(0, fillName, OBJPROP_YSIZE, 20);
    ObjectSetInteger(0, fillName, OBJPROP_BGCOLOR, GetSignalColor(SignalStrength));
    ObjectSetInteger(0, fillName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, fillName, OBJPROP_ZORDER, 3);
    ObjectSetInteger(0, fillName, OBJPROP_BORDER_TYPE, BORDER_FLAT);

    return true;
}

//+------------------------------------------------------------------+
//| Create signal indicators section                                 |
//+------------------------------------------------------------------+
bool CreateSignalIndicators()
{
    if (!CreateLabel("BuySignalLabel", "Buy Signal: --", 10, 170)) return false;
    if (!CreateLabel("SellSignalLabel", "Sell Signal: --", 10, 190)) return false;
    if (!CreateLabel("RSILabel", "RSI: --", 160, 170)) return false;
    if (!CreateLabel("MACDLabel", "MACD: --", 160, 190)) return false;
    if (!CreateLabel("ATRLabel", "ATR: --", 280, 190)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Create recommendation label                                      |
//+------------------------------------------------------------------+
bool CreateRecommendationLabel()
{
    string objName = "RecommendationLabel";
    if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create ", objName);
        return false;
    }
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 215);
    ObjectSetString(0, objName, OBJPROP_TEXT, "Recommendation: NO TRADE");
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FontSize + 2);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create Labels                                            |
//+------------------------------------------------------------------+
bool CreateLabels()
{
    if (!CreateLabel("ProfitFactorLabel", "Profit Factor: --", 10, 245)) return false;
    if (!CreateLabel("WinRateLabel", "Win Rate: --", 150, 245)) return false;
    if (!CreateLabel("AccountBalanceLabel", "Balance: --", 280, 245)) return false;
    if (!CreateLabel("LotSizeLabel", "Lot Size: --", 10, 262)) return false;
    if (!CreateLabel("SpreadLabel", "Spread: --", 150, 262)) return false;
    if (!CreateLabel("PositionCountLabel", "Positions: 0", 10, 279)) return false;
    if (!CreateLabel("TotalProfitLabel", "Profit: $0.00", 150, 279)) return false;
    if (!CreateLabel("DailyTradesLabel", "Daily: 0 trades", 280, 262)) return false;
    if (!CreateLabel("DailyProfitLabel", "Daily P/L: $0.00", 280, 279)) return false;
    if (!CreateLabel("TrailingStatusLabel", "TS: OFF", 10, 296)) return false;
    if (!CreateLabel("BreakEvenStatusLabel", "BE: OFF", 120, 296)) return false;
    if (!CreateLabel("FilterStatusLabel", "Filters: OK", 240, 296)) return false;
    if (!CreateLabel("ConsecutiveLossLabel", "CL: 0", 350, 296)) return false;
    if (!CreateLabel("MarketStatusLabel", "Mkt: OPEN", 10, 313)) return false;
    if (!CreateLabel("NewsStatusLabel", "News: SAFE", 150, 313)) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Helper: Create a Label                                           |
//+------------------------------------------------------------------+
bool CreateLabel(string name, string prefix, int x, int y)
{
    if (!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        Print("Failed to create label: ", name);
        return false;
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, prefix);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    return true;
}

//+------------------------------------------------------------------+
//| Update trend indicator display                                   |
//+------------------------------------------------------------------+
void UpdateTrendIndicator()
{
    string trendText = "Trend: ";
    color trendColor = clrBlack;
    
    switch(currentAnalysis.trend)
    {
        case TREND_UP:
            trendText += "▲ UP";
            trendColor = clrGreen;
            break;
        case TREND_DOWN:
            trendText += "▼ DOWN";
            trendColor = clrRed;
            break;
        case TREND_SIDEWAYS:
            trendText += "↔ SIDEWAYS";
            trendColor = clrOrange;
            break;
        default:
            trendText += "UNKNOWN";
            trendColor = clrGray;
    }
    
    ObjectSetString(0, "TrendDirectionLabel", OBJPROP_TEXT, trendText);
    ObjectSetInteger(0, "TrendDirectionLabel", OBJPROP_COLOR, trendColor);
    
    string strengthText = "Strength: " + DoubleToString(currentAnalysis.trendStrength, 1);
    ObjectSetString(0, "TrendStrengthLabel", OBJPROP_TEXT, strengthText);
    
    if(UseADX && ArraySize(adx) >= 3)
    {
        string adxText = "ADX: " + DoubleToString(adx[0], 1);
        ObjectSetString(0, "ADXLabel", OBJPROP_TEXT, adxText);
        ObjectSetInteger(0, "ADXLabel", OBJPROP_COLOR, adx[0] > ADX_Threshold ? clrGreen : clrRed);
    }
}

//+------------------------------------------------------------------+
//| Update signal indicators display                                 |
//+------------------------------------------------------------------+
void UpdateSignalIndicators()
{
    // Buy signal
    string buySignalText = "Buy Signal: ";
    color buyColor = clrGray;
    
    switch(currentAnalysis.buyStrength)
    {
        case SIGNAL_VERY_STRONG:
            buySignalText += "★★★★";
            buyColor = clrGreen;
            break;
        case SIGNAL_STRONG:
            buySignalText += "★★★";
            buyColor = clrGreen;
            break;
        case SIGNAL_MODERATE:
            buySignalText += "★★";
            buyColor = clrOrange;
            break;
        default:
            buySignalText += "★";
            buyColor = clrGray;
    }
    
    ObjectSetString(0, "BuySignalLabel", OBJPROP_TEXT, buySignalText);
    ObjectSetInteger(0, "BuySignalLabel", OBJPROP_COLOR, buyColor);
    
    // Sell signal
    string sellSignalText = "Sell Signal: ";
    color sellColor = clrGray;
    
    switch(currentAnalysis.sellStrength)
    {
        case SIGNAL_VERY_STRONG:
            sellSignalText += "★★★★";
            sellColor = clrRed;
            break;
        case SIGNAL_STRONG:
            sellSignalText += "★★★";
            sellColor = clrRed;
            break;
        case SIGNAL_MODERATE:
            sellSignalText += "★★";
            sellColor = clrOrange;
            break;
        default:
            sellSignalText += "★";
            sellColor = clrGray;
    }
    
    ObjectSetString(0, "SellSignalLabel", OBJPROP_TEXT, sellSignalText);
    ObjectSetInteger(0, "SellSignalLabel", OBJPROP_COLOR, sellColor);
    
    // RSI
    if(UseRSI && ArraySize(rsi) >= 3)
    {
        string rsiText = "RSI: " + DoubleToString(rsi[0], 1);
        color rsiColor = (rsi[0] > RSI_Overbought) ? clrRed : 
                         (rsi[0] < RSI_Oversold) ? clrGreen : clrBlack;
        ObjectSetString(0, "RSILabel", OBJPROP_TEXT, rsiText);
        ObjectSetInteger(0, "RSILabel", OBJPROP_COLOR, rsiColor);
    }
    
    // MACD
    if(UseMACD && ArraySize(macdMain) >= 3 && ArraySize(macdSignal) >= 3)
    {
        string macdText = "MACD: " + DoubleToString(macdMain[0] - macdSignal[0], 5);
        color macdColor = (macdMain[0] > macdSignal[0]) ? clrGreen : clrRed;
        ObjectSetString(0, "MACDLabel", OBJPROP_TEXT, macdText);
        ObjectSetInteger(0, "MACDLabel", OBJPROP_COLOR, macdColor);
    }
    
    // ATR
    if(UseATRforSLTP && ArraySize(atrBuffer) >= 3 && atrBuffer[0] != EMPTY_VALUE)
    {
        string atrText = "ATR: " + DoubleToString(atrBuffer[0], (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
        ObjectSetString(0, "ATRLabel", OBJPROP_TEXT, atrText);
    }
    
    UpdateButtonColors();
}

//+------------------------------------------------------------------+
//| Update button colors based on signals                            |
//+------------------------------------------------------------------+
void UpdateButtonColors()
{
    // BUY button
    if(currentAnalysis.buySignal && currentAnalysis.buyStrength >= SIGNAL_VERY_STRONG)
    {
        ObjectSetInteger(0, "BuyButton", OBJPROP_BGCOLOR, clrLime);
        ObjectSetInteger(0, "BuyButton", OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, "BuyButton", OBJPROP_BORDER_COLOR, clrGreen);
    }
    else if(currentAnalysis.buySignal && currentAnalysis.buyStrength == SIGNAL_STRONG)
    {
        ObjectSetInteger(0, "BuyButton", OBJPROP_BGCOLOR, clrGreen);
        ObjectSetInteger(0, "BuyButton", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "BuyButton", OBJPROP_BORDER_COLOR, clrBlack);
    }
    else if(currentAnalysis.buySignal && currentAnalysis.buyStrength == SIGNAL_MODERATE)
    {
        ObjectSetInteger(0, "BuyButton", OBJPROP_BGCOLOR, clrMediumSeaGreen);
        ObjectSetInteger(0, "BuyButton", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "BuyButton", OBJPROP_BORDER_COLOR, clrBlack);
    }
    else
    {
        ObjectSetInteger(0, "BuyButton", OBJPROP_BGCOLOR, clrDarkGray);
        ObjectSetInteger(0, "BuyButton", OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, "BuyButton", OBJPROP_BORDER_COLOR, clrGray);
    }
    
    // SELL button
    if(currentAnalysis.sellSignal && currentAnalysis.sellStrength >= SIGNAL_VERY_STRONG)
    {
        ObjectSetInteger(0, "SellButton", OBJPROP_BGCOLOR, clrTomato);
        ObjectSetInteger(0, "SellButton", OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, "SellButton", OBJPROP_BORDER_COLOR, clrRed);
    }
    else if(currentAnalysis.sellSignal && currentAnalysis.sellStrength == SIGNAL_STRONG)
    {
        ObjectSetInteger(0, "SellButton", OBJPROP_BGCOLOR, clrRed);
        ObjectSetInteger(0, "SellButton", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "SellButton", OBJPROP_BORDER_COLOR, clrBlack);
    }
    else if(currentAnalysis.sellSignal && currentAnalysis.sellStrength == SIGNAL_MODERATE)
    {
        ObjectSetInteger(0, "SellButton", OBJPROP_BGCOLOR, clrIndianRed);
        ObjectSetInteger(0, "SellButton", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "SellButton", OBJPROP_BORDER_COLOR, clrBlack);
    }
    else
    {
        ObjectSetInteger(0, "SellButton", OBJPROP_BGCOLOR, clrDarkGray);
        ObjectSetInteger(0, "SellButton", OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, "SellButton", OBJPROP_BORDER_COLOR, clrGray);
    }
}

//+------------------------------------------------------------------+
//| Update trade recommendation display                              |
//+------------------------------------------------------------------+
void UpdateTradeRecommendation()
{
    string recText = "Recommendation: " + currentAnalysis.recommendation;
    color recColor = clrGray;
    
    if(StringFind(currentAnalysis.recommendation, "STRONG BUY") >= 0)
        recColor = clrGreen;
    else if(StringFind(currentAnalysis.recommendation, "BUY") >= 0)
        recColor = clrDarkGreen;
    else if(StringFind(currentAnalysis.recommendation, "STRONG SELL") >= 0)
        recColor = clrRed;
    else if(StringFind(currentAnalysis.recommendation, "SELL") >= 0)
        recColor = clrDarkRed;
    else if(StringFind(currentAnalysis.recommendation, "WAIT") >= 0)
        recColor = clrOrange;
    else if(StringFind(currentAnalysis.recommendation, "LIMIT") >= 0)
        recColor = clrPurple;
    else if(StringFind(currentAnalysis.recommendation, "CLOSED") >= 0 ||
            StringFind(currentAnalysis.recommendation, "BLOCK") >= 0 ||
            StringFind(currentAnalysis.recommendation, "COOLDOWN") >= 0)
        recColor = clrPurple;
    
    ObjectSetString(0, "RecommendationLabel", OBJPROP_TEXT, recText);
    ObjectSetInteger(0, "RecommendationLabel", OBJPROP_COLOR, recColor);
}

//+------------------------------------------------------------------+
//| Update signal strength bar                                       |
//+------------------------------------------------------------------+
void UpdateSignalStrengthBar()
{
    double strength = CalculateOverallStrength();
    SignalStrength = strength;
    
    int barWidth = (int)(strength * 2.48);
    if(barWidth < 0) barWidth = 0;
    if(barWidth > 248) barWidth = 248;
    
    ObjectSetInteger(0, "SignalStrengthFill", OBJPROP_XSIZE, barWidth);
    
    color barColor;
    if(currentAnalysis.trend == TREND_UP)
        barColor = GetSignalColor(strength);
    else if(currentAnalysis.trend == TREND_DOWN)
        barColor = GetSignalColor(100 - strength);
    else
        barColor = clrYellow;
    
    ObjectSetInteger(0, "SignalStrengthFill", OBJPROP_BGCOLOR, barColor);
    ObjectSetString(0, "SignalStrengthLabel", OBJPROP_TEXT, 
                   "Signal: " + IntegerToString((int)strength) + "%");
}

//+------------------------------------------------------------------+
//| Calculate overall signal strength                                |
//+------------------------------------------------------------------+
double CalculateOverallStrength()
{
    double strength = 50;
    
    if(currentAnalysis.trend == TREND_UP)
        strength += MathMin(20, currentAnalysis.trendStrength * 0.2);
    else if(currentAnalysis.trend == TREND_DOWN)
        strength -= MathMin(20, currentAnalysis.trendStrength * 0.2);
    
    if(currentAnalysis.buyStrength >= SIGNAL_VERY_STRONG) strength += 25;
    else if(currentAnalysis.buyStrength == SIGNAL_STRONG) strength += 20;
    else if(currentAnalysis.buyStrength == SIGNAL_MODERATE) strength += 10;
    
    if(currentAnalysis.sellStrength >= SIGNAL_VERY_STRONG) strength -= 25;
    else if(currentAnalysis.sellStrength == SIGNAL_STRONG) strength -= 20;
    else if(currentAnalysis.sellStrength == SIGNAL_MODERATE) strength -= 10;
    
    if(UseRSI && ArraySize(rsi) >= 3)
    {
        if(rsi[0] < RSI_Oversold) strength += 10;
        else if(rsi[0] > RSI_Overbought) strength -= 10;
    }
    
    if(UseMACD && ArraySize(macdMain) >= 3 && ArraySize(macdSignal) >= 3)
    {
        double macdDiff = macdMain[0] - macdSignal[0];
        strength += MathMin(10, MathAbs(macdDiff) * 1000) * (macdDiff > 0 ? 1 : -1);
    }
    
    return NormalizeDouble(MathMax(0, MathMin(100, strength)), 1);
}

//+------------------------------------------------------------------+
//| Get color based on signal strength                               |
//+------------------------------------------------------------------+
color GetSignalColor(double strength)
{
    if(strength >= 70) return clrLime;
    if(strength >= 40) return clrYellow;
    if(strength >= 20) return clrOrange;
    return clrRed;
}

//+------------------------------------------------------------------+
//| Update profit factor display                                     |
//+------------------------------------------------------------------+
void UpdateProfitFactor()
{
    ObjectSetString(0, "ProfitFactorLabel", OBJPROP_TEXT, 
        "Profit Factor: " + DoubleToString(ProfitFactor, 2));
    
    color pfColor = (ProfitFactor >= 1.5) ? clrGreen : 
                    (ProfitFactor >= 1.0) ? clrOrange : clrRed;
    ObjectSetInteger(0, "ProfitFactorLabel", OBJPROP_COLOR, pfColor);
}

//+------------------------------------------------------------------+
//| Update win rate display                                          |
//+------------------------------------------------------------------+
void UpdateWinRate()
{
    ObjectSetString(0, "WinRateLabel", OBJPROP_TEXT, 
        "Win Rate: " + DoubleToString(WinRate, 1) + "%");
    
    color wrColor = (WinRate >= 60) ? clrGreen : 
                    (WinRate >= 40) ? clrOrange : clrRed;
    ObjectSetInteger(0, "WinRateLabel", OBJPROP_COLOR, wrColor);
}

//+------------------------------------------------------------------+
//| Update lot size display                                          |
//+------------------------------------------------------------------+
void UpdateLotSizeDisplay()
{
    double currentLot = UseAutoLot ? CalculateAutoLot() : LotSize;
    ObjectSetString(0, "LotSizeLabel", OBJPROP_TEXT, 
        "Lot Size: " + DoubleToString(currentLot, 2));
    
    ObjectSetString(0, "AccountBalanceLabel", OBJPROP_TEXT, 
        "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    
    // Cache spread calculation
    static double lastSpreadPips = -1;
    static datetime lastSpreadTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Only recalculate spread every 5 seconds to reduce overhead
    if(currentTime - lastSpreadTime >= 5 || lastSpreadPips < 0)
    {
        lastSpreadPips = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID)) / GetPipValue();
        lastSpreadTime = currentTime;
    }
    
    ObjectSetString(0, "SpreadLabel", OBJPROP_TEXT, 
        "Spread: " + DoubleToString(lastSpreadPips, 1) + " pips");
}

//+------------------------------------------------------------------+
//| Update position info display                                     |
//+------------------------------------------------------------------+
void UpdatePositionInfo()
{
    int buyCount = 0, sellCount = 0;
    double totalProfit = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!IsOurPosition(ticket))
            continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT) + 
                       PositionGetDouble(POSITION_SWAP);
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buyCount++;
        else
            sellCount++;
        
        totalProfit += profit;
    }
    
    int totalCount = buyCount + sellCount;
    ObjectSetString(0, "PositionCountLabel", OBJPROP_TEXT, 
        StringFormat("Positions: %d (B:%d S:%d)", totalCount, buyCount, sellCount));
    
    color profitColor = (totalProfit > 0) ? clrGreen : (totalProfit < 0) ? clrRed : clrBlack;
    ObjectSetString(0, "TotalProfitLabel", OBJPROP_TEXT, 
        "Profit: $" + DoubleToString(totalProfit, 2));
    ObjectSetInteger(0, "TotalProfitLabel", OBJPROP_COLOR, profitColor);
    
    // Update trailing stop and break-even status
    ObjectSetString(0, "TrailingStatusLabel", OBJPROP_TEXT, 
        "TS: " + (UseTrailingStop ? "ON" : "OFF"));
    ObjectSetInteger(0, "TrailingStatusLabel", OBJPROP_COLOR, 
        UseTrailingStop ? clrGreen : clrGray);
    
    ObjectSetString(0, "BreakEvenStatusLabel", OBJPROP_TEXT, 
        "BE: " + (UseBreakEven ? "ON" : "OFF"));
    ObjectSetInteger(0, "BreakEvenStatusLabel", OBJPROP_COLOR, 
        UseBreakEven ? clrGreen : clrGray);
    
    // Update filter status
    string filterStatus = "Filters: ";
    if(UseMarketHoursFilter && !currentAnalysis.marketOpen)
        filterStatus += "MKT CLOSED";
    else if(UseMaxSpreadFilter && !currentAnalysis.spreadOk)
        filterStatus += "HIGH SPRD";
    else if(UseNewsFilter && !currentAnalysis.newsOk)
        filterStatus += "NEWS BLK";
    else
        filterStatus += "ALL OK";
    ObjectSetString(0, "FilterStatusLabel", OBJPROP_TEXT, filterStatus);
    
    // Update consecutive loss counter
    if(MaxConsecutiveLosses > 0)
        ObjectSetString(0, "ConsecutiveLossLabel", OBJPROP_TEXT, 
            "CL: " + IntegerToString(ConsecutiveLosses) + "/" + IntegerToString(MaxConsecutiveLosses));
    
    // Update market/status labels using cached values from AnalyzeMarket
    ObjectSetString(0, "MarketStatusLabel", OBJPROP_TEXT, 
        "Mkt: " + string(currentAnalysis.marketOpen ? "OPEN" : "CLOSED"));
    ObjectSetString(0, "NewsStatusLabel", OBJPROP_TEXT, 
        "News: " + string(currentAnalysis.newsOk ? "SAFE" : "BLOCK"));
}

//+------------------------------------------------------------------+
//| Update daily stats display                                       |
//+------------------------------------------------------------------+
void UpdateDailyStats()
{
    ObjectSetString(0, "DailyTradesLabel", OBJPROP_TEXT, 
        StringFormat("Daily: %d trades", DailyTradeCount));
    
    color dailyColor = (DailyProfit > 0) ? clrGreen : (DailyProfit < 0) ? clrRed : clrBlack;
    ObjectSetString(0, "DailyProfitLabel", OBJPROP_TEXT, 
        "Daily P/L: $" + DoubleToString(DailyProfit, 2));
    ObjectSetInteger(0, "DailyProfitLabel", OBJPROP_COLOR, dailyColor);
}

//+------------------------------------------------------------------+
//| Calculate real statistics from trade history                     |
//+------------------------------------------------------------------+
void CalculateRealStatistics()
{
    double totalProfit = 0;
    double totalLoss = 0;
    int wins = 0;
    int losses = 0;
    int totalChecked = 0;
    
    // Select all history (limit to last 500 deals for performance)
    datetime startTime = TimeCurrent() - (180 * 24 * 60 * 60); // Last 6 months only
    if(!HistorySelect(startTime, TimeCurrent()))
        return;
    
    int totalDeals = HistoryDealsTotal();
    // Cap at 500 deals: prevents O(n) slowdown on accounts with large trade history
    // while still providing statistically meaningful results over the 6-month window.
    if(totalDeals > 500) totalDeals = 500;
    
    for(int i = 0; i < totalDeals; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket <= 0) continue;
        
        // Filter by magic number and symbol
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
            continue;
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol())
            continue;
        
        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                       HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                       HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        
        totalChecked++;
        
        // Only count exit deals for statistics
        if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
        {
            if(profit > 0)
            {
                totalProfit += profit;
                wins++;
            }
            else if(profit < 0)
            {
                totalLoss += MathAbs(profit);
                losses++;
            }
        }
    }
    
    // Calculate profit factor
    if(totalLoss > 0)
        ProfitFactor = NormalizeDouble(totalProfit / totalLoss, 2);
    else if(totalProfit > 0)
        ProfitFactor = 999.99; // No losses
    
    // Calculate win rate
    int totalTrades = wins + losses;
    if(totalTrades > 0)
        WinRate = NormalizeDouble((double)wins / totalTrades * 100, 1);
    
    // Calculate Sharpe Ratio (simplified: mean / stddev of per-trade returns)
    SharpeRatio = 0.0;
    if(totalTrades >= 2)
    {
        // Collect per-trade P&L for variance calculation
        double tradeReturns[];
        ArrayResize(tradeReturns, totalTrades);
        int idx = 0;
        double sumReturns = 0.0;
        
        int totalDealsAll = HistoryDealsTotal();
        if(totalDealsAll > 500) totalDealsAll = 500;
        
        for(int i = 0; i < totalDealsAll && idx < totalTrades; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket <= 0) continue;
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) != Symbol()) continue;
            
            ENUM_DEAL_ENTRY entry2 = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(entry2 != DEAL_ENTRY_OUT && entry2 != DEAL_ENTRY_INOUT) continue;
            
            double p = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                       HistoryDealGetDouble(ticket, DEAL_SWAP) +
                       HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            tradeReturns[idx] = p;
            sumReturns += p;
            idx++;
        }
        
        if(idx >= 2)
        {
            double mean = sumReturns / idx;
            double variance = 0.0;
            for(int j = 0; j < idx; j++)
                variance += (tradeReturns[j] - mean) * (tradeReturns[j] - mean);
            variance /= (idx - 1); // sample variance
            double stddev = MathSqrt(variance);
            if(stddev > 0.0)
                SharpeRatio = NormalizeDouble(mean / stddev, 2);
        }
    }
    
    Print("Statistics calculated from ", totalChecked, " deals - Trades: ", totalTrades, 
          ", Win Rate: ", DoubleToString(WinRate, 1), "%",
          ", Profit Factor: ", DoubleToString(ProfitFactor, 2),
          ", Sharpe Ratio: ", DoubleToString(SharpeRatio, 2));
    ConsecutiveLosses = 0; // Reset consecutive loss counter on init
}

//+------------------------------------------------------------------+
//| Calculate auto lot size based on risk                            |
//+------------------------------------------------------------------+
double CalculateAutoLot()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100;
    
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    
    if(tickValue <= 0 || tickSize <= 0 || point <= 0) return LotSize;
    
    // Calculate SL in points
    double slPoints;
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    if(digits == 3 || digits == 5)
        slPoints = AutoLotStopLossPips * 10;
    else
        slPoints = AutoLotStopLossPips;
    
    if(slPoints <= 0) return LotSize;
    
    // Calculate lot size
    double slValue = slPoints * point * tickValue / tickSize;
    if(slValue <= 0) return LotSize;
    
    double lotSize = riskAmount / slValue;
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    if(lotStep <= 0) lotStep = 0.01;
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = NormalizeDouble(lotSize, 2);
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Get pip size in points                                           |
//+------------------------------------------------------------------+
double GetPipSize()
{
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    return (digits == 3 || digits == 5) ? 10.0 : 1.0;
}

//+------------------------------------------------------------------+
//| Get pip value in price                                           |
//+------------------------------------------------------------------+
double GetPipValue()
{
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    return point * GetPipSize();
}

//+------------------------------------------------------------------+
//| Get ATR-based SL/TP values                                      |
//+------------------------------------------------------------------+
void GetATRBasedSLTP(double &slPips, double &tpPips)
{
    if(UseATRforSLTP && ArraySize(atrBuffer) >= 3 && atrBuffer[0] != EMPTY_VALUE && atrBuffer[0] > 0)
    {
        double atrValue = atrBuffer[0];
        double pipValue = GetPipValue();
        slPips = NormalizeDouble((int)(atrValue * ATR_SL_Multiplier / pipValue), 0);
        tpPips = NormalizeDouble((int)(atrValue * ATR_TP_Multiplier / pipValue), 0);
        
        // Apply minimum bound to SL only (TP has its own multiplier and must not be
        // artificially constrained by the SL minimum)
        if(ATR_MinSLPoints > 0 && slPips < ATR_MinSLPoints) slPips = ATR_MinSLPoints;
        
        // Apply maximum bounds independently for SL and TP
        if(ATR_MaxSLPoints > 0 && slPips > ATR_MaxSLPoints) slPips = ATR_MaxSLPoints;
        if(ATR_MaxSLPoints > 0 && tpPips > ATR_MaxSLPoints) tpPips = ATR_MaxSLPoints;
        
        // Fallback to fixed pips if clamped values are invalid
        if(slPips < 1) slPips = StopLossPips;
        if(tpPips < 1) tpPips = TakeProfitPips;
    }
    else
    {
        slPips = StopLossPips;
        tpPips = TakeProfitPips;
    }
}

//+------------------------------------------------------------------+
//| Calculate sell signal strength score (internal, no signal guard)|
//+------------------------------------------------------------------+
ENUM_SIGNAL_STRENGTH CalculateSellStrengthInternal()
{
    if(ArraySize(rsi) < 3 || ArraySize(macdMain) < 3 || ArraySize(macdSignal) < 3 || ArraySize(maFast) < 3 || ArraySize(maSlow) < 3)
        return SIGNAL_WEAK;
    
    int strengthScore = 0;
    double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Trend alignment (max 3 points)
    if(currentAnalysis.trend == TREND_DOWN) strengthScore += 3;
    else if(currentAnalysis.trend == TREND_SIDEWAYS) strengthScore += 1;
    
    // RSI analysis (max 3 points)
    if(UseRSI)
    {
        if(rsi[0] > 60 && rsi[0] < 70) strengthScore += 3; // Overbought reversal
        else if(rsi[0] > 50 && rsi[0] < 60) strengthScore += 2;
        else if(rsi[0] > 30 && rsi[0] < 50) strengthScore += 1;
    }
    
    // MACD momentum (max 3 points)
    if(UseMACD)
    {
        if(macdMain[0] < macdSignal[0] && macdMain[0] < 0 && macdMain[1] >= macdSignal[1])
            strengthScore += 3; // Bearish crossover below zero
        else if(macdMain[0] < macdSignal[0] && macdMain[0] < 0)
            strengthScore += 2;
        else if(macdMain[0] < macdSignal[0])
            strengthScore += 1;
    }
    
    // ADX strength (max 2 points)
    if(UseADX)
    {
        if(adx[0] > ADX_Threshold && adxMinus[0] > adxPlus[0]) strengthScore += 1;
        if(adx[0] > 40) strengthScore += 1;
    }
    
    // Bollinger Bands (max 2 points)
    if(UseBollingerBands && bbHandle != INVALID_HANDLE && ArraySize(bbUpper) >= 3)
    {
        if(price >= bbUpper[0]) strengthScore += 2; // Touching upper band
        else if(price > bbMiddle[0] && price < bbUpper[0]) strengthScore += 1;
    }
    
    // RSI divergence bonus (max 1 point)
    if(UseRSIDivergence && currentAnalysis.divergence == DIV_BEARISH) strengthScore += 1;
    
    // MTF confirmation bonus (max 1 point)
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_DOWN) strengthScore += 1;
    
    if(strengthScore >= 9) return SIGNAL_VERY_STRONG;
    if(strengthScore >= 6) return SIGNAL_STRONG;
    if(strengthScore >= 3) return SIGNAL_MODERATE;
    return SIGNAL_WEAK;
}

//+------------------------------------------------------------------+
//| Calculate sell signal strength                                   |
//+------------------------------------------------------------------+
ENUM_SIGNAL_STRENGTH CalculateSellStrength()
{
    if(!currentAnalysis.sellSignal)
        return SIGNAL_WEAK;
    
    return CalculateSellStrengthInternal();
}

//+------------------------------------------------------------------+
//| Generate trade recommendation                                    |
//+------------------------------------------------------------------+
string GenerateRecommendation()
{
    // Check daily limits
    if(MaxDailyTrades > 0 && DailyTradeCount >= MaxDailyTrades)
        return "DAILY LIMIT";
    if(MaxDailyLoss > 0 && DailyProfit <= -MaxDailyLoss)
        return "DAILY LOSS LIMIT";
    if(MaxConsecutiveLosses > 0 && ConsecutiveLosses >= MaxConsecutiveLosses)
        return "COOLDOWN";
    
    // Market filters override
    if(!currentAnalysis.marketOpen)
        return "MARKET CLOSED";
    if(!currentAnalysis.spreadOk)
        return "HIGH SPREAD";
    if(!currentAnalysis.newsOk)
        return "NEWS BLOCK";
    
    if(currentAnalysis.buySignal && currentAnalysis.buyStrength >= SIGNAL_VERY_STRONG)
        return "STRONG BUY";
    else if(currentAnalysis.buySignal && currentAnalysis.buyStrength == SIGNAL_STRONG)
        return "BUY";
    else if(currentAnalysis.buySignal && currentAnalysis.buyStrength == SIGNAL_MODERATE)
        return "WEAK BUY";
    else if(currentAnalysis.sellSignal && currentAnalysis.sellStrength >= SIGNAL_VERY_STRONG)
        return "STRONG SELL";
    else if(currentAnalysis.sellSignal && currentAnalysis.sellStrength == SIGNAL_STRONG)
        return "SELL";
    else if(currentAnalysis.sellSignal && currentAnalysis.sellStrength == SIGNAL_MODERATE)
        return "WEAK SELL";
    else if(currentAnalysis.trend == TREND_SIDEWAYS)
        return "WAIT";
    else
        return "NO TRADE";
}

//+------------------------------------------------------------------+
//| Determine multi-timeframe trend                                  |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION DetermineMTFTrend()
{
    if(!UseMultiTimeframe) return TREND_UNKNOWN;
    if(mtfMaFastHandle == INVALID_HANDLE || mtfMaSlowHandle == INVALID_HANDLE) return TREND_UNKNOWN;
    
    if(CopyBuffer(mtfMaFastHandle, 0, 0, 3, mtfMaFast) < 3) return TREND_UNKNOWN;
    if(CopyBuffer(mtfMaSlowHandle, 0, 0, 3, mtfMaSlow) < 3) return TREND_UNKNOWN;
    
    if(mtfMaFast[0] == EMPTY_VALUE || mtfMaSlow[0] == EMPTY_VALUE) return TREND_UNKNOWN;
    
    if(mtfMaFast[0] > mtfMaSlow[0] && mtfMaFast[0] > mtfMaFast[1])
        return TREND_UP;
    if(mtfMaFast[0] < mtfMaSlow[0] && mtfMaFast[0] < mtfMaFast[1])
        return TREND_DOWN;
    
    return TREND_SIDEWAYS;
}

//+------------------------------------------------------------------+
//| Detect RSI divergence using proper swing point tracking         |
//| Returns DIV_BULLISH (price lower low + RSI higher low)          |
//|         DIV_BEARISH (price higher high + RSI lower high)        |
//|         DIV_NONE if no divergence found                         |
//+------------------------------------------------------------------+
ENUM_DIVERGENCE_TYPE DetectRSIDivergence()
{
    int lookback = MathMax(8, MathMin(DivergenceLookback, 50));
    // Minimum 8 bars ensures at least two distinct swings can form;
    // maximum 50 bars keeps computation lightweight and divergence signals timely.
    int needed   = lookback + 2;
    
    // We need price (close) and RSI values
    double closeBuffer[];  // price close series (index 0 = most recent)
    double rsiBuffer[];    // RSI series matching TrendTimeframe
    ArraySetAsSeries(closeBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);
    
    if(CopyClose(Symbol(), TrendTimeframe, 0, needed, closeBuffer) < needed) return DIV_NONE;
    if(CopyBuffer(rsiHandle, 0, 0, needed, rsiBuffer) < needed) return DIV_NONE;
    
    // Find the two most recent swing lows (for bullish divergence)
    // A swing low is a bar where the close is lower than both its neighbours
    int swingLow1 = -1, swingLow2 = -1; // indices (0 = most recent)
    for(int i = 1; i < lookback && (swingLow1 < 0 || swingLow2 < 0); i++)
    {
        if(closeBuffer[i] < closeBuffer[i-1] && closeBuffer[i] < closeBuffer[i+1])
        {
            if(swingLow1 < 0)
                swingLow1 = i;
            else if(swingLow2 < 0)
                swingLow2 = i;
        }
    }
    
    // Find the two most recent swing highs (for bearish divergence)
    int swingHigh1 = -1, swingHigh2 = -1;
    for(int i = 1; i < lookback && (swingHigh1 < 0 || swingHigh2 < 0); i++)
    {
        if(closeBuffer[i] > closeBuffer[i-1] && closeBuffer[i] > closeBuffer[i+1])
        {
            if(swingHigh1 < 0)
                swingHigh1 = i;
            else if(swingHigh2 < 0)
                swingHigh2 = i;
        }
    }
    
    // Bullish divergence: price makes lower low but RSI makes higher low
    if(swingLow1 >= 0 && swingLow2 >= 0)
    {
        // swingLow1 is more recent than swingLow2
        bool priceLowerLow = (closeBuffer[swingLow1] < closeBuffer[swingLow2]);
        bool rsiHigherLow  = (rsiBuffer[swingLow1] > rsiBuffer[swingLow2]);
        if(priceLowerLow && rsiHigherLow) return DIV_BULLISH;
    }
    
    // Bearish divergence: price makes higher high but RSI makes lower high
    if(swingHigh1 >= 0 && swingHigh2 >= 0)
    {
        bool priceHigherHigh = (closeBuffer[swingHigh1] > closeBuffer[swingHigh2]);
        bool rsiLowerHigh    = (rsiBuffer[swingHigh1] < rsiBuffer[swingHigh2]);
        if(priceHigherHigh && rsiLowerHigh) return DIV_BEARISH;
    }
    
    return DIV_NONE;
}

//+------------------------------------------------------------------+
//| Calculate numeric buy score (0–100) for analytics               |
//+------------------------------------------------------------------+
double CalculateBuyScore()
{
    if(!currentAnalysis.buySignal) return 0.0;
    
    double score = 0.0;
    
    // Trend component (40 pts max)
    if(currentAnalysis.trend == TREND_UP)
    {
        score += 20.0;
        if(UseADX && currentAnalysis.adxValue > ADX_Threshold) score += 10.0;
        if(UseADX && currentAnalysis.adxPlusValue > currentAnalysis.adxMinusValue) score += 10.0;
    }
    
    // MACD component (20 pts max)
    if(currentAnalysis.macdValue > 0) score += 20.0;
    
    // RSI component (20 pts max)
    if(UseRSI)
    {
        if(currentAnalysis.rsiValue < RSI_Oversold) score += 20.0;
        else if(currentAnalysis.rsiValue < 50) score += 10.0;
    }
    
    // MTF component (10 pts max)
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_UP) score += 10.0;
    
    // Divergence component (10 pts max)
    if(UseRSIDivergence && currentAnalysis.divergence == DIV_BULLISH) score += 10.0;
    
    return NormalizeDouble(MathMin(100.0, score), 1);
}

//+------------------------------------------------------------------+
//| Calculate numeric sell score (0–100) for analytics              |
//+------------------------------------------------------------------+
double CalculateSellScore()
{
    if(!currentAnalysis.sellSignal) return 0.0;
    
    double score = 0.0;
    
    // Trend component (40 pts max)
    if(currentAnalysis.trend == TREND_DOWN)
    {
        score += 20.0;
        if(UseADX && currentAnalysis.adxValue > ADX_Threshold) score += 10.0;
        if(UseADX && currentAnalysis.adxMinusValue > currentAnalysis.adxPlusValue) score += 10.0;
    }
    
    // MACD component (20 pts max)
    if(currentAnalysis.macdValue < 0) score += 20.0;
    
    // RSI component (20 pts max)
    if(UseRSI)
    {
        if(currentAnalysis.rsiValue > RSI_Overbought) score += 20.0;
        else if(currentAnalysis.rsiValue > 50) score += 10.0;
    }
    
    // MTF component (10 pts max)
    if(UseMultiTimeframe && currentAnalysis.mtfTrend == TREND_DOWN) score += 10.0;
    
    // Divergence component (10 pts max)
    if(UseRSIDivergence && currentAnalysis.divergence == DIV_BEARISH) score += 10.0;
    
    return NormalizeDouble(MathMin(100.0, score), 1);
}

//+------------------------------------------------------------------+
//| Check for signal changes and alert                               |
//+------------------------------------------------------------------+
void CheckSignalChange()
{
    // New strong buy signal
    if(currentAnalysis.buySignal && currentAnalysis.buyStrength >= SIGNAL_STRONG &&
       (!previousAnalysis.buySignal || previousAnalysis.buyStrength < SIGNAL_STRONG))
    {
        if(EnableSoundAlerts)
            PlaySound(BuySoundFile);
        SendNotification(Symbol() + " - Strong BUY Signal detected!");
    }
    
    // New strong sell signal
    if(currentAnalysis.sellSignal && currentAnalysis.sellStrength >= SIGNAL_STRONG &&
       (!previousAnalysis.sellSignal || previousAnalysis.sellStrength < SIGNAL_STRONG))
    {
        if(EnableSoundAlerts)
            PlaySound(SellSoundFile);
        SendNotification(Symbol() + " - Strong SELL Signal detected!");
    }
}
