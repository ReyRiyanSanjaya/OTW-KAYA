//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_Risk.mqh                            |
//+------------------------------------------------------------------+
//| MODULE: Risk Management & Market Regime Detection
//|
//| DESCRIPTION:
//|   Handles risk management, market regime detection, BSL/SSL
//|   liquidity level detection, and position sizing based on
//|   market conditions.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh (required)
//|   - ESD_Inputs.mqh (required)
//|   - ESD_Visuals.mqh (for ESD_DrawBSL_SSLLevels)
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_DetectMarketRegime()      : Detect current market regime
//|   - ESD_IsRegimeConfirmed()       : Check regime confirmation
//|   - ESD_IsRegimeFavorable()       : Check if regime is favorable
//|   - ESD_RegimeFilter()            : Filter signals by regime
//|   - ESD_GetRegimeDescription()    : Get regime as string
//|   - ESD_GetRegimeAdjustedLotSize(): Calculate lot size by regime
//|   - ESD_DetectBSL_SSLLevels()     : Detect liquidity levels
//|   - ESD_FindSignificantSwingLow() : Find significant swing lows
//|   - ESD_FindSignificantSwingHigh(): Find significant swing highs
//|   - ESD_IsInBSL_SSLZone()         : Check if price is in BSL/SSL
//|
//| VERSION: 2.1
//| LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

// --- CIRCUIT BREAKER GLOBALS ---
double ESD_daily_loss_accumulated = 0;
datetime ESD_last_loss_check_day = 0;
bool ESD_circuit_breaker_tripped = false;

//+------------------------------------------------------------------+
//| Detect Market Regime                                              |
//| Uses ATR and linear regression to classify market conditions     |
//+------------------------------------------------------------------+
void ESD_DetectMarketRegime()
{
    if (!ESD_UseRegimeDetection)
        return;

    double atr_buffer[];
    double close_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    // Get ATR for volatility measurement
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, ESD_RegimeSmoothingPeriod);
    CopyBuffer(atr_handle, 0, 0, ESD_RegimeSmoothingPeriod, atr_buffer);

    // Get closing prices for trend analysis
    CopyClose(_Symbol, PERIOD_CURRENT, 0, ESD_RegimeSmoothingPeriod, close_buffer);

    if (ArraySize(atr_buffer) < ESD_RegimeSmoothingPeriod ||
        ArraySize(close_buffer) < ESD_RegimeSmoothingPeriod)
        return;

    // Calculate volatility index (normalized ATR)
    double current_atr = atr_buffer[0];
    double price_mid = (close_buffer[0] + close_buffer[ESD_RegimeSmoothingPeriod - 1]) / 2.0;
    ESD_volatility_index = current_atr / price_mid;

    // Calculate trend index using linear regression
    double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
    for (int i = 0; i < ESD_RegimeSmoothingPeriod; i++)
    {
        sum_x += i;
        sum_y += close_buffer[i];
        sum_xy += i * close_buffer[i];
        sum_x2 += i * i;
    }

    double slope = (ESD_RegimeSmoothingPeriod * sum_xy - sum_x * sum_y) /
                   (ESD_RegimeSmoothingPeriod * sum_x2 - sum_x * sum_x);

    // Normalize trend strength
    ESD_trend_index = MathAbs(slope) / price_mid;

    // Store previous regime
    ESD_previous_regime = ESD_current_regime;

    // Determine current regime based on volatility and trend
    if (ESD_volatility_index < ESD_VolatilityThreshold)
    {
        // Low volatility environment
        if (ESD_trend_index > ESD_TrendThreshold)
        {
            // Trending in low volatility
            ESD_current_regime = (slope > 0) ? REGIME_TRENDING_BULLISH : REGIME_TRENDING_BEARISH;
            ESD_regime_strength = ESD_trend_index / ESD_TrendThreshold;
        }
        else
        {
            // Ranging with low volatility
            ESD_current_regime = REGIME_RANGING_LOW_VOL;
            ESD_regime_strength = 1.0 - (ESD_trend_index / ESD_TrendThreshold);
        }
    }
    else
    {
        // High volatility environment
        if (ESD_trend_index > ESD_TrendThreshold * 1.5)
        {
            // Strong trending with high volatility (breakout)
            ESD_current_regime = (slope > 0) ? REGIME_BREAKOUT_BULLISH : REGIME_BREAKOUT_BEARISH;
            ESD_regime_strength = ESD_trend_index / (ESD_TrendThreshold * 1.5);
        }
        else
        {
            // Ranging with high volatility
            ESD_current_regime = REGIME_RANGING_HIGH_VOL;
            ESD_regime_strength = ESD_volatility_index / ESD_VolatilityThreshold;
        }
    }

    // Check for regime confirmation
    if (!ESD_IsRegimeConfirmed())
    {
        ESD_current_regime = REGIME_TRANSITION;
        ESD_regime_strength = 0.5;
    }

    // Update regime duration and change time
    if (ESD_current_regime != ESD_previous_regime)
    {
        ESD_regime_change_time = TimeCurrent();
        ESD_regime_duration = 0;
    }
    else
    {
        ESD_regime_duration++;
    }

    // Update filter status for regime
    ESD_UpdateRegimeFilterStatus();
}


//+------------------------------------------------------------------+
//| Check if regime has been consistent                               |
//+------------------------------------------------------------------+
bool ESD_IsRegimeConfirmed()
{
    // Check if regime has been consistent for confirmation bars
    ENUM_MARKET_REGIME test_regime = ESD_current_regime;

    for (int i = 1; i <= ESD_RegimeConfirmationBars; i++)
    {
        ENUM_MARKET_REGIME historical_regime = ESD_GetHistoricalRegime(i);
        if (historical_regime != test_regime)
            return false;
    }

    return true;
}


//+------------------------------------------------------------------+
//| Update regime filter status for monitoring panel                  |
//+------------------------------------------------------------------+
void ESD_UpdateRegimeFilterStatus()
{
    // Add regime filter to filter monitoring array
    int regime_index = -1;

    // Find regime filter index
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "Market Regime")
        {
            regime_index = i;
            break;
        }
    }

    // If not found, add it
    if (regime_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        regime_index = new_size - 1;

        ESD_filter_status[regime_index].name = "Market Regime";
    }

    // Update regime filter status
    ESD_filter_status[regime_index].enabled = ESD_UseRegimeDetection;
    ESD_filter_status[regime_index].passed = ESD_IsRegimeFavorable();
    ESD_filter_status[regime_index].strength = ESD_regime_strength;
    ESD_filter_status[regime_index].details = ESD_GetRegimeDescription();
    ESD_filter_status[regime_index].last_update = TimeCurrent();
}


//+------------------------------------------------------------------+
//| Check if current regime is favorable for trading                  |
//+------------------------------------------------------------------+
bool ESD_IsRegimeFavorable()
{
    if (!ESD_UseRegimeDetection)
        return true;

    // Define favorable regimes based on current strategy
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BULLISH:
    case REGIME_BREAKOUT_BEARISH:
        return true; // Trending regimes are generally favorable

    case REGIME_RANGING_LOW_VOL:
        return ESD_AggressiveMode; // Only trade ranging in aggressive mode

    case REGIME_RANGING_HIGH_VOL:
    case REGIME_TRANSITION:
    default:
        return false; // Avoid high volatility ranging and transitions
    }
}


//+------------------------------------------------------------------+
//| Get human-readable regime description                             |
//+------------------------------------------------------------------+
string ESD_GetRegimeDescription()
{
    string descriptions[7] = {
        "TRENDING BULLISH",
        "TRENDING BEARISH",
        "RANGING LOW VOL",
        "RANGING HIGH VOL",
        "BREAKOUT BULLISH",
        "BREAKOUT BEARISH",
        "TRANSITION"};

    return descriptions[ESD_current_regime] +
           StringFormat(" (%.1f%%)", ESD_regime_strength * 100) +
           StringFormat(" %dbars", ESD_regime_duration);
}


//+------------------------------------------------------------------+
//| Filter trading signals based on market regime                     |
//| Returns true if signal should be allowed, false to filter out    |
//+------------------------------------------------------------------+
bool ESD_RegimeFilter(bool is_buy_signal)
{
    if (!ESD_UseRegimeDetection)
        return true;

    // Enhanced filtering based on market regime for both buy and sell signals
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
        // Favor buy signals in bullish trends, filter sell signals
        if (is_buy_signal)
            return (ESD_regime_strength > 0.7); // Allow buys in strong bullish trends
        else
            return (ESD_regime_strength < 0.4); // Only allow sells if bullish trend is weak

    case REGIME_TRENDING_BEARISH:
        // Favor sell signals in bearish trends, filter buy signals
        if (!is_buy_signal)
            return (ESD_regime_strength > 0.7); // Allow sells in strong bearish trends
        else
            return (ESD_regime_strength < 0.4); // Only allow buys if bearish trend is weak

    case REGIME_BREAKOUT_BULLISH:
        // Strongly favor buy signals in bullish breakouts
        if (is_buy_signal)
            return (ESD_regime_strength > 0.6); // Allow buys
        else
            return (ESD_regime_strength < 0.3); // Very restrictive for sells

    case REGIME_BREAKOUT_BEARISH:
        // Strongly favor sell signals in bearish breakouts
        if (!is_buy_signal)
            return (ESD_regime_strength > 0.6); // Allow sells
        else
            return (ESD_regime_strength < 0.3); // Very restrictive for buys

    case REGIME_RANGING_LOW_VOL:
        // Allow both directions but with tighter filters in ranging
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.6); // Moderate filter for aggressive mode
        else
            return (ESD_regime_strength > 0.8); // Strong filter for conservative mode

    case REGIME_RANGING_HIGH_VOL:
        // Generally avoid trading in high volatility ranging
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.9); // Only very strong signals
        else
            return false; // Avoid completely in conservative mode

    case REGIME_TRANSITION:
        // Avoid trading during regime transitions
        if (ESD_AggressiveMode)
            return (ESD_regime_strength > 0.8); // Only very strong signals
        else
            return false; // Avoid completely
    }

    return true; // Default allow if regime not recognized
}


//+------------------------------------------------------------------+
//| Calculate lot size adjusted by market regime                      |
//| Reduces lot in high volatility, increases in trending markets    |
//+------------------------------------------------------------------+
double ESD_GetRegimeAdjustedLotSize()
{
    double adjusted_lot = ESD_LotSize;

    // ================================================================
    // 1️⃣ Regime-based multiplier
    // ================================================================
    if (ESD_UseRegimeDetection)
    {
        switch (ESD_current_regime)
        {
        case REGIME_TRENDING_BULLISH:
        case REGIME_TRENDING_BEARISH:
            adjusted_lot *= 1.2;
            break;

        case REGIME_BREAKOUT_BULLISH:
        case REGIME_BREAKOUT_BEARISH:
            adjusted_lot *= 1.1;
            break;

        case REGIME_RANGING_LOW_VOL:
            break;

        case REGIME_RANGING_HIGH_VOL:
            adjusted_lot *= 0.7;
            break;

        case REGIME_TRANSITION:
            adjusted_lot *= 0.5;
            break;
        }
    }

    // ================================================================
    // 2️⃣ Volatility Safety Control
    //    - If ATR is high, reduce lot to prevent margin issues
    // ================================================================
    double atr_fast = iATR(_Symbol, PERIOD_M5, 5);
    double atr_slow = iATR(_Symbol, PERIOD_M5, 14);

    // High ATR = High risk = Reduce lot size
    if (atr_fast > atr_slow * 1.5)         adjusted_lot *= 0.7;
    if (atr_fast > atr_slow * 2.0)         adjusted_lot *= 0.5;
    if (atr_fast > atr_slow * 3.0)         adjusted_lot *= 0.3;

    // ================================================================
    // 3️⃣ Broker constraints
    // ================================================================
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    adjusted_lot = MathMax(adjusted_lot, min_lot);
    adjusted_lot = MathMin(adjusted_lot, max_lot);

    return NormalizeDouble(adjusted_lot, 2);
}


//+------------------------------------------------------------------+
//| Detect BSL/SSL (Liquidity) Levels                                 |
//| BSL = Buy Side Liquidity (support areas)                          |
//| SSL = Sell Side Liquidity (resistance areas)                      |
//+------------------------------------------------------------------+
void ESD_DetectBSL_SSLLevels()
{
    if (!ESD_AvoidBSL_SSL)
        return;

    int bars_to_check = 50;
    double high_buffer[], low_buffer[], close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars_to_check, high_buffer);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_check, low_buffer);
    CopyClose(_Symbol, PERIOD_CURRENT, 0, bars_to_check, close_buffer);

    // Detect BSL (Buy Side Liquidity) - swing lows where buyers typically enter
    ESD_bsl_level = ESD_FindSignificantSwingLow(low_buffer, high_buffer, bars_to_check);

    // Detect SSL (Sell Side Liquidity) - swing highs where sellers typically enter
    ESD_ssl_level = ESD_FindSignificantSwingHigh(high_buffer, low_buffer, bars_to_check);

    // Update last detection time
    ESD_last_bsl_ssl_update = TimeCurrent();

    // Draw levels if enabled
    if (ESD_ShowBSL_SSL)
    {
        ESD_DrawBSL_SSLLevels();
    }
}


//+------------------------------------------------------------------+
//| Find Significant Swing Low for BSL Detection                      |
//| Returns the most recent significant swing low level               |
//+------------------------------------------------------------------+
double ESD_FindSignificantSwingLow(const double &low_buffer[], const double &high_buffer[], int total_bars)
{
    double significant_lows[];
    int count = 0;

    for (int i = 3; i < total_bars - 3; i++)
    {
        // Check if this is a valid swing low
        if (low_buffer[i] < low_buffer[i - 1] && low_buffer[i] < low_buffer[i - 2] &&
            low_buffer[i] < low_buffer[i + 1] && low_buffer[i] < low_buffer[i + 2])
        {
            // Validate swing strength (minimum ATR-based)
            double range = high_buffer[i] - low_buffer[i];
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

            if (range > atr * 0.3) // Significant swing
            {
                // Check for duplicates
                bool is_duplicate = false;
                for (int j = 0; j < count; j++)
                {
                    if (MathAbs(significant_lows[j] - low_buffer[i]) < atr * 0.1)
                    {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate)
                {
                    ArrayResize(significant_lows, count + 1);
                    significant_lows[count] = low_buffer[i];
                    count++;
                }
            }
        }
    }

    // Return most recent significant swing low
    if (count > 0)
        return significant_lows[0];

    return EMPTY_VALUE;
}


//+------------------------------------------------------------------+
//| Find Significant Swing High for SSL Detection                     |
//| Returns the most recent significant swing high level              |
//+------------------------------------------------------------------+
double ESD_FindSignificantSwingHigh(const double &high_buffer[], const double &low_buffer[], int total_bars)
{
    double significant_highs[];
    int count = 0;

    for (int i = 3; i < total_bars - 3; i++)
    {
        // Check if this is a valid swing high
        if (high_buffer[i] > high_buffer[i - 1] && high_buffer[i] > high_buffer[i - 2] &&
            high_buffer[i] > high_buffer[i + 1] && high_buffer[i] > high_buffer[i + 2])
        {
            // Validate swing strength (minimum ATR-based)
            double range = high_buffer[i] - low_buffer[i];
            double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

            if (range > atr * 0.3) // Significant swing
            {
                // Check for duplicates
                bool is_duplicate = false;
                for (int j = 0; j < count; j++)
                {
                    if (MathAbs(significant_highs[j] - high_buffer[i]) < atr * 0.1)
                    {
                        is_duplicate = true;
                        break;
                    }
                }

                if (!is_duplicate)
                {
                    ArrayResize(significant_highs, count + 1);
                    significant_highs[count] = high_buffer[i];
                    count++;
                }
            }
        }
    }

    // Return most recent significant swing high
    if (count > 0)
        return significant_highs[0];

    return EMPTY_VALUE;
}


//+------------------------------------------------------------------+
//| Check if price is in BSL/SSL Zone                                 |
//| Returns true if price is near liquidity level (avoid entry)       |
//+------------------------------------------------------------------+
bool ESD_IsInBSL_SSLZone(double price, bool is_buy_signal)
{
    if (!ESD_AvoidBSL_SSL)
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double buffer_size = ESD_BSL_SSL_BufferPoints * point;

    // For buy signal, avoid area around SSL (resistance)
    if (is_buy_signal && ESD_ssl_level != EMPTY_VALUE)
    {
        if (price >= ESD_ssl_level - buffer_size && price <= ESD_ssl_level + buffer_size)
        {
            Print("Avoid BUY - Price in SSL zone: ", ESD_ssl_level);
            return true;
        }
    }

    // For sell signal, avoid area around BSL (support)
    if (!is_buy_signal && ESD_bsl_level != EMPTY_VALUE)
    {
        if (price >= ESD_bsl_level - buffer_size && price <= ESD_bsl_level + buffer_size)
        {
            Print("Avoid SELL - Price in BSL zone: ", ESD_bsl_level);
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| HARD CIRCUIT BREAKER: Check Daily Loss Limit                      |
//| Returns TRUE if trading should be STOPPED (Kill Switch)           |
//+------------------------------------------------------------------+
bool ESD_CheckHardCircuitBreaker()
{
    // Reset counter on new day
    if (TimeDay(TimeCurrent()) != TimeDay(ESD_last_loss_check_day))
    {
        ESD_daily_loss_accumulated = 0;
        ESD_circuit_breaker_tripped = false;
        ESD_last_loss_check_day = TimeCurrent();
    }
    
    // If already tripped, stay blocked
    if (ESD_circuit_breaker_tripped) return true;

    // Calculate Today's Realized Loss
    HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent());
    double daily_profit = 0;
    
    for (int i=0; i<HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT && 
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == ESD_MagicNumber)
        {
            daily_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
        }
    }
    
    // Check Limit (Def: 5% of Balance)
    double max_loss = AccountInfoDouble(ACCOUNT_BALANCE) * 0.05; // 5% Hard Stop
    
    if (daily_profit < -max_loss)
    {
        ESD_circuit_breaker_tripped = true;
        Print("🚨 CIRCUIT BREAKER TRIPPED! Daily Loss exceeded ", DoubleToString(max_loss, 2), ". System HALTED.");
        return true; // STOP TRADING
    }
    
    return false;
}