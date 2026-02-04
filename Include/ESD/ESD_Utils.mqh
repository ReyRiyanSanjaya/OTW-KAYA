//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_Utils.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Utility Functions
//|
//| DESCRIPTION:
//|   Centralized utility functions untuk seluruh framework.
//|   Berisi helper functions yang sering dipakai di berbagai module.
//|
//| CATEGORIES:
//|   - Price Utilities     : Get prices, spread, normalize
//|   - Array Utilities     : Push, average, min, max
//|   - Time Utilities      : New bar detection, time helpers
//|   - Math Utilities      : Normalize, clamp, map range
//|   - Debug Utilities     : Logging, error handling
//|
//| VERSION: 1.0 | CREATED: 2025-12-18
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//|                    PRICE UTILITIES                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get current Ask price                                            |
//+------------------------------------------------------------------+
double ESD_GetAsk()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Get current Bid price                                            |
//+------------------------------------------------------------------+
double ESD_GetBid()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//| Get current spread in points                                     |
//+------------------------------------------------------------------+
double ESD_GetSpreadPoints()
{
    return (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//| Get point value for current symbol                               |
//+------------------------------------------------------------------+
double ESD_GetPoint()
{
    return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Convert points to price value                                    |
//+------------------------------------------------------------------+
double ESD_PointsToPrice(int points)
{
    return points * ESD_GetPoint();
}

//+------------------------------------------------------------------+
//| Convert price value to points                                    |
//+------------------------------------------------------------------+
int ESD_PriceToPoints(double price_diff)
{
    double point = ESD_GetPoint();
    if (point == 0) return 0;
    return (int)MathRound(price_diff / point);
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                 |
//+------------------------------------------------------------------+
double ESD_NormalizePrice(double price)
{
    return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//|                    ARRAY UTILITIES                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Push value to end of double array                                |
//+------------------------------------------------------------------+
void ESD_ArrayPush(double &arr[], double value)
{
    int size = ArraySize(arr);
    ArrayResize(arr, size + 1);
    arr[size] = value;
}

//+------------------------------------------------------------------+
//| Calculate average of double array                                |
//+------------------------------------------------------------------+
double ESD_ArrayAverage(const double &arr[])
{
    int size = ArraySize(arr);
    if (size == 0) return 0;
    
    double sum = 0;
    for (int i = 0; i < size; i++)
        sum += arr[i];
    
    return sum / size;
}

//+------------------------------------------------------------------+
//| Get maximum value from double array                              |
//+------------------------------------------------------------------+
double ESD_ArrayMaxValue(const double &arr[])
{
    int size = ArraySize(arr);
    if (size == 0) return 0;
    
    double max_val = arr[0];
    for (int i = 1; i < size; i++)
        if (arr[i] > max_val) max_val = arr[i];
    
    return max_val;
}

//+------------------------------------------------------------------+
//| Get minimum value from double array                              |
//+------------------------------------------------------------------+
double ESD_ArrayMinValue(const double &arr[])
{
    int size = ArraySize(arr);
    if (size == 0) return 0;
    
    double min_val = arr[0];
    for (int i = 1; i < size; i++)
        if (arr[i] < min_val) min_val = arr[i];
    
    return min_val;
}

//+------------------------------------------------------------------+
//|                    TIME UTILITIES                                 |
//+------------------------------------------------------------------+

// Static variable for new bar detection
datetime ESD_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                    |
//+------------------------------------------------------------------+
bool ESD_IsNewBar(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
    datetime current_bar_time = iTime(_Symbol, tf, 0);
    
    if (current_bar_time != ESD_last_bar_time)
    {
        ESD_last_bar_time = current_bar_time;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get current server hour                                          |
//+------------------------------------------------------------------+
int ESD_GetCurrentHour()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return dt.hour;
}

//+------------------------------------------------------------------+
//| Get current day of week (0=Sunday, 6=Saturday)                   |
//+------------------------------------------------------------------+
int ESD_GetDayOfWeek()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return dt.day_of_week;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool ESD_IsWithinTradingHours(int start_hour, int end_hour)
{
    int current_hour = ESD_GetCurrentHour();
    
    if (start_hour < end_hour)
        return (current_hour >= start_hour && current_hour < end_hour);
    else  // Overnight session
        return (current_hour >= start_hour || current_hour < end_hour);
}

//+------------------------------------------------------------------+
//| Format datetime to string                                        |
//+------------------------------------------------------------------+
string ESD_FormatTime(datetime time)
{
    return TimeToString(time, TIME_DATE | TIME_MINUTES);
}

//+------------------------------------------------------------------+
//|                    MATH UTILITIES                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Clamp value between min and max                                  |
//+------------------------------------------------------------------+
double ESD_Clamp(double value, double min_val, double max_val)
{
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

//+------------------------------------------------------------------+
//| Map value from one range to another                              |
//+------------------------------------------------------------------+
double ESD_MapRange(double value, double in_min, double in_max, double out_min, double out_max)
{
    if (in_max - in_min == 0) return out_min;
    return out_min + ((value - in_min) * (out_max - out_min)) / (in_max - in_min);
}

//+------------------------------------------------------------------+
//| Linear interpolation                                             |
//+------------------------------------------------------------------+
double ESD_Lerp(double a, double b, double t)
{
    return a + (b - a) * ESD_Clamp(t, 0.0, 1.0);
}

//+------------------------------------------------------------------+
//| Calculate percentage change                                      |
//+------------------------------------------------------------------+
double ESD_PercentChange(double old_val, double new_val)
{
    if (old_val == 0) return 0;
    return ((new_val - old_val) / old_val) * 100;
}

//+------------------------------------------------------------------+
//|                    DEBUG UTILITIES                                |
//+------------------------------------------------------------------+

// Log levels
#define ESD_LOG_INFO    0
#define ESD_LOG_WARNING 1
#define ESD_LOG_ERROR   2
#define ESD_LOG_DEBUG   3

//+------------------------------------------------------------------+
//| Log message with level                                           |
//+------------------------------------------------------------------+
void ESD_Log(string message, int level = ESD_LOG_INFO)
{
    string prefix = "";
    
    switch (level)
    {
        case ESD_LOG_INFO:    prefix = "ℹ️ INFO: ";    break;
        case ESD_LOG_WARNING: prefix = "⚠️ WARNING: "; break;
        case ESD_LOG_ERROR:   prefix = "❌ ERROR: ";   break;
        case ESD_LOG_DEBUG:   prefix = "🔍 DEBUG: ";   break;
    }
    
    Print(prefix, message);
}

//+------------------------------------------------------------------+
//| Debug log with function name                                     |
//+------------------------------------------------------------------+
void ESD_Debug(string func_name, string message)
{
    Print("🔍 [", func_name, "] ", message);
}

//+------------------------------------------------------------------+
//| Error log with function name                                     |
//+------------------------------------------------------------------+
void ESD_Error(string func_name, string error)
{
    Print("❌ ERROR in [", func_name, "]: ", error);
}

//+------------------------------------------------------------------+
//| Format number with thousands separator                           |
//+------------------------------------------------------------------+
string ESD_FormatNumber(double value, int digits = 2)
{
    return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Get system status string                                         |
//+------------------------------------------------------------------+
string ESD_GetSystemInfo()
{
    return StringFormat(
        "Account: %d | Balance: $%.2f | Equity: $%.2f | Spread: %.0f pts",
        AccountInfoInteger(ACCOUNT_LOGIN),
        AccountInfoDouble(ACCOUNT_BALANCE),
        AccountInfoDouble(ACCOUNT_EQUITY),
        ESD_GetSpreadPoints()
    );
}

//+------------------------------------------------------------------+
//|                    INDICATOR HELPERS                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double ESD_GetATR(int period = 14, int shift = 0)
{
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, period);
    if (CopyBuffer(atr_handle, 0, shift, 1, atr_buffer) > 0)
        return atr_buffer[0];
    
    return 0;
}

//+------------------------------------------------------------------+
//| Get RSI value                                                    |
//+------------------------------------------------------------------+
double ESD_GetRSI(int period = 14, int shift = 0)
{
    double rsi_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, period, PRICE_CLOSE);
    if (CopyBuffer(rsi_handle, 0, shift, 1, rsi_buffer) > 0)
        return rsi_buffer[0];
    
    return 50; // Neutral default
}

//+------------------------------------------------------------------+
//| Get EMA value                                                    |
//+------------------------------------------------------------------+
double ESD_GetEMA(int period, int shift = 0)
{
    double ema_buffer[];
    ArraySetAsSeries(ema_buffer, true);
    
    int ema_handle = iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_EMA, PRICE_CLOSE);
    if (CopyBuffer(ema_handle, 0, shift, 1, ema_buffer) > 0)
        return ema_buffer[0];
    
    return 0;
}

//+------------------------------------------------------------------+
//|                    MARKET SESSION UTILITIES                       |
//+------------------------------------------------------------------+

// Session definitions (Server Time GMT+2/GMT+3)
#define SESSION_SYDNEY_START    22  // 22:00
#define SESSION_SYDNEY_END      7   // 07:00
#define SESSION_TOKYO_START     0   // 00:00
#define SESSION_TOKYO_END       9   // 09:00
#define SESSION_LONDON_START    8   // 08:00
#define SESSION_LONDON_END      17  // 17:00
#define SESSION_NEWYORK_START   13  // 13:00
#define SESSION_NEWYORK_END     22  // 22:00

//+------------------------------------------------------------------+
//| Check if we are in Sydney Session                                |
//+------------------------------------------------------------------+
bool ESD_IsSydneySession()
{
    return ESD_IsWithinTradingHours(SESSION_SYDNEY_START, SESSION_SYDNEY_END);
}

//+------------------------------------------------------------------+
//| Check if we are in Tokyo Session                                 |
//+------------------------------------------------------------------+
bool ESD_IsTokyoSession()
{
    return ESD_IsWithinTradingHours(SESSION_TOKYO_START, SESSION_TOKYO_END);
}

//+------------------------------------------------------------------+
//| Check if we are in London Session                                |
//+------------------------------------------------------------------+
bool ESD_IsLondonSession()
{
    return ESD_IsWithinTradingHours(SESSION_LONDON_START, SESSION_LONDON_END);
}

//+------------------------------------------------------------------+
//| Check if we are in New York Session                              |
//+------------------------------------------------------------------+
bool ESD_IsNewYorkSession()
{
    return ESD_IsWithinTradingHours(SESSION_NEWYORK_START, SESSION_NEWYORK_END);
}

//+------------------------------------------------------------------+
//| Get current session name                                         |
//+------------------------------------------------------------------+
string ESD_GetCurrentSession()
{
    if (ESD_IsLondonSession() && ESD_IsNewYorkSession())
        return "London-NY Overlap";
    else if (ESD_IsNewYorkSession())
        return "New York";
    else if (ESD_IsLondonSession())
        return "London";
    else if (ESD_IsTokyoSession())
        return "Tokyo";
    else if (ESD_IsSydneySession())
        return "Sydney";
    else
        return "Off-Hours";
}

//+------------------------------------------------------------------+
//| Check if we are in major session (London or NY)                  |
//+------------------------------------------------------------------+
bool ESD_IsInMajorSession()
{
    return ESD_IsLondonSession() || ESD_IsNewYorkSession();
}

//+------------------------------------------------------------------+
//| Check if we are in London-NY overlap (highest volatility)        |
//+------------------------------------------------------------------+
bool ESD_IsInOverlap()
{
    return ESD_IsLondonSession() && ESD_IsNewYorkSession();
}

//+------------------------------------------------------------------+
//|                    POSITION MANAGEMENT UTILITIES                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Count active positions for current symbol                        |
//+------------------------------------------------------------------+
int ESD_CountPositions(ulong magic = 0)
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                if (magic == 0 || PositionGetInteger(POSITION_MAGIC) == magic)
                    count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Count Buy positions                                              |
//+------------------------------------------------------------------+
int ESD_CountBuyPositions(ulong magic = 0)
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                if (magic == 0 || PositionGetInteger(POSITION_MAGIC) == magic)
                    count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Count Sell positions                                             |
//+------------------------------------------------------------------+
int ESD_CountSellPositions(ulong magic = 0)
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                if (magic == 0 || PositionGetInteger(POSITION_MAGIC) == magic)
                    count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get total floating profit for symbol                             |
//+------------------------------------------------------------------+
double ESD_GetTotalProfit(ulong magic = 0)
{
    double total = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                if (magic == 0 || PositionGetInteger(POSITION_MAGIC) == magic)
                    total += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    return total;
}

//+------------------------------------------------------------------+
//|                    BREAKEVEN UTILITIES                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Move position to breakeven                                       |
//| Params:                                                          |
//|   ticket - Position ticket                                       |
//|   buffer_points - Points above/below entry for safety            |
//+------------------------------------------------------------------+
bool ESD_MoveToBreakeven(ulong ticket, int buffer_points = 10)
{
    if (!PositionSelectByTicket(ticket))
        return false;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    double point = ESD_GetPoint();
    long pos_type = PositionGetInteger(POSITION_TYPE);
    
    double new_sl = 0;
    
    if (pos_type == POSITION_TYPE_BUY)
    {
        new_sl = entry + buffer_points * point;
        // Only move if new SL is above current SL
        if (new_sl <= current_sl && current_sl > 0)
            return false;
    }
    else if (pos_type == POSITION_TYPE_SELL)
    {
        new_sl = entry - buffer_points * point;
        // Only move if new SL is below current SL
        if (new_sl >= current_sl && current_sl > 0)
            return false;
    }
    
    new_sl = ESD_NormalizePrice(new_sl);
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = new_sl;
    request.tp = tp;
    
    if (OrderSend(request, result))
    {
        if (result.retcode == TRADE_RETCODE_DONE)
        {
            ESD_Log(StringFormat("Moved to breakeven: Ticket %d, SL: %.5f", ticket, new_sl), ESD_LOG_INFO);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Auto-manage breakeven for all positions                          |
//| Move SL to breakeven when profit reaches activation_points       |
//+------------------------------------------------------------------+
void ESD_AutoBreakeven(int activation_points, int buffer_points = 10, ulong magic = 0)
{
    double point = ESD_GetPoint();
    
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        
        if (PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
        
        if (magic > 0 && PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
        
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        long pos_type = PositionGetInteger(POSITION_TYPE);
        double current_price = 0;
        double profit_points = 0;
        
        if (pos_type == POSITION_TYPE_BUY)
        {
            current_price = ESD_GetBid();
            profit_points = (current_price - entry) / point;
            
            // Check if already at breakeven
            if (current_sl >= entry)
                continue;
        }
        else if (pos_type == POSITION_TYPE_SELL)
        {
            current_price = ESD_GetAsk();
            profit_points = (entry - current_price) / point;
            
            // Check if already at breakeven
            if (current_sl <= entry && current_sl > 0)
                continue;
        }
        
        // Move to breakeven if activation threshold reached
        if (profit_points >= activation_points)
        {
            ESD_MoveToBreakeven(ticket, buffer_points);
        }
    }
}

//+------------------------------------------------------------------+
//|                    RISK CALCULATION UTILITIES                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double ESD_CalculateLotSize(double risk_percent, int sl_points)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (risk_percent / 100.0);
    
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = ESD_GetPoint();
    
    if (tick_size == 0 || tick_value == 0)
        return 0.01;
    
    double point_value = tick_value * (point / tick_size);
    double sl_value = sl_points * point_value;
    
    if (sl_value == 0)
        return 0.01;
    
    double lot = risk_amount / sl_value;
    
    // Normalize to broker limits
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(lot, min_lot);
    lot = MathMin(lot, max_lot);
    lot = MathFloor(lot / lot_step) * lot_step;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Get daily profit/loss in currency                                |
//+------------------------------------------------------------------+
double ESD_GetDailyProfitLoss()
{
    double daily_pnl = 0;
    datetime today_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    // Check history
    HistorySelect(today_start, TimeCurrent());
    
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            daily_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            daily_pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
            daily_pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }
    
    // Add floating profit
    daily_pnl += ESD_GetTotalProfit();
    
    return daily_pnl;
}

//+------------------------------------------------------------------+
//| Check if daily loss limit is reached                             |
//+------------------------------------------------------------------+
bool ESD_IsDailyLossLimitReached(double max_loss_percent)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double max_loss = balance * (max_loss_percent / 100.0);
    double daily_pnl = ESD_GetDailyProfitLoss();
    
    return (daily_pnl < -max_loss);
}

// --- END OF FILE ---

