//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                         ESD_Strategies.mqh                        |
//+------------------------------------------------------------------+
//| MODULE: Advanced Entry Strategies
//|
//| DESCRIPTION:
//|   Contains additional entry strategies that are modular and
//|   maintainable. Separated from ESD_Entry.mqh for better
//|   organization and easier extension.
//|
//| STRATEGIES:
//|   1. RSI Divergence Strategy
//|   2. Supply/Demand Zone Strategy
//|   3. Session Momentum Strategy
//|   4. Multi-Timeframe Confluence
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh
//|   - ESD_Inputs.mqh
//|   - ESD_Utils.mqh
//|
//| VERSION: 1.0 | CREATED: 2025-12-18
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//|                    GLOBAL VARIABLES                               |
//+------------------------------------------------------------------+
// RSI Divergence tracking
int      g_rsi_handle = INVALID_HANDLE;
double   g_last_rsi_high = 0;
double   g_last_rsi_low = 100;
double   g_last_price_high = 0;
double   g_last_price_low = 0;
datetime g_last_divergence_time = 0;

// Supply/Demand zones
struct ESD_SDZone
{
    double upper;
    double lower;
    datetime created;
    bool is_supply;
    bool is_fresh;
    int touches;
};

ESD_SDZone g_supply_zones[];
ESD_SDZone g_demand_zones[];
int g_max_zones = 10;

//+------------------------------------------------------------------+
//|               INITIALIZATION                                      |
//+------------------------------------------------------------------+
void ESD_Strategies_Init()
{
    // Initialize RSI handle
    g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, ESD_RSIPeriod, PRICE_CLOSE);
    
    // Initialize zone arrays
    ArrayResize(g_supply_zones, 0);
    ArrayResize(g_demand_zones, 0);
    
    Print("✅ ESD_Strategies initialized");
}

void ESD_Strategies_Deinit()
{
    if (g_rsi_handle != INVALID_HANDLE)
        IndicatorRelease(g_rsi_handle);
}

//+------------------------------------------------------------------+
//|           RSI DIVERGENCE STRATEGY                                 |
//+------------------------------------------------------------------+
//| Detects bullish/bearish divergence between price and RSI         |
//|                                                                   |
//| Bullish Divergence: Price makes lower low, RSI makes higher low  |
//| Bearish Divergence: Price makes higher high, RSI makes lower high|
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get current RSI value                                            |
//+------------------------------------------------------------------+
double ESD_Strategy_GetRSI(int shift = 0)
{
    if (g_rsi_handle == INVALID_HANDLE)
        return 50.0;
    
    double rsi_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    
    if (CopyBuffer(g_rsi_handle, 0, shift, 1, rsi_buffer) > 0)
        return rsi_buffer[0];
    
    return 50.0;
}

//+------------------------------------------------------------------+
//| Detect RSI Divergence                                            |
//| Returns: 1 = Bullish, -1 = Bearish, 0 = None                    |
//+------------------------------------------------------------------+
int ESD_DetectRSIDivergence(int lookback = 20)
{
    if (!ESD_EnableRSIDivergence)
        return 0;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, lookback, rates) < lookback)
        return 0;
    
    // Find price swing highs and lows
    double price_high1 = 0, price_high2 = 0;
    double price_low1 = 0, price_low2 = 0;
    int high_idx1 = -1, high_idx2 = -1;
    int low_idx1 = -1, low_idx2 = -1;
    
    // Find the two most recent swing highs
    for (int i = 2; i < lookback - 2; i++)
    {
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
        {
            if (high_idx1 == -1)
            {
                high_idx1 = i;
                price_high1 = rates[i].high;
            }
            else if (high_idx2 == -1)
            {
                high_idx2 = i;
                price_high2 = rates[i].high;
                break;
            }
        }
    }
    
    // Find the two most recent swing lows
    for (int i = 2; i < lookback - 2; i++)
    {
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
        {
            if (low_idx1 == -1)
            {
                low_idx1 = i;
                price_low1 = rates[i].low;
            }
            else if (low_idx2 == -1)
            {
                low_idx2 = i;
                price_low2 = rates[i].low;
                break;
            }
        }
    }
    
    // Check for Bullish Divergence (price lower low, RSI higher low)
    if (low_idx1 > 0 && low_idx2 > 0)
    {
        double rsi_at_low1 = ESD_Strategy_GetRSI(low_idx1);
        double rsi_at_low2 = ESD_Strategy_GetRSI(low_idx2);
        
        if (price_low1 < price_low2 && rsi_at_low1 > rsi_at_low2)
        {
            // Bullish divergence confirmed
            if (rsi_at_low1 < ESD_RSIOversold + 10)
            {
                return 1;  // Bullish
            }
        }
    }
    
    // Check for Bearish Divergence (price higher high, RSI lower high)
    if (high_idx1 > 0 && high_idx2 > 0)
    {
        double rsi_at_high1 = ESD_Strategy_GetRSI(high_idx1);
        double rsi_at_high2 = ESD_Strategy_GetRSI(high_idx2);
        
        if (price_high1 > price_high2 && rsi_at_high1 < rsi_at_high2)
        {
            // Bearish divergence confirmed
            if (rsi_at_high1 > ESD_RSIOverbought - 10)
            {
                return -1;  // Bearish
            }
        }
    }
    
    return 0;  // No divergence
}

//+------------------------------------------------------------------+
//| Execute RSI Divergence Trade                                     |
//+------------------------------------------------------------------+
void ESD_TryRSIDivergenceEntry()
{
    if (!ESD_EnableRSIDivergence)
        return;
    
    // Limit positions
    if (ESD_CountPositions(ESD_MagicNumber) >= 5)
        return;
    
    // Check for divergence
    int divergence = ESD_DetectRSIDivergence();
    
    if (divergence == 0)
        return;
    
    // Cooldown check
    if (TimeCurrent() - g_last_divergence_time < 3600)
        return;
    
    double ask = ESD_GetAsk();
    double bid = ESD_GetBid();
    double point = ESD_GetPoint();
    double atr = ESD_GetATR();
    
    double sl = 0, tp = 0;
    double lot = 0.1;
    string comment = "";
    
    if (divergence == 1)  // Bullish
    {
        sl = bid - atr * 1.5;
        tp = ask + atr * 3.0;
        comment = "RSI_Divergence_BUY";
        
        if (ESD_trade.Buy(lot, _Symbol, ask, sl, tp, comment))
        {
            g_last_divergence_time = TimeCurrent();
            Print("✅ RSI Bullish Divergence Entry @ ", ask);
        }
    }
    else if (divergence == -1)  // Bearish
    {
        sl = ask + atr * 1.5;
        tp = bid - atr * 3.0;
        comment = "RSI_Divergence_SELL";
        
        if (ESD_trade.Sell(lot, _Symbol, bid, sl, tp, comment))
        {
            g_last_divergence_time = TimeCurrent();
            Print("✅ RSI Bearish Divergence Entry @ ", bid);
        }
    }
}

//+------------------------------------------------------------------+
//|           SUPPLY/DEMAND ZONE STRATEGY                             |
//+------------------------------------------------------------------+
//| Detects fresh supply and demand zones based on strong moves      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Supply/Demand Zones                                       |
//+------------------------------------------------------------------+
void ESD_DetectSupplyDemandZones()
{
    if (!ESD_EnableSupplyDemand)
        return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, ESD_SDZoneLookback, rates) < ESD_SDZoneLookback)
        return;
    
    double atr = ESD_GetATR();
    double strong_move_threshold = atr * 2.0;
    
    // Look for demand zones (strong bullish move from consolidation)
    for (int i = 3; i < ESD_SDZoneLookback - 3; i++)
    {
        // Check for explosive bullish move
        double move = rates[i-1].close - rates[i].open;
        double candle_body = MathAbs(rates[i-1].close - rates[i-1].open);
        
        if (move > strong_move_threshold && candle_body > atr)
        {
            // Found demand zone - the consolidation before the move
            ESD_SDZone zone;
            zone.lower = rates[i].low;
            zone.upper = rates[i].open;
            zone.created = rates[i].time;
            zone.is_supply = false;
            zone.is_fresh = true;
            zone.touches = 0;
            
            // Add if not already exists
            if (ArraySize(g_demand_zones) < g_max_zones)
            {
                int size = ArraySize(g_demand_zones);
                ArrayResize(g_demand_zones, size + 1);
                g_demand_zones[size] = zone;
            }
        }
        
        // Check for explosive bearish move
        move = rates[i].open - rates[i-1].close;
        candle_body = MathAbs(rates[i-1].close - rates[i-1].open);
        
        if (move > strong_move_threshold && candle_body > atr)
        {
            // Found supply zone
            ESD_SDZone zone;
            zone.upper = rates[i].high;
            zone.lower = rates[i].open;
            zone.created = rates[i].time;
            zone.is_supply = true;
            zone.is_fresh = true;
            zone.touches = 0;
            
            if (ArraySize(g_supply_zones) < g_max_zones)
            {
                int size = ArraySize(g_supply_zones);
                ArrayResize(g_supply_zones, size + 1);
                g_supply_zones[size] = zone;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if price is in demand zone                                 |
//+------------------------------------------------------------------+
bool ESD_IsInDemandZone(double price)
{
    for (int i = 0; i < ArraySize(g_demand_zones); i++)
    {
        if (g_demand_zones[i].is_fresh &&
            price >= g_demand_zones[i].lower &&
            price <= g_demand_zones[i].upper)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if price is in supply zone                                 |
//+------------------------------------------------------------------+
bool ESD_IsInSupplyZone(double price)
{
    for (int i = 0; i < ArraySize(g_supply_zones); i++)
    {
        if (g_supply_zones[i].is_fresh &&
            price >= g_supply_zones[i].lower &&
            price <= g_supply_zones[i].upper)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Execute Supply/Demand Trade                                      |
//+------------------------------------------------------------------+
void ESD_TrySupplyDemandEntry()
{
    if (!ESD_EnableSupplyDemand)
        return;
    
    if (ESD_CountPositions(ESD_MagicNumber) >= 5)
        return;
    
    double current_price = ESD_GetBid();
    double ask = ESD_GetAsk();
    double bid = ESD_GetBid();
    double point = ESD_GetPoint();
    double atr = ESD_GetATR();
    
    // Check demand zone for buy
    if (ESD_IsInDemandZone(current_price))
    {
        // Additional confirmation - bullish candle
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates);
        
        if (rates[0].close > rates[0].open)  // Bullish candle
        {
            double sl = current_price - atr * 1.5;
            double tp = current_price + atr * 3.0;
            
            if (ESD_trade.Buy(0.1, _Symbol, ask, sl, tp, "SD_Demand_BUY"))
            {
                // Mark zone as used
                for (int i = 0; i < ArraySize(g_demand_zones); i++)
                {
                    if (current_price >= g_demand_zones[i].lower &&
                        current_price <= g_demand_zones[i].upper)
                    {
                        g_demand_zones[i].touches++;
                        if (g_demand_zones[i].touches >= 2)
                            g_demand_zones[i].is_fresh = false;
                    }
                }
                Print("✅ Supply/Demand BUY Entry @ ", ask);
            }
        }
    }
    
    // Check supply zone for sell
    if (ESD_IsInSupplyZone(current_price))
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates);
        
        if (rates[0].close < rates[0].open)  // Bearish candle
        {
            double sl = current_price + atr * 1.5;
            double tp = current_price - atr * 3.0;
            
            if (ESD_trade.Sell(0.1, _Symbol, bid, sl, tp, "SD_Supply_SELL"))
            {
                for (int i = 0; i < ArraySize(g_supply_zones); i++)
                {
                    if (current_price >= g_supply_zones[i].lower &&
                        current_price <= g_supply_zones[i].upper)
                    {
                        g_supply_zones[i].touches++;
                        if (g_supply_zones[i].touches >= 2)
                            g_supply_zones[i].is_fresh = false;
                    }
                }
                Print("✅ Supply/Demand SELL Entry @ ", bid);
            }
        }
    }
}

//+------------------------------------------------------------------+
//|           SESSION MOMENTUM STRATEGY                               |
//+------------------------------------------------------------------+
//| Trades momentum during session opens (London, NY)                |
//+------------------------------------------------------------------+

datetime g_last_session_trade_time = 0;

void ESD_TrySessionMomentumEntry()
{
    if (!ESD_EnableSessionMomentum)
        return;
    
    if (ESD_CountPositions(ESD_MagicNumber) >= 5)
        return;
    
    // Only trade first 2 hours of London or NY session
    int hour = ESD_GetCurrentHour();
    bool is_london_open = (hour >= 8 && hour <= 10);
    bool is_ny_open = (hour >= 13 && hour <= 15);
    
    if (!is_london_open && !is_ny_open)
        return;
    
    // Cooldown - 1 trade per session open
    if (TimeCurrent() - g_last_session_trade_time < 7200)
        return;
    
    // Check momentum - compare current candle to ATR
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, PERIOD_M15, 0, 5, rates);
    
    double atr = ESD_GetATR();
    double candle_size = MathAbs(rates[0].close - rates[0].open);
    
    // Momentum candle = larger than 0.8 * ATR
    if (candle_size < atr * 0.8)
        return;
    
    bool is_bullish = rates[0].close > rates[0].open;
    double ask = ESD_GetAsk();
    double bid = ESD_GetBid();
    
    double sl = 0, tp = 0;
    
    if (is_bullish)
    {
        sl = rates[0].low - atr * 0.5;
        tp = ask + atr * 2.5;
        
        if (ESD_trade.Buy(0.1, _Symbol, ask, sl, tp, "Session_Momentum_BUY"))
        {
            g_last_session_trade_time = TimeCurrent();
            Print("✅ Session Momentum BUY @ ", ask, " (", is_london_open ? "London" : "NY", " Open)");
        }
    }
    else
    {
        sl = rates[0].high + atr * 0.5;
        tp = bid - atr * 2.5;
        
        if (ESD_trade.Sell(0.1, _Symbol, bid, sl, tp, "Session_Momentum_SELL"))
        {
            g_last_session_trade_time = TimeCurrent();
            Print("✅ Session Momentum SELL @ ", bid, " (", is_london_open ? "London" : "NY", " Open)");
        }
    }
}

//+------------------------------------------------------------------+
//|           MASTER STRATEGY FUNCTION                                |
//+------------------------------------------------------------------+
//| Call this from Controller to run all strategies                   |
//+------------------------------------------------------------------+
void ESD_RunAllStrategies()
{
    // Update Supply/Demand zones periodically
    static datetime last_zone_update = 0;
    if (TimeCurrent() - last_zone_update > PeriodSeconds(PERIOD_H1))
    {
        ESD_DetectSupplyDemandZones();
        last_zone_update = TimeCurrent();
    }
    
    // Run individual strategies
    ESD_TryRSIDivergenceEntry();
    ESD_TrySupplyDemandEntry();
    ESD_TrySessionMomentumEntry();
}

// --- END OF FILE ---
