//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                             trade.mq5                             |
//+------------------------------------------------------------------+
//| MAIN EA FILE: ESD SMC Trading System v2.2
//|
//| DESCRIPTION:
//|   Expert Advisor combining Smart Money Concepts (SMC), Machine
//|   Learning optimization, News filtering, and multiple trading
//|   strategies for XAUUSD and other pairs.
//|
//| ARCHITECTURE:
//|   This file serves as the entry point only. All logic is
//|   managed by ESD_Controller which coordinates subsystems:
//|
//|   ┌─────────────────────────────────────────────────────────────┐
//|   │                     ESD_Controller                          │
//|   │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
//|   │  │ ML_Mgr  │ │ SMC_Mgr │ │Risk_Mgr │ │Trade_Mgr│           │
//|   │  └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
//|   └─────────────────────────────────────────────────────────────┘
//|
//| MODULES:
//|   Layer 1 (Foundation): Types, Inputs, Globals, Utils
//|   Layer 2 (Analysis):   Trend, SMC, ML, Risk, Core, News
//|   Layer 3 (Execution):  Entry, Execution, Dragon, Confirmation
//|
//| VERSION: 2.2 (Controller Architecture)
//| LAST UPDATED: 2025-12-18
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"
#property version   "2.20"

//--- Single Include - Controller manages all dependencies
#include "Include/ESD/ESD_Controller.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    return ESD_Controller_Init() ? INIT_SUCCEEDED : INIT_FAILED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ESD_Controller_Deinit(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    ESD_Controller_OnTick();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Reserved for future trade event handling
}

// --- END OF FILE ---
