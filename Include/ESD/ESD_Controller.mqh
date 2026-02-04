//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                        ESD_Controller.mqh                         |
//+------------------------------------------------------------------+
//| MODULE: Central Controller
//|
//| DESCRIPTION:
//|   Central controller untuk mengelola semua subsystem EA.
//|   Single entry point untuk OnInit, OnTick, OnDeinit.
//|   Mengkoordinasikan semua module dan memastikan execution order.
//|
//| SUBSYSTEMS:
//|   - ML Manager      : Machine Learning operations
//|   - SMC Manager     : Smart Money Concepts detection
//|   - Risk Manager    : Risk management and circuit breakers
//|   - News Manager    : Economic calendar filter
//|   - Trade Manager   : Trade execution and management
//|   - Visual Manager  : Dashboard and chart objects
//|
//| ARCHITECTURE:
//|   trade.mq5 → Controller → Managers → Modules
//|
//| VERSION: 1.0 | CREATED: 2025-12-18
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

//--- Include All Dependencies in Order
#include "ESD_Types.mqh"
#include "ESD_Inputs.mqh"
#include "ESD_Globals.mqh"
#include "ESD_Utils.mqh"
#include "ESD_Visuals.mqh"
#include "ESD_Risk.mqh"
#include "ESD_News.mqh"
#include "ESD_Trend.mqh"
#include "ESD_SMC.mqh"
#include "ESD_ML.mqh"
#include "ESD_Core.mqh"
#include "ESD_Execution.mqh"
#include "ESD_Entry.mqh"
#include "ESD_Dragon.mqh"
#include "ESD_Confirmation.mqh"
#include "ESD_Strategies.mqh"

//+------------------------------------------------------------------+
//|                    CONTROLLER STATE                               |
//+------------------------------------------------------------------+

struct ESD_ControllerState
{
    bool        initialized;
    bool        trading_enabled;
    bool        news_blocking;
    bool        circuit_breaker_active;
    datetime    last_update;
    string      status_message;
    int         tick_count;
};

ESD_ControllerState g_controller;

//+------------------------------------------------------------------+
//|                    INITIALIZATION                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Main Controller Initialization                                   |
//+------------------------------------------------------------------+
bool ESD_Controller_Init()
{
    ESD_Log("═══════════════════════════════════════════════════════", ESD_LOG_INFO);
    ESD_Log("         ESD TRADING FRAMEWORK v2.1 INITIALIZING        ", ESD_LOG_INFO);
    ESD_Log("═══════════════════════════════════════════════════════", ESD_LOG_INFO);
    
    // Reset controller state
    g_controller.initialized = false;
    g_controller.trading_enabled = true;
    g_controller.news_blocking = false;
    g_controller.circuit_breaker_active = false;
    g_controller.last_update = 0;
    g_controller.status_message = "Initializing...";
    g_controller.tick_count = 0;
    
    // === PHASE 1: Initialize Trade Object ===
    if (!ESD_InitTradeManager())
    {
        ESD_Error("Controller_Init", "Trade Manager initialization failed");
        return false;
    }
    
    // === PHASE 2: Initialize News Manager ===
    if (!ESD_InitNewsManager())
    {
        ESD_Log("News Manager skipped (disabled)", ESD_LOG_WARNING);
    }
    
    // === PHASE 3: Initialize ML Manager ===
    if (!ESD_InitMLManager())
    {
        ESD_Log("ML Manager skipped (disabled)", ESD_LOG_WARNING);
    }
    
    // === PHASE 4: Initialize Dragon Strategy ===
    if (!ESD_InitDragonManager())
    {
        ESD_Error("Controller_Init", "Dragon Strategy initialization failed");
        return false;
    }
    
    // === PHASE 5: Initialize Visual Manager ===
    ESD_InitVisualManager();
    
    // === PHASE 6: Detect Initial Market State ===
    ESD_InitMarketState();
    
    // Mark as initialized
    g_controller.initialized = true;
    g_controller.status_message = "Ready";
    
    ESD_Log("═══════════════════════════════════════════════════════", ESD_LOG_INFO);
    ESD_Log("         ✅ ESD TRADING FRAMEWORK READY                  ", ESD_LOG_INFO);
    ESD_Log("═══════════════════════════════════════════════════════", ESD_LOG_INFO);
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Trade Manager                                         |
//+------------------------------------------------------------------+
bool ESD_InitTradeManager()
{
    ESD_trade.SetExpertMagicNumber(ESD_MagicNumber);
    ESD_trade.SetDeviationInPoints(ESD_Slippage);
    ESD_trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    ESD_Log("Trade Manager initialized", ESD_LOG_INFO);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize News Manager                                          |
//+------------------------------------------------------------------+
bool ESD_InitNewsManager()
{
    if (!ESD_UseNewsFilter)
        return false;
    
    ESD_InitializeNewsFilter();
    ESD_Log("News Manager initialized", ESD_LOG_INFO);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize ML Manager                                            |
//+------------------------------------------------------------------+
bool ESD_InitMLManager()
{
    if (!ESD_UseMachineLearning)
        return false;
    
    ESD_InitializeML();
    ESD_Log("ML Manager initialized", ESD_LOG_INFO);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Dragon Strategy Manager                               |
//+------------------------------------------------------------------+
bool ESD_InitDragonManager()
{
    if (OnInitDragon() != INIT_SUCCEEDED)
        return false;
    
    ESD_Log("Dragon Manager initialized", ESD_LOG_INFO);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Visual Manager                                        |
//+------------------------------------------------------------------+
void ESD_InitVisualManager()
{
    ESD_InitializeMonitoringPanels();
    ESD_Log("Visual Manager initialized", ESD_LOG_INFO);
}

//+------------------------------------------------------------------+
//| Initialize Market State                                          |
//+------------------------------------------------------------------+
void ESD_InitMarketState()
{
    ESD_DetectInitialTrend();
    ESD_Log("Market State initialized", ESD_LOG_INFO);
}

//+------------------------------------------------------------------+
//|                    MAIN TICK HANDLER                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Controller OnTick - Main Entry Point                             |
//+------------------------------------------------------------------+
void ESD_Controller_OnTick()
{
    if (!g_controller.initialized)
        return;
    
    g_controller.tick_count++;
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 0: VIRTUAL LEARNING (Always Active)
    // ═══════════════════════════════════════════════════════════════
    ESD_MLManager_VirtualTrades();
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: POSITION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════
    ESD_RiskManager_Protect();
    
    // Auto-Breakeven Management
    if (ESD_UseAutoBreakeven)
    {
        ESD_AutoBreakeven(ESD_BreakevenActivation, ESD_BreakevenBuffer, ESD_MagicNumber);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: SESSION & NEWS FILTER CHECK
    // ═══════════════════════════════════════════════════════════════
    if (!ESD_SessionManager_CanTrade())
    {
        ESD_AnalysisManager_Update();
        return;
    }
    
    if (!ESD_NewsManager_CanTrade())
    {
        ESD_AnalysisManager_Update();
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: UPDATE ALL ANALYSIS
    // ═══════════════════════════════════════════════════════════════
    ESD_AnalysisManager_Update();
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 4: ENTRY LOGIC
    // ═══════════════════════════════════════════════════════════════
    ESD_TradeManager_CheckEntries();
}

//+------------------------------------------------------------------+
//|                    SUBSYSTEM MANAGERS                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ML Manager - Virtual Trades                                      |
//+------------------------------------------------------------------+
void ESD_MLManager_VirtualTrades()
{
    if (!ESD_UseMachineLearning)
        return;
    
    ESD_ManageVirtualTrades(ESD_GetBid(), ESD_GetAsk());
}

//+------------------------------------------------------------------+
//| ML Manager - Update Model                                        |
//+------------------------------------------------------------------+
void ESD_MLManager_Update()
{
    if (!ESD_UseMachineLearning)
        return;
    
    ESD_UpdateMLModel();
}

//+------------------------------------------------------------------+
//| Risk Manager - Protection Checks                                 |
//+------------------------------------------------------------------+
void ESD_RiskManager_Protect()
{
    ESD_UpdateMaxLossSL_AndReversal(300);
}

//+------------------------------------------------------------------+
//| Session Manager - Can Trade Check                                |
//+------------------------------------------------------------------+
bool ESD_SessionManager_CanTrade()
{
    if (!ESD_UseSessionFilter)
        return true;
    
    // Check overlap-only mode
    if (ESD_TradeOnOverlapOnly)
    {
        bool in_overlap = ESD_IsInOverlap();
        if (!in_overlap)
            return false;
        return true;
    }
    
    // Check major sessions only mode
    if (ESD_TradeOnlyMajorSessions)
    {
        if (!ESD_IsInMajorSession())
            return false;
    }
    
    // Check individual session permissions
    if (ESD_IsSydneySession() && !ESD_TradeSydney)
        return false;
    if (ESD_IsTokyoSession() && !ESD_TradeTokyo)
        return false;
    if (ESD_IsLondonSession() && !ESD_TradeLondon)
        return false;
    if (ESD_IsNewYorkSession() && !ESD_TradeNewYork)
        return false;
    
    // No session active and filter is on - block trading
    string current = ESD_GetCurrentSession();
    if (current == "Off-Hours")
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| News Manager - Can Trade Check                                   |
//+------------------------------------------------------------------+
bool ESD_NewsManager_CanTrade()
{
    if (!ESD_UseNewsFilter)
        return true;
    
    ESD_UpdateNewsCalendar();
    ESD_DrawNewsIndicator();
    
    bool can_trade = ESD_NewsFilter();
    g_controller.news_blocking = !can_trade;
    
    return can_trade;
}

//+------------------------------------------------------------------+
//| Analysis Manager - Update All Analysis                           |
//+------------------------------------------------------------------+
void ESD_AnalysisManager_Update()
{
    // ML Model Update
    ESD_MLManager_Update();
    
    // Dragon Momentum
    DragonMomentum();
    
    // SMC Structures
    ESD_SMCManager_Update();
    
    // Session Panel Update
    ESD_DrawSessionPanel();
    
    // Trend Analysis
    ESD_DetectSupremeTimeframeTrend();
    
    // Market Regime
    ESD_DetectMarketRegime();
    
    // Liquidity Levels
    ESD_DetectBSL_SSLLevels();
    
    // Heatmap & Order Flow
    ESD_AnalyzeHeatmap();
    ESD_AnalyzeOrderFlow();
    
    // Filter Status
    ESD_UpdateFilterStatus();
    
    // Trading Data
    ESD_UpdateTradingData();
    
    g_controller.last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| SMC Manager - Update SMC Detection                               |
//+------------------------------------------------------------------+
void ESD_SMCManager_Update()
{
    ESD_DetectSMC();
}

//+------------------------------------------------------------------+
//| Trade Manager - Check and Execute Entries                        |
//+------------------------------------------------------------------+
void ESD_TradeManager_CheckEntries()
{
    // Main Strategy Entry
    if (ESD_UseMachineLearning)
    {
        ESD_CheckForEntryWithML();
        ESD_CheckMLAggressiveAlternativeEntries();
        
        // ML Stochastic Strategy (Multi-TF Confirmation)
        ESD_TryOpenMLStochasticTrade();
    }
    else
    {
        ESD_CheckForEntry();
    }
    
    // Short Opportunities
    if (ESD_EnableShortTrading)
    {
        ESD_CheckForShortEntries();
    }
    
    // Aggressive Entries
    ESD_CheckForAggressiveEntry();
    
    // Advanced Strategies (RSI Divergence, S/D Zones, Session Momentum)
    ESD_RunAllStrategies();
}

//+------------------------------------------------------------------+
//|                    DEINITIALIZATION                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Controller Deinit - Cleanup                                      |
//+------------------------------------------------------------------+
void ESD_Controller_Deinit(int reason)
{
    ESD_Log("Deinitializing ESD Framework...", ESD_LOG_INFO);
    
    // Clean up visual objects
    if (ESD_ShowObjects)
    {
        ObjectsDeleteAll(0, "ESD_");
    }
    
    // Release Dragon indicator
    IndicatorRelease(emaHandle);
    
    // Save ML Data
    if (ESD_UseMachineLearning)
    {
        ESD_SaveMLData();
        ESD_Log("ML Data saved", ESD_LOG_INFO);
    }
    
    g_controller.initialized = false;
    
    ESD_Log(StringFormat("ESD Framework Deinitialized. Reason: %d", reason), ESD_LOG_INFO);
}

//+------------------------------------------------------------------+
//|                    STATUS & DIAGNOSTICS                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Controller Status                                            |
//+------------------------------------------------------------------+
string ESD_Controller_GetStatus()
{
    return StringFormat(
        "Status: %s | Ticks: %d | News Block: %s | CB: %s",
        g_controller.status_message,
        g_controller.tick_count,
        g_controller.news_blocking ? "YES" : "NO",
        g_controller.circuit_breaker_active ? "ACTIVE" : "OFF"
    );
}

//+------------------------------------------------------------------+
//| Check if system is ready to trade                                |
//+------------------------------------------------------------------+
bool ESD_IsReadyToTrade()
{
    if (!g_controller.initialized) return false;
    if (!g_controller.trading_enabled) return false;
    if (g_controller.news_blocking) return false;
    if (g_controller.circuit_breaker_active) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Log Current System State                                         |
//+------------------------------------------------------------------+
void ESD_LogSystemState()
{
    ESD_Log("=== SYSTEM STATE ===", ESD_LOG_DEBUG);
    ESD_Log(StringFormat("Initialized: %s", g_controller.initialized ? "YES" : "NO"), ESD_LOG_DEBUG);
    ESD_Log(StringFormat("Trading: %s", g_controller.trading_enabled ? "ENABLED" : "DISABLED"), ESD_LOG_DEBUG);
    ESD_Log(StringFormat("News Blocking: %s", g_controller.news_blocking ? "YES" : "NO"), ESD_LOG_DEBUG);
    ESD_Log(StringFormat("Circuit Breaker: %s", g_controller.circuit_breaker_active ? "ACTIVE" : "OFF"), ESD_LOG_DEBUG);
    ESD_Log(StringFormat("Tick Count: %d", g_controller.tick_count), ESD_LOG_DEBUG);
    ESD_Log(ESD_GetSystemInfo(), ESD_LOG_DEBUG);
}

// --- END OF FILE ---
