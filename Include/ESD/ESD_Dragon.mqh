//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                          ESD_Dragon.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Dragon Momentum Strategy
//|
//| DESCRIPTION:
//|   Momentum-based scalping strategy using EMA deviation
//|   and strong candle detection for M1 timeframe entries.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - OnInitDragon()             : Initialize EMA handle
//|   - DragonMomentum()           : Main momentum detection
//|   - UpdateMaxLossSL_AndReversal() : SL management + reversal
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

int emaHandle = INVALID_HANDLE;
datetime lastCandleTime = 0;
int OnInitDragon()
{
   emaHandle = iMA(_Symbol, PERIOD_M1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE)
   {
      Print("Error creating EMA indicator");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}


void DragonMomentum()
{
   MqlRates currentCandle[];
   ArraySetAsSeries(currentCandle, true);
   CopyRates(_Symbol, PERIOD_M1, 1, 1, currentCandle);
    
   if(currentCandle[0].time == lastCandleTime) return;
   
   // --- TIME FILTER CHECK (Dragon Enhanced) ---
   if (Dragon_UseTimeFilter)
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      int currentHour = dt.hour;
      
      bool isAllowedTime = false;
      if (Dragon_StartHour < Dragon_EndHour)
      {
         // Standard window (e.g., 08 to 17)
         if (currentHour >= Dragon_StartHour && currentHour < Dragon_EndHour)
            isAllowedTime = true;
      }
      else
      {
         // Overnight window (e.g., 22 to 10)
         if (currentHour >= Dragon_StartHour || currentHour < Dragon_EndHour)
            isAllowedTime = true;
      }
      
      if (!isAllowedTime) return; // Skip if outside allowed hours
   }
   
   double candleRange = currentCandle[0].high - currentCandle[0].low;
   double bodySize = MathAbs(currentCandle[0].close - currentCandle[0].open);
   
   bool isStrongCandle = (candleRange > MinDragonPower) && 
                        (bodySize >= SoulEssence * candleRange);
   
   if(isStrongCandle && !PositionSelect(_Symbol))
   {
      // Dapatkan nilai EMA
      double emaValue[];
      ArraySetAsSeries(emaValue, true);
      CopyBuffer(emaHandle, 0, 0, 1, emaValue);
      
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double deviation = MathAbs(currentAsk - emaValue[0]) / _Point;
      
      // Hitung ATR jika enabled
      double atrValue = 0;
      if (Dragon_UseATR)
      {
         int atrHandle = iATR(_Symbol, PERIOD_M1, Dragon_ATR_Period);
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
         atrValue = atrBuffer[0];
      }
      
      // Tentukan arah candle
      bool isBullish = currentCandle[0].close > currentCandle[0].open;
      bool isBearish = currentCandle[0].close < currentCandle[0].open;
      
      // Inisialisasi variabel dengan nilai default
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
      double entryPrice = currentAsk;
      double sl = 0.0;
      double tp = 0.0;
      bool shouldEntry = false;
      
      if(isBullish)
      {
         // BUY: Hanya entry jika harga TIDAK JAUH DI ATAS EMA
         if(currentAsk <= emaValue[0] + (Max_Deviation_Pips * _Point))
         {
            orderType = ORDER_TYPE_BUY;
            entryPrice = currentAsk;
            
            // Calculate SL/TP
            if (Dragon_UseATR && atrValue > 0)
            {
               sl = entryPrice - (atrValue * Dragon_SL_ATR_Multiplier);
               tp = entryPrice + (atrValue * Dragon_TP_ATR_Multiplier);
            }
            else
            {
               sl = entryPrice - FireBreath * _Point;
               tp = entryPrice + SkyReach * _Point;
            }
            
            shouldEntry = true;
            Print("✅ BUY Signal - Harga dekat atau di bawah EMA10");
         }
         else
         {
            Print("❌ Skip BUY - Harga sudah terlalu jauh di atas EMA10. Deviation: ", deviation, " pips");
         }
      }
      else if(isBearish)
      {
         // SELL: Hanya entry jika harga TIDAK JAUH DI BAWAH EMA
         if(currentBid >= emaValue[0] - (Max_Deviation_Pips * _Point))
         {
            orderType = ORDER_TYPE_SELL;
            entryPrice = currentBid;
            
            // Calculate SL/TP
            if (Dragon_UseATR && atrValue > 0)
            {
               sl = entryPrice + (atrValue * Dragon_SL_ATR_Multiplier);
               tp = entryPrice - (atrValue * Dragon_TP_ATR_Multiplier);
            }
            else
            {
               sl = entryPrice + FireBreath * _Point;
               tp = entryPrice - SkyReach * _Point;
            }
            
            shouldEntry = true;
            Print("✅ SELL Signal - Harga dekat atau di atas EMA10");
         }
         else
         {
            Print("❌ Skip SELL - Harga sudah terlalu jauh di bawah EMA10. Deviation: ", deviation, " pips");
         }
      }
      
      // Eksekusi trade jika memenuhi kriteria
      if(shouldEntry)
      {
         // Retry Loop for robustness (up to 3 times)
         int max_retries = 3;
         bool executed = false;
         
         for(int i=0; i<max_retries; i++)
         {
            bool res = false;
            if(orderType == ORDER_TYPE_BUY)
               res = ESD_trade.Buy(DragonScale, _Symbol, entryPrice, sl, tp, "Dragon Momentum v2");
            else
               res = ESD_trade.Sell(DragonScale, _Symbol, entryPrice, sl, tp, "Dragon Momentum v2");
               
            if(res)
            {
               executed = true;
               lastCandleTime = currentCandle[0].time;
               Print("🐉 Entry Dragon v2 ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", 
                     " | ATR SL: ", Dragon_UseATR);
               break;
            }
            else
            {
               Print("⚠️ Dragon Entry Failed (Retry ", i+1, "/", max_retries, ") Error: ", GetLastError());
               Sleep(100); // Wait 100ms before retry
               
               // Update price for retry
               if(orderType == ORDER_TYPE_BUY) entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               else entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
         }
      }
      else
      {
         lastCandleTime = currentCandle[0].time; // Tetap update waktu meski skip entry
      }
   }
}


// --- FUNCTION REMOVED (MOVED TO ESD_RISK.MQH) ---

