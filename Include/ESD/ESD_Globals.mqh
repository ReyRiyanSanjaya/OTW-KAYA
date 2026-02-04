//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                          ESD_Globals.mqh                          |
//+------------------------------------------------------------------+
//| MODULE: Global Variables & State
//|
//| DESCRIPTION:
//|   Central state management for all EA global variables including
//|   SMC structures, trend state, ML parameters, and trade data.
//|
//| INCLUDES:
//|   - CTrade instance (ESD_trade)
//|   - Trend/Strength variables
//|   - SMC zones (OB, FVG, Liquidity)
//|   - ML performance metrics
//|   - News filter state
//|   - Regime detection state
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include <Trade\Trade.mqh>
#include "ESD_Types.mqh"

// Non-Input Globals
double ESD_TrendStrengthThreshold = 0.5;          // Minimum trend strength (0-1)
double ESD_MinZoneQualityScore = 0.3;                  // Minimum zone quality score (0-1)
int ESD_HeatmapStrengthThreshold = 70;           // Min heatmap strength (0-100)

// Liquidity Grab Variables
datetime last_liquidity_grab_time = 0;
double liquidity_grab_level = 0;
bool liquidity_grab_active = false;
int liquidity_grab_direction = 0; // 1 = bullish, -1 = bearish
string liquidity_grab_signal_type;  // Untuk menyimpan jenis sinyal (BoS/CHOCH)
double liquidity_grab_signal_price; // Untuk menyimpan harga sinyal

// Objek Global
CTrade ESD_trade;

// Variabel untuk menyimpan level SMC
double ESD_bullish_ob_top = EMPTY_VALUE;
double ESD_bullish_ob_bottom = EMPTY_VALUE;
double ESD_bearish_ob_top = EMPTY_VALUE;
double ESD_bearish_ob_bottom = EMPTY_VALUE;

// Variabel untuk menyimpan level FVG
double ESD_bullish_fvg_top = EMPTY_VALUE;
double ESD_bullish_fvg_bottom = EMPTY_VALUE;
double ESD_bearish_fvg_top = EMPTY_VALUE;
double ESD_bearish_fvg_bottom = EMPTY_VALUE;
datetime ESD_fvg_creation_time = 0;

datetime ESD_last_bos_time = 0;
datetime ESD_last_choch_time = 0;
bool ESD_bullish_trend_confirmed = false;
bool ESD_bearish_trend_confirmed = false;
double ESD_bullish_trend_strength = 0.0;
double ESD_bearish_trend_strength = 0.0;

// Variabel untuk liquidity levels
double ESD_bullish_liquidity = EMPTY_VALUE;
double ESD_bearish_liquidity = EMPTY_VALUE;

// Variabel untuk menyimpan Pivot Point terakhir
double ESD_last_significant_ph = 0;
datetime ESD_last_significant_ph_time = 0;
double ESD_last_significant_pl = 0;
datetime ESD_last_significant_pl_time = 0;

// Variabel untuk Market Structure Shift
bool ESD_bullish_mss_detected = true;
bool ESD_bearish_mss_detected = true;
datetime ESD_bullish_mss_time = 0;
datetime ESD_bearish_mss_time = 0;

// Variabel untuk Aggressive Mode
datetime ESD_last_fvg_buy_time = 0;
datetime ESD_last_fvg_sell_time = 0;
datetime ESD_last_choch_buy_time = 0;
datetime ESD_last_choch_sell_time = 0;
datetime ESD_last_bos_buy_time = 0;
datetime ESD_last_bos_sell_time = 0;

// Heatmap Variables
double ESD_heatmap_strength = 0.0;    // Current heatmap strength (-100 to +100)
bool ESD_heatmap_bullish = false;     // Heatmap bias
bool ESD_heatmap_bearish = false;     // Heatmap bias
double ESD_sector_strength = 0.0;     // Sector strength
datetime ESD_last_heatmap_update = 0; // Last heatmap update time

// Order Flow Variables
double ESD_orderflow_strength = 0.0;    // Order flow strength (-100 to +100)
double ESD_delta_value = 0.0;           // Current delta value
double ESD_cumulative_delta = 0.0;      // Cumulative delta
double ESD_volume_imbalance = 0.0;      // Volume imbalance ratio
bool ESD_absorption_detected = false;   // Absorption detected
bool ESD_imbalance_detected = false;    // Imbalance detected
datetime ESD_last_orderflow_update = 0; // Last order flow update
double ESD_poc_price = 0.0;             // Point of Control price
double ESD_high_volume_nodes[];         // High volume nodes array

// ML Variables
double ESD_ml_risk_appetite = 0.5;
double ESD_ml_optimal_sl_multiplier = 1.0;
double ESD_ml_optimal_tp_multiplier = 1.0;

// Historical Array
ESD_SMStructure ESD_smc_structures[];

// ML Variables
double ESD_ml_trend_weight = 1.0;
double ESD_ml_volatility_weight = 1.0;
double ESD_ml_momentum_weight = 1.0;
double ESD_ml_lot_size_multiplier = 1.0;
ESD_ML_Performance ESD_ml_performance;

// Static-like Globals for ML System
PerformanceMetrics g_perf_metrics;
PerformanceMetrics g_prev_perf_metrics;

// Experience Replay Buffer (Global for simplicity, or could be in ESD_ML.mqh static)
// Since we have ESD_Globals included everywhere, this makes them accessible.
// However, the definitions in trade_backup.mq5 used defines for sizes.
// Moving the defines here or to types? types or globals.
/*
#define MAX_EXPERIENCES 1000
#define BATCH_SIZE 32
#define STATES 243 
#define ACTIONS 9 
*/
// I will not define macros in Globals generally, but for array sizes we need them or literals.
// I'll use literals for now to avoid include scope issues if defines were local?
// Or I can put defines in Types?

// News Filter Variables
datetime ESD_next_high_impact_news = 0;
string ESD_next_news_event = "";
bool ESD_news_filter_active = false;
datetime ESD_last_news_update = 0;

// Regime Detection Variables
ENUM_MARKET_REGIME ESD_current_regime = REGIME_TRANSITION;
ENUM_MARKET_REGIME ESD_previous_regime = REGIME_TRANSITION;
double ESD_regime_strength = 0.0;
double ESD_volatility_index = 0.0;
double ESD_trend_index = 0.0;
int ESD_regime_duration = 0;
datetime ESD_regime_change_time = 0;

// BSL/SSL Detection Variables
double ESD_bsl_level = EMPTY_VALUE;
double ESD_ssl_level = EMPTY_VALUE;
datetime ESD_last_bsl_ssl_update = 0;

// Filter Status Array
ESD_FilterStatus ESD_filter_status[];

// --- ULTIMATE ML GLOBALS ---
ESD_ML_Brain_State ESD_Brain_Trend;     // Specialist Brain 1
ESD_ML_Brain_State ESD_Brain_Reversal;  // Specialist Brain 2
ESD_SymbolProfile  ESD_CurrentProfile;  // Current Pair Personality

ESD_VirtualTrade   ESD_virtual_trades[]; // Virtual positions array
int                ESD_virtual_ticket_counter = 0;
bool               ESD_ml_data_loaded = false;
