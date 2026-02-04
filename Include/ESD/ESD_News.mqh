//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_News.mqh                            |
//+------------------------------------------------------------------+
//| MODULE: Economic News Filter with External API
//|
//| DESCRIPTION:
//|   Filters trading during high-impact economic news events.
//|   Uses external API (Forex Factory / Investing.com via WebRequest)
//|   to automatically fetch economic calendar data.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh (required)
//|   - ESD_Inputs.mqh (required)
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_InitializeNewsFilter()    : Initialize news system
//|   - ESD_UpdateNewsCalendar()      : Fetch news from API
//|   - ESD_IsHighImpactNewsTime()    : Check if news is imminent
//|   - ESD_NewsFilter()              : Filter trades during news
//|   - ESD_GetNextNewsEvent()        : Get next scheduled news
//|   - ESD_DrawNewsIndicator()       : Visual news indicator
//|
//| API SOURCES:
//|   - Primary: Forex Factory Calendar API
//|   - Backup: Manual high-impact events (NFP, FOMC, CPI)
//|
//| NOTES:
//|   - Requires WebRequest enabled in MT5 Terminal Settings
//|   - Add URLs to Tools > Options > Expert Advisors > Allow WebRequest
//|
//| VERSION: 1.0
//| LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

//+------------------------------------------------------------------+
//| News Event Structure                                              |
//+------------------------------------------------------------------+
struct ESD_NewsEvent
{
    datetime time;           // Event time (server time)
    string   currency;       // Currency affected (USD, EUR, etc.)
    string   title;          // Event title
    int      impact;         // Impact level: 1=Low, 2=Medium, 3=High
    string   forecast;       // Forecast value
    string   previous;       // Previous value
    bool     is_active;      // Is this event still relevant
};

//+------------------------------------------------------------------+
//| News Calendar Storage                                             |
//+------------------------------------------------------------------+
ESD_NewsEvent ESD_news_calendar[];
int           ESD_news_count = 0;
datetime      ESD_last_calendar_fetch = 0;
bool          ESD_calendar_initialized = false;
string        ESD_api_url = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";

//+------------------------------------------------------------------+
//| Manual High-Impact Events (Backup when API fails)                 |
//+------------------------------------------------------------------+
struct ESD_ManualNewsEvent
{
    int      day_of_week;    // 0=Sunday ... 5=Friday
    int      hour;           // Hour (GMT)
    int      minute;         // Minute
    string   title;          // Event name
    int      week_of_month;  // 1-4, 0=every week
};

//+------------------------------------------------------------------+
//| Initialize News Filter System                                     |
//+------------------------------------------------------------------+
void ESD_InitializeNewsFilter()
{
    if (!ESD_UseNewsFilter)
        return;
    
    Print("═══════════════════════════════════════════════════════");
    Print("       ESD NEWS FILTER SYSTEM INITIALIZING...           ");
    Print("═══════════════════════════════════════════════════════");
    
    // Initialize arrays
    ArrayResize(ESD_news_calendar, 0);
    ESD_news_count = 0;
    
    // Load manual fallback events
    ESD_LoadManualNewsEvents();
    
    // Attempt to fetch from API
    if (ESD_FetchNewsFromAPI())
    {
        Print("✅ News calendar loaded from API successfully");
        Print("   Total events: ", ESD_news_count);
    }
    else
    {
        Print("⚠️ API fetch failed - using manual calendar");
    }
    
    ESD_calendar_initialized = true;
    ESD_last_calendar_fetch = TimeCurrent();
    
    // Add to filter status
    ESD_AddNewsToFilterStatus();
    
    Print("═══════════════════════════════════════════════════════");
}


//+------------------------------------------------------------------+
//| Fetch News Calendar from External API                             |
//| Uses Forex Factory JSON API                                       |
//+------------------------------------------------------------------+
bool ESD_FetchNewsFromAPI()
{
    if (!ESD_UseNewsFilter)
        return false;
    
    string headers = "Content-Type: application/json\r\n";
    char   post_data[];
    char   result_data[];
    string result_headers;
    
    int timeout = 5000; // 5 seconds timeout
    
    // Send WebRequest to Forex Factory API
    int res = WebRequest(
        "GET",
        ESD_api_url,
        headers,
        timeout,
        post_data,
        result_data,
        result_headers
    );
    
    if (res == -1)
    {
        int error = GetLastError();
        Print("❌ WebRequest failed. Error: ", error);
        Print("   Make sure to add this URL to allowed list:");
        Print("   Tools > Options > Expert Advisors > Allow WebRequest for listed URL");
        Print("   URL: ", ESD_api_url);
        return false;
    }
    
    if (res != 200)
    {
        Print("❌ API returned error code: ", res);
        return false;
    }
    
    // Parse JSON response
    string json_string = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
    
    if (StringLen(json_string) < 10)
    {
        Print("❌ Empty or invalid response from API");
        return false;
    }
    
    // Parse the JSON calendar data
    return ESD_ParseNewsJSON(json_string);
}


//+------------------------------------------------------------------+
//| Parse JSON News Data                                              |
//| Format: [{"title":"...", "country":"USD", "date":"...", ...}]    |
//+------------------------------------------------------------------+
bool ESD_ParseNewsJSON(string json)
{
    // Clear existing calendar
    ArrayResize(ESD_news_calendar, 0);
    ESD_news_count = 0;
    
    // Simple JSON parser for Forex Factory format
    int pos = 0;
    int event_count = 0;
    
    while (pos < StringLen(json) && event_count < 100)
    {
        // Find event object start
        int obj_start = StringFind(json, "{", pos);
        if (obj_start < 0) break;
        
        int obj_end = StringFind(json, "}", obj_start);
        if (obj_end < 0) break;
        
        string event_json = StringSubstr(json, obj_start, obj_end - obj_start + 1);
        
        // Parse individual event
        ESD_NewsEvent event;
        
        // Extract title
        event.title = ESD_ExtractJSONValue(event_json, "title");
        
        // Extract country/currency
        event.currency = ESD_ExtractJSONValue(event_json, "country");
        
        // Extract date
        string date_str = ESD_ExtractJSONValue(event_json, "date");
        
        // Extract impact
        string impact_str = ESD_ExtractJSONValue(event_json, "impact");
        if (impact_str == "High")
            event.impact = 3;
        else if (impact_str == "Medium")
            event.impact = 2;
        else
            event.impact = 1;
        
        // Extract forecast/previous
        event.forecast = ESD_ExtractJSONValue(event_json, "forecast");
        event.previous = ESD_ExtractJSONValue(event_json, "previous");
        
        // Parse datetime
        event.time = ESD_ParseNewsDateTime(date_str);
        event.is_active = (event.time > TimeCurrent());
        
        // Only add relevant events (high/medium impact, USD/EUR)
        if (event.impact >= 2 && 
            (event.currency == "USD" || event.currency == "EUR" || 
             event.currency == "GBP" || event.currency == "JPY"))
        {
            ArrayResize(ESD_news_calendar, event_count + 1);
            ESD_news_calendar[event_count] = event;
            event_count++;
        }
        
        pos = obj_end + 1;
    }
    
    ESD_news_count = event_count;
    return (event_count > 0);
}


//+------------------------------------------------------------------+
//| Extract value from JSON string                                    |
//+------------------------------------------------------------------+
string ESD_ExtractJSONValue(string json, string key)
{
    string search = "\"" + key + "\":";
    int key_pos = StringFind(json, search);
    if (key_pos < 0) return "";
    
    int value_start = key_pos + StringLen(search);
    
    // Skip whitespace
    while (value_start < StringLen(json) && StringGetCharacter(json, value_start) == ' ')
        value_start++;
    
    // Check if string value (starts with ")
    if (StringGetCharacter(json, value_start) == '"')
    {
        value_start++;
        int value_end = StringFind(json, "\"", value_start);
        if (value_end < 0) return "";
        return StringSubstr(json, value_start, value_end - value_start);
    }
    else
    {
        // Numeric or null value
        int value_end = value_start;
        while (value_end < StringLen(json))
        {
            ushort c = StringGetCharacter(json, value_end);
            if (c == ',' || c == '}') break;
            value_end++;
        }
        return StringSubstr(json, value_start, value_end - value_start);
    }
}


//+------------------------------------------------------------------+
//| Parse News DateTime from various formats                          |
//+------------------------------------------------------------------+
datetime ESD_ParseNewsDateTime(string date_str)
{
    // Try parsing format: "2025-12-17T14:30:00-05:00"
    datetime result = 0;
    
    // Extract date parts
    if (StringLen(date_str) >= 10)
    {
        string date_part = StringSubstr(date_str, 0, 10);
        string time_part = "00:00:00";
        
        if (StringLen(date_str) >= 19)
        {
            time_part = StringSubstr(date_str, 11, 8);
        }
        
        result = StringToTime(date_part + " " + time_part);
        
        // Adjust for timezone if needed (convert to broker time)
        // Most forex calendars use EST/EDT
        // This is a simplified adjustment - you may need to fine-tune
        result += 5 * 3600; // Add 5 hours for EST to GMT
    }
    
    return result;
}


//+------------------------------------------------------------------+
//| Load Manual High-Impact News Events (Fallback)                    |
//+------------------------------------------------------------------+
void ESD_LoadManualNewsEvents()
{
    // Add well-known high-impact events as fallback
    ESD_AddManualEvent(5, 13, 30, "Non-Farm Payrolls (NFP)", 1);        // First Friday
    ESD_AddManualEvent(3, 19, 0,  "FOMC Interest Rate Decision", 0);    // Every FOMC meeting
    ESD_AddManualEvent(3, 13, 30, "CPI (Consumer Price Index)", 0);     // Monthly
    ESD_AddManualEvent(4, 13, 30, "Retail Sales", 0);                   // Monthly
    ESD_AddManualEvent(2, 15, 0,  "Fed Chair Powell Speech", 0);        // As scheduled
    ESD_AddManualEvent(5, 15, 0,  "Fed Chair Powell Speech", 0);        // As scheduled
    
    Print("   Loaded ", 6, " manual fallback events");
}


//+------------------------------------------------------------------+
//| Add Manual Event to Calendar                                      |
//+------------------------------------------------------------------+
void ESD_AddManualEvent(int day_of_week, int hour, int minute, string title, int week_of_month)
{
    // Calculate next occurrence of this event
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    // Find next occurrence of this day
    int days_ahead = day_of_week - dt.day_of_week;
    if (days_ahead < 0) days_ahead += 7;
    
    datetime event_time = now + days_ahead * 86400;
    MqlDateTime event_dt;
    TimeToStruct(event_time, event_dt);
    event_dt.hour = hour;
    event_dt.min = minute;
    event_dt.sec = 0;
    
    event_time = StructToTime(event_dt);
    
    // Add to calendar if in future
    if (event_time > now)
    {
        int idx = ArraySize(ESD_news_calendar);
        ArrayResize(ESD_news_calendar, idx + 1);
        
        ESD_news_calendar[idx].time = event_time;
        ESD_news_calendar[idx].currency = "USD";
        ESD_news_calendar[idx].title = title;
        ESD_news_calendar[idx].impact = 3; // High impact
        ESD_news_calendar[idx].forecast = "";
        ESD_news_calendar[idx].previous = "";
        ESD_news_calendar[idx].is_active = true;
        
        ESD_news_count++;
    }
}


//+------------------------------------------------------------------+
//| Update News Calendar (call periodically)                          |
//+------------------------------------------------------------------+
void ESD_UpdateNewsCalendar()
{
    if (!ESD_UseNewsFilter)
        return;
    
    datetime now = TimeCurrent();
    
    // Refresh calendar every 4 hours
    if (now - ESD_last_calendar_fetch > 4 * 3600)
    {
        Print("🔄 Refreshing news calendar...");
        if (ESD_FetchNewsFromAPI())
        {
            Print("✅ Calendar refreshed. Events: ", ESD_news_count);
        }
        ESD_last_calendar_fetch = now;
    }
    
    // Update global variables for next news
    ESD_UpdateNextNewsInfo();
    
    // Update filter status
    ESD_AddNewsToFilterStatus();
}


//+------------------------------------------------------------------+
//| Update Next News Event Information                                |
//+------------------------------------------------------------------+
void ESD_UpdateNextNewsInfo()
{
    datetime now = TimeCurrent();
    datetime closest_time = 0;
    string closest_event = "";
    
    for (int i = 0; i < ESD_news_count; i++)
    {
        if (ESD_news_calendar[i].time > now && ESD_news_calendar[i].impact >= 2)
        {
            if (closest_time == 0 || ESD_news_calendar[i].time < closest_time)
            {
                closest_time = ESD_news_calendar[i].time;
                closest_event = ESD_news_calendar[i].title;
            }
        }
    }
    
    ESD_next_high_impact_news = closest_time;
    ESD_next_news_event = closest_event;
}


//+------------------------------------------------------------------+
//| Check if High-Impact News is Imminent                             |
//| Returns true if should avoid trading                              |
//+------------------------------------------------------------------+
bool ESD_IsHighImpactNewsTime()
{
    if (!ESD_UseNewsFilter)
        return false;
    
    datetime now = TimeCurrent();
    
    for (int i = 0; i < ESD_news_count; i++)
    {
        if (ESD_news_calendar[i].impact < 2) continue; // Skip low impact
        if (!ESD_FilterHighImpact && ESD_news_calendar[i].impact < 3) continue;
        if (!ESD_FilterMediumImpact && ESD_news_calendar[i].impact == 2) continue;
        
        datetime event_time = ESD_news_calendar[i].time;
        datetime buffer_before = event_time - ESD_NewsBufferMinutesBefore * 60;
        datetime buffer_after = event_time + ESD_NewsBufferMinutesAfter * 60;
        
        if (now >= buffer_before && now <= buffer_after)
        {
            Print("⚠️ NEWS FILTER ACTIVE: ", ESD_news_calendar[i].title);
            Print("   Event time: ", TimeToString(event_time));
            ESD_news_filter_active = true;
            return true;
        }
    }
    
    ESD_news_filter_active = false;
    return false;
}


//+------------------------------------------------------------------+
//| News Filter - Main Entry Point                                    |
//| Returns true if trading is allowed, false to block                |
//+------------------------------------------------------------------+
bool ESD_NewsFilter()
{
    if (!ESD_UseNewsFilter)
        return true; // Filter disabled, allow trading
    
    // Check if we're in news window
    if (ESD_IsHighImpactNewsTime())
    {
        // Close positions before news if enabled
        if (ESD_ClosePositionsBeforeNews)
        {
            ESD_CloseAllPositionsForNews();
        }
        
        return false; // Block new trades
    }
    
    return true; // Allow trading
}


//+------------------------------------------------------------------+
//| Close All Positions Before High-Impact News                       |
//+------------------------------------------------------------------+
void ESD_CloseAllPositionsForNews()
{
    if (!ESD_ClosePositionsBeforeNews)
        return;
    
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetTicket(i) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            // Only close if in profit or close to breakeven
            if (profit >= -10) // Adjust threshold as needed
            {
                Print("📰 Closing position before news. Profit: ", profit);
                ESD_trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Get Next News Event String for Display                            |
//+------------------------------------------------------------------+
string ESD_GetNextNewsEvent()
{
    if (ESD_next_high_impact_news == 0 || ESD_next_news_event == "")
        return "No upcoming news";
    
    datetime now = TimeCurrent();
    int minutes_until = (int)((ESD_next_high_impact_news - now) / 60);
    
    if (minutes_until < 0)
        return "No upcoming news";
    else if (minutes_until < 60)
        return StringFormat("%s in %d min", ESD_next_news_event, minutes_until);
    else if (minutes_until < 1440)
        return StringFormat("%s in %d hr", ESD_next_news_event, minutes_until / 60);
    else
        return StringFormat("%s on %s", ESD_next_news_event, 
                           TimeToString(ESD_next_high_impact_news, TIME_DATE | TIME_MINUTES));
}


//+------------------------------------------------------------------+
//| Add News Filter to Monitoring Panel                               |
//+------------------------------------------------------------------+
void ESD_AddNewsToFilterStatus()
{
    int news_index = -1;
    
    // Find existing news filter entry
    for (int i = 0; i < ArraySize(ESD_filter_status); i++)
    {
        if (ESD_filter_status[i].name == "News Filter")
        {
            news_index = i;
            break;
        }
    }
    
    // Add if not found
    if (news_index == -1)
    {
        int new_size = ArraySize(ESD_filter_status) + 1;
        ArrayResize(ESD_filter_status, new_size);
        news_index = new_size - 1;
        ESD_filter_status[news_index].name = "News Filter";
    }
    
    // Update status
    ESD_filter_status[news_index].enabled = ESD_UseNewsFilter;
    ESD_filter_status[news_index].passed = !ESD_news_filter_active;
    ESD_filter_status[news_index].strength = ESD_news_filter_active ? 0.0 : 1.0;
    ESD_filter_status[news_index].details = ESD_GetNextNewsEvent();
    ESD_filter_status[news_index].last_update = TimeCurrent();
}


//+------------------------------------------------------------------+
//| Draw News Indicator on Chart                                      |
//+------------------------------------------------------------------+
void ESD_DrawNewsIndicator()
{
    if (!ESD_ShowObjects || !ESD_UseNewsFilter)
        return;
    
    string label_name = "ESD_News_Indicator";
    
    if (ObjectFind(0, label_name) < 0)
    {
        ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, 60);
        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, label_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
    }
    
    color indicator_color;
    string indicator_text;
    
    if (ESD_news_filter_active)
    {
        indicator_color = clrRed;
        indicator_text = "📰 NEWS ACTIVE - NO TRADING";
    }
    else if (ESD_next_high_impact_news > 0)
    {
        datetime now = TimeCurrent();
        int minutes_until = (int)((ESD_next_high_impact_news - now) / 60);
        
        if (minutes_until <= ESD_NewsBufferMinutesBefore + 10)
        {
            indicator_color = clrOrange;
            indicator_text = "⚠️ News in " + IntegerToString(minutes_until) + " min";
        }
        else
        {
            indicator_color = clrLime;
            indicator_text = "✅ Clear - " + ESD_GetNextNewsEvent();
        }
    }
    else
    {
        indicator_color = clrLime;
        indicator_text = "✅ No upcoming news";
    }
    
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, indicator_color);
    ObjectSetString(0, label_name, OBJPROP_TEXT, indicator_text);
}


//+------------------------------------------------------------------+
//| Print News Calendar (for debugging)                               |
//+------------------------------------------------------------------+
void ESD_PrintNewsCalendar()
{
    Print("════════════════ NEWS CALENDAR ════════════════");
    Print("Total events: ", ESD_news_count);
    
    for (int i = 0; i < ESD_news_count && i < 10; i++)
    {
        string impact_str = (ESD_news_calendar[i].impact == 3) ? "HIGH" :
                           (ESD_news_calendar[i].impact == 2) ? "MED" : "LOW";
        
        Print(StringFormat("[%s] %s %s - %s",
              impact_str,
              ESD_news_calendar[i].currency,
              TimeToString(ESD_news_calendar[i].time, TIME_DATE | TIME_MINUTES),
              ESD_news_calendar[i].title));
    }
    
    Print("══════════════════════════════════════════════");
}
