//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_Trend.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Trend Analysis & Detection
//|
//| DESCRIPTION:
//|   Multi-timeframe trend detection, strength calculation,
//|   and Market Structure Shift (MSS) detection.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_DetectInitialTrend()           : Initial trend detection
//|   - ESD_CalculateTrendStrength()       : Volume-weighted strength
//|   - ESD_DetectSupremeTimeframeTrend()  : Higher TF confirmation
//|   - ESD_DetectMarketStructureShift()   : MSS detection
//|   - ESD_ConfirmBreak()                 : Break confirmation
//|   - ESD_IsValidMomentum()              : EMA momentum check
//|   - ESD_CalculateTimeframeStrength()   : TF strength calculation
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

void ESD_DetectInitialTrend()
{
    int bars_to_check = MathMax(ESD_SwingLookback, 20);
    double high_buffer[], low_buffer[], close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);

    CopyHigh(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, high_buffer);
    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, close_buffer);

    // Reset trend confirmation
    ESD_bullish_trend_confirmed = false;
    ESD_bearish_trend_confirmed = false;

    // Enhanced trend detection dengan multiple conditions
    int bullish_signals = 0;
    int bearish_signals = 0;

    // Condition 1: Price position relative to recent swings
    double current_high = high_buffer[0];
    double current_low = low_buffer[0];
    double mid_range = (current_high + current_low) / 2;

    // Check last 5 candles for momentum
    for (int i = 0; i < 5; i++)
    {
        if (close_buffer[i] > close_buffer[i + 1])
            bullish_signals++;
        else if (close_buffer[i] < close_buffer[i + 1])
            bearish_signals++;
    }

    // Condition 2: Swing structure
    if (high_buffer[0] > high_buffer[2] && low_buffer[0] > low_buffer[2])
        bullish_signals += 2;
    else if (high_buffer[0] < high_buffer[2] && low_buffer[0] < low_buffer[2])
        bearish_signals += 2;

    // Condition 3: Strong momentum confirmation
    if (bullish_signals >= 4 && bearish_signals <= 2)
    {
        ESD_bullish_trend_confirmed = true;
        ESD_bearish_trend_confirmed = false;
        ESD_bullish_trend_strength = 0.8;
        ESD_bearish_trend_strength = 0.2;
    }
    else if (bearish_signals >= 4 && bullish_signals <= 2)
    {
        ESD_bearish_trend_confirmed = true;
        ESD_bullish_trend_confirmed = false;
        ESD_bearish_trend_strength = 0.8;
        ESD_bullish_trend_strength = 0.2;
    }
    else
    {
        // Neutral/consolidation
        ESD_bullish_trend_confirmed = false;
        ESD_bearish_trend_confirmed = false;
        ESD_bullish_trend_strength = 0.5;
        ESD_bearish_trend_strength = 0.5;
    }
}


double ESD_CalculateTrendStrength(const double &close_buffer[], bool is_bullish)
{
    int bars = ArraySize(close_buffer);
    if (bars < 10)
        return 0.0;

    double strength = 0.0;
    int confirming_bars = 0;

    // ENHANCEMENT: Add volume-weighted trend strength
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyRates(_Symbol, ESD_HigherTimeframe, 0, bars, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars, volume_buffer);

    // Count bars that confirm the trend dengan volume consideration
    double total_volume = 0;
    double confirming_volume = 0;

    for (int i = 0; i < bars - 1; i++)
    {
        total_volume += (double)volume_buffer[i];

        if (is_bullish && close_buffer[i] > close_buffer[i + 1])
        {
            confirming_bars++;
            confirming_volume += (double)volume_buffer[i];
        }
        else if (!is_bullish && close_buffer[i] < close_buffer[i + 1])
        {
            confirming_bars++;
            confirming_volume += (double)volume_buffer[i];
        }
    }

    // Calculate strength as ratio of confirming bars (existing)
    strength = (double)confirming_bars / (bars - 1);

    // ENHANCEMENT: Volume-based strength adjustment
    double volume_strength = (total_volume > 0) ? (confirming_volume / total_volume) : 0.5;
    strength = (strength * 0.6) + (volume_strength * 0.4);

    // Existing recent momentum calculation tetap...
    double recent_momentum = 0.0;
    int recent_bars = MathMin(5, bars / 2);
    for (int i = 0; i < recent_bars; i++)
    {
        if (is_bullish && close_buffer[i] > close_buffer[i + 1])
            recent_momentum += 1.0;
        else if (!is_bullish && close_buffer[i] < close_buffer[i + 1])
            recent_momentum += 1.0;
    }
    recent_momentum /= recent_bars;

    // Combine dengan weight yang disesuaikan
    strength = (strength * 0.5) + (recent_momentum * 0.3) + (volume_strength * 0.2);

    return MathMax(0.0, MathMin(1.0, strength));
}


void ESD_DetectSupremeTimeframeTrend()
{
    int bars_to_check = ESD_SwingLookback;
    double high_buffer[];
    double low_buffer[];
    double close_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    CopyHigh(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, high_buffer);
    CopyLow(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, low_buffer);
    CopyClose(_Symbol, ESD_SupremeTimeframe, 1, bars_to_check, close_buffer);

    // Calculate trend strength on supreme timeframe
    double supreme_bullish_strength = ESD_CalculateTrendStrength(close_buffer, true);
    double supreme_bearish_strength = ESD_CalculateTrendStrength(close_buffer, false);

    // Only override higher timeframe trend if supreme trend is strong
    if (ESD_UseStrictTrendConfirmation)
    {
        if (supreme_bullish_strength > ESD_TrendStrengthThreshold &&
            supreme_bullish_strength > supreme_bearish_strength)
        {
            // Strong bullish trend on supreme timeframe
            if (ESD_bullish_trend_strength < ESD_TrendStrengthThreshold)
            {
                ESD_bullish_trend_confirmed = true;
                ESD_bearish_trend_confirmed = false;
            }
        }
        else if (supreme_bearish_strength > ESD_TrendStrengthThreshold &&
                 supreme_bearish_strength > supreme_bullish_strength)
        {
            // Strong bearish trend on supreme timeframe
            if (ESD_bearish_trend_strength < ESD_TrendStrengthThreshold)
            {
                ESD_bearish_trend_confirmed = true;
                ESD_bullish_trend_confirmed = false;
            }
        }
    }

    // Display trend strength if enabled
    if (ESD_ShowObjects && ESD_ShowTrendStrength)
    {
        string text = StringFormat("HTF: B=%.2f S=%.2f | STF: B=%.2f S=%.2f",
                                   ESD_bullish_trend_strength, ESD_bearish_trend_strength,
                                   supreme_bullish_strength, supreme_bearish_strength);
        ESD_DrawLabel("ESD_TrendStrength", iTime(_Symbol, PERIOD_CURRENT, 0),
                      iHigh(_Symbol, PERIOD_CURRENT, 0), text, ESD_NeutralColor, false);
    }
}


void ESD_DetectMarketStructureShift(const double &high_buffer[], const double &low_buffer[], const double &close_buffer[])
{
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    int bars_to_check = 20;
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars_to_check, volume_buffer);

    // Bullish MSS: Lower Low followed by break of previous Lower High
    if (ESD_last_significant_pl > 0 && ESD_last_significant_ph > 0)
    {
        // Check for a new lower low
        for (int i = 1; i < 10; i++)
        {
            if (low_buffer[i] < ESD_last_significant_pl)
            {
                // Found a new lower low, now check for break of previous lower high
                for (int j = 1; j < i; j++)
                {
                    if (high_buffer[j] > ESD_last_significant_ph)
                    {

                        double break_strength = (high_buffer[j] - ESD_last_significant_ph) / (high_buffer[j] - low_buffer[j]);
                        bool strong_break = (break_strength > 0.6);

                        if (strong_break)
                        {
                            // Bullish MSS detected
                            ESD_bullish_mss_detected = true;
                            ESD_bullish_mss_time = iTime(_Symbol, ESD_HigherTimeframe, j);

                            // Add to historical structures
                            ESD_SMStructure new_mss;
                            new_mss.time = ESD_bullish_mss_time;
                            new_mss.price = ESD_last_significant_ph;
                            new_mss.is_bullish = true;
                            new_mss.type = "MSS";
                            new_mss.top = ESD_last_significant_ph;
                            new_mss.bottom = ESD_last_significant_pl;
                            new_mss.quality_score = 0.8; // High quality signal
                            ESD_AddToHistoricalStructures(new_mss);

                            // Update trend strength
                            ESD_bullish_trend_strength = MathMin(1.0, ESD_bullish_trend_strength + 0.4);
                            ESD_bearish_trend_strength = MathMax(0.0, ESD_bearish_trend_strength - 0.4);

                            if (ESD_bullish_trend_strength > ESD_TrendStrengthThreshold)
                                ESD_bullish_trend_confirmed = true;

                            // In aggressive mode, trigger a buy signal immediately
                            if (ESD_AggressiveMode && ESD_last_fvg_buy_time != ESD_bullish_mss_time)
                            {
                                ESD_last_fvg_buy_time = ESD_bullish_mss_time;
                                ESD_ExecuteAggressiveBuy("MSS", ESD_last_significant_ph, ESD_bullish_mss_time);
                            }

                            return;
                        }
                    }
                }
                break;
            }
        }
    }

    // Bearish MSS: Higher High followed by break of previous Higher Low
    if (ESD_last_significant_ph > 0 && ESD_last_significant_pl > 0)
    {
        // Check for a new higher high
        for (int i = 1; i < 10; i++)
        {
            if (high_buffer[i] > ESD_last_significant_ph)
            {
                // Found a new higher high, now check for break of previous higher low
                for (int j = 1; j < i; j++)
                {
                    if (low_buffer[j] < ESD_last_significant_pl)
                    {
                        // Bearish MSS detected
                        ESD_bearish_mss_detected = true;
                        ESD_bearish_mss_time = iTime(_Symbol, ESD_HigherTimeframe, j);

                        // Add to historical structures
                        ESD_SMStructure new_mss;
                        new_mss.time = ESD_bearish_mss_time;
                        new_mss.price = ESD_last_significant_pl;
                        new_mss.is_bullish = false;
                        new_mss.type = "MSS";
                        new_mss.top = ESD_last_significant_ph;
                        new_mss.bottom = ESD_last_significant_pl;
                        new_mss.quality_score = 0.8; // High quality signal
                        ESD_AddToHistoricalStructures(new_mss);

                        // Update trend strength
                        ESD_bearish_trend_strength = MathMin(1.0, ESD_bearish_trend_strength + 0.3);
                        ESD_bullish_trend_strength = MathMax(0.0, ESD_bullish_trend_strength - 0.3);

                        if (ESD_bearish_trend_strength > ESD_TrendStrengthThreshold)
                            ESD_bearish_trend_confirmed = true;

                        // In aggressive mode, trigger a sell signal immediately
                        if (ESD_AggressiveMode && ESD_last_fvg_sell_time != ESD_bearish_mss_time)
                        {
                            ESD_last_fvg_sell_time = ESD_bearish_mss_time;
                            ESD_ExecuteAggressiveSell("MSS", ESD_last_significant_pl, ESD_bearish_mss_time);
                        }

                        return;
                    }
                }
                break;
            }
        }
    }
}


bool ESD_ConfirmBreak(const double &price_buffer[], double level, bool is_bullish, int confirmation_bars)
{
    if (confirmation_bars <= 1)
        return true;

    int confirmed = 0;
    for (int i = 0; i < confirmation_bars; i++)
    {
        if (is_bullish && price_buffer[i] > level)
            confirmed++;
        else if (!is_bullish && price_buffer[i] < level)
            confirmed++;
    }

    return (confirmed >= confirmation_bars / 2 + 1);
}


bool ESD_IsValidMomentum(bool is_bullish)
{
    double ema20[], ema50[];
    ArraySetAsSeries(ema20, true);
    ArraySetAsSeries(ema50, true);

    int ema20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    int ema50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);

    CopyBuffer(ema20_handle, 0, 0, 3, ema20);
    CopyBuffer(ema50_handle, 0, 0, 3, ema50);

    if (is_bullish)
    {
        // EMA 20 > EMA 50 dan trending up
        return (ema20[0] > ema50[0]) && (ema20[0] > ema20[1]) && (ema50[0] > ema50[1]);
    }
    else
    {
        // EMA 20 < EMA 50 dan trending down
        return (ema20[0] < ema50[0]) && (ema20[0] < ema20[1]) && (ema50[0] < ema50[1]);
    }
}


double ESD_CalculateTimeframeStrength(ENUM_TIMEFRAMES tf)
{
    int bars = 10;
    double close_buffer[];
    ArraySetAsSeries(close_buffer, true);

    if (CopyClose(_Symbol, tf, 0, bars, close_buffer) < bars)
        return 0.0;

    double strength = 0.0;
    int bullish_count = 0;

    // Calculate momentum strength
    for (int i = 0; i < bars - 1; i++)
    {
        if (close_buffer[i] > close_buffer[i + 1])
            bullish_count++;
    }

    double bullish_ratio = (double)bullish_count / (bars - 1);
    strength = (bullish_ratio - 0.5) * 2; // Convert to -1 to +1 range

    return strength;
}


