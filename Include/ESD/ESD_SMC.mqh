//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                            ESD_SMC.mqh                            |
//+------------------------------------------------------------------+
//| MODULE: Smart Money Concepts (SMC) Analysis
//|
//| DESCRIPTION:
//|   Core SMC detection engine for institutional trading patterns
//|   including BoS, CHoCH, Order Blocks, FVG, and Liquidity Levels.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh, ESD_Visuals.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_DetectSMC()                  : Main detection loop
//|   - ESD_FindPivotHighIndex()         : Find swing high
//|   - ESD_FindPivotLowIndex()          : Find swing low
//|   - ESD_DetectMarketStructureShift() : Detect MSS
//|   - ESD_CalculateOrderBlockQuality() : Score OB quality
//|   - ESD_CalculateFVGQuality()        : Score FVG quality
//|
//| SMC CONCEPTS: BoS, CHoCH, OB, FVG, MSS, Liquidity Levels
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

#include "ESD_Visuals.mqh"
void ESD_DetectSMC()
{
    int bars_to_copy = ESD_SwingLookback + ESD_BosLookback + ESD_ObLookback + ESD_FvgLookback + 10;
    double high_buffer[];
    double low_buffer[];
    double close_buffer[];
    double open_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    ArraySetAsSeries(open_buffer, true);
    CopyHigh(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, high_buffer);
    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, close_buffer);
    CopyOpen(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, open_buffer);

    // Calculate ATR if needed
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double atr_value = 0;
    if (ESD_UseAtrMethod)
    {
        int atr_handle = iATR(_Symbol, ESD_HigherTimeframe, 14);
        if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
        {
            atr_value = atr_buffer[0];
        }
    }

    // --- Deteksi Pivot Point (Swing High/Low) ---
    int ph_index = ESD_FindPivotHighIndex(high_buffer, ESD_BosLookback);
    if (ph_index != -1)
    {
        double current_ph = high_buffer[ph_index];
        datetime current_ph_time = iTime(_Symbol, ESD_HigherTimeframe, ph_index);

        // Check if this is a significant swing based on ATR
        bool is_significant = true;
        if (ESD_UseAtrMethod && atr_value > 0)
        {
            double swing_strength = (current_ph - low_buffer[ph_index]) / atr_value;
            is_significant = swing_strength >= ESD_MinSwingStrength;
        }

        if (is_significant && current_ph_time > ESD_last_significant_ph_time)
        {
            ESD_last_significant_ph = current_ph;
            ESD_last_significant_ph_time = current_ph_time;

            // Add to historical structures
            ESD_SMStructure new_ph;
            new_ph.time = current_ph_time;
            new_ph.price = current_ph;
            new_ph.is_bullish = false;
            new_ph.type = "PH";
            new_ph.top = current_ph;
            new_ph.bottom = current_ph;
            new_ph.quality_score = ESD_CalculatePivotQuality(ph_index, high_buffer, low_buffer, false);
            ESD_AddToHistoricalStructures(new_ph);

            if (ESD_ShowObjects && ESD_ShowLabels)
            {
                ESD_DrawSwingPoint(current_ph_time, current_ph, "PH", ESD_BearishColor);
            }
        }
    }

    int pl_index = ESD_FindPivotLowIndex(low_buffer, ESD_BosLookback);
    if (pl_index != -1)
    {
        double current_pl = low_buffer[pl_index];
        datetime current_pl_time = iTime(_Symbol, ESD_HigherTimeframe, pl_index);

        // Check if this is a significant swing based on ATR
        bool is_significant = true;
        if (ESD_UseAtrMethod && atr_value > 0)
        {
            double swing_strength = (high_buffer[pl_index] - current_pl) / atr_value;
            is_significant = swing_strength >= ESD_MinSwingStrength;
        }

        if (is_significant && current_pl_time > ESD_last_significant_pl_time)
        {
            ESD_last_significant_pl = current_pl;
            ESD_last_significant_pl_time = current_pl_time;

            // Add to historical structures
            ESD_SMStructure new_pl;
            new_pl.time = current_pl_time;
            new_pl.price = current_pl;
            new_pl.is_bullish = true;
            new_pl.type = "PL";
            new_pl.top = current_pl;
            new_pl.bottom = current_pl;
            new_pl.quality_score = ESD_CalculatePivotQuality(pl_index, high_buffer, low_buffer, true);
            ESD_AddToHistoricalStructures(new_pl);

            if (ESD_ShowObjects && ESD_ShowLabels)
            {
                ESD_DrawSwingPoint(current_pl_time, current_pl, "PL", ESD_BullishColor);
            }
        }
    }

    // --- Deteksi Market Structure Shift (MSS) ---
    ESD_DetectMarketStructureShift(high_buffer, low_buffer, close_buffer);

    // --- Deteksi BoS / CHoCH ---
    datetime bos_time = iTime(_Symbol, ESD_HigherTimeframe, 1);

    // Bullish Break (PH Break)
    if (ESD_last_significant_ph != 0 && high_buffer[1] > ESD_last_significant_ph && bos_time > ESD_last_bos_time)
    {
        MqlRates current_rates[], prev_rates[];
        long volume_buffer[];
        ArraySetAsSeries(current_rates, true);
        ArraySetAsSeries(prev_rates, true);
        ArraySetAsSeries(volume_buffer, true);

        CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, current_rates);
        CopyRates(_Symbol, ESD_HigherTimeframe, 1, 2, prev_rates);
        CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, 3, volume_buffer);

        bool bullish_break = (current_rates[0].close > current_rates[0].open);

        bool confirmed_break = false;
        double avg_volume = 0;

        if (ESD_UseStrictTrendConfirmation)
        {
            confirmed_break = ESD_ConfirmBreak(high_buffer, ESD_last_significant_ph, true, ESD_TrendConfirmationBars);
        }
        else
        {
            double break_candle_range = prev_rates[0].high - prev_rates[0].low;
            double break_candle_body = MathAbs(prev_rates[0].close - prev_rates[0].open);
            double break_strength = break_candle_body / break_candle_range;

            if (ArraySize(volume_buffer) >= 3)
            {
                avg_volume = (volume_buffer[1] + volume_buffer[2]) / 2.0;
            }
            else
            {
                avg_volume = volume_buffer[0] * 0.8;
            }

            bool volume_confirm = (volume_buffer[0] > avg_volume * 1.4);
            bool momentum_confirm = (break_strength > 0.6);
            bool follow_through = bullish_break;

            confirmed_break = volume_confirm && momentum_confirm && follow_through;
        }

        if (confirmed_break && bullish_break)
        {
            // 🆕 LIQUIDITY GRAB STRATEGY: Entry lawan arah dulu
            if (ESD_UseLiquidityGrabStrategy && !liquidity_grab_active &&
                (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabCooldown)
            {
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                // Entry SELL lawan arah untuk ambil liquidity dengan TP yang lebih ketat
                double sl = ESD_last_significant_ph + (30 * point);       // SL lebih ketat
                double tp = ask - (ESD_PartialTPDistance1 * 0.5 * point); // TP lebih pendek

                string comment = StringFormat("LIQUIDITY-GRAB-SELL @ BoS - PH: %.5f", ESD_last_significant_ph);

                if (ESD_ExecuteTrade(false, ask, sl, tp, ESD_LiquidityGrabLotSize, comment))
                {
                    liquidity_grab_active = true;
                    liquidity_grab_level = ESD_last_significant_ph;
                    liquidity_grab_direction = -1;
                    liquidity_grab_signal_type = "BoS"; // Simpan jenis sinyal
                    liquidity_grab_signal_price = ESD_last_significant_ph;
                    last_liquidity_grab_time = TimeCurrent();

                    Print("Liquidity Grab SELL Executed: ", comment);
                }
            }

            // Tandai sinyal yang terdeteksi
            string signal_type = "BoS";
            if (ESD_bearish_trend_confirmed)
            {
                signal_type = "CHOCH";

                if (ESD_ShowObjects && ESD_ShowChoch)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_ph, true, ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_CHOCH_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_ph, "CHoCH", ESD_ChochColor, true);
                }

                ESD_SMStructure new_choch;
                new_choch.time = bos_time;
                new_choch.price = ESD_last_significant_ph;
                new_choch.is_bullish = true;
                new_choch.type = "CHOCH";
                new_choch.top = ESD_last_significant_ph;
                new_choch.bottom = ESD_last_significant_ph;
                new_choch.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_ph, true);
                ESD_AddToHistoricalStructures(new_choch);

                ESD_last_choch_time = bos_time;
            }
            else
            {
                if (ESD_ShowObjects && ESD_ShowBos)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_ph, true, ESD_BullishColor, ESD_BosLineStyle, ESD_BosStyle, "BOS");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_BoS_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_ph, "BoS", ESD_BullishColor, true);
                }

                ESD_SMStructure new_bos;
                new_bos.time = bos_time;
                new_bos.price = ESD_last_significant_ph;
                new_bos.is_bullish = true;
                new_bos.type = "BOS";
                new_bos.top = ESD_last_significant_ph;
                new_bos.bottom = ESD_last_significant_ph;
                new_bos.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_ph, true);
                ESD_AddToHistoricalStructures(new_bos);
            }

            // 🆕 TUNGGU LIQUIDITY GRAB SELESAI DULU SEBELUM ENTRY SINYAL ASLI
            if (!liquidity_grab_active)
            {
                // 🆕 KONFIRMASI CANDLE SETELAH LIQUIDITY GRAB SELESAI + KONDISI STOCHASTIC
                if (ESD_IsBullishConfirmationCandle())
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK BUY - TUNGGU OVERSOLD SELESAI
                    bool stochastic_ok = false;

                    // Untuk sinyal BUY, pastikan stochastic sudah/sedang dari oversold
                    if (signal_type == "CHOCH" || signal_type == "BoS")
                    {
                        // Cek apakah stochastic menunjukkan kondisi oversold atau keluar dari oversold
                        // --- Buat handle Stochastic
                        int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                        // --- Siapkan array penampung
                        double stoch_main_array[], stoch_signal_array[];

                        // --- Ambil nilai dari buffer
                        CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                        CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                        // --- Simpan ke variabel lama (nama tidak diubah)
                        double stoch_main = stoch_main_array[0];
                        double stoch_signal = stoch_signal_array[0];

                        // Kondisi untuk BUY: stochastic <= 20 (oversold) atau sedang keluar dari oversold
                        stochastic_ok = (stoch_main <= 20) || (stoch_main > 20 && stoch_main > stoch_signal);

                        if (stochastic_ok)
                        {
                            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                            double sl = ESD_last_significant_ph - (ESD_StopLossPoints * point);
                            double tp = ask + (ESD_PartialTPDistance3 * point);

                            string comment = StringFormat(signal_type,"-BUY after Liquidity Grab %s - PH: %.5f",  ESD_last_significant_ph);
                            if (ESD_ExecuteTrade(true, ask, sl, tp, ESD_LotSize, comment))
                            {
                                Print("Confirmed BUY after Liquidity Grab - ", signal_type);
                            }
                        }
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnCHOCHDetection && ESD_last_choch_buy_time != bos_time && signal_type == "CHOCH")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE BUY
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    ESD_last_choch_buy_time = bos_time;
                    ESD_ExecuteAggressiveBuy("CHOCH", ESD_last_significant_ph, bos_time);
                }
                else if (ESD_AggressiveMode && ESD_TradeOnBOSSignal && ESD_last_bos_buy_time != bos_time && signal_type == "BoS")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE BUY
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    // Untuk aggressive BUY, pastikan stochastic oversold
                    if (stoch_main <= 20 || (stoch_main > 20 && stoch_main > stoch_signal))
                    {
                        ESD_last_bos_buy_time = bos_time;
                        ESD_ExecuteAggressiveBuy("BoS", ESD_last_significant_ph, bos_time);
                    }
                }
            }

            double volume_strength = MathMin(volume_buffer[0] / (avg_volume + 0.1), 2.0) / 2.0;
            ESD_bullish_trend_strength = MathMin(1.0, ESD_bullish_trend_strength + 0.2 + (volume_strength * 0.1));
            ESD_bearish_trend_strength = MathMax(0.0, ESD_bearish_trend_strength - 0.2);

            if (ESD_bullish_trend_strength > ESD_TrendStrengthThreshold)
                ESD_bullish_trend_confirmed = true;

            ESD_bearish_trend_confirmed = false;
            ESD_last_bos_time = bos_time;
            ESD_bearish_liquidity = ESD_last_significant_ph;

            if (ESD_ObLookback < ArraySize(high_buffer))
            {
                ESD_bullish_ob_top = high_buffer[ESD_ObLookback];
                ESD_bullish_ob_bottom = low_buffer[ESD_ObLookback];

                ESD_SMStructure new_ob;
                new_ob.time = iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback);
                new_ob.price = (ESD_bullish_ob_top + ESD_bullish_ob_bottom) / 2;
                new_ob.is_bullish = true;
                new_ob.type = "OB";
                new_ob.top = ESD_bullish_ob_top;
                new_ob.bottom = ESD_bullish_ob_bottom;
                new_ob.quality_score = ESD_CalculateOrderBlockQuality(ESD_ObLookback, high_buffer, low_buffer, close_buffer, open_buffer, true);
                ESD_AddToHistoricalStructures(new_ob);
            }
        }
    }

    // Bearish Break (PL Break)
    if (ESD_last_significant_pl != 0 && low_buffer[1] < ESD_last_significant_pl && bos_time > ESD_last_bos_time)
    {
        MqlRates current_rates[];
        ArraySetAsSeries(current_rates, true);
        if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_rates) <= 0)
            return;

        bool bearish_break = (current_rates[0].close < current_rates[0].open);

        bool confirmed_break = false;
        if (ESD_UseStrictTrendConfirmation)
        {
            confirmed_break = ESD_ConfirmBreak(low_buffer, ESD_last_significant_pl, false, ESD_TrendConfirmationBars);
        }
        else
        {
            confirmed_break = true;
        }

        if (confirmed_break && bearish_break)
        {
            // 🆕 LIQUIDITY GRAB STRATEGY: Entry lawan arah dulu
            if (ESD_UseLiquidityGrabStrategy && !liquidity_grab_active &&
                (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabCooldown)
            {
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

                // Entry BUY lawan arah untuk ambil liquidity dengan TP yang lebih ketat
                double sl = ESD_last_significant_pl - (30 * point);       // SL lebih ketat
                double tp = bid + (ESD_PartialTPDistance1 * 0.5 * point); // TP lebih pendek

                string comment = StringFormat("LIQUIDITY-GRAB-BUY @ BoS - PL: %.5f", ESD_last_significant_pl);

                if (ESD_ExecuteTrade(true, bid, sl, tp, ESD_LiquidityGrabLotSize, comment))
                {
                    liquidity_grab_active = true;
                    liquidity_grab_level = ESD_last_significant_pl;
                    liquidity_grab_direction = 1;
                    liquidity_grab_signal_type = "BoS"; // Simpan jenis sinyal
                    liquidity_grab_signal_price = ESD_last_significant_pl;
                    last_liquidity_grab_time = TimeCurrent();

                    Print("Liquidity Grab BUY Executed: ", comment);
                }
            }

            // Tandai sinyal yang terdeteksi
            string signal_type = "BoS";
            if (ESD_bullish_trend_confirmed)
            {
                signal_type = "CHOCH";

                if (ESD_ShowObjects && ESD_ShowChoch)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_pl, false, ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_CHOCH_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_pl, "CHoCH", ESD_ChochColor, true);
                }

                ESD_SMStructure new_choch;
                new_choch.time = bos_time;
                new_choch.price = ESD_last_significant_pl;
                new_choch.is_bullish = false;
                new_choch.type = "CHOCH";
                new_choch.top = ESD_last_significant_pl;
                new_choch.bottom = ESD_last_significant_pl;
                new_choch.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_pl, false);
                ESD_AddToHistoricalStructures(new_choch);

                ESD_last_choch_time = bos_time;
            }
            else
            {
                if (ESD_ShowObjects && ESD_ShowBos)
                {
                    ESD_DrawBreakStructure(bos_time, ESD_last_significant_pl, false, ESD_BearishColor, ESD_BosLineStyle, ESD_BosStyle, "BOS");
                    if (ESD_ShowLabels)
                        ESD_DrawLabel("ESD_BoS_Label_" + IntegerToString(bos_time), bos_time, ESD_last_significant_pl, "BoS", ESD_BearishColor, true);
                }

                ESD_SMStructure new_bos;
                new_bos.time = bos_time;
                new_bos.price = ESD_last_significant_pl;
                new_bos.is_bullish = false;
                new_bos.type = "BOS";
                new_bos.top = ESD_last_significant_pl;
                new_bos.bottom = ESD_last_significant_pl;
                new_bos.quality_score = ESD_CalculateBreakQuality(bos_time, ESD_last_significant_pl, false);
                ESD_AddToHistoricalStructures(new_bos);
            }

            // 🆕 TUNGGU LIQUIDITY GRAB SELESAI DULU SEBELUM ENTRY SINYAL ASLI
            if (!liquidity_grab_active)
            {
                // 🆕 KONFIRMASI CANDLE SETELAH LIQUIDITY GRAB SELESAI + KONDISI STOCHASTIC
                if (ESD_IsBearishConfirmationCandle())
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK SELL - TUNGGU OVERBOUGHT SELESAI
                    bool stochastic_ok = false;

                    // Untuk sinyal SELL, pastikan stochastic sudah/sedang dari overbought
                    if (signal_type == "CHOCH" || signal_type == "BoS")
                    {
                        // Cek apakah stochastic menunjukkan kondisi overbought atau keluar dari overbought
                        // --- Buat handle Stochastic
                        int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                        // --- Siapkan array penampung
                        double stoch_main_array[], stoch_signal_array[];

                        // --- Ambil nilai dari buffer
                        CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                        CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                        // --- Simpan ke variabel lama (nama tidak diubah)
                        double stoch_main = stoch_main_array[0];
                        double stoch_signal = stoch_signal_array[0];

                        // Kondisi untuk SELL: stochastic >= 80 (overbought) atau sedang keluar dari overbought
                        stochastic_ok = (stoch_main >= 80) || (stoch_main < 80 && stoch_main < stoch_signal);

                        if (stochastic_ok)
                        {
                            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                            double sl = ESD_last_significant_pl + (ESD_StopLossPoints * point);
                            double tp = bid - (ESD_PartialTPDistance3 * point);

                            string comment = StringFormat(signal_type, "-SELL after Liquidity Take %s - PL: %.5f", ESD_last_significant_pl);
                            if (ESD_ExecuteTrade(false, bid, sl, tp, ESD_LotSize, comment))
                            {
                                Print("Confirmed SELL after Liquidity Grab - ", signal_type);
                            }
                        }
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnCHOCHDetection && ESD_last_choch_sell_time != bos_time && signal_type == "CHOCH")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE SELL
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    // Untuk aggressive SELL, pastikan stochastic overbought
                    if (stoch_main >= 80 || (stoch_main < 80 && stoch_main < stoch_signal))
                    {
                        ESD_last_choch_sell_time = bos_time;
                        ESD_ExecuteAggressiveSell("CHOCH", ESD_last_significant_pl, bos_time);
                    }
                }
                else if (ESD_AggressiveMode && ESD_TradeOnBOSSignal && ESD_last_bos_sell_time != bos_time && signal_type == "BoS")
                {
                    // 🆕 TAMBAH KONDISI STOCHASTIC UNTUK AGGRESSIVE SELL
                    // --- Buat handle Stochastic
                    int stoch_handle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

                    // --- Siapkan array penampung
                    double stoch_main_array[], stoch_signal_array[];

                    // --- Ambil nilai dari buffer
                    CopyBuffer(stoch_handle, 0, 0, 1, stoch_main_array);   // buffer 0 = MAIN (%K)
                    CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal_array); // buffer 1 = SIGNAL (%D)

                    // --- Simpan ke variabel lama (nama tidak diubah)
                    double stoch_main = stoch_main_array[0];
                    double stoch_signal = stoch_signal_array[0];

                    ESD_last_bos_sell_time = bos_time;
                    ESD_ExecuteAggressiveSell("BoS", ESD_last_significant_pl, bos_time);
                    
                }
            }

            ESD_bearish_trend_strength = MathMin(1.0, ESD_bearish_trend_strength + 0.2);
            ESD_bullish_trend_strength = MathMax(0.0, ESD_bullish_trend_strength - 0.2);

            if (ESD_bearish_trend_strength > ESD_TrendStrengthThreshold)
                ESD_bearish_trend_confirmed = true;

            ESD_bullish_trend_confirmed = false;
            ESD_last_bos_time = bos_time;
            ESD_bullish_liquidity = ESD_last_significant_pl;

            if (ESD_ObLookback < bars_to_copy)
            {
                ESD_bearish_ob_top = high_buffer[ESD_ObLookback];
                ESD_bearish_ob_bottom = low_buffer[ESD_ObLookback];

                ESD_SMStructure new_ob;
                new_ob.time = iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback);
                new_ob.price = (ESD_bearish_ob_top + ESD_bearish_ob_bottom) / 2;
                new_ob.is_bullish = false;
                new_ob.type = "OB";
                new_ob.top = ESD_bearish_ob_top;
                new_ob.bottom = ESD_bearish_ob_bottom;
                new_ob.quality_score = ESD_CalculateOrderBlockQuality(ESD_ObLookback, high_buffer, low_buffer, close_buffer, open_buffer, false);
                ESD_AddToHistoricalStructures(new_ob);
            }
        }
    }

    // 🆕 RESET LIQUIDITY GRAB JIKA SUDAH EXPIRED
    if (liquidity_grab_active && (TimeCurrent() - last_liquidity_grab_time) > ESD_LiquidityGrabTimeout)
    {
        liquidity_grab_active = false;
        Print("Liquidity Grab expired - no confirmation within ", ESD_LiquidityGrabTimeout, " seconds");
    }

    // --- Deteksi FVG (Fair Value Gap) ---
    datetime fvg_time = iTime(_Symbol, ESD_HigherTimeframe, 0);
    if (low_buffer[2] > high_buffer[0])
    {
        ESD_bullish_fvg_top = high_buffer[0];
        ESD_bullish_fvg_bottom = low_buffer[2];
        ESD_fvg_creation_time = fvg_time;

        if (ESD_ShowObjects && ESD_ShowFvg)
        {
            ESD_DrawFVG("ESD_BullishFVG", ESD_bullish_fvg_top, ESD_bullish_fvg_bottom, ESD_fvg_creation_time, ESD_BullishColor);
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_BullishFVG_Label", fvg_time, ESD_bullish_fvg_bottom, "FVG", ESD_BullishColor, true);
                ESD_DrawLabel("ESD_BullishPOI_Label", fvg_time, (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2, "POI", clrWhite, false);
            }
        }

        ESD_SMStructure new_fvg;
        new_fvg.time = fvg_time;
        new_fvg.price = (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2;
        new_fvg.is_bullish = true;
        new_fvg.type = "FVG";
        new_fvg.top = ESD_bullish_fvg_top;
        new_fvg.bottom = ESD_bullish_fvg_bottom;
        new_fvg.quality_score = ESD_CalculateFVGQuality(0, high_buffer, low_buffer, true);
        ESD_AddToHistoricalStructures(new_fvg);

        if (ESD_AggressiveMode && ESD_TradeOnFVGDetection && ESD_last_fvg_buy_time != fvg_time && !liquidity_grab_active)
        {
            ESD_last_fvg_buy_time = fvg_time;
            ESD_ExecuteAggressiveBuy("FVG", (ESD_bullish_fvg_top + ESD_bullish_fvg_bottom) / 2, fvg_time);
        }
    }

    if (high_buffer[2] < low_buffer[0])
    {
        ESD_bearish_fvg_top = high_buffer[2];
        ESD_bearish_fvg_bottom = low_buffer[0];
        ESD_fvg_creation_time = fvg_time;

        if (ESD_ShowObjects && ESD_ShowFvg)
        {
            ESD_DrawFVG("ESD_BearishFVG", ESD_bearish_fvg_top, ESD_bearish_fvg_bottom, ESD_fvg_creation_time, ESD_BearishColor);
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_BearishFVG_Label", fvg_time, ESD_bearish_fvg_top, "FVG", ESD_BearishColor, true);
                ESD_DrawLabel("ESD_BearishPOI_Label", fvg_time, (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2, "POI", clrWhite, false);
            }
        }

        ESD_SMStructure new_fvg;
        new_fvg.time = fvg_time;
        new_fvg.price = (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2;
        new_fvg.is_bullish = false;
        new_fvg.type = "FVG";
        new_fvg.top = ESD_bearish_fvg_top;
        new_fvg.bottom = ESD_bearish_fvg_bottom;
        new_fvg.quality_score = ESD_CalculateFVGQuality(0, high_buffer, low_buffer, false);
        ESD_AddToHistoricalStructures(new_fvg);

        if (ESD_AggressiveMode && ESD_TradeOnFVGDetection && ESD_last_fvg_sell_time != fvg_time && !liquidity_grab_active)
        {
            ESD_last_fvg_sell_time = fvg_time;
            ESD_ExecuteAggressiveSell("FVG", (ESD_bearish_fvg_top + ESD_bearish_fvg_bottom) / 2, fvg_time);
        }
    }

    // Draw Objects
    if (ESD_ShowObjects)
    {
        if (ESD_ShowOb)
        {
            ESD_DrawOrderBlock("ESD_BullishOB", ESD_bullish_ob_top, ESD_bullish_ob_bottom, ESD_BullishColor, ESD_ObLineStyle, ESD_ObStyle);
            ESD_DrawOrderBlock("ESD_BearishOB", ESD_bearish_ob_top, ESD_bearish_ob_bottom, ESD_BearishColor, ESD_ObLineStyle, ESD_ObStyle);
        }

        if (ESD_ShowLabels)
        {
            if (ESD_bullish_ob_bottom != EMPTY_VALUE)
            {
                ESD_DrawLabel("ESD_BullishOB_Label", fvg_time, ESD_bullish_ob_bottom, "OB", ESD_BullishColor, true);
                ESD_DrawLabel("ESD_BullishOB_POI_Label", fvg_time, (ESD_bullish_ob_top + ESD_bullish_ob_bottom) / 2, "POI", clrWhite, false);
            }
            if (ESD_bearish_ob_top != EMPTY_VALUE)
            {
                ESD_DrawLabel("ESD_BearishOB_Label", fvg_time, ESD_bearish_ob_top, "OB", ESD_BearishColor, true);
                ESD_DrawLabel("ESD_BearishOB_POI_Label", fvg_time, (ESD_bearish_ob_top + ESD_bearish_ob_bottom) / 2, "POI", clrWhite, false);
            }
        }

        // Draw Liquidity Levels
        if (ESD_ShowLiquidity)
        {
            if (ESD_bullish_liquidity != EMPTY_VALUE)
            {
                ESD_DrawLiquidityLine("ESD_BullishLiquidity", ESD_bullish_liquidity, clrAqua);
                if (ESD_ShowLabels)
                    ESD_DrawLabel("ESD_BullishLiq_Label", fvg_time, ESD_bullish_liquidity, "LIQUIDITY", clrAqua, true);
            }
            if (ESD_bearish_liquidity != EMPTY_VALUE)
            {
                ESD_DrawLiquidityLine("ESD_BearishLiquidity", ESD_bearish_liquidity, clrMagenta);
                if (ESD_ShowLabels)
                    ESD_DrawLabel("ESD_BearishLiq_Label", fvg_time, ESD_bearish_liquidity, "LIQUIDITY", clrMagenta, true);
            }
        }

        // Draw Market Structure Shift
        if (ESD_ShowLabels)
        {
            if (ESD_bullish_mss_detected)
                ESD_DrawLabel("ESD_BullishMSS_Label", ESD_bullish_mss_time, 0, "MSS", ESD_BullishColor, true);
            if (ESD_bearish_mss_detected)
                ESD_DrawLabel("ESD_BearishMSS_Label", ESD_bearish_mss_time, 0, "MSS", ESD_BearishColor, true);
        }
    }

    // Draw Heatmap strength indicator
    if (ESD_ShowObjects && ESD_UseHeatmapFilter)
    {
        string heatmap_indicator = "ESD_Heatmap_Indicator";
        double price_level = iLow(_Symbol, PERIOD_CURRENT, 0) - 150 * _Point;

        color indicator_color = ESD_NeutralColor;
        if (ESD_heatmap_strength > 0)
            indicator_color = (color)ColorToARGB(ESD_StrongBullishColor, (uchar)(MathAbs(ESD_heatmap_strength) * 2.55));
        else
            indicator_color = (color)ColorToARGB(ESD_StrongBearishColor, (uchar)(MathAbs(ESD_heatmap_strength) * 2.55));

        ESD_DrawLabel(heatmap_indicator, iTime(_Symbol, PERIOD_CURRENT, 0),
                      price_level,
                      StringFormat("HEAT: %+.0f", ESD_heatmap_strength),
                      indicator_color, true);
    }

    // Draw historical structures if enabled
    if (ESD_ShowHistorical)
    {
        ESD_DrawHistoricalStructures();
    }
}


int ESD_FindPivotHighIndex(const double &high_buffer[], int lookback)
{
    int bars_to_copy = lookback * 2 + 10;
    double low_buffer[], close_buffer[];
    long volume_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);
    ArraySetAsSeries(close_buffer, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyLow(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, low_buffer);
    CopyClose(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, close_buffer);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, 0, bars_to_copy, volume_buffer);

    for (int i = lookback; i < ArraySize(high_buffer) - lookback; i++)
    {
        bool is_pivot = true;

        // 1. Price Structure Check (Existing)
        for (int j = i - lookback; j <= i + lookback; j++)
        {
            if (j == i)
                continue;
            if (high_buffer[j] > high_buffer[i])
            {
                is_pivot = false;
                break;
            }
        }

        if (is_pivot)
        {
            // 2. ENHANCEMENT: Volume Confirmation
            double avg_volume = 0;
            int volume_lookback = MathMin(5, i);
            int valid_count = 0; // Count valid volume readings

            for (int k = 1; k <= volume_lookback; k++)
            {
                int index = i - k;
                // Check if index is valid
                if (index >= 0 && index < ArraySize(volume_buffer))
                {
                    avg_volume += (double)volume_buffer[index];
                    valid_count++;
                }
            }

            // Check if we have enough valid data points
            if (valid_count == 0)
                return -1;
            avg_volume /= valid_count;

            // Check if current volume index is valid
            if (i >= ArraySize(volume_buffer))
                return -1;
            bool volume_ok = (volume_buffer[i] > avg_volume * 1.3);

            // 3. ENHANCEMENT: Momentum Strength
            // Check if current and previous candle indices are valid
            if (i >= ArraySize(high_buffer) || i >= ArraySize(low_buffer) ||
                (i - 1) < 0 || (i - 1) >= ArraySize(high_buffer) || (i - 1) >= ArraySize(low_buffer))
                return -1;

            double candle_range = high_buffer[i] - low_buffer[i];
            double prev_range = high_buffer[i - 1] - low_buffer[i - 1];
            bool momentum_ok = (candle_range > prev_range * 0.7);

            // 4. ENHANCEMENT: Close Position
            if (i >= ArraySize(close_buffer))
                return -1;
            double close_position = (close_buffer[i] - low_buffer[i]) / candle_range;
            bool close_ok = (close_position < 0.4);

            if (volume_ok && momentum_ok && close_ok)
                return i;
        }
    }
    return -1;
}


int ESD_FindPivotLowIndex(const double &price_array[], int lookback)
{
    for (int i = lookback; i < ArraySize(price_array) - lookback; i++)
    {
        bool is_pivot = true;
        for (int j = i - lookback; j <= i + lookback; j++)
        {
            if (price_array[j] < price_array[i])
            {
                is_pivot = false;
                break;
            }
        }
        if (is_pivot)
            return i;
    }
    return -1;
}


double ESD_CalculatePivotQuality(int index, const double &high_buffer[], const double &low_buffer[], bool is_low)
{
    double quality = 0.5; // Base quality

    // Check the strength of the pivot (how much it stands out)
    if (is_low)
    {
        double min_left = low_buffer[index];
        double min_right = low_buffer[index];

        for (int i = index - ESD_BosLookback; i < index; i++)
        {
            if (i >= 0 && low_buffer[i] < min_left)
                min_left = low_buffer[i];
        }

        for (int i = index + 1; i <= index + ESD_BosLookback; i++)
        {
            if (i < ArraySize(low_buffer) && low_buffer[i] < min_right)
                min_right = low_buffer[i];
        }

        // The higher the pivot compared to surrounding lows, the higher the quality
        double left_diff = low_buffer[index] - min_left;
        double right_diff = low_buffer[index] - min_right;
        quality += (left_diff + right_diff) / (2 * low_buffer[index]) * 5;
    }
    else
    {
        double max_left = high_buffer[index];
        double max_right = high_buffer[index];

        for (int i = index - ESD_BosLookback; i < index; i++)
        {
            if (i >= 0 && high_buffer[i] > max_left)
                max_left = high_buffer[i];
        }

        for (int i = index + 1; i <= index + ESD_BosLookback; i++)
        {
            if (i < ArraySize(high_buffer) && high_buffer[i] > max_right)
                max_right = high_buffer[i];
        }

        // The lower the pivot compared to surrounding highs, the higher the quality
        double left_diff = max_left - high_buffer[index];
        double right_diff = max_right - high_buffer[index];
        quality += (left_diff + right_diff) / (2 * high_buffer[index]) * 5;
    }

    return MathMin(1.0, quality);
}


double ESD_CalculateBreakQuality(datetime time, double level, bool is_bullish)
{
    double quality = 0.5; // Base quality

    // Get the bar that broke the level
    int shift = iBarShift(_Symbol, ESD_HigherTimeframe, time);
    if (shift < 0)
        return quality;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, shift, 2, rates);

    if (ArraySize(rates) < 2)
        return quality;

    // Check the strength of the break (how much it exceeded the level)
    if (is_bullish)
    {
        double excess = rates[0].high - level;
        double range = rates[0].high - rates[0].low;
        quality += (excess / range) * 0.3;

        // Check if the close is also above the level
        if (rates[0].close > level)
            quality += 0.2;
    }
    else
    {
        double excess = level - rates[0].low;
        double range = rates[0].high - rates[0].low;
        quality += (excess / range) * 0.3;

        // Check if the close is also below the level
        if (rates[0].close < level)
            quality += 0.2;
    }

    return MathMin(1.0, quality);
}


double ESD_CalculateOrderBlockQuality(int index, const double &high_buffer[], const double &low_buffer[],
                                      const double &close_buffer[], const double &open_buffer[], bool is_bullish)


double ESD_CalculateFVGQuality(int index, const double &high_buffer[], const double &low_buffer[], bool is_bullish)
{
    double quality = 0.5; // Base quality

    if (index < 0 || index + 2 >= ArraySize(high_buffer))
        return quality;

    // ENHANCEMENT: Add volume analysis untuk FVG
    MqlRates rates[];
    long volume_buffer[];
    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(volume_buffer, true);

    CopyRates(_Symbol, ESD_HigherTimeframe, index, 3, rates);
    CopyTickVolume(_Symbol, ESD_HigherTimeframe, index, 3, volume_buffer);

    // Calculate FVG size (existing)
    double fvg_size;
    if (is_bullish)
        fvg_size = low_buffer[index + 2] - high_buffer[index];
    else
        fvg_size = high_buffer[index + 2] - low_buffer[index];

    // Existing ATR-based quality
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double atr_value = 0;
    int atr_handle = iATR(_Symbol, ESD_HigherTimeframe, 14);
    if (CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
    {
        atr_value = atr_buffer[0];
    }

    if (atr_value > 0)
    {
        quality += MathMin(0.3, fvg_size / atr_value);
    }

    // ENHANCEMENT 1: Volume Confirmation untuk FVG
    if (ArraySize(volume_buffer) >= 3)
    {
        double avg_volume = (volume_buffer[0] + volume_buffer[1] + volume_buffer[2]) / 3.0;
        double fvg_volume = (double)MathMax(volume_buffer[0], volume_buffer[2]); // Volume di candle FVG

        if (avg_volume > 0)
            quality += MathMin(0.2, (fvg_volume / avg_volume - 1.0) * 0.1);
    }

    // ENHANCEMENT 2: Momentum Strength of FVG candles - PERBAIKAN DI SINI
    double range1 = high_buffer[index + 2] - low_buffer[index + 2];
    double range2 = high_buffer[index] - low_buffer[index];
    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);

    // PERBAIKAN: Handle zero division untuk range1 dan range2
    double strength1 = 0.0;
    double strength2 = 0.0;

    if (range1 > 0)
        strength1 = body1 / range1;
    else
        strength1 = (body1 > 0) ? 1.0 : 0.0; // Jika range=0 tapi ada body

    if (range2 > 0)
        strength2 = body2 / range2;
    else
        strength2 = (body2 > 0) ? 1.0 : 0.0; // Jika range=0 tapi ada body

    quality += (strength1 + strength2) * 0.1; // Strong candles = better FVG

    // ENHANCEMENT 3: Follow-through Confirmation
    if (index > 0)
    {
        if (is_bullish)
        {
            // Untuk bullish FVG, price harus maintain di atas FVG bottom
            bool follow_through = (low_buffer[index - 1] > low_buffer[index + 2]);
            if (follow_through)
                quality += 0.1;
        }
        else
        {
            // Untuk bearish FVG, price harus maintain di bawah FVG top
            bool follow_through = (high_buffer[index - 1] < high_buffer[index + 2]);
            if (follow_through)
                quality += 0.1;
        }
    }

    return MathMin(1.0, quality);
}


void ESD_AddToHistoricalStructures(ESD_SMStructure &structure)
{
    int size = ArraySize(ESD_smc_structures);
    ArrayResize(ESD_smc_structures, size + 1);
    ESD_smc_structures[size] = structure;
}


double ESD_GetZoneQuality(string zone_type, datetime time, bool is_bullish)
{
    int structures_count = ArraySize(ESD_smc_structures);
    for (int i = structures_count - 1; i >= 0; i--)
    {
        ESD_SMStructure structure = ESD_smc_structures[i];

        if (structure.type == zone_type &&
            structure.is_bullish == is_bullish &&
            structure.time == time)
        {
            return structure.quality_score;
        }
    }

    return 0.5; // Default quality if not found
}


double ESD_GetCurrentZoneQuality()
{
    double quality = 0.0;
    int count = 0;

    if (ESD_bullish_fvg_bottom != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), true);
        count++;
    }

    if (ESD_bearish_fvg_top != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("FVG", iTime(_Symbol, ESD_HigherTimeframe, 0), false);
        count++;
    }

    if (ESD_bullish_ob_bottom != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), true);
        count++;
    }

    if (ESD_bearish_ob_top != EMPTY_VALUE)
    {
        quality += ESD_GetZoneQuality("OB", iTime(_Symbol, ESD_HigherTimeframe, ESD_ObLookback), false);
        count++;
    }

    return count > 0 ? quality / count : 0.0;
}


bool ESD_IsRejectionCandle(MqlRates &candle, bool is_bullish)
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


bool ESD_IsLiquiditySweeped(double liquidity_level, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, 5, rates);

    if (ArraySize(rates) < 5)
        return false;

    if (is_bullish)
    {
        // Check if price swept below bullish liquidity and came back up
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].low < liquidity_level && rates[0].close > liquidity_level)
                return true;
        }
    }
    else
    {
        // Check if price swept above bearish liquidity and came back down
        for (int i = 1; i < 5; i++)
        {
            if (rates[i].high > liquidity_level && rates[0].close < liquidity_level)
                return true;
        }
    }

    return false;
}


bool ESD_IsFVGMitigated(double fvg_top, double fvg_bottom, bool is_bullish)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, ESD_HigherTimeframe, 0, 10, rates);

    if (ArraySize(rates) < 10)
        return false;

    if (is_bullish)
    {
        // Check if bullish FVG has been mitigated (price touched the top)
        for (int i = 1; i < 10; i++)
        {
            if (rates[i].high >= fvg_top)
                return true;
        }
    }
    else
    {
        // Check if bearish FVG has been mitigated (price touched the bottom)
        for (int i = 1; i < 10; i++)
        {
            if (rates[i].low <= fvg_bottom)
                return true;
        }
    }

    return false;
}


double ESD_GetHTFSwingHigh()
{
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);
    if (CopyHigh(_Symbol, ESD_SupremeTimeframe, 0, 20, high_buffer) == 20)
    {
        for (int i = 1; i < 19; i++)
            if (high_buffer[i] >= high_buffer[i - 1] && high_buffer[i] >= high_buffer[i + 1])
                return high_buffer[i];
    }
    return 0;
}


double ESD_GetHTFSwingLow()
{
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);
    if (CopyLow(_Symbol, ESD_SupremeTimeframe, 0, 20, low_buffer) == 20)
    {
        for (int i = 1; i < 19; i++)
            if (low_buffer[i] <= low_buffer[i - 1] && low_buffer[i] <= low_buffer[i + 1])
                return low_buffer[i];
    }
    return 0;
}


double ESD_GetRecentSwingHigh()
{
    double high_buffer[];
    ArraySetAsSeries(high_buffer, true);
    CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, high_buffer);
    return high_buffer[ArrayMaximum(high_buffer, 0, 50)];
}


double ESD_GetRecentSwingLow()
{
    double low_buffer[];
    ArraySetAsSeries(low_buffer, true);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, low_buffer);
    return low_buffer[ArrayMinimum(low_buffer, 0, 50)];
}


void ESD_UpdateSwingLevels()
{
    int bars = 20;
    double high_buffer[], low_buffer[];
    ArraySetAsSeries(high_buffer, true);
    ArraySetAsSeries(low_buffer, true);

    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high_buffer);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low_buffer);

    // Find recent swing high
    ESD_last_swing_high = high_buffer[0];
    for (int i = 1; i < bars - 1; i++)
    {
        if (high_buffer[i] > high_buffer[i - 1] && high_buffer[i] > high_buffer[i + 1])
        {
            if (high_buffer[i] > ESD_last_swing_high)
                ESD_last_swing_high = high_buffer[i];
        }
    }

    // Find recent swing low
    ESD_last_swing_low = low_buffer[0];
    for (int i = 1; i < bars - 1; i++)
    {
        if (low_buffer[i] < low_buffer[i - 1] && low_buffer[i] < low_buffer[i + 1])
        {
            if (low_buffer[i] < ESD_last_swing_low)
                ESD_last_swing_low = low_buffer[i];
        }
    }

    // Jika tidak ditemukan swing, gunakan high/low terakhir
    if (ESD_last_swing_high == high_buffer[0])
        ESD_last_swing_high = high_buffer[ArrayMaximum(high_buffer, 0, bars)];
    if (ESD_last_swing_low == low_buffer[0])
        ESD_last_swing_low = low_buffer[ArrayMinimum(low_buffer, 0, bars)];
}


