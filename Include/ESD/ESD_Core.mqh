//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                            ESD_Core.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Core Analysis Functions
//|
//| DESCRIPTION:
//|   Central analysis engine for heatmap analysis, order flow,
//|   filter monitoring, and trading data tracking.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh, ESD_Visuals.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_InitializeTradingData()   : Initialize trade tracking
//|   - ESD_UpdateTradingData()       : Update trade metrics
//|   - ESD_AnalyzeHeatmap()          : Multi-TF heatmap analysis
//|   - ESD_HeatmapFilter()           : Filter by heatmap bias
//|   - ESD_AnalyzeOrderFlow()        : Order flow analysis
//|   - ESD_OrderFlowFilter()         : Filter by order flow
//|   - ESD_UpdateFilterStatus()      : Update filter panel
//|   - ESD_InitializeMonitoringPanels() : Setup dashboards
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

#include "ESD_Visuals.mqh"
#include "ESD_Confirmation.mqh"
void ESD_InitializeTradingData()
{
    ESD_trade_data.total_trades = 0;
    ESD_trade_data.winning_trades = 0;
    ESD_trade_data.losing_trades = 0;
    ESD_trade_data.total_profit = 0;
    ESD_trade_data.total_loss = 0;
    ESD_trade_data.largest_win = 0;
    ESD_trade_data.largest_loss = 0;
    ESD_trade_data.current_streak = 0;
    ESD_trade_data.best_streak = 0;
    ESD_trade_data.win_rate = 0;
    ESD_trade_data.profit_factor = 0;
    ESD_trade_data.average_win = 0;
    ESD_trade_data.average_loss = 0;
    ESD_trade_data.expectancy = 0;
    ESD_trade_data.last_trade_time = 0;
    ESD_trade_data.daily_profit = 0;
    ESD_trade_data.weekly_profit = 0;
    ESD_trade_data.monthly_profit = 0;

    ESD_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_weekly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_monthly_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}


void ESD_UpdateTradingData()
{
    double total_profit = 0;
    int wins = 0;
    int losses = 0;
    double profit_sum = 0;
    double loss_sum = 0;
    double largest_win = 0;
    double largest_loss = 0;
    double current_streak = 0;
    double best_streak = 0;
    double last_profit = 0;

    // Get history for today
    HistorySelect(0, TimeCurrent());
    int total = HistoryDealsTotal();

    for (int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != ESD_MagicNumber)
            continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        total_profit += profit;

        if (profit > 0)
        {
            wins++;
            profit_sum += profit;
            if (profit > largest_win)
                largest_win = profit;
            if (last_profit > 0)
                current_streak++;
            else
                current_streak = 1;
        }
        else
        {
            losses++;
            loss_sum += MathAbs(profit);
            if (profit < largest_loss)
                largest_loss = profit;
            if (last_profit <= 0)
                current_streak--;
            else
                current_streak = -1;
        }

        if (MathAbs(current_streak) > MathAbs(best_streak))
            best_streak = current_streak;

        last_profit = profit;
    }

    // Update trade data
    ESD_trade_data.total_trades = wins + losses;
    ESD_trade_data.winning_trades = wins;
    ESD_trade_data.losing_trades = losses;
    ESD_trade_data.total_profit = profit_sum;
    ESD_trade_data.total_loss = loss_sum;
    ESD_trade_data.largest_win = largest_win;
    ESD_trade_data.largest_loss = largest_loss;
    ESD_trade_data.current_streak = current_streak;
    ESD_trade_data.best_streak = best_streak;

    // Calculate metrics
    if (ESD_trade_data.total_trades > 0)
    {
        ESD_trade_data.win_rate = (double)wins / ESD_trade_data.total_trades * 100;
        ESD_trade_data.profit_factor = loss_sum > 0 ? profit_sum / loss_sum : profit_sum > 0 ? 999
                                                                                             : 0;
        ESD_trade_data.average_win = wins > 0 ? profit_sum / wins : 0;
        ESD_trade_data.average_loss = losses > 0 ? loss_sum / losses : 0;
        ESD_trade_data.expectancy = (ESD_trade_data.win_rate / 100 * ESD_trade_data.average_win) -
                                    ((100 - ESD_trade_data.win_rate) / 100 * ESD_trade_data.average_loss);
    }

    // Update period profits
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ESD_trade_data.daily_profit = current_balance - ESD_daily_start_balance;
    ESD_trade_data.weekly_profit = current_balance - ESD_weekly_start_balance;
    ESD_trade_data.monthly_profit = current_balance - ESD_monthly_start_balance;
}


void ESD_AnalyzeHeatmap()
{
    // Simulate heatmap analysis based on multi-timeframe momentum
    // In real implementation, this would connect to actual heatmap data

    double momentum_score = 0.0;
    int confirming_bars = 0;

    // Analyze multiple timeframes for heatmap-like strength assessment
    ENUM_TIMEFRAMES tf_list[4] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
    double timeframe_weights[4] = {0.2, 0.3, 0.3, 0.2}; // Weights for each TF

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

    // Visual feedback
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        string heatmap_text = StringFormat("HEATMAP: %.1f", ESD_heatmap_strength);
        color heatmap_color = ESD_NeutralColor;

        if (ESD_heatmap_strength > ESD_HeatmapStrengthThreshold)
            heatmap_color = ESD_StrongBullishColor;
        else if (ESD_heatmap_strength > 20)
            heatmap_color = ESD_WeakBullishColor;
        else if (ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold)
            heatmap_color = ESD_StrongBearishColor;
        else if (ESD_heatmap_strength < -20)
            heatmap_color = ESD_WeakBearishColor;

        ESD_DrawLabel("ESD_Heatmap_Status", iTime(_Symbol, PERIOD_CURRENT, 0),
                      iHigh(_Symbol, PERIOD_CURRENT, 0) + 100 * _Point,
                      heatmap_text, heatmap_color, true);
    }
}


bool ESD_HeatmapFilter(bool proposed_buy_signal)
{
    if (!ESD_UseHeatmapFilter)
        return true;

    // If heatmap strongly disagrees, filter the signal
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

    // If heatmap strongly agrees, allow earlier entries
    if (proposed_buy_signal && ESD_heatmap_bullish &&
        ESD_heatmap_strength > ESD_HeatmapStrengthThreshold * 1.2)
    {
        return true; // Strengthen buy signal
    }

    if (!proposed_buy_signal && ESD_heatmap_bearish &&
        ESD_heatmap_strength < -ESD_HeatmapStrengthThreshold * 1.2)
    {
        return true; // Strengthen sell signal
    }

    return true; // Default allow
}


void ESD_AnalyzeOrderFlow()
{
    if (!ESD_UseOrderFlow)
        return;

    double total_volume = 0.0;
    double bid_volume = 0.0;
    double ask_volume = 0.0;
    double volume_imbalance_sum = 0.0;

    // Analyze recent candles for order flow
    MqlRates rates[];
    long tick_volume[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(tick_volume, true);

    int bars = 20; // Analyze last 20 candles
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates) == bars &&
        CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars, tick_volume) == bars)
    {
        // Calculate delta and volume analysis
        for (int i = 0; i < bars; i++)
        {
            double candle_size = rates[i].high - rates[i].low;
            if (candle_size == 0)
                continue;

            // Simple delta calculation based on price action
            double buy_pressure = (rates[i].close - rates[i].low) / candle_size;
            double sell_pressure = (rates[i].high - rates[i].close) / candle_size;

            double candle_delta = (buy_pressure - sell_pressure) * tick_volume[i];
            ESD_cumulative_delta += candle_delta;

            // Volume classification (simplified)
            if (rates[i].close > rates[i].open)
                bid_volume += tick_volume[i] * buy_pressure;
            else
                ask_volume += tick_volume[i] * sell_pressure;

            total_volume += (double)tick_volume[i];
        }

        // Calculate order flow strength
        if (total_volume > 0)
        {
            ESD_delta_value = ESD_cumulative_delta / total_volume;
            ESD_volume_imbalance = (bid_volume - ask_volume) / total_volume;

            // Detect absorption
            ESD_absorption_detected = ESD_DetectAbsorption(rates, tick_volume, bars);

            // Detect imbalances
            ESD_imbalance_detected = ESD_DetectImbalance(rates, tick_volume, bars);

            // Calculate overall order flow strength
            ESD_orderflow_strength = (ESD_delta_value * 0.4 + ESD_volume_imbalance * 0.4 +
                                      (ESD_absorption_detected ? -0.2 : 0.0)) *
                                     100;
        }

        ESD_last_orderflow_update = TimeCurrent();
    }

    // Visual feedback
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        ESD_DrawOrderFlowIndicators();
    }
}


bool ESD_DetectAbsorption(const MqlRates &rates[], const long &volume[], int bars)
{
    // Detect absorption patterns (large volume without significant price movement)
    for (int i = 1; i < bars - 1; i++)
    {
        double price_change = MathAbs(rates[i].close - rates[i - 1].close) / rates[i - 1].close;
        double volume_ratio = (double)volume[i] / volume[i - 1];

        // High volume with small price change suggests absorption
        if (volume_ratio > 2.0 && price_change < 0.001) // 0.1% price change
        {
            return true;
        }
    }
    return false;
}


bool ESD_DetectImbalance(const MqlRates &rates[], const long &volume[], int bars)
{
    // Detect significant order flow imbalances
    int imbalance_count = 0;

    for (int i = 0; i < bars; i++)
    {
        double body_size = MathAbs(rates[i].close - rates[i].open);
        double total_range = rates[i].high - rates[i].low;

        if (total_range > 0)
        {
            double body_ratio = body_size / total_range;

            // Strong directional move with high volume indicates imbalance
            if (body_ratio > 0.7 && volume[i] > ESD_VolumeThreshold)
            {
                imbalance_count++;
            }
        }
    }

    return (imbalance_count >= 3); // Multiple imbalances detected
}


bool ESD_OrderFlowFilter(bool proposed_buy_signal)
{
    if (!ESD_UseOrderFlow)
        return true;

    double of_strength = MathAbs(ESD_orderflow_strength);

    // Strong order flow filter
    if (of_strength > 60) // Very strong order flow
    {
        if (proposed_buy_signal && ESD_orderflow_strength < -50)
            return false; // Reject buy on strong selling pressure

        if (!proposed_buy_signal && ESD_orderflow_strength > 50)
            return false; // Reject sell on strong buying pressure
    }

    // Absorption filter
    if (ESD_UseAbsorptionDetection && ESD_absorption_detected)
    {
        // Be cautious when absorption is detected
        if (of_strength < 30)
            return false;
    }

    // Delta confirmation
    if (ESD_UseDeltaAnalysis)
    {
        if (proposed_buy_signal && ESD_delta_value < -ESD_DeltaThreshold)
            return false; // Reject buy on negative delta

        if (!proposed_buy_signal && ESD_delta_value > ESD_DeltaThreshold)
            return false; // Reject sell on positive delta
    }

    return true;
}


void ESD_InitializeFilterMonitoring()
{
    ArrayResize(ESD_filter_status, 15);

    // Trend Filters
    ESD_filter_status[0].name = "Trend Direction";
    ESD_filter_status[1].name = "Trend Strength";
    ESD_filter_status[2].name = "Market Structure";

    // Confirmation Filters
    ESD_filter_status[3].name = "Heatmap Filter";
    ESD_filter_status[4].name = "Order Flow Filter";
    ESD_filter_status[5].name = "Volume Confirmation";
    ESD_filter_status[6].name = "Momentum Filter";

    // Entry Filters
    ESD_filter_status[7].name = "Zone Quality";
    ESD_filter_status[8].name = "Retest Confirmation";
    ESD_filter_status[9].name = "Rejection Candle";
    ESD_filter_status[10].name = "Liquidity Sweep";
    ESD_filter_status[11].name = "FVG Mitigation";

    // Risk Filters
    ESD_filter_status[12].name = "Risk-Reward Check";
    ESD_filter_status[13].name = "Zone Distance";
    ESD_filter_status[14].name = "Aggressive Mode";
}


void ESD_UpdateFilterStatus()
{
    // Trend Filters
    ESD_filter_status[0].enabled = true;
    ESD_filter_status[0].passed = ESD_bullish_trend_confirmed || ESD_bearish_trend_confirmed;
    ESD_filter_status[0].strength = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    ESD_filter_status[0].details = ESD_bullish_trend_confirmed ? "BULLISH" : ESD_bearish_trend_confirmed ? "BEARISH"
                                                                                                         : "RANGING";

    ESD_filter_status[1].enabled = ESD_UseStrictTrendConfirmation;
    ESD_filter_status[1].passed = ESD_bullish_trend_strength >= ESD_TrendStrengthThreshold ||
                                  ESD_bearish_trend_strength >= ESD_TrendStrengthThreshold;
    ESD_filter_status[1].strength = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    ESD_filter_status[1].details = StringFormat("Bull:%.1f%%, Bear:%.1f%%",
                                                ESD_bullish_trend_strength * 100,
                                                ESD_bearish_trend_strength * 100);

    ESD_filter_status[2].enabled = ESD_UseMarketStructureShift;
    ESD_filter_status[2].passed = ESD_bullish_mss_detected || ESD_bearish_mss_detected;
    ESD_filter_status[2].strength = 0.8;
    ESD_filter_status[2].details = StringFormat("MSS Bull:%s Bear:%s",
                                                ESD_bullish_mss_detected ? "YES" : "NO",
                                                ESD_bearish_mss_detected ? "YES" : "NO");

    // Confirmation Filters
    ESD_filter_status[3].enabled = ESD_UseHeatmapFilter;
    ESD_filter_status[3].passed = MathAbs(ESD_heatmap_strength) >= ESD_HeatmapStrengthThreshold;
    ESD_filter_status[3].strength = MathAbs(ESD_heatmap_strength) / 100.0;
    ESD_filter_status[3].details = StringFormat("Strength: %.1f", ESD_heatmap_strength);

    ESD_filter_status[4].enabled = ESD_UseOrderFlow;
    ESD_filter_status[4].passed = MathAbs(ESD_orderflow_strength) >= 30;
    ESD_filter_status[4].strength = MathAbs(ESD_orderflow_strength) / 100.0;
    ESD_filter_status[4].details = StringFormat("OF: %.1f, Delta: %.3f",
                                                ESD_orderflow_strength, ESD_delta_value);

    ESD_filter_status[5].enabled = ESD_UseVolumeConfirmation;
    ESD_filter_status[5].passed = ESD_volume_imbalance > ESD_DeltaThreshold;
    ESD_filter_status[5].strength = MathAbs(ESD_volume_imbalance);
    ESD_filter_status[5].details = StringFormat("Imbalance: %.3f", ESD_volume_imbalance);

    ESD_filter_status[6].enabled = true;
    ESD_filter_status[6].passed = ESD_IsValidMomentum(true) || ESD_IsValidMomentum(false);
    ESD_filter_status[6].strength = 0.7;
    ESD_filter_status[6].details = "Momentum OK";

    // Entry Filters
    ESD_filter_status[7].enabled = ESD_EnableQualityFilter;
    double current_quality = ESD_GetCurrentZoneQuality();
    ESD_filter_status[7].passed = current_quality >= ESD_MinZoneQualityScore;
    ESD_filter_status[7].strength = current_quality;
    ESD_filter_status[7].details = StringFormat("Quality: %.2f/%.2f",
                                                current_quality, ESD_MinZoneQualityScore);

    ESD_filter_status[8].enabled = true;
    bool retest_bull = ESD_HasRetestOccurred("FVG", ESD_bullish_fvg_bottom, true);
    bool retest_bear = ESD_HasRetestOccurred("FVG", ESD_bearish_fvg_top, false);
    ESD_filter_status[8].passed = retest_bull || retest_bear;
    ESD_filter_status[8].strength = 0.6;
    ESD_filter_status[8].details = StringFormat("Bull:%s Bear:%s",
                                                retest_bull ? "YES" : "NO",
                                                retest_bear ? "YES" : "NO");

    ESD_filter_status[9].enabled = ESD_UseRejectionCandleConfirmation;
    MqlRates current_candle[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_candle);
    bool rejection_bull = ESD_IsRejectionCandle(current_candle[0], true);
    bool rejection_bear = ESD_IsRejectionCandle(current_candle[0], false);
    ESD_filter_status[9].passed = rejection_bull || rejection_bear;
    ESD_filter_status[9].strength = 0.5;
    ESD_filter_status[9].details = StringFormat("Bull:%s Bear:%s",
                                                rejection_bull ? "YES" : "NO",
                                                rejection_bear ? "YES" : "NO");

    ESD_filter_status[10].enabled = ESD_EnableLiquiditySweepFilter;
    bool sweep_bull = ESD_IsLiquiditySweeped(ESD_bullish_liquidity, true);
    bool sweep_bear = ESD_IsLiquiditySweeped(ESD_bearish_liquidity, false);
    ESD_filter_status[10].passed = sweep_bull || sweep_bear;
    ESD_filter_status[10].strength = 0.7;
    ESD_filter_status[10].details = StringFormat("Bull:%s Bear:%s",
                                                 sweep_bull ? "YES" : "NO",
                                                 sweep_bear ? "YES" : "NO");

    ESD_filter_status[11].enabled = ESD_UseFvgMitigationFilter;
    bool fvg_bull = ESD_IsFVGMitigated(ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, true);
    bool fvg_bear = ESD_IsFVGMitigated(ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, false);
    ESD_filter_status[11].passed = fvg_bull || fvg_bear;
    ESD_filter_status[11].strength = 0.6;
    ESD_filter_status[11].details = StringFormat("Bull:%s Bear:%s",
                                                 fvg_bull ? "YES" : "NO",
                                                 fvg_bear ? "YES" : "NO");

    // Risk Filters
    ESD_filter_status[12].enabled = ESD_SlTpMethod == ESD_RISK_REWARD_RATIO;
    ESD_filter_status[12].passed = ESD_RiskRewardRatio >= 1.5;
    ESD_filter_status[12].strength = ESD_RiskRewardRatio / 3.0;
    ESD_filter_status[12].details = StringFormat("R/R: %.1f", ESD_RiskRewardRatio);

    ESD_filter_status[13].enabled = true;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double distance_bull = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ESD_bullish_fvg_bottom) / point;
    double distance_bear = (ESD_bearish_fvg_top - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
    bool distance_ok = MathAbs(distance_bull) <= ESD_ZoneTolerancePoints ||
                       MathAbs(distance_bear) <= ESD_ZoneTolerancePoints;
    ESD_filter_status[13].passed = distance_ok;
    ESD_filter_status[13].strength = 1.0 - (MathMin(MathAbs(distance_bull), MathAbs(distance_bear)) / ESD_ZoneTolerancePoints);
    ESD_filter_status[13].details = StringFormat("Bull:%.0f Bear:%.0f", distance_bull, distance_bear);

    ESD_filter_status[14].enabled = ESD_AggressiveMode;
    ESD_filter_status[14].passed = ESD_AggressiveMode;
    ESD_filter_status[14].strength = 1.0;
    ESD_filter_status[14].details = ESD_AggressiveMode ? "ACTIVE" : "INACTIVE";

    // Add liquidity zone filter status
    int liquidity_index = -1;
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "Liquidity Zone")
        {
            liquidity_index = i;
            break;
        }
    }

    if (liquidity_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        liquidity_index = new_size - 1;
        ESD_filter_status[liquidity_index].name = "Liquidity Zone";
    }

    ESD_filter_status[liquidity_index].enabled = ESD_UseLiquidityZones;
    ESD_filter_status[liquidity_index].passed = (ESD_upper_liquidity_zone != EMPTY_VALUE ||
                                                 ESD_lower_liquidity_zone != EMPTY_VALUE);
    ESD_filter_status[liquidity_index].strength = 0.8;
    ESD_filter_status[liquidity_index].details = StringFormat("Upper: %.5f Lower: %.5f",
                                                              ESD_upper_liquidity_zone,
                                                              ESD_lower_liquidity_zone);
    ESD_filter_status[liquidity_index].last_update = TimeCurrent();

    // Tambahkan BSL/SSL status
    int bsl_ssl_index = -1;
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "BSL/SSL Avoidance")
        {
            bsl_ssl_index = i;
            break;
        }
    }

    if (bsl_ssl_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        bsl_ssl_index = new_size - 1;
        ESD_filter_status[bsl_ssl_index].name = "BSL/SSL Avoidance";
    }

    ESD_filter_status[bsl_ssl_index].enabled = ESD_AvoidBSL_SSL;
    ESD_filter_status[bsl_ssl_index].passed = (ESD_bsl_level != EMPTY_VALUE || ESD_ssl_level != EMPTY_VALUE);
    ESD_filter_status[bsl_ssl_index].strength = 0.8;
    ESD_filter_status[bsl_ssl_index].details = StringFormat("BSL: %.5f SSL: %.5f",
                                                            ESD_bsl_level, ESD_ssl_level);
    ESD_filter_status[bsl_ssl_index].last_update = TimeCurrent();

    // Update timestamps
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        ESD_filter_status[i].last_update = TimeCurrent();
    }
}


void ESD_DeleteFilterMonitor()
{
    string names[] = {"ESD_FilterPanel", "ESD_FilterText"};
    for (int i = 0; i < ArraySize(names); i++)
    {
        if (ObjectFind(0, names[i]) >= 0)
            ObjectDelete(0, names[i]);
    }
}


void ESD_DeleteDataPanels()
{
    string names[] = {"ESD_DataPanel", "ESD_DataText", "ESD_SystemPanel", "ESD_SystemText"};
    for (int i = 0; i < ArraySize(names); i++)
    {
        if (ObjectFind(0, names[i]) >= 0)
            ObjectDelete(0, names[i]);
    }
}


void ESD_DeleteAllMonitoringPanels()
{
    ESD_DeleteFilterMonitor();
    ESD_DeleteDataPanels();
}


void ESD_InitializeMonitoringPanels()
{
    Print("Initializing ESD Monitoring Panels...");

    // Hapus panel lama terlebih dahulu
    ESD_DeleteAllMonitoringPanels();

    // Tunggu sebentar untuk memastikan objects terhapus
    Sleep(100);

    // Inisialisasi status filter
    ESD_InitializeFilterMonitoring();

    // Inisialisasi data trading
    ESD_InitializeTradingData();

    // Force draw panels based on input parameters
    if (ESD_ShowFilterMonitor)
    {
        ESD_DrawFilterMonitor();
        Print("Filter Monitor: ENABLED");
    }
    else
    {
        Print("Filter Monitor: DISABLED (input parameter)");
    }

    // Always draw system info panel
    ESD_DrawSystemInfoPanel();

    Print("ESD Monitoring Panels Initialization Complete");
    Print("Check corners: Filter=", EnumToString(ESD_FilterCorner), " Data=", EnumToString(ESD_DataCorner));
}


string ESD_GetSystemInfo()
{
    string system_info = "=== SYSTEM INFORMATION ===\n";

    // Account Information
    system_info += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n";
    system_info += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    system_info += "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    system_info += "Free Margin: $" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + "\n";
    system_info += "Margin Level: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) + "%\n\n";

    // Current Positions
    int buy_positions = 0;
    int sell_positions = 0;
    double total_floating = 0;

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetSymbol(i) == _Symbol)
        {
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if (magic == ESD_MagicNumber)
            {
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    buy_positions++;
                else
                    sell_positions++;

                total_floating += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }

    system_info += "Active Positions:\n";
    system_info += "  Buy: " + IntegerToString(buy_positions) + "\n";
    system_info += "  Sell: " + IntegerToString(sell_positions) + "\n";
    system_info += "  Floating: $" + DoubleToString(total_floating, 2) + "\n\n";

    // Market Conditions
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    system_info += "Market Conditions:\n";
    system_info += "  Spread: " + DoubleToString(spread / SymbolInfoDouble(_Symbol, SYMBOL_POINT), 0) + " pts\n";
    system_info += "  Digits: " + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) + "\n";
    system_info += "  Lot Size: " + DoubleToString(ESD_LotSize, 2) + "\n";
    system_info += "  Magic: " + IntegerToString(ESD_MagicNumber) + "\n";

    return system_info;
}


