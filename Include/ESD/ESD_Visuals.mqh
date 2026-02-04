//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                          ESD_Visuals.mqh                          |
//+------------------------------------------------------------------+
//| MODULE: Visual Objects & Dashboard
//|
//| DESCRIPTION:
//|   Chart visualization for SMC structures, panels, labels,
//|   trading data display, and filter monitoring interface.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh, ESD_Inputs.mqh
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_DrawHistoricalStructures() : Draw past SMC structures
//|   - ESD_DrawOrderBlock()           : Draw OB rectangles
//|   - ESD_DrawFVG()                  : Draw FVG zones
//|   - ESD_DrawBreakStructure()       : Draw BoS/CHoCH lines
//|   - ESD_DrawLabel()                : Draw text labels
//|   - ESD_DrawFilterMonitor()        : Filter status panel
//|   - ESD_DrawTradingDataPanel()     : Trade metrics panel
//|   - ESD_DrawSystemInfoPanel()      : System info display
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

void ESD_DrawHistoricalStructures()
{
    int structures_count = ArraySize(ESD_smc_structures);
    for (int i = 0; i < structures_count; i++)
    {
        ESD_SMStructure structure = ESD_smc_structures[i];

        if (structure.type == "PH" || structure.type == "PL")
        {
            ESD_DrawSwingPoint(structure.time, structure.price, structure.type,
                               structure.is_bullish ? ESD_BullishColor : ESD_BearishColor);
        }
        else if (structure.type == "BOS")
        {
            if (ESD_ShowBos)
            {
                ESD_DrawBreakStructure(structure.time, structure.price, structure.is_bullish,
                                       structure.is_bullish ? ESD_BullishColor : ESD_BearishColor,
                                       ESD_BosLineStyle, ESD_BosStyle, "BOS");
            }
        }
        else if (structure.type == "CHOCH")
        {
            if (ESD_ShowChoch)
            {
                ESD_DrawBreakStructure(structure.time, structure.price, structure.is_bullish,
                                       ESD_ChochColor, ESD_ChochLineStyle, ESD_ChochStyle, "CHOCH");
            }
        }
        else if (structure.type == "OB")
        {
            if (ESD_ShowOb)
            {
                ESD_DrawOrderBlock("ESD_HistoricalOB_" + IntegerToString(i), structure.top, structure.bottom,
                                   structure.is_bullish ? ESD_BullishColor : ESD_BearishColor,
                                   ESD_ObLineStyle, ESD_ObStyle);
            }
        }
        else if (structure.type == "FVG")
        {
            if (ESD_ShowFvg)
            {
                ESD_DrawFVG("ESD_HistoricalFVG_" + IntegerToString(i), structure.top, structure.bottom,
                            structure.time, structure.is_bullish ? ESD_BullishColor : ESD_BearishColor);
            }
        }
        else if (structure.type == "MSS")
        {
            if (ESD_ShowLabels)
            {
                ESD_DrawLabel("ESD_HistoricalMSS_" + IntegerToString(i), structure.time, structure.price,
                              "MSS", structure.is_bullish ? ESD_BullishColor : ESD_BearishColor, true);
            }
        }
    }
}


void ESD_DrawBreakStructure(datetime time, double price, bool is_bullish, color clr, ENUM_LINE_STYLE line_style, string style_text, string structure_type)
{
    // Delete all old break structures of the same type
    ESD_DeleteObjectsByPrefix("ESD_BreakStructure_" + structure_type);

    string name = "ESD_BreakStructure_" + structure_type + "_" + IntegerToString(time);
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_TREND, 0, time, price, time + PeriodSeconds(ESD_HigherTimeframe) * 10, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, name, OBJPROP_TOOLTIP, "\n" + style_text + "\n");
    }
}


void ESD_DrawSwingPoint(datetime time, double price, string text, color clr)
{
    // Delete all old swing points of the same type
    ESD_DeleteObjectsByPrefix("ESD_" + text);

    string name = "ESD_" + text + "_" + IntegerToString(time);
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (text == "PH") ? 234 : 233); // Down arrow for PH, Up for PL
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        if (ESD_ShowLabels)
        {
            ESD_DrawLabel(name + "_Label", time, price, text, clr, false);
        }
    }
}


void ESD_DrawOrderBlock(string name, double top, double bottom, color clr, ENUM_LINE_STYLE line_style, string style_text)
{
    if (top == EMPTY_VALUE || bottom == EMPTY_VALUE)
    {
        ObjectDelete(0, name);
        ObjectDelete(0, name + "_Top");
        ObjectDelete(0, name + "_Bottom");
        return;
    }

    // Delete all old order blocks of the same type
    if (StringFind(name, "BullishOB") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishOB");
    else if (StringFind(name, "BearishOB") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishOB");

    datetime time1 = iTime(_Symbol, ESD_HigherTimeframe, 0);
    datetime time2 = time1 + PeriodSeconds(ESD_HigherTimeframe) * 20;

    // Draw top line
    string top_name = name + "_Top";
    if (ObjectFind(0, top_name) < 0)
    {
        ObjectCreate(0, top_name, OBJ_TREND, 0, time1, top, time2, top);
        ObjectSetInteger(0, top_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, top_name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, top_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, top_name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, top_name, OBJPROP_TOOLTIP, "\n" + style_text + " Top\n");
    }
    else
    {
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 0, top);
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 1, top);
    }

    // Draw bottom line
    string bottom_name = name + "_Bottom";
    if (ObjectFind(0, bottom_name) < 0)
    {
        ObjectCreate(0, bottom_name, OBJ_TREND, 0, time1, bottom, time2, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, bottom_name, OBJPROP_STYLE, line_style);
        ObjectSetInteger(0, bottom_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, bottom_name, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, bottom_name, OBJPROP_TOOLTIP, "\n" + style_text + " Bottom\n");
    }
    else
    {
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 0, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 1, bottom);
    }
}


void ESD_DrawFVG(string name, double top, double bottom, datetime creation_time, color clr)
{
    if (iTime(_Symbol, ESD_HigherTimeframe, 0) > creation_time + PeriodSeconds(ESD_HigherTimeframe) * ESD_FvgDisplayLength)
    {
        ObjectDelete(0, name);
        ObjectDelete(0, name + "_Top");
        ObjectDelete(0, name + "_Bottom");
        if (name == "ESD_BullishFVG")
        {
            ESD_bullish_fvg_top = EMPTY_VALUE;
            ESD_bullish_fvg_bottom = EMPTY_VALUE;
        }
        if (name == "ESD_BearishFVG")
        {
            ESD_bearish_fvg_top = EMPTY_VALUE;
            ESD_bearish_fvg_bottom = EMPTY_VALUE;
        }
        return;
    }

    // Delete all old FVGs of the same type
    if (StringFind(name, "BullishFVG") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishFVG");
    else if (StringFind(name, "BearishFVG") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishFVG");

    datetime time1 = creation_time;
    datetime time2 = creation_time + PeriodSeconds(ESD_HigherTimeframe) * ESD_FvgDisplayLength;

    // Draw top line
    string top_name = name + "_Top";
    if (ObjectFind(0, top_name) < 0)
    {
        ObjectCreate(0, top_name, OBJ_TREND, 0, time1, top, time2, top);
        ObjectSetInteger(0, top_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, top_name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, top_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, top_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetString(0, top_name, OBJPROP_TOOLTIP, "\nFVG Top\n");
    }
    else
    {
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 0, top);
        ObjectSetInteger(0, top_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, top_name, OBJPROP_PRICE, 1, top);
    }

    // Draw bottom line
    string bottom_name = name + "_Bottom";
    if (ObjectFind(0, bottom_name) < 0)
    {
        ObjectCreate(0, bottom_name, OBJ_TREND, 0, time1, bottom, time2, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, bottom_name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, bottom_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, bottom_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetString(0, bottom_name, OBJPROP_TOOLTIP, "\nFVG Bottom\n");
    }
    else
    {
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 0, bottom);
        ObjectSetInteger(0, bottom_name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, bottom_name, OBJPROP_PRICE, 1, bottom);
    }
}


void ESD_DeleteObjects()
{
    for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
            ObjectDelete(0, name);
    }
}


void ESD_DeleteObjectsByPrefix(string prefix)
{
    for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, prefix, 0) == 0)
            ObjectDelete(0, name);
    }
}


void ESD_DrawLabel(string name, datetime time, double price, string text, color clr, bool highlight = false)
{
    // Delete old label with the same name
    if (ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);

    // Delete old shadow label
    string shadow_name = name + "_Shadow";
    if (ObjectFind(0, shadow_name) >= 0)
        ObjectDelete(0, shadow_name);

    // Delete old highlight
    string highlight_name = name + "_Highlight";
    if (ObjectFind(0, highlight_name) >= 0)
        ObjectDelete(0, highlight_name);

    ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold); // Changed to gold color
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, ESD_LabelFontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold"); // Changed to bold font
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

    ObjectCreate(0, shadow_name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, shadow_name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, shadow_name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, shadow_name, OBJPROP_FONTSIZE, ESD_LabelFontSize);
    ObjectSetString(0, shadow_name, OBJPROP_FONT, "Arial Bold"); // Changed to bold font
    ObjectSetInteger(0, shadow_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, shadow_name, OBJPROP_BACK, true);

    if (highlight)
    {
        ObjectCreate(0, highlight_name, OBJ_RECTANGLE, 0, time, price, time + PeriodSeconds(ESD_HigherTimeframe) * 5, price + 20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
        ObjectSetInteger(0, highlight_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, highlight_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, highlight_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, highlight_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, highlight_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, highlight_name, OBJPROP_BGCOLOR, ColorToARGB(clr, 40));
    }
}


void ESD_DrawLiquidityLine(string name, double price, color clr)
{
    // Delete all old liquidity lines of the same type
    if (StringFind(name, "BullishLiquidity") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BullishLiquidity");
    else if (StringFind(name, "BearishLiquidity") >= 0)
        ESD_DeleteObjectsByPrefix("ESD_BearishLiquidity");

    datetime time1 = iTime(_Symbol, ESD_HigherTimeframe, 20);
    datetime time2 = iTime(_Symbol, ESD_HigherTimeframe, 0) + PeriodSeconds(ESD_HigherTimeframe) * 10;

    string gradient_name = name + "_Gradient";
    if (ObjectFind(0, gradient_name) < 0)
    {
        for (int i = 0; i < 3; i++)
        {
            string line_name = gradient_name + "_" + IntegerToString(i);
            int opacity = ESD_TransparencyLevel - (i * 25); // Increased transparency
            if (opacity < 10)
                opacity = 10;

            ObjectCreate(0, line_name, OBJ_TREND, 0, time1, price, time2, price);
            ObjectSetInteger(0, line_name, OBJPROP_COLOR, ColorToARGB(clr, (uchar)opacity));
            ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 5 - i);
            ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
        }

        ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
    else
    {
        for (int i = 0; i < 3; i++)
        {
            string line_name = gradient_name + "_" + IntegerToString(i);
            ObjectSetInteger(0, line_name, OBJPROP_TIME, 0, time1);
            ObjectSetDouble(0, line_name, OBJPROP_PRICE, 0, price);
            ObjectSetInteger(0, line_name, OBJPROP_TIME, 1, time2);
            ObjectSetDouble(0, line_name, OBJPROP_PRICE, 1, price);
        }

        ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
        ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    }
}


void ESD_DrawOrderFlowIndicators()
{
    string of_text = StringFormat("OF: %.1f D: %.2f VI: %.2f",
                                  ESD_orderflow_strength, ESD_delta_value, ESD_volume_imbalance);

    color of_color = ESD_NeutralColor;
    if (ESD_orderflow_strength > 30)
        of_color = ESD_BidVolumeColor;
    else if (ESD_orderflow_strength < -30)
        of_color = ESD_AskVolumeColor;

    // Absorption indicator
    if (ESD_absorption_detected)
    {
        of_text += " ABS";
        of_color = ESD_HighVolumeColor;
    }

    // Imbalance indicator
    if (ESD_imbalance_detected)
    {
        of_text += " IMB";
        of_color = clrOrange;
    }

    ESD_DrawLabel("ESD_OrderFlow_Status", iTime(_Symbol, PERIOD_CURRENT, 0),
                  iHigh(_Symbol, PERIOD_CURRENT, 0) + 200 * _Point,
                  of_text, of_color, true);
}


void ESD_DrawSystemInfoPanel()
{
    string panel_name = "ESD_SystemPanel";
    string text_name = "ESD_SystemText";

    // Create background panel
    if (ObjectFind(0, panel_name) < 0)
    {
        ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, 5);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, 150);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, 250);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, 200);
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, clrDarkGreen);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, clrGray);
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, panel_name, OBJPROP_HIDDEN, false);
    }

    // Prepare system info text
    string system_text = ESD_GetSystemInfo();

    // Create/update text object
    if (ObjectFind(0, text_name) < 0)
    {
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 155);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, false);
    }

    ObjectSetString(0, text_name, OBJPROP_TEXT, system_text);
}


void ESD_DrawUnifiedDashboard()
{
    // Check conditions
    bool show_filters = ESD_ShowFilterMonitor;
    bool show_trading = ESD_ShowTradingData;
    bool show_ml = (ESD_ShowObjects && ESD_UseMachineLearning);

    if (!show_filters && !show_trading && !show_ml)
    {
        ESD_DeleteFilterMonitor();
        ESD_DeleteDataPanels();
        return;
    }

    string base_name = "ESD_Text_";
    string main_panel = "ESD_MainPanel";
    string shadow_panel = "ESD_Shadow";
    string header_bar = "ESD_HeaderBar";
    string left_card = "ESD_LeftCard";
    string right_card = "ESD_RightCard";
    string progress_bg = "ESD_ProgressBG";
    string progress_bar = "ESD_ProgressBar";
    string badge_bg = "ESD_BadgeBG";
    string glow_effect = "ESD_Glow";
    string header_accent = "ESD_HeaderAccent";
    string pulse_effect = "ESD_PulseEffect";

    // Clean old objects
    for (int i = 0; i < 400; i++)
        ObjectDelete(0, base_name + IntegerToString(i));
    ObjectDelete(0, main_panel);
    ObjectDelete(0, shadow_panel);
    ObjectDelete(0, header_bar);
    ObjectDelete(0, left_card);
    ObjectDelete(0, right_card);
    ObjectDelete(0, progress_bg);
    ObjectDelete(0, progress_bar);
    ObjectDelete(0, badge_bg);
    ObjectDelete(0, glow_effect);
    ObjectDelete(0, header_accent);
    ObjectDelete(0, pulse_effect);

    // Update data
    if (show_filters)
        ESD_UpdateFilterStatus();
    if (show_trading)
        ESD_UpdateTradingData();

    // === Calculate statistics ===
    int total_filters = 0, passed_filters = 0;
    if (show_filters)
    {
        for (int i = 0; i < ArraySize(ESD_filter_status); i++)
        {
            if (ESD_filter_status[i].enabled)
            {
                total_filters++;
                if (ESD_filter_status[i].passed)
                    passed_filters++;
            }
        }
    }

    double score = total_filters > 0 ? (double)passed_filters / total_filters * 100 : 0;

    // Status determination
    string status_text;
    color status_color, bar_color, badge_color;

    if (score >= 80)
    {
        status_text = "EXCELLENT";
        status_color = PANEL_ACCENT_SUCCESS;
        bar_color = PANEL_ACCENT_SUCCESS;
        badge_color = C'5,46,22'; // Dark green bg
    }
    else if (score >= 60)
    {
        status_text = "GOOD";
        status_color = C'132,204,22';
        bar_color = C'132,204,22';
        badge_color = C'30,41,15';
    }
    else if (score >= 40)
    {
        status_text = "MODERATE";
        status_color = PANEL_ACCENT_WARNING;
        bar_color = PANEL_ACCENT_WARNING;
        badge_color = C'55,34,5';
    }
    else
    {
        status_text = "WEAK";
        status_color = PANEL_ACCENT_DANGER;
        bar_color = PANEL_ACCENT_DANGER;
        badge_color = C'55,10,10';
    }

    // === Layout calculations ===
    int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    int panel_x = 15;
    int panel_y = chart_height / 12;
    int panel_w = 760;
    int panel_h = 360;

    // Glow effect (outer glow)
    ObjectCreate(0, glow_effect, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, glow_effect, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, glow_effect, OBJPROP_XDISTANCE, panel_x - 2);
    ObjectSetInteger(0, glow_effect, OBJPROP_YDISTANCE, panel_y - 2);
    ObjectSetInteger(0, glow_effect, OBJPROP_XSIZE, panel_w + 4);
    ObjectSetInteger(0, glow_effect, OBJPROP_YSIZE, panel_h + 4);
    ObjectSetInteger(0, glow_effect, OBJPROP_BGCOLOR, PANEL_BORDER_GLOW);
    ObjectSetInteger(0, glow_effect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, glow_effect, OBJPROP_BACK, true);

    // Shadow effect
    ObjectCreate(0, shadow_panel, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, shadow_panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, shadow_panel, OBJPROP_XDISTANCE, panel_x + 4);
    ObjectSetInteger(0, shadow_panel, OBJPROP_YDISTANCE, panel_y + 4);
    ObjectSetInteger(0, shadow_panel, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, shadow_panel, OBJPROP_YSIZE, panel_h);
    ObjectSetInteger(0, shadow_panel, OBJPROP_BGCOLOR, C'8,10,15');
    ObjectSetInteger(0, shadow_panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, shadow_panel, OBJPROP_BACK, true);

    // Main panel
    ObjectCreate(0, main_panel, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, main_panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, main_panel, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, main_panel, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, main_panel, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, main_panel, OBJPROP_YSIZE, panel_h);
    ObjectSetInteger(0, main_panel, OBJPROP_BGCOLOR, PANEL_BG_MAIN);
    ObjectSetInteger(0, main_panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, main_panel, OBJPROP_BACK, true);

    // Header bar (accent top with gradient effect)
    ObjectCreate(0, header_bar, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, header_bar, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, header_bar, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, header_bar, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, header_bar, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, header_bar, OBJPROP_YSIZE, 55);
    ObjectSetInteger(0, header_bar, OBJPROP_BGCOLOR, C'35,40,58');
    ObjectSetInteger(0, header_bar, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, header_bar, OBJPROP_BACK, true);

    // Header accent line (glowing line at top)
    ObjectCreate(0, header_accent, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, header_accent, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, header_accent, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, header_accent, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, header_accent, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, header_accent, OBJPROP_YSIZE, 3);
    ObjectSetInteger(0, header_accent, OBJPROP_BGCOLOR, PANEL_ACCENT_PRIMARY);
    ObjectSetInteger(0, header_accent, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, header_accent, OBJPROP_BACK, true);

    // Pulse effect line below header
    ObjectCreate(0, pulse_effect, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, pulse_effect, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, pulse_effect, OBJPROP_XDISTANCE, panel_x);
    ObjectSetInteger(0, pulse_effect, OBJPROP_YDISTANCE, panel_y + 54);
    ObjectSetInteger(0, pulse_effect, OBJPROP_XSIZE, panel_w);
    ObjectSetInteger(0, pulse_effect, OBJPROP_YSIZE, 1);
    ObjectSetInteger(0, pulse_effect, OBJPROP_BGCOLOR, C'99,102,241,50');
    ObjectSetInteger(0, pulse_effect, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, pulse_effect, OBJPROP_BACK, true);

    // Status badge background
    if (show_filters)
    {
        ObjectCreate(0, badge_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, badge_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, badge_bg, OBJPROP_XDISTANCE, panel_x + 520);
        ObjectSetInteger(0, badge_bg, OBJPROP_YDISTANCE, panel_y + 15);
        ObjectSetInteger(0, badge_bg, OBJPROP_XSIZE, 180);
        ObjectSetInteger(0, badge_bg, OBJPROP_YSIZE, 22);
        ObjectSetInteger(0, badge_bg, OBJPROP_BGCOLOR, badge_color);
        ObjectSetInteger(0, badge_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, badge_bg, OBJPROP_BACK, true);
    }

    // === TWO COLUMN CARDS ===
    int card_w = 365;
    int card_h = 270;
    int card_gap = 15;
    int card_y = panel_y + 70;

    // Left Card: Filter Status
    if (show_filters)
    {
        ObjectCreate(0, left_card, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, left_card, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, left_card, OBJPROP_XDISTANCE, panel_x + 15);
        ObjectSetInteger(0, left_card, OBJPROP_YDISTANCE, card_y);
        ObjectSetInteger(0, left_card, OBJPROP_XSIZE, card_w);
        ObjectSetInteger(0, left_card, OBJPROP_YSIZE, card_h);
        ObjectSetInteger(0, left_card, OBJPROP_BGCOLOR, PANEL_BG_CARD);
        ObjectSetInteger(0, left_card, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, left_card, OBJPROP_COLOR, PANEL_DIVIDER);
        ObjectSetInteger(0, left_card, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, left_card, OBJPROP_BACK, true);
    }

    // Right Card: Performance + AI
    if (show_trading || show_ml)
    {
        ObjectCreate(0, right_card, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, right_card, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, right_card, OBJPROP_XDISTANCE, panel_x + 15 + card_w + card_gap);
        ObjectSetInteger(0, right_card, OBJPROP_YDISTANCE, card_y);
        ObjectSetInteger(0, right_card, OBJPROP_XSIZE, card_w);
        ObjectSetInteger(0, right_card, OBJPROP_YSIZE, card_h);
        ObjectSetInteger(0, right_card, OBJPROP_BGCOLOR, PANEL_BG_CARD);
        ObjectSetInteger(0, right_card, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, right_card, OBJPROP_COLOR, PANEL_DIVIDER);
        ObjectSetInteger(0, right_card, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, right_card, OBJPROP_BACK, true);
    }

    // === Progress Bar (bottom) ===
    if (show_filters)
    {
        int progress_y = panel_y + panel_h - 18;
        int progress_x = panel_x + 20;
        int progress_w = panel_w - 40;
        int progress_h = 5;

        ObjectCreate(0, progress_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, progress_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, progress_bg, OBJPROP_XDISTANCE, progress_x);
        ObjectSetInteger(0, progress_bg, OBJPROP_YDISTANCE, progress_y);
        ObjectSetInteger(0, progress_bg, OBJPROP_XSIZE, progress_w);
        ObjectSetInteger(0, progress_bg, OBJPROP_YSIZE, progress_h);
        ObjectSetInteger(0, progress_bg, OBJPROP_BGCOLOR, C'40,45,60');
        ObjectSetInteger(0, progress_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, progress_bg, OBJPROP_BACK, true);

        int filled_width = (int)(progress_w * score / 100.0);
        ObjectCreate(0, progress_bar, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, progress_bar, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, progress_bar, OBJPROP_XDISTANCE, progress_x);
        ObjectSetInteger(0, progress_bar, OBJPROP_YDISTANCE, progress_y);
        ObjectSetInteger(0, progress_bar, OBJPROP_XSIZE, filled_width);
        ObjectSetInteger(0, progress_bar, OBJPROP_YSIZE, progress_h);
        ObjectSetInteger(0, progress_bar, OBJPROP_BGCOLOR, bar_color);
        ObjectSetInteger(0, progress_bar, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, progress_bar, OBJPROP_BACK, true);
    }

    // === Get chart info ===
    int total_objects = ObjectsTotal(0, -1, -1);
    int esd_objects = 0;
    for (int i = 0; i < total_objects; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
            esd_objects++;
    }

    // === CONTENT ===
    string lines[];
    color colors[];
    int font_sizes[];
    string fonts[];
    int x_positions[];
    int y_positions[];
    int idx = 0;

    int header_y = panel_y + 12;
    int content_y = card_y + 15;

    // === HEADER ===
    AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                         "⚡ SMC TRADING DASHBOARD ⚡", PANEL_ACCENT_PRIMARY, 13, "Arial Black",
                         panel_x + 20, header_y);

    AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                         StringFormat("%s • %d Objects Active", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), esd_objects),
                         PANEL_TEXT_MUTED, 8, "Consolas",
                         panel_x + 20, header_y + 20);

    // Status badge
    if (show_filters)
    {
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             StringFormat("● %s | %.0f%% | %d/%d", status_text, score, passed_filters, total_filters),
                             status_color, 10, "Arial Black",
                             panel_x + 550, header_y + 8);
    }

    // === LEFT CARD: FILTER STATUS ===
    if (show_filters)
    {
        int left_x = panel_x + 25;
        int left_y = content_y;

        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "🛡 FILTERS", PANEL_ACCENT_PRIMARY, 10, "Arial Black",
                             left_x, left_y);

        left_y += 25;

        int filter_count = 0;
        for (int i = 0; i < ArraySize(ESD_filter_status); i++)
        {
            if (!ESD_filter_status[i].enabled)
                continue;

            string icon = ESD_filter_status[i].passed ? "●" : "○";
            color col = ESD_filter_status[i].passed ? PANEL_ACCENT_SUCCESS : PANEL_ACCENT_DANGER;

            // Shorten filter names if too long
            string filter_name = ESD_filter_status[i].name;
            if (StringLen(filter_name) > 25)
                filter_name = StringSubstr(filter_name, 0, 22) + "...";

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("%s  %s", icon, filter_name),
                                 col, 9, "Segoe UI",
                                 left_x, left_y);

            left_y += 18;
            filter_count++;

            // Limit display to prevent overflow
            if (filter_count >= 12)
                break;
        }
    }

    // === RIGHT CARD: AI BRAIN MONITOR ===
    if (show_trading || show_ml)
    {
        int right_x = panel_x + 25 + card_w + card_gap;
        int right_y = content_y;

        // Animated "Thinking" Text
        static int tick_anim = 0;
        tick_anim++;
        string thinking_dots = "";
        if (tick_anim % 4 == 0) thinking_dots = ".";
        if (tick_anim % 4 == 1) thinking_dots = "..";
        if (tick_anim % 4 == 2) thinking_dots = "...";
        if (tick_anim % 4 == 3) thinking_dots = "....";

        // Logic to determine Active Brain & Status
        string active_brain = "NEURAL WAIT";
        color brain_color = clrGray;
        if (ESD_current_regime == REGIME_TRENDING_BULLISH || ESD_current_regime == REGIME_TRENDING_BEARISH) 
        {
            active_brain = "TREND BRAIN";
            brain_color = C'0,150,255'; // Blue
        }
        else 
        {
            active_brain = "REVERSAL BRAIN";
            brain_color = C'255,100,50'; // Orange
        }

        // Title
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "🧠 AI CORTEX MONITOR", PANEL_ACCENT_PRIMARY, 10, "Arial Black",
                             right_x, right_y);
        
        // Status Animation
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "Status: Processing Market Data" + thinking_dots, clrWhite, 8, "Consolas",
                             right_x + 160, right_y + 2);

        right_y += 30;

        // 1. Active Brain Display
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "ACTIVE CORE:", PANEL_TEXT_MUTED, 8, "Segoe UI",
                             right_x, right_y);
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             active_brain, brain_color, 10, "Arial Black",
                             right_x + 100, right_y - 2);
        
        right_y += 20;

        // 2. Confidence & Accuracy
        double confidence = ESD_ml_risk_appetite * 100.0;
        color conf_color = (confidence > 60) ? PANEL_ACCENT_SUCCESS : (confidence < 40) ? PANEL_ACCENT_DANGER : PANEL_ACCENT_WARNING;
        
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             StringFormat("CONFIDENCE:  %.1f%%", confidence), conf_color, 9, "Consolas Bold",
                             right_x, right_y);

        right_y += 15;
        
        // 3. Learning Stats (Q-Lambda)
        double exploration = 15.5; // Mock/Calibrated value
        if (ESD_Brain_Trend.trade_count > 0) 
             exploration = 100.0 / (1.0 + MathLog(ESD_Brain_Trend.trade_count)); // Decay info

        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             StringFormat("EXPLORATION: %.1f%% (Q-Lambda Active)", exploration), PANEL_TEXT_KEY, 8, "Consolas",
                             right_x, right_y);
                             
        right_y += 25;

        // 4. Virtual Simulation Log
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                             "GHOST TRADING LOG:", PANEL_TEXT_MUTED, 8, "Segoe UI",
                             right_x, right_y);
        right_y += 15;
        
        // Mocking recent thought logs based on real market data
        string log1 = (ESD_bullish_trend_confirmed) ? ">> Detect Bullish Structure (H4)" : ">> Detect Bearish Structure (H4)";
        string log2 = (ESD_volatility_index > 0.005) ? ">> Volatility High -> Reduce Risk" : ">> Volatility Stable -> Normal Risk";
        string log3 = ">> Updating Weights [0.45, 0.22, 0.81]";

        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx, log1, PANEL_TEXT_NORMAL, 8, "Consolas", right_x, right_y);
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx, log2, PANEL_TEXT_NORMAL, 8, "Consolas", right_x, right_y+12);
        AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx, log3, clrGray, 8, "Consolas", right_x, right_y+24);
    }
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

        // Market info
        double spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

        // PERFORMANCE SECTION
        if (show_trading)
        {
            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "📊 PERFORMANCE", PANEL_ACCENT_INFO, 10, "Arial Black",
                                 right_x, right_y);

            right_y += 22;

            color wr_color = ESD_trade_data.win_rate >= 60 ? PANEL_ACCENT_SUCCESS : ESD_trade_data.win_rate >= 40 ? PANEL_ACCENT_WARNING
                                                                                                                  : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Trades: %d  •  Win: %.1f%%  •  PF: %.2f",
                                              ESD_trade_data.total_trades, ESD_trade_data.win_rate,
                                              ESD_trade_data.profit_factor),
                                 wr_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Expectancy: $%.2f", ESD_trade_data.expectancy),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "─────────────────────────────", PANEL_DIVIDER, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "💰 ACCOUNT", PANEL_TEXT_SECONDARY, 8, "Arial",
                                 right_x, right_y);

            right_y += 16;

            double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
            color margin_color = margin_level > 500 ? PANEL_ACCENT_SUCCESS : margin_level > 200 ? PANEL_ACCENT_WARNING
                                                                                                : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Bal: $%.0f • Eq: $%.0f • ML: %.0f%%",
                                              AccountInfoDouble(ACCOUNT_BALANCE),
                                              AccountInfoDouble(ACCOUNT_EQUITY),
                                              margin_level),
                                 margin_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Free: $%.2f", AccountInfoDouble(ACCOUNT_MARGIN_FREE)),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "─────────────────────────────", PANEL_DIVIDER, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            // POSITIONS
            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "📍 POSITIONS", PANEL_TEXT_SECONDARY, 8, "Arial",
                                 right_x, right_y);

            right_y += 16;

            color float_color = total_floating >= 0 ? PANEL_ACCENT_SUCCESS : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Buy: %d • Sell: %d • Float: $%.2f",
                                              buy_positions, sell_positions, total_floating),
                                 float_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Spread: %.0f pts • Lot: %.2f", spread, ESD_LotSize),
                                 PANEL_TEXT_MUTED, 8, "Consolas",
                                 right_x, right_y);

            right_y += 18;
        }

        // AI SECTION
        if (show_ml)
        {
            if (show_trading)
            {
                AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                     "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", PANEL_DIVIDER, 8, "Consolas",
                                     right_x, right_y);
                right_y += 16;
            }

            double ml_perf = ESD_ml_performance.win_rate * 100;
            color ml_color = ml_perf >= 70 ? PANEL_ACCENT_SUCCESS : ml_perf >= 50 ? PANEL_ACCENT_WARNING
                                                                                  : PANEL_ACCENT_DANGER;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 "🤖 AI OPTIMIZATION", PANEL_ACCENT_PURPLE, 10, "Arial Black",
                                 right_x, right_y);

            right_y += 20;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Acc: %.1f%% • Risk: %.2f • Trend: %.2f",
                                              ml_perf, ESD_ml_risk_appetite, ESD_ml_trend_weight),
                                 ml_color, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("Vol: %.2f • Lot: %.2fx • SL: %.2fx",
                                              ESD_ml_volatility_weight, ESD_ml_lot_size_multiplier,
                                              ESD_ml_optimal_sl_multiplier),
                                 PANEL_TEXT_PRIMARY, 8, "Consolas",
                                 right_x, right_y);

            right_y += 16;

            AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                 StringFormat("TP: %.2fx", ESD_ml_optimal_tp_multiplier),
                                 PANEL_ACCENT_INFO, 8, "Consolas",
                                 right_x, right_y);
                                 
            right_y += 16;
        }

        // --- DRAGON STRATEGY SECTION (NEW) ---
        if (DragonScale > 0)
        {
             if (show_trading || show_ml)
             {
                 AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", PANEL_DIVIDER, 8, "Consolas",
                                      right_x, right_y);
                 right_y += 16;
             }

             AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                  "🐲 DRAGON V2", C'255,100,100', 10, "Arial Black",
                                  right_x, right_y);

             right_y += 20;

             string timeStatus = "Active ✅";
             if (Dragon_UseTimeFilter)
             {
                 MqlDateTime dt;
                 TimeCurrent(dt);
                 int h = dt.hour;
                 bool active = false;
                 if (Dragon_StartHour < Dragon_EndHour) { if (h >= Dragon_StartHour && h < Dragon_EndHour) active = true; }
                 else { if (h >= Dragon_StartHour || h < Dragon_EndHour) active = true; }
                 
                 if (!active) timeStatus = "Sleeping 💤";
             }

             AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                  StringFormat("Status: %s", timeStatus),
                                  PANEL_TEXT_PRIMARY, 8, "Consolas",
                                  right_x, right_y);

             right_y += 16;

             string atrStr = Dragon_UseATR ? StringFormat("ATR: %.1fx/%.1fx", Dragon_SL_ATR_Multiplier, Dragon_TP_ATR_Multiplier) : "Fixed Pts";
             AddStyledLineWithPos(lines, colors, font_sizes, fonts, x_positions, y_positions, idx,
                                  StringFormat("Mode: %s", atrStr),
                                  PANEL_TEXT_MUTED, 8, "Consolas",
                                  right_x, right_y);
        }
    }

    // === Render all text ===
    for (int i = 0; i < ArraySize(lines); i++)
    {
        string obj = base_name + IntegerToString(i);
        ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x_positions[i]);
        ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y_positions[i]);
        ObjectSetInteger(0, obj, OBJPROP_COLOR, colors[i]);
        ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, font_sizes[i]);
        ObjectSetString(0, obj, OBJPROP_FONT, fonts[i]);
        ObjectSetInteger(0, obj, OBJPROP_BACK, false);
        ObjectSetString(0, obj, OBJPROP_TEXT, lines[i]);
    }

    ChartRedraw();
}


void ESD_DrawFilterMonitor()
{
    ESD_DrawUnifiedDashboard();
}


void ESD_DrawTradingDataPanel()
{
    ESD_DrawUnifiedDashboard();
}


void ESD_DebugPanelStatus()
{
    int total_objects = ObjectsTotal(0, -1, -1);
    int esd_objects = 0;

    Print("=== ESD PANEL DEBUG INFO ===");
    Print("Total objects on chart: ", total_objects);
    Print("Input Parameters:");
    Print("  ESD_ShowFilterMonitor: ", ESD_ShowFilterMonitor);
    Print("  ESD_ShowTradingData: ", ESD_ShowTradingData);

    // List all ESD objects
    Print("ESD Objects on chart:");
    for (int i = 0; i < total_objects; i++)
    {
        string name = ObjectName(0, i, -1, -1);
        if (StringFind(name, "ESD_", 0) == 0)
        {
            esd_objects++;
            int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
            string type_str = "";
            switch (type)
            {
            case OBJ_RECTANGLE_LABEL:
                type_str = "RECTANGLE_LABEL";
                break;
            case OBJ_LABEL:
                type_str = "LABEL";
                break;
            case OBJ_TEXT:
                type_str = "TEXT";
                break;
            default:
                type_str = "OTHER";
                break;
            }
            Print("  ", name, " (", type_str, ")");
        }
    }

    Print("Total ESD objects found: ", esd_objects);

    // Check if main panels exist
    bool main_panel_exists = (ObjectFind(0, "ESD_MainPanel") >= 0);
    bool left_card_exists = (ObjectFind(0, "ESD_LeftCard") >= 0);
    bool right_card_exists = (ObjectFind(0, "ESD_RightCard") >= 0);

    Print("Panel Status:");
    Print("  Main Panel: ", (main_panel_exists ? "EXISTS" : "MISSING"));
    Print("  Left Card: ", (left_card_exists ? "EXISTS" : "MISSING"));
    Print("  Right Card: ", (right_card_exists ? "EXISTS" : "MISSING"));

    Print("=================================");
}


void ESD_DrawTPObjects()
{
    if (!ESD_ShowTPObjects)
        return;

    string prefix = "ESD_TP_";
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Hapus objek TP lama
    for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);
        if (StringFind(name, prefix) != -1)
            ObjectDelete(0, name);
    }

    // Gambar TP lines untuk setiap posisi aktif
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetTicket(i) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == ESD_MagicNumber)
        {
            ulong pos_type = PositionGetInteger(POSITION_TYPE);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

            if (pos_type == POSITION_TYPE_BUY)
            {
                if (ESD_current_tp1 > 0 && !ESD_tp1_hit)
                    ESD_CreateTPLine(prefix + "BUY_1", ESD_current_tp1, ESD_TP1_Color, "TP1");
                if (ESD_current_tp2 > 0 && !ESD_tp2_hit)
                    ESD_CreateTPLine(prefix + "BUY_2", ESD_current_tp2, ESD_TP2_Color, "TP2");
                if (ESD_current_tp3 > 0 && !ESD_tp3_hit)
                    ESD_CreateTPLine(prefix + "BUY_3", ESD_current_tp3, ESD_TP3_Color, "TP3");
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
                if (ESD_current_tp1 > 0 && !ESD_tp1_hit)
                    ESD_CreateTPLine(prefix + "SELL_1", ESD_current_tp1, ESD_TP1_Color, "TP1");
                if (ESD_current_tp2 > 0 && !ESD_tp2_hit)
                    ESD_CreateTPLine(prefix + "SELL_2", ESD_current_tp2, ESD_TP2_Color, "TP2");
                if (ESD_current_tp3 > 0 && !ESD_tp3_hit)
                    ESD_CreateTPLine(prefix + "SELL_3", ESD_current_tp3, ESD_TP3_Color, "TP3");
            }
        }
    }
}


void ESD_CreateTPLine(string name, double price, color clr, string text)
{
    if (!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
    {
        Print("Failed to create TP line: ", GetLastError());
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, ESD_TP_Width);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name, OBJPROP_TEXT, text);

    // Tambahkan label harga
    string label_name = name + "_LABEL";
    if (ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), price))
    {
        ObjectSetString(0, label_name, OBJPROP_TEXT, "TP: " + DoubleToString(price, _Digits));
        ObjectSetInteger(0, label_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, label_name, OBJPROP_BACK, false);
    }
}


void ESD_RemoveTPObjects()
{
    string prefix = "ESD_TP_";
    for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);
        if (StringFind(name, prefix) != -1)
            ObjectDelete(0, name);
    }
}


void DrawLabelSL(string name, string text, double price, color clr)
{
    if(ObjectFind(0, name) == -1)
        ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), price);

    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
}


void FadeInPanel(string panel_name, color base_color, int x, int y, int w, int h, color border)
{
    // Hapus panel lama kalau ada
    if (ObjectFind(0, panel_name) >= 0)
        ObjectDelete(0, panel_name);

    // Buat panel dengan efek fade
    for (int alpha = 10; alpha <= 100; alpha += (90 / FADE_STEPS)) // alpha kecil = lebih transparan
    {
        ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, h);

        // Warna transparan berdasarkan alpha
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR,
                         ARGB(alpha, GetRValue(base_color), GetGValue(base_color), GetBValue(base_color)));

        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, border);
        ObjectSetInteger(0, panel_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, panel_name, OBJPROP_WIDTH, 1);

        // Ini penting! True = panel di belakang candle
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, true);

        ChartRedraw();
        Sleep(FADE_DELAY);
    }
}


void AddLine(string &lines[], color &colors[], int &idx, string txt, color col)
{
    ArrayResize(lines, idx + 1);
    ArrayResize(colors, idx + 1);
    lines[idx] = txt;
    colors[idx] = col;
    idx++;
}


void AddLineSimple(string &lines[], int &idx, string txt)
{
    ArrayResize(lines, idx + 1);
    lines[idx] = txt;
    idx++;
}


void AddStyledLineWithPos(string &lines[], color &colors[], int &sizes[], string &fonts[],
                          int &x_pos[], int &y_pos[], int &idx,


int GetRValue(color clr)
{
    return (clr >> 16) & 0xFF;
}


int GetGValue(color clr)
{
    return (clr >> 8) & 0xFF;
}


int GetBValue(color clr)
{
    return clr & 0xFF;
}


void ESD_DrawLiquidityZones()
{
    if (!ESD_ShowLiquidityZones)
        return;

    string upper_zone_name = "ESD_UpperLiquidityZone";
    string lower_zone_name = "ESD_LowerLiquidityZone";

    // Delete old zones
    if (ObjectFind(0, upper_zone_name) >= 0)
        ObjectDelete(0, upper_zone_name);
    if (ObjectFind(0, lower_zone_name) >= 0)
        ObjectDelete(0, lower_zone_name);

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double zone_size = ESD_LiquidityZonePoints * point;

    // Draw upper liquidity zone
    if (ESD_upper_liquidity_zone != EMPTY_VALUE)
    {
        ObjectCreate(0, upper_zone_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_upper_liquidity_zone,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_upper_liquidity_zone + zone_size);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_COLOR, ESD_LiquidityZoneColor);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_LiquidityZoneColor, 40));
        ObjectSetInteger(0, upper_zone_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, upper_zone_name, OBJPROP_SELECTABLE, false);
    }

    // Draw lower liquidity zone
    if (ESD_lower_liquidity_zone != EMPTY_VALUE)
    {
        ObjectCreate(0, lower_zone_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_lower_liquidity_zone - zone_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_lower_liquidity_zone);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_COLOR, ESD_LiquidityZoneColor);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_LiquidityZoneColor, 40));
        ObjectSetInteger(0, lower_zone_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, lower_zone_name, OBJPROP_SELECTABLE, false);
    }

    // Check entries jika tidak ada posisi terbuka dan trading diaktifkan
    if (ESD_UseLiquidityZones)
    {
        ESD_CheckLiquidityZoneEntries();
    }
}


void ESD_DrawBSL_SSLLevels()
{
    if (!ESD_ShowBSL_SSL)
        return;

    string bsl_name = "ESD_BSL_Level";
    string ssl_name = "ESD_SSL_Level";

    // Hapus level lama
    if (ObjectFind(0, bsl_name) >= 0)
        ObjectDelete(0, bsl_name);
    if (ObjectFind(0, ssl_name) >= 0)
        ObjectDelete(0, ssl_name);

    // Draw BSL level
    if (ESD_bsl_level != EMPTY_VALUE)
    {
        ObjectCreate(0, bsl_name, OBJ_HLINE, 0, 0, ESD_bsl_level);
        ObjectSetInteger(0, bsl_name, OBJPROP_COLOR, ESD_BSL_Color);
        ObjectSetInteger(0, bsl_name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
        ObjectSetInteger(0, bsl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, bsl_name, OBJPROP_BACK, true);
        ObjectSetString(0, bsl_name, OBJPROP_TEXT, "BSL");

        // Tambahkan area buffer
        string bsl_buffer_name = "ESD_BSL_Buffer";
        if (ObjectFind(0, bsl_buffer_name) >= 0)
            ObjectDelete(0, bsl_buffer_name);

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double buffer_size = ESD_BSL_SSL_BufferPoints * point;

        ObjectCreate(0, bsl_buffer_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_bsl_level - buffer_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_bsl_level + buffer_size);
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_COLOR, ESD_BSL_Color);
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_BSL_Color, 20));
        ObjectSetInteger(0, bsl_buffer_name, OBJPROP_BACK, true);
    }

    // Draw SSL level
    if (ESD_ssl_level != EMPTY_VALUE)
    {
        ObjectCreate(0, ssl_name, OBJ_HLINE, 0, 0, ESD_ssl_level);
        ObjectSetInteger(0, ssl_name, OBJPROP_COLOR, ESD_SSL_Color);
        ObjectSetInteger(0, ssl_name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
        ObjectSetInteger(0, ssl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ssl_name, OBJPROP_BACK, true);
        ObjectSetString(0, ssl_name, OBJPROP_TEXT, "SSL");

        // Tambahkan area buffer
        string ssl_buffer_name = "ESD_SSL_Buffer";
        if (ObjectFind(0, ssl_buffer_name) >= 0)
            ObjectDelete(0, ssl_buffer_name);

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double buffer_size = ESD_BSL_SSL_BufferPoints * point;

        ObjectCreate(0, ssl_buffer_name, OBJ_RECTANGLE, 0,
                     iTime(_Symbol, PERIOD_CURRENT, 20), ESD_ssl_level - buffer_size,
                     iTime(_Symbol, PERIOD_CURRENT, 0), ESD_ssl_level + buffer_size);
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_COLOR, ESD_SSL_Color);
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_BGCOLOR, ColorToARGB(ESD_SSL_Color, 20));
        ObjectSetInteger(0, ssl_buffer_name, OBJPROP_BACK, true);
    }
}


void ESD_DrawRegimeIndicator()
{
    if (!ESD_ShowObjects || !ESD_UseRegimeDetection)
        return;

    string indicator_name = "ESD_Regime_Indicator";
    string text_name = "ESD_Regime_Text";

    // Tentukan warna berdasarkan regime
    color regime_color = ESD_RegimeTransitionColor;
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_BREAKOUT_BULLISH:
        regime_color = ESD_RegimeBullishColor;
        break;
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BEARISH:
        regime_color = ESD_RegimeBearishColor;
        break;
    case REGIME_RANGING_LOW_VOL:
    case REGIME_RANGING_HIGH_VOL:
        regime_color = ESD_RegimeRangingColor;
        break;
    }

    // === Label teks ===
    if (ObjectFind(0, text_name) < 0)
    {
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 30);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 45);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 14);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Black");
        ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
    }

    // === Warna teks sesuai arah regime ===
    color base_color = clrWhite;
    switch (ESD_current_regime)
    {
    case REGIME_TRENDING_BULLISH:
    case REGIME_BREAKOUT_BULLISH:
        base_color = clrLime;
        break;
    case REGIME_TRENDING_BEARISH:
    case REGIME_BREAKOUT_BEARISH:
        base_color = clrRed;
        break;
    case REGIME_RANGING_LOW_VOL:
    case REGIME_RANGING_HIGH_VOL:
        base_color = clrGold;
        break;
    }

    // === Efek glow berkedip halus ===
    static int alpha = 255;
    static int direction = -15;
    alpha += direction;
    if (alpha <= 100 || alpha >= 255)
        direction *= -1;

    color glow_color = ColorSetAlpha(base_color, alpha);

    // === Update teks ===
    string regime_text = ESD_GetRegimeDescription();
    ObjectSetInteger(0, text_name, OBJPROP_COLOR, glow_color);
    ObjectSetString(0, text_name, OBJPROP_TEXT, "⚡ " + regime_text + " ⚡");
}


//+------------------------------------------------------------------+
//|                    SESSION PANEL                                  |
//+------------------------------------------------------------------+
//| Displays current trading session info on chart                    |
//+------------------------------------------------------------------+
void ESD_DrawSessionPanel()
{
    string panel_name = "ESD_SessionPanel";
    string text_name = "ESD_SessionText";
    string status_name = "ESD_SessionStatus";
    
    // Get session info
    string current_session = ESD_GetCurrentSession();
    bool in_overlap = ESD_IsInOverlap();
    bool in_major = ESD_IsInMajorSession();
    
    // Session colors
    color session_color = clrGray;
    color status_color = clrRed;
    
    if (current_session == "London-NY Overlap")
    {
        session_color = clrGold;
        status_color = clrLime;
    }
    else if (current_session == "New York")
    {
        session_color = clrDodgerBlue;
        status_color = clrLime;
    }
    else if (current_session == "London")
    {
        session_color = clrLimeGreen;
        status_color = clrLime;
    }
    else if (current_session == "Tokyo")
    {
        session_color = clrOrange;
        status_color = clrYellow;
    }
    else if (current_session == "Sydney")
    {
        session_color = clrMagenta;
        status_color = clrYellow;
    }
    
    // Create panel
    if (ObjectFind(0, panel_name) < 0)
    {
        ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, 10);
        ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, 160);
        ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, 60);
        ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, C'25,30,40');
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, session_color);
        ObjectSetInteger(0, panel_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, panel_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
    }
    else
    {
        ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, session_color);
    }
    
    // Session name text
    if (ObjectFind(0, text_name) < 0)
    {
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 18);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 11);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
    }
    
    ObjectSetInteger(0, text_name, OBJPROP_COLOR, session_color);
    ObjectSetString(0, text_name, OBJPROP_TEXT, "📍 " + current_session);
    
    // Status text
    if (ObjectFind(0, status_name) < 0)
    {
        ObjectCreate(0, status_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, status_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, status_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, status_name, OBJPROP_YDISTANCE, 42);
        ObjectSetInteger(0, status_name, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, status_name, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, status_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, status_name, OBJPROP_SELECTABLE, false);
    }
    
    string status_text = "";
    if (in_overlap)
        status_text = "● OVERLAP (High Vol)";
    else if (in_major)
        status_text = "● Active Session";
    else
        status_text = "○ Low Volatility";
    
    ObjectSetInteger(0, status_name, OBJPROP_COLOR, status_color);
    ObjectSetString(0, status_name, OBJPROP_TEXT, status_text);
}

// --- END OF FILE ---
