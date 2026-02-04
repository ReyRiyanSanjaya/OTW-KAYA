//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                       ESD_Confirmation.mqh                        |
//+------------------------------------------------------------------+
//| MODULE: Advanced Confirmation Filters
//|
//| DESCRIPTION:
//|   Konsolidasi semua filter konfirmasi lanjutan untuk entry:
//|   1. Stochastic Filter     - No Buy in Overbought/Oversold
//|   2. Candle Rejection      - Wick/Body Analysis
//|   3. Heatmap Analysis      - Multi-TF Momentum
//|   4. Order Flow Analysis   - Delta & Volume
//|   5. Aggressive FVG Entry  - Scalping Mode
//|   6. Inducement Liquidity  - False Breakout Detection
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh
//|
//| PUBLIC FUNCTIONS:
//|   STOCHASTIC:
//|   - ESD_StochasticEntryFilter()    : Main stochastic filter
//|   - ESD_IsStochasticOverbought()   : Check overbought
//|   - ESD_IsStochasticOversold()     : Check oversold
//|
//|   CANDLE REJECTION:
//|   - ESD_IsRejectionCandle()        : Detect rejection pattern
//|   - ESD_IsPinBar()                 : Pin bar detection
//|   - ESD_GetWickRatio()             : Calculate wick ratio
//|
//|   HEATMAP:
//|   - ESD_AnalyzeHeatmap()           : Multi-TF momentum
//|   - ESD_HeatmapFilter()            : Filter by heatmap bias
//|
//|   ORDER FLOW:
//|   - ESD_AnalyzeOrderFlow()         : Delta & absorption
//|   - ESD_OrderFlowFilter()          : Filter by order flow
//|   - ESD_DetectAbsorption()         : Absorption detection
//|   - ESD_DetectImbalance()          : Volume imbalance
//|
//|   AGGRESSIVE FVG:
//|   - ESD_CheckAggressiveFVGEntry()  : Check aggressive entry
//|   - ESD_CalculateFVGQuality()      : Score FVG zone
//|
//|   INDUCEMENT:
//|   - ESD_TradeAgainstInducement()   : Main inducement logic
//|   - ESD_IsBullishInducementSignal(): False breakdown
//|   - ESD_IsBearishInducementSignal(): False breakout
//|   - ESD_IsLiquiditySweeped()       : Sweep confirmation
//|
//| VERSION: 1.0 | CREATED: 2025-12-18
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

//+------------------------------------------------------------------+
//|                    STOCHASTIC FILTER                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if stochastic is in overbought zone (>80)                  |
//+------------------------------------------------------------------+
bool ESD_IsStochasticOverbought(int k_period = 14, int d_period = 3, int slowing = 3)
{
    double k[], d[];
    ArraySetAsSeries(k, true);
    ArraySetAsSeries(d, true);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, k_period, d_period, slowing, MODE_SMA, STO_LOWHIGH);
    if(CopyBuffer(stoch_handle, 0, 0, 2, k) < 2)
        return false; // Default not overbought if error
       
    return (k[0] >= 80);
}

//+------------------------------------------------------------------+
//| Check if stochastic is in oversold zone (<20)                    |
//+------------------------------------------------------------------+
bool ESD_IsStochasticOversold(int k_period = 14, int d_period = 3, int slowing = 3)
{
    double k[], d[];
    ArraySetAsSeries(k, true);
    ArraySetAsSeries(d, true);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, k_period, d_period, slowing, MODE_SMA, STO_LOWHIGH);
    if(CopyBuffer(stoch_handle, 0, 0, 2, k) < 2)
        return false; // Default not oversold if error
       
    return (k[0] <= 20);
}

//+------------------------------------------------------------------+
//| Main Stochastic Entry Filter                                     |
//| Blocks entries in extreme zones:                                 |
//| - Buy blocked in overbought (K > 80)                             |
//| - Sell blocked in oversold (K < 20)                              |
//+------------------------------------------------------------------+
bool ESD_ConfirmationStochasticFilter(bool is_buy)
{
    double k[], d[];
    ArraySetAsSeries(k, true);
    ArraySetAsSeries(d, true);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(CopyBuffer(stoch_handle, 0, 0, 2, k) < 2 || CopyBuffer(stoch_handle, 1, 0, 2, d) < 2)
       return true; // Default allow if error
       
    if (is_buy)
        return (k[0] < 80); // Jangan beli di overbought ekstrim
    else
        return (k[0] > 20); // Jangan jual di oversold ekstrim
}

//+------------------------------------------------------------------+
//| Get stochastic values for ML/custom logic                        |
//+------------------------------------------------------------------+
void ESD_GetStochasticValues(double &k_value, double &d_value, int k_period = 5, int d_period = 3, int slowing = 3)
{
    double k[], d[];
    ArraySetAsSeries(k, true);
    ArraySetAsSeries(d, true);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, k_period, d_period, slowing, MODE_SMA, STO_LOWHIGH);
    
    if(CopyBuffer(stoch_handle, 0, 0, 1, k) >= 1)
        k_value = k[0];
    else
        k_value = 50; // Default neutral
        
    if(CopyBuffer(stoch_handle, 1, 0, 1, d) >= 1)
        d_value = d[0];
    else
        d_value = 50; // Default neutral
}

//+------------------------------------------------------------------+
//|                    CANDLE REJECTION                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for rejection candle pattern                               |
//| Bullish: long lower wick (>60%), small body (<30%)               |
//| Bearish: long upper wick (>60%), small body (<30%)               |
//+------------------------------------------------------------------+
bool ESD_ConfirmationRejectionCandle(MqlRates &candle, bool is_bullish)
{
    double body_size = MathAbs(candle.close - candle.open);
    double upper_wick = candle.high - MathMax(candle.open, candle.close);
    double lower_wick = MathMin(candle.open, candle.close) - candle.low;
    double total_range = candle.high - candle.low;

    if (total_range == 0)
        return false;

    double body_ratio = body_size / total_range;
    double upper_wick_ratio = upper_wick / total_range;
    double lower_wick_ratio = lower_wick / total_range;

    if (is_bullish)
    {
        // Bullish rejection candle: long lower wick, small body
        return (lower_wick_ratio > 0.6 && body_ratio < 0.3);
    }
    else
    {
        // Bearish rejection candle: long upper wick, small body
        return (upper_wick_ratio > 0.6 && body_ratio < 0.3);
    }
}

//+------------------------------------------------------------------+
//| Check for Pin Bar pattern (stricter rejection)                   |
//+------------------------------------------------------------------+
bool ESD_IsPinBar(MqlRates &candle, bool is_bullish)
{
    double body_size = MathAbs(candle.close - candle.open);
    double upper_wick = candle.high - MathMax(candle.open, candle.close);
    double lower_wick = MathMin(candle.open, candle.close) - candle.low;
    double total_range = candle.high - candle.low;

    if (total_range == 0)
        return false;

    double body_ratio = body_size / total_range;
    double dominant_wick = is_bullish ? lower_wick : upper_wick;
    double opposite_wick = is_bullish ? upper_wick : lower_wick;
    
    // Pin bar: dominant wick > 66%, body < 25%, opposite wick < 15%
    return (dominant_wick / total_range > 0.66 && 
            body_ratio < 0.25 && 
            opposite_wick / total_range < 0.15);
}

//+------------------------------------------------------------------+
//| Get wick ratio for analysis                                      |
//+------------------------------------------------------------------+
double ESD_GetWickRatio(MqlRates &candle, bool upper_wick)
{
    double total_range = candle.high - candle.low;
    if (total_range == 0)
        return 0;
        
    if (upper_wick)
        return (candle.high - MathMax(candle.open, candle.close)) / total_range;
    else
        return (MathMin(candle.open, candle.close) - candle.low) / total_range;
}

//+------------------------------------------------------------------+
//|                    HEATMAP ANALYSIS                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate timeframe strength for heatmap                         |
//+------------------------------------------------------------------+
double ESD_CalculateTimeframeStrength(ENUM_TIMEFRAMES tf)
{
    double rsi = iRSI(_Symbol, tf, 14, PRICE_CLOSE);
    double macd_main[], macd_signal[];
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    int macd_handle = iMACD(_Symbol, tf, 12, 26, 9, PRICE_CLOSE);
    CopyBuffer(macd_handle, 0, 0, 1, macd_main);
    CopyBuffer(macd_handle, 1, 0, 1, macd_signal);
    
    // Calculate momentum score (-1 to +1)
    double rsi_score = (rsi - 50) / 50; // -1 to +1
    double macd_score = 0;
    if (ArraySize(macd_main) > 0 && ArraySize(macd_signal) > 0)
    {
        macd_score = (macd_main[0] > macd_signal[0]) ? 0.5 : -0.5;
        if (macd_main[0] > 0) macd_score += 0.3;
        else macd_score -= 0.3;
    }
    
    return (rsi_score * 0.6 + macd_score * 0.4);
}

//+------------------------------------------------------------------+
//| Analyze multi-timeframe heatmap                                  |
//+------------------------------------------------------------------+
void ESD_ConfirmationAnalyzeHeatmap()
{
    double momentum_score = 0.0;

    // Analyze multiple timeframes
    ENUM_TIMEFRAMES tf_list[4] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
    double timeframe_weights[4] = {0.2, 0.3, 0.3, 0.2};

    for (int i = 0; i < 4; i++)
    {
        double tf_strength = ESD_CalculateTimeframeStrength(tf_list[i]);
        momentum_score += tf_strength * timeframe_weights[i];
    }

    // Convert to heatmap strength (-100 to +100)
    ESD_heatmap_strength = momentum_score * 100;

    // Determine bias
    ESD_heatmap_bullish = (ESD_heatmap_strength > ESD_HeatmapStrengthThreshold);
    ESD_heatmap_bearish = (ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold);

    ESD_last_heatmap_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Filter entry based on heatmap                                    |
//+------------------------------------------------------------------+
bool ESD_ConfirmationHeatmapFilter(bool proposed_buy_signal)
{
    if (!ESD_UseHeatmapFilter)
        return true;

    // Strong disagreement filter
    if (proposed_buy_signal && ESD_heatmap_bearish &&
        MathAbs(ESD_heatmap_strength) > ESD_HeatmapStrengthThreshold * 1.5)
    {
        return false; // Reject buy when heatmap strongly bearish
    }

    if (!proposed_buy_signal && ESD_heatmap_bullish &&
        MathAbs(ESD_heatmap_strength) > ESD_HeatmapStrengthThreshold * 1.5)
    {
        return false; // Reject sell when heatmap strongly bullish
    }

    return true;
}

//+------------------------------------------------------------------+
//|                    ORDER FLOW ANALYSIS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect absorption pattern                                        |
//+------------------------------------------------------------------+
bool ESD_ConfirmationDetectAbsorption(const MqlRates &rates[], const long &volume[], int bars)
{
    for (int i = 1; i < bars - 1; i++)
    {
        double price_change = MathAbs(rates[i].close - rates[i - 1].close) / rates[i - 1].close;
        double volume_ratio = (double)volume[i] / volume[i - 1];

        // High volume with small price change suggests absorption
        if (volume_ratio > 2.0 && price_change < 0.001)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Detect volume imbalance                                          |
//+------------------------------------------------------------------+
bool ESD_ConfirmationDetectImbalance(const MqlRates &rates[], const long &volume[], int bars)
{
    int imbalance_count = 0;

    for (int i = 0; i < bars; i++)
    {
        double body_size = MathAbs(rates[i].close - rates[i].open);
        double total_range = rates[i].high - rates[i].low;

        if (total_range > 0)
        {
            double body_ratio = body_size / total_range;

            // Strong move with high volume = imbalance
            if (body_ratio > 0.7 && volume[i] > ESD_VolumeThreshold)
            {
                imbalance_count++;
            }
        }
    }

    return (imbalance_count >= 3);
}

//+------------------------------------------------------------------+
//| Analyze order flow                                               |
//+------------------------------------------------------------------+
void ESD_ConfirmationAnalyzeOrderFlow()
{
    if (!ESD_UseOrderFlow)
        return;

    double total_volume = 0.0;
    double bid_volume = 0.0;
    double ask_volume = 0.0;

    MqlRates rates[];
    long tick_volume[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(tick_volume, true);

    int bars = 20;
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates) == bars &&
        CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars, tick_volume) == bars)
    {
        for (int i = 0; i < bars; i++)
        {
            double candle_size = rates[i].high - rates[i].low;
            if (candle_size == 0)
                continue;

            double buy_pressure = (rates[i].close - rates[i].low) / candle_size;
            double sell_pressure = (rates[i].high - rates[i].close) / candle_size;

            double candle_delta = (buy_pressure - sell_pressure) * tick_volume[i];
            ESD_cumulative_delta += candle_delta;

            if (rates[i].close > rates[i].open)
                bid_volume += tick_volume[i] * buy_pressure;
            else
                ask_volume += tick_volume[i] * sell_pressure;

            total_volume += (double)tick_volume[i];
        }

        if (total_volume > 0)
        {
            ESD_delta_value = ESD_cumulative_delta / total_volume;
            ESD_volume_imbalance = (bid_volume - ask_volume) / total_volume;

            ESD_absorption_detected = ESD_ConfirmationDetectAbsorption(rates, tick_volume, bars);
            ESD_imbalance_detected = ESD_ConfirmationDetectImbalance(rates, tick_volume, bars);

            ESD_orderflow_strength = (ESD_delta_value * 0.4 + ESD_volume_imbalance * 0.4 +
                                      (ESD_absorption_detected ? -0.2 : 0.0)) * 100;
        }

        ESD_last_orderflow_update = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Filter entry based on order flow                                 |
//+------------------------------------------------------------------+
bool ESD_ConfirmationOrderFlowFilter(bool proposed_buy_signal)
{
    if (!ESD_UseOrderFlow)
        return true;

    double of_strength = MathAbs(ESD_orderflow_strength);

    // Strong order flow filter
    if (of_strength > 60)
    {
        if (proposed_buy_signal && ESD_orderflow_strength < -50)
            return false; // Reject buy on strong selling pressure

        if (!proposed_buy_signal && ESD_orderflow_strength > 50)
            return false; // Reject sell on strong buying pressure
    }

    // Absorption filter
    if (ESD_UseAbsorptionDetection && ESD_absorption_detected)
    {
        if (of_strength < 30)
            return false;
    }

    // Delta confirmation
    if (ESD_UseDeltaAnalysis)
    {
        if (proposed_buy_signal && ESD_delta_value < -ESD_DeltaThreshold)
            return false;

        if (!proposed_buy_signal && ESD_delta_value > ESD_DeltaThreshold)
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//|                    AGGRESSIVE FVG ENTRY                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for aggressive FVG entry opportunity                       |
//+------------------------------------------------------------------+
bool ESD_CheckAggressiveFVGEntry(bool &is_buy)
{
    if (!ESD_AggressiveMode || !ESD_TradeOnFVGDetection)
        return false;
        
    // Check if FVG was recently created (within 60 seconds)
    if (ESD_fvg_creation_time <= TimeCurrent() - 60)
        return false;
        
    // Check for bullish FVG
    if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
    {
        is_buy = true;
        return true;
    }
    
    // Check for bearish FVG
    if (ESD_bearish_fvg_top != EMPTY_VALUE)
    {
        is_buy = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate FVG quality score                                      |
//+------------------------------------------------------------------+
double ESD_ConfirmationCalculateFVGQuality(double fvg_top, double fvg_bottom, bool is_bullish)
{
    double quality = 0.5; // Base score
    
    // 1. Size factor (larger gap = higher quality)
    double gap_size = MathAbs(fvg_top - fvg_bottom);
    double atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
    {
        double gap_ratio = gap_size / atr_buffer[0];
        quality += MathMin(gap_ratio * 0.2, 0.2);
    }
    
    // 2. Trend alignment
    if (is_bullish && ESD_bullish_trend_confirmed)
        quality += 0.15;
    else if (!is_bullish && ESD_bearish_trend_confirmed)
        quality += 0.15;
    
    // 3. Fresh FVG bonus
    if (ESD_fvg_creation_time > TimeCurrent() - 300) // Within 5 minutes
        quality += 0.1;
    
    return MathMin(quality, 1.0);
}

//+------------------------------------------------------------------+
//|                    INDUCEMENT LIQUIDITY                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if liquidity level was swept                               |
//+------------------------------------------------------------------+
bool ESD_ConfirmationLiquiditySweeped(double liquidity_level, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, 5, rates);

    if (ArraySize(rates) < 5)
        return false;

    if (is_bullish)
    {
        // Price swept below bullish liquidity and came back up
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].low < liquidity_level && rates[0].close > liquidity_level)
                return true;
        }
    }
    else
    {
        // Price swept above bearish liquidity and came back down
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].high > liquidity_level && rates[0].close < liquidity_level)
                return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check for bullish inducement signal (false breakdown)            |
//+------------------------------------------------------------------+
bool ESD_ConfirmationBullishInducementSignal()
{
    // Get recent price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10)
        return false;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1)
        return false;
    double atr = atr_buffer[0];
    
    // Check for false breakdown pattern:
    // 1. Price broke below SSL level
    // 2. Then closed back above with rejection
    
    if (ESD_ssl_level == EMPTY_VALUE)
        return false;
        
    bool broke_below = false;
    for (int i = 1; i < 5; i++)
    {
        if (rates[i].low < ESD_ssl_level - (5 * point))
            broke_below = true;
    }
    
    bool closed_above = (rates[0].close > ESD_ssl_level + (10 * point));
    bool has_rejection = ESD_ConfirmationRejectionCandle(rates[1], true);
    
    return (broke_below && closed_above && has_rejection);
}

//+------------------------------------------------------------------+
//| Check for bearish inducement signal (false breakout)             |
//+------------------------------------------------------------------+
bool ESD_ConfirmationBearishInducementSignal()
{
    // Get recent price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10)
        return false;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1)
        return false;
    double atr = atr_buffer[0];
    
    // Check for false breakout pattern:
    // 1. Price broke above BSL level
    // 2. Then closed back below with rejection
    
    if (ESD_bsl_level == EMPTY_VALUE)
        return false;
        
    bool broke_above = false;
    for (int i = 1; i < 5; i++)
    {
        if (rates[i].high > ESD_bsl_level + (5 * point))
            broke_above = true;
    }
    
    bool closed_below = (rates[0].close < ESD_bsl_level - (10 * point));
    bool has_rejection = ESD_ConfirmationRejectionCandle(rates[1], false);
    
    return (broke_above && closed_below && has_rejection);
}

//+------------------------------------------------------------------+
//| Main inducement trading logic                                    |
//+------------------------------------------------------------------+
bool ESD_ConfirmationTradeAgainstInducement()
{
    // Get market data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10)
        return false;
        
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1)
        return false;
    double atr = atr_buffer[0];
    
    // Check for inducement signals
    bool is_bullish_false_breakout = ESD_ConfirmationBullishInducementSignal();
    bool is_bearish_false_breakout = ESD_ConfirmationBearishInducementSignal();
    
    if (is_bullish_false_breakout)
    {
        // Bullish inducement - price swept SSL and reversed
        // This is a potential BUY opportunity
        return true;
    }
    else if (is_bearish_false_breakout)
    {
        // Bearish inducement - price swept BSL and reversed
        // This is a potential SELL opportunity
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//|                    COMBINED CONFIRMATION                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Run all confirmation checks for entry                            |
//+------------------------------------------------------------------+
bool ESD_RunAllConfirmations(bool is_buy_signal)
{
    // 1. Stochastic Filter
    if (!ESD_ConfirmationStochasticFilter(is_buy_signal))
    {
        Print("Confirmation BLOCKED: Stochastic in extreme zone");
        return false;
    }
    
    // 2. Heatmap Filter
    if (!ESD_ConfirmationHeatmapFilter(is_buy_signal))
    {
        Print("Confirmation BLOCKED: Heatmap disagrees");
        return false;
    }
    
    // 3. Order Flow Filter
    if (!ESD_ConfirmationOrderFlowFilter(is_buy_signal))
    {
        Print("Confirmation BLOCKED: Order flow disagrees");
        return false;
    }
    
    return true;
}

// --- END OF FILE ---
