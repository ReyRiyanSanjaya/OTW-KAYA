//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                       ESD_Execution.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Trade Execution & Management
//|
//| DESCRIPTION:
//|   Handles the execution of trade orders, including:
//|   - Aggressive Entry Logic (Buy/Sell)
//|   - ML-Enhanced Entry Logic (Buy/Sell)
//|   - Partial Take Profit Management (TP1, TP2, TP3)
//|   - Structure-Based Trailing Stop
//|   - Profit Protection Mechanisms
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh
//|   - ESD_Inputs.mqh
//|   - ESD_Trend.mqh
//|   - ESD_Core.mqh
//|   - ESD_ML.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_ExecuteAggressiveBuy()      : Execute aggressive buy order
//|   - ESD_ExecuteAggressiveSell()     : Execute aggressive sell order
//|   - ESD_ExecuteMLAggressiveBuy()    : ML-enhanced buy order
//|   - ESD_ExecuteMLAggressiveSell()   : ML-enhanced sell order
//|   - ESD_ManagePartialTP()           : Monitor and execute partial TPs
//|   - ESD_ManageStructureTrailing()   : Update trailing stops
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"
//+------------------------------------------------------------------+
//| Execute Aggressive Buy Order                                      |
//| Enters trade immediately if confirmation conditions are met       |
//+------------------------------------------------------------------+
void ESD_ExecuteAggressiveBuy(string signal_type, double trigger_price, datetime signal_time)
{
    // Jika sudah ada posisi, tidak usah entry lagi
    if (PositionSelect(_Symbol))
        return;

    // Tambahkan regime filter
    if (!ESD_RegimeFilter(true))
        return;

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bullish = (current_rates[0].close > current_rates[0].open);
        if (!is_bullish)
        {
            return; // Jangan entry buy jika candle saat ini bearish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, true))
        return; // Jangan entry sebelum retest terjadi

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Calculate SL and TP for aggressive mode
    double sl = 0;
    double tp = 0;

    // Use a wider SL for aggressive mode to account for higher risk
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier;

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
    {
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }

    case ESD_STRUCTURE_BASED:
    {
        // For FVG, place SL below the FVG
        if (signal_type == "FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
            sl = ESD_bullish_fvg_bottom - ESD_SlBufferPoints * point;
        // For CHOCH/BoS, place SL below the broken level
        else if (signal_type == "CHOCH" || signal_type == "BoS")
            sl = trigger_price - ESD_SlBufferPoints * point;
        else
            sl = ask - aggressive_sl_points * point; // Fallback

        // TP based on risk/reward or fixed points
        double risk = ask - sl;
        if (risk > 0)
            tp = ask + (risk * ESD_RiskRewardRatio);
        else
            tp = ask + aggressive_tp_points * point; // Fallback
        break;
    }

    default:
    {
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }
    }

    // Validasi SL/TP agar tidak salah
    if (sl >= ask)
        sl = ask - 10 * point; // Paksa SL minimal
    if (tp <= ask)
        tp = ask + 10 * point; // Paksa TP minimal
    if (sl <= 0 || tp <= 0)
        return; // Jangan trade jika SL/TP tidak valid

    string comment = StringFormat("Aggressive Buy (%s)", signal_type);
    // ESD_trade.Buy(ESD_LotSize, _Symbol, ask, sl, tp, comment); setingan manual lot

    // dengan regime filter ESD_GetRegimeAdjustedLotSize
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();
    ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
}


void ESD_ExecuteAggressiveSell(string signal_type, double trigger_price, datetime signal_time)
{
    // Jika sudah ada posisi, tidak usah entry lagi
    if (PositionSelect(_Symbol))
        return;

    // Tambahkan regime filter
    if (!ESD_RegimeFilter(false))
        return;

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bearish = (current_rates[0].close < current_rates[0].open);
        if (!is_bearish)
        {
            return; // Jangan entry sell jika candle saat ini bullish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, false))
        return; // Jangan entry sebelum retest terjadi

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Calculate SL and TP for aggressive mode
    double sl = 0;
    double tp = 0;

    // Use a wider SL for aggressive mode to account for higher risk
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier;

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
    {
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }

    case ESD_STRUCTURE_BASED:
    {
        // For FVG, place SL above the FVG
        if (signal_type == "FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
            sl = ESD_bearish_fvg_top + ESD_SlBufferPoints * point;
        // For CHOCH/BoS, place SL above the broken level
        else if (signal_type == "CHOCH" || signal_type == "BoS")
            sl = trigger_price + ESD_SlBufferPoints * point;
        else
            sl = bid + aggressive_sl_points * point; // Fallback

        // TP based on risk/reward or fixed points
        double risk = sl - bid;
        if (risk > 0)
            tp = bid - (risk * ESD_RiskRewardRatio);
        else
            tp = bid - aggressive_tp_points * point; // Fallback
        break;
    }

    default:
    {
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }
    }

    // Validasi SL/TP agar tidak salah
    if (sl <= bid)
        sl = bid + 10 * point; // Paksa SL minimal
    if (tp >= bid)
        tp = bid - 10 * point; // Paksa TP minimal
    if (sl <= 0 || tp <= 0)
        return; // Jangan trade jika SL/TP tidak valid

    string comment = StringFormat("Aggressive Sell (%s)", signal_type);
    // ESD_trade.Sell(ESD_LotSize, _Symbol, bid, sl, tp, comment); setingan manual lot size

    // dengan regime filter lot size
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();
    ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
}


void ESD_ExecuteMLAggressiveBuy(string signal_type, double trigger_price, datetime signal_time)
{
    // Enhanced aggressive buy dengan ML parameters
    if (PositionSelect(_Symbol))
        return;

    // ML Risk Appetite Check
    if (ESD_ml_risk_appetite < 0.3)
    {
        Print("ML Risk Appetite too low for aggressive buy: ", ESD_ml_risk_appetite);
        return;
    }

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bullish = (current_rates[0].close > current_rates[0].open);
        if (!is_bullish)
        {
            return; // Jangan entry buy jika candle saat ini bearish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, true))
        return;

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // ML-Enhanced SL and TP calculation
    double sl = 0;
    double tp = 0;
    double risk = ask - sl;

    // Use ML-adjusted multipliers untuk aggressive mode
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier * ESD_ml_optimal_sl_multiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier * ESD_ml_optimal_tp_multiplier;

    // ML-Enhanced position sizing
    double ml_lot_size = ESD_GetMLAdjustedLotSize();
    double aggressive_lot = ml_lot_size * 1.2; // Slightly larger lots untuk aggressive mode

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;

    case ESD_STRUCTURE_BASED:
        // For FVG, place SL below the FVG dengan ML adjustment
        if (signal_type == "ML_Aggressive_FVG" && ESD_bullish_fvg_bottom != EMPTY_VALUE)
            sl = ESD_bullish_fvg_bottom - (ESD_SlBufferPoints * ESD_ml_optimal_sl_multiplier * point);
        else
            sl = ask - aggressive_sl_points * point;

        if (risk > 0)
            tp = ask + (risk * ESD_RiskRewardRatio * ESD_ml_optimal_tp_multiplier);
        else
            tp = ask + aggressive_tp_points * point;
        break;

    default:
        sl = ask - aggressive_sl_points * point;
        tp = ask + aggressive_tp_points * point;
        break;
    }

    // Validasi SL/TP
    if (sl >= ask)
        sl = ask - 10 * point;
    if (tp <= ask)
        tp = ask + 10 * point;
    if (sl <= 0 || tp <= 0)
        return;

    string comment = StringFormat("ML-Aggressive Buy (%s) Conf:%.2f", signal_type, ESD_ml_risk_appetite);

    // Execute dengan ML-enhanced parameters
    ESD_ExecuteTradeWithPartialTP(true, ask, sl, comment);
}


void ESD_ExecuteMLAggressiveSell(string signal_type, double trigger_price, datetime signal_time)
{
    // Enhanced aggressive sell dengan ML parameters
    if (PositionSelect(_Symbol))
        return;

    // ML Risk Appetite Check
    if (ESD_ml_risk_appetite < 0.3)
    {
        Print("ML Risk Appetite too low for aggressive sell: ", ESD_ml_risk_appetite);
        return;
    }

    // CEK KONFIRMASI CANDLE SAAT INI
    MqlRates current_rates[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates);

    if (ArraySize(current_rates) > 0)
    {
        bool is_bearish = (current_rates[0].close < current_rates[0].open);
        if (!is_bearish)
        {
            return; // Jangan entry sell jika candle saat ini bullish
        }
    }

    // CEK APAKAH SUDAH ADA RETEST
    if (!ESD_HasRetestOccurred(signal_type, trigger_price, false))
        return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // ML-Enhanced SL and TP calculation
    double sl = 0;
    double tp = 0;
    double risk = sl - bid;

    // Use ML-adjusted multipliers untuk aggressive mode
    double aggressive_sl_points = ESD_StopLossPoints * ESD_AggressiveSLMultiplier * ESD_ml_optimal_sl_multiplier;
    double aggressive_tp_points = ESD_TakeProfitPoints * ESD_AggressiveTPMultiplier * ESD_ml_optimal_tp_multiplier;

    // ML-Enhanced position sizing
    double ml_lot_size = ESD_GetMLAdjustedLotSize();
    double aggressive_lot = ml_lot_size * 1.2; // Slightly larger lots untuk aggressive mode

    switch (ESD_SlTpMethod)
    {
    case ESD_FIXED_POINTS:
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;

    case ESD_STRUCTURE_BASED:
        // For FVG, place SL above the FVG dengan ML adjustment
        if (signal_type == "ML_Aggressive_FVG" && ESD_bearish_fvg_top != EMPTY_VALUE)
            sl = ESD_bearish_fvg_top + (ESD_SlBufferPoints * ESD_ml_optimal_sl_multiplier * point);
        else
            sl = bid + aggressive_sl_points * point;

        // TP based on ML-enhanced risk/reward
        if (risk > 0)
            tp = bid - (risk * ESD_RiskRewardRatio * ESD_ml_optimal_tp_multiplier);
        else
            tp = bid - aggressive_tp_points * point;
        break;

    default:
        sl = bid + aggressive_sl_points * point;
        tp = bid - aggressive_tp_points * point;
        break;
    }

    // Validasi SL/TP
    if (sl <= bid)
        sl = bid + 10 * point;
    if (tp >= bid)
        tp = bid - 10 * point;
    if (sl <= 0 || tp <= 0)
        return;

    string comment = StringFormat("ML-Aggressive Sell (%s) Conf:%.2f", signal_type, ESD_ml_risk_appetite);

    // Execute dengan ML-enhanced parameters
    ESD_ExecuteTradeWithPartialTP(false, bid, sl, comment);
}


void ESD_ExecuteTradeWithPartialTP(bool is_buy, double entry_price, double sl, string comment)
{
    double adjusted_lot = ESD_GetRegimeAdjustedLotSize();

    // Calculate enhanced TP levels
    ESD_CalculateEnhancedTP(is_buy, entry_price);

    // Execute trade dengan TP = 0 (akan di-manage manually)
    if (is_buy)
    {
        if (ESD_trade.Buy(adjusted_lot, _Symbol, entry_price, sl, 0, comment))
        {
            Print("BUY Order dengan PowerPull TP - Entry: ", entry_price,
                  " TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
            ESD_DrawTPObjects(); // Draw TP lines immediately
        }
    }
    else
    {
        if (ESD_trade.Sell(adjusted_lot, _Symbol, entry_price, sl, 0, comment))
        {
            Print("SELL Order dengan PowerPull TP - Entry: ", entry_price,
                  " TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
            ESD_DrawTPObjects(); // Draw TP lines immediately
        }
    }
}


void ESD_ManagePartialTP()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetTicket(i) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            ulong ticket = PositionGetTicket(i);
            double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            ulong pos_type = PositionGetInteger(POSITION_TYPE);

            // 🛡️ Profit Protection: Close jika profit sudah tinggi tapi belum kena TP
            if (profit > 0 && ESD_ShouldProtectProfit(ticket, profit))
            {
                ESD_trade.PositionClose(ticket);
                Print("Profit Protection activated! Closed position with profit: ", profit);
                ESD_RemoveTPObjects();
                continue;
            }

            if (pos_type == POSITION_TYPE_BUY)
            {
                // TP1 Logic
                if (!ESD_tp1_hit && current_price >= ESD_current_tp1 && ESD_PartialTPRatio1 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio1;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP1"))
                    {
                        ESD_tp1_hit = true;
                        Print("✅ TP1 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP2 Logic
                if (!ESD_tp2_hit && current_price >= ESD_current_tp2 && ESD_PartialTPRatio2 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio2;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP2"))
                    {
                        ESD_tp2_hit = true;
                        Print("✅ TP2 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP3 Logic
                if (!ESD_tp3_hit && current_price >= ESD_current_tp3 && ESD_PartialTPRatio3 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio3;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP3"))
                    {
                        ESD_tp3_hit = true;
                        Print("✅ TP3 HIT! Closed ", close_volume, " lots");
                        ESD_RemoveTPObjects(); // Hapus objek setelah TP3
                    }
                }
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                // TP1 Logic
                if (!ESD_tp1_hit && current_price <= ESD_current_tp1 && ESD_PartialTPRatio1 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio1;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP1"))
                    {
                        ESD_tp1_hit = true;
                        Print("✅ TP1 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP2 Logic
                if (!ESD_tp2_hit && current_price <= ESD_current_tp2 && ESD_PartialTPRatio2 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio2;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP2"))
                    {
                        ESD_tp2_hit = true;
                        Print("✅ TP2 HIT! Closed ", close_volume, " lots");
                    }
                }

                // TP3 Logic
                if (!ESD_tp3_hit && current_price <= ESD_current_tp3 && ESD_PartialTPRatio3 > 0)
                {
                    double close_volume = volume * ESD_PartialTPRatio3;
                    if (ESD_ExecutePartialClose(ticket, close_volume, "TP3"))
                    {
                        ESD_tp3_hit = true;
                        Print("✅ TP3 HIT! Closed ", close_volume, " lots");
                        ESD_RemoveTPObjects(); // Hapus objek setelah TP3
                    }
                }
            }

            // Update TP objects visual
            ESD_DrawTPObjects();
        }
    }
}


void ESD_ExecutePartialTPBuy(ulong ticket, double open_price, double current_price, double volume, double point)
{
    double profit_points = (current_price - open_price) / point;
    double close_volume = 0;

    // TP Level 1
    if (profit_points >= ESD_PartialTPDistance1 && ESD_PartialTPRatio1 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio1;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP1 executed for Buy: ", close_volume, " lots");
        }
    }

    // TP Level 2
    if (profit_points >= ESD_PartialTPDistance2 && ESD_PartialTPRatio2 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio2;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP2 executed for Buy: ", close_volume, " lots");
        }
    }

    // TP Level 3
    if (profit_points >= ESD_PartialTPDistance3 && ESD_PartialTPRatio3 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio3;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP3 executed for Buy: ", close_volume, " lots");
        }
    }
}


void ESD_ExecutePartialTPSell(ulong ticket, double open_price, double current_price, double volume, double point)
{
    double profit_points = (open_price - current_price) / point;
    double close_volume = 0;

    // TP Level 1
    if (profit_points >= ESD_PartialTPDistance1 && ESD_PartialTPRatio1 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio1;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP1 executed for Sell: ", close_volume, " lots");
        }
    }

    // TP Level 2
    if (profit_points >= ESD_PartialTPDistance2 && ESD_PartialTPRatio2 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio2;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP2 executed for Sell: ", close_volume, " lots");
        }
    }

    // TP Level 3
    if (profit_points >= ESD_PartialTPDistance3 && ESD_PartialTPRatio3 > 0)
    {
        close_volume = volume * ESD_PartialTPRatio3;
        if (close_volume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            ESD_trade.PositionClosePartial(ticket, close_volume);
            Print("Partial TP3 executed for Sell: ", close_volume, " lots");
        }
    }
}


void ESD_ManageStructureTrailing()
{
    if (!ESD_UseStructureTrailing)
        return;

    // Update swing levels setiap beberapa candle
    if (TimeCurrent() - ESD_last_trailing_update > PeriodSeconds(PERIOD_CURRENT) * 5)
    {
        ESD_UpdateSwingLevels();
        ESD_last_trailing_update = TimeCurrent();
    }

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            double current_sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = 0;
            ulong pos_type = PositionGetInteger(POSITION_TYPE);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

            if (pos_type == POSITION_TYPE_BUY)
            {
                current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                ESD_UpdateBuyTrailing(ticket, current_sl, open_price, current_price, point);
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                ESD_UpdateSellTrailing(ticket, current_sl, open_price, current_price, point);
            }
        }
    }
}


void ESD_UpdateBuyTrailing(ulong ticket, double current_sl, double open_price, double current_price, double point)
{
    double new_sl = current_sl;
    double activation_distance = ESD_TrailingActivation * point;
    if (current_price - open_price < activation_distance)
        return;

    double buffer = ESD_SlBufferPoints * point * ESD_TrailingBufferRatio;

    switch (ESD_TrailingType)
    {
    case TRAIL_SWING:
        if (ESD_last_swing_low > 0)
            new_sl = MathMax(new_sl, ESD_last_swing_low - buffer);
        break;

    case TRAIL_STRUCTURE:
        // Prioritize Volume Profile POC if available
        if (ESD_poc_price > 0)
            new_sl = MathMax(new_sl, ESD_poc_price - buffer);
        // Then FVG bottom
        else if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
            new_sl = MathMax(new_sl, ESD_bullish_fvg_bottom - buffer);
        // Then swing low
        else if (ESD_last_significant_pl > 0)
            new_sl = MathMax(new_sl, ESD_last_significant_pl - buffer);
        break;

    case TRAIL_BREAK_EVEN:
        new_sl = MathMax(new_sl, open_price + 10 * point);
        break;
    }

    // Ensure trailing SL is above current SL and safe distance from price
    if (new_sl > current_sl && new_sl < current_price - 100 * point)
    {
        ESD_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        Print("Buy Trailing SL updated to: ", new_sl);
    }
}


void ESD_UpdateSellTrailing(ulong ticket, double current_sl, double open_price, double current_price, double point)
{
    double new_sl = current_sl;
    double activation_distance = ESD_TrailingActivation * point;
    if (open_price - current_price < activation_distance)
        return;

    double buffer = ESD_SlBufferPoints * point * ESD_TrailingBufferRatio;

    switch (ESD_TrailingType)
    {
    case TRAIL_SWING:
        if (ESD_last_swing_high > 0)
            new_sl = MathMin(new_sl, ESD_last_swing_high + buffer);
        break;

    case TRAIL_STRUCTURE:
        // Prioritize Volume Profile POC
        if (ESD_poc_price > 0)
            new_sl = MathMin(new_sl, ESD_poc_price + buffer);
        // Then FVG top
        else if (ESD_bearish_fvg_top != EMPTY_VALUE)
            new_sl = MathMin(new_sl, ESD_bearish_fvg_top + buffer);
        // Then swing high
        else if (ESD_last_significant_ph > 0)
            new_sl = MathMin(new_sl, ESD_last_significant_ph + buffer);
        break;

    case TRAIL_BREAK_EVEN:
        new_sl = MathMin(new_sl, open_price - 10 * point);
        break;
    }

    // Ensure trailing SL is below current SL and safe distance from price
    if (new_sl < current_sl && new_sl > current_price + 100 * point)
    {
        ESD_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        Print("Sell Trailing SL updated to: ", new_sl);
    }
}


void ManagePositionsSL(double partialPercent = 0.50,
                     double cutProfitPips = 10,


bool ESD_ExecutePartialClose(ulong ticket, double volume, string reason)
{
    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    if (volume < min_volume)
    {
        Print("Volume too small for partial close. Required: ", min_volume, " Has: ", volume);
        return false;
    }

    if (ESD_trade.PositionClosePartial(ticket, volume))
    {
        Print("Partial Close (", reason, ") executed: ", volume, " lots");
        return true;
    }
    else
    {
        Print("Partial Close failed: ", ESD_trade.ResultRetcodeDescription());
        return false;
    }
}


bool ESD_ShouldProtectProfit(ulong ticket, double profit)
{
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Jika profit sudah besar tapi harga stuck/menolak di level tertentu
    double profit_points = MathAbs(current_price - open_price) / point;
    double expected_tp1 = ESD_UseAdaptiveTP ? 800 : ESD_PartialTPDistance1;

    // Close jika sudah melebihi TP1 expected distance tapi belum kena TP
    if (profit_points > expected_tp1 * 1.2 && profit > 0)
    {
        // Cek apakah harga sudah mulai reject
        if (ESD_IsPriceRejecting(current_price))
        {
            Print("Profit Protection: Price rejecting at high profit level");
            return true;
        }
    }

    return false;
}


void ESD_CalculateEnhancedTP(bool is_buy, double entry_price)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);

    if (is_buy)
    {
        // 🎯 TP1: Immediate Resistance (FVG/Liquidity)
        ESD_current_tp1 = ESD_GetNearestBearishLevel(entry_price);
        if (ESD_current_tp1 <= entry_price)
            ESD_current_tp1 = entry_price + (ESD_UseAdaptiveTP ? atr * 2 : 1000 * point);

        // 🎯 TP2: Swing High + ATR Buffer
        ESD_current_tp2 = ESD_GetSwingHighWithBuffer();
        if (ESD_current_tp2 <= ESD_current_tp1)
            ESD_current_tp2 = ESD_current_tp1 + (ESD_UseAdaptiveTP ? atr * 3 : 1000 * point);

        // 🎯 TP3: Major HTF Resistance dengan multiplier
        ESD_current_tp3 = ESD_GetMajorResistance();
        if (ESD_current_tp3 <= ESD_current_tp2)
            ESD_current_tp3 = ESD_current_tp2 + (ESD_UseAdaptiveTP ? atr * 4 : 1500 * point);

        // Apply multiplier untuk lebih aggressive
        if (ESD_TP_Multiplier > 1.0)
        {
            double base_move = (ESD_current_tp1 - entry_price) * (ESD_TP_Multiplier - 1.0);
            ESD_current_tp1 += base_move * 0.3;
            ESD_current_tp2 += base_move * 0.5;
            ESD_current_tp3 += base_move * 0.8;
        }
    }
    else
    {
        // 🎯 TP1: Immediate Support (FVG/Liquidity)
        ESD_current_tp1 = ESD_GetNearestBullishLevel(entry_price);
        if (ESD_current_tp1 >= entry_price)
            ESD_current_tp1 = entry_price - (ESD_UseAdaptiveTP ? atr * 2 : 1000 * point);

        // 🎯 TP2: Swing Low + ATR Buffer
        ESD_current_tp2 = ESD_GetSwingLowWithBuffer();
        if (ESD_current_tp2 >= ESD_current_tp1)
            ESD_current_tp2 = ESD_current_tp1 - (ESD_UseAdaptiveTP ? atr * 3 : 1000 * point);

        // 🎯 TP3: Major HTF Support dengan multiplier
        ESD_current_tp3 = ESD_GetMajorSupport();
        if (ESD_current_tp3 >= ESD_current_tp2)
            ESD_current_tp3 = ESD_current_tp2 - (ESD_UseAdaptiveTP ? atr * 4 : 1500 * point);

        // Apply multiplier untuk lebih aggressive
        if (ESD_TP_Multiplier > 1.0)
        {
            double base_move = (entry_price - ESD_current_tp1) * (ESD_TP_Multiplier - 1.0);
            ESD_current_tp1 -= base_move * 0.3;
            ESD_current_tp2 -= base_move * 0.5;
            ESD_current_tp3 -= base_move * 0.8;
        }
    }

    // Reset TP hit flags
    ESD_tp1_hit = ESD_tp2_hit = ESD_tp3_hit = false;

    Print("Enhanced TP Calculated - TP1: ", ESD_current_tp1, " TP2: ", ESD_current_tp2, " TP3: ", ESD_current_tp3);
}


double ESD_GetNearestBearishLevel(double current_price)
{
    double levels[10];
    int count = 0;

    // Priority 1: Bearish FVG Top
    if (ESD_bearish_fvg_top != EMPTY_VALUE && ESD_bearish_fvg_top > current_price)
        levels[count++] = ESD_bearish_fvg_top;

    // Priority 2: Bearish Liquidity
    if (ESD_bearish_liquidity != EMPTY_VALUE && ESD_bearish_liquidity > current_price)
        levels[count++] = ESD_bearish_liquidity;

    // Priority 3: Recent Swing High
    double recent_high = ESD_GetRecentSwingHigh();
    if (recent_high > current_price)
        levels[count++] = recent_high;

    // Priority 4: Order Block Resistance
    double ob_resistance = ESD_GetOrderBlockResistance();
    if (ob_resistance > current_price)
        levels[count++] = ob_resistance;

    // Return the nearest level
    if (count > 0)
    {
        double nearest = levels[0];
        for (int i = 1; i < count; i++)
        {
            if (levels[i] < nearest)
                nearest = levels[i];
        }
        return nearest;
    }

    return 0;
}


double ESD_GetNearestBullishLevel(double current_price)
{
    double levels[10];
    int count = 0;

    // Priority 1: Bullish FVG Bottom
    if (ESD_bullish_fvg_bottom != EMPTY_VALUE && ESD_bullish_fvg_bottom < current_price)
        levels[count++] = ESD_bullish_fvg_bottom;

    // Priority 2: Bullish Liquidity
    if (ESD_bullish_liquidity != EMPTY_VALUE && ESD_bullish_liquidity < current_price)
        levels[count++] = ESD_bullish_liquidity;

    // Priority 3: Recent Swing Low
    double recent_low = ESD_GetRecentSwingLow();
    if (recent_low < current_price)
        levels[count++] = recent_low;

    // Priority 4: Order Block Support
    double ob_support = ESD_GetOrderBlockSupport();
    if (ob_support < current_price)
        levels[count++] = ob_support;

    // Return the nearest level
    if (count > 0)
    {
        double nearest = levels[0];
        for (int i = 1; i < count; i++)
        {
            if (levels[i] > nearest)
                nearest = levels[i];
        }
        return nearest;
    }

    return 0;
}


bool ESD_IsPriceRejecting(double current_price)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) == 3)
    {
        // Deteksi pin bar atau rejection candle
        if (rates[0].close < rates[0].open &&
            (rates[0].high - rates[0].open) > (rates[0].open - rates[0].close) * 2)
            return true;

        // Deteksi double top/bottom pattern
        if (MathAbs(rates[0].high - rates[2].high) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
            return true;
    }

    return false;
}


bool PriceRejection(string symbol)
{
    MqlRates r[];
    if(CopyRates(symbol, PERIOD_M5, 0, 3, r) < 3)
        return false;

    // contoh logic rejection (upper shadow atau lower shadow panjang)
    double body   = MathAbs(r[1].close - r[1].open);
    double upperW = r[1].high - MathMax(r[1].close, r[1].open);
    double lowerW = MathMin(r[1].close, r[1].open) - r[1].low;

    return (upperW > body*1.5 || lowerW > body*1.5);
}


