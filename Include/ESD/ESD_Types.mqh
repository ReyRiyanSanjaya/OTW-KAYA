//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                           ESD_Types.mqh                           |
//+------------------------------------------------------------------+
//| MODULE: Type Definitions
//|
//| DESCRIPTION:
//|   Core type definitions, enums, and structures used across
//|   all ESD framework modules.
//|
//| ENUMS:
//|   - ENUM_ESD_SL_TP_METHOD   : SL/TP calculation methods
//|   - ENUM_TRAILING_TYPE      : Trailing stop types
//|   - ENUM_MARKET_REGIME      : Market regime classification
//|
//| STRUCTS:
//|   - ESD_SMStructure         : SMC structure data
//|   - ESD_ML_Features         : ML feature vector
//|   - ESD_ML_Performance      : ML performance metrics
//|   - ESD_TradingData         : Trade statistics
//|   - ESD_FilterStatus        : Filter monitoring data
//|   - Experience              : Q-Learning experience
//|
//| VERSION: 2.1 | LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#ifndef ESD_TYPES_MQH
#define ESD_TYPES_MQH

// ENUMS
enum ENUM_ESD_SL_TP_METHOD
{
    ESD_FIXED_POINTS,      // Fixed Points
    ESD_SWING_POINTS,      // Berdasarkan Swing High/Low Terakhir
    ESD_LIQUIDITY_LEVELS,  // Berdasarkan Level Likuiditas Berlawanan
    ESD_RISK_REWARD_RATIO, // Berdasarkan Rasio Risk:Reward
    ESD_STRUCTURE_BASED    // Based on SMC structures (OB/FVG)
};

//--- Market Regime Classification
enum ENUM_MARKET_REGIME
{
    REGIME_TRENDING_BULLISH,   // Strong bullish trend
    REGIME_TRENDING_BEARISH,   // Strong bearish trend
    REGIME_RANGING_LOW_VOL,    // Ranging with low volatility
    REGIME_RANGING_HIGH_VOL,   // Ranging with high volatility
    REGIME_BREAKOUT_BULLISH,   // Bullish breakout
    REGIME_BREAKOUT_BEARISH,   // Bearish breakout
    REGIME_TRANSITION          // Transitioning between regimes
};

//--- Filter Status for Monitoring Panel
struct ESD_FilterStatus
{
    string   name;             // Filter name
    bool     enabled;          // Is filter enabled
    bool     passed;           // Did filter pass
    double   strength;         // Filter strength (0-1)
    string   details;          // Additional details
    datetime last_update;      // Last update time
};

//--- Trading Data for Dashboard
struct ESD_TradingData
{
    int      total_trades;
    int      winning_trades;
    int      losing_trades;
    double   total_profit;
    double   total_loss;
    double   win_rate;
    double   profit_factor;
    double   expectancy;
    double   largest_win;
    double   largest_loss;
    double   current_streak;
    double   daily_profit;
    double   weekly_profit;
    double   monthly_profit;
};


// STRUCTS
struct ESD_SMStructure
{
    datetime time;
    double price;
    bool is_bullish;
    string type; // "BOS", "CHOCH", "OB", "FVG", "LIQUIDITY", "MSS"
    double top;
    double bottom;
    double quality_score; // 0-1, higher is better
};

struct PerformanceMetrics
{
    double total_profit;
    double total_loss;
    double max_drawdown;
    double sharpe_ratio;
    int consecutive_wins;
    int consecutive_losses;
    double avg_win;
    double avg_loss;
    datetime last_update;
};

// --- ULTIMATE ML V3.0 STRUCTURES ---

enum ENUM_ML_BRAIN_TYPE
{
    ML_BRAIN_TREND,
    ML_BRAIN_REVERSAL,
    ML_BRAIN_HYBRID
};

struct ESD_VirtualTrade
{
    ulong ticket;           // Virtual ticket ID
    datetime open_time;
    int type;              // ORDER_TYPE_BUY or ORDER_TYPE_SELL
    double open_price;
    double sl;
    double tp;
    double lot;
    string comment;
    bool active;
    
    int state_id;
    int action_id;
    ENUM_ML_BRAIN_TYPE brain_used;
    
    // Sniper Reward Tracking
    double max_unrealized_loss; // Max floating drawdown seen
    double max_unrealized_profit;
};

struct ESD_SymbolProfile
{
    string symbol;
    double avg_daily_range;       // Average volatility
    double spike_probability;     // How often price spikes > 2x ATR
    double reversion_speed;       // How fast price returns to mean
    double trend_persistence;     // How likely trend continues
    double session_volatility[3]; // Asia, London, NY avg volatility
    int total_samples;
    datetime last_update;
};

struct ESD_ML_Brain_State
{
    double q_table[729][9]; // Matrix 729 States x 9 Actions
    double e_table[729][9]; // ELIGIBILITY TRACES (Q-Lambda)
    bool initialized;
    double accuracy;
    int trade_count;
};

//--- ML Performance Tracking
struct ESD_ML_Performance
{
    double win_rate;
    double profit_factor;
    double sharpe_ratio;
    double max_drawdown;
    double volatility;
    datetime last_update;
    int trade_count;
    double total_return;
    double total_profit;
    double total_loss;
    double average_win;
    double average_loss;
    int total_trades;
};

//--- ML Feature Vector
struct ESD_ML_Features
{
    double trend_strength;
    double volatility;
    double momentum;
    double volume_ratio;
    double market_regime;
    double time_of_day;
    double heatmap_strength;
    double orderflow_strength;
    double structure_quality;
    double risk_sentiment;
    double rsi;
    double correlation;
    double higher_tf_trend; // Mata Elang Feature (H4/D1 Trend)
};

//--- RL Experience REPLAY
struct Experience
{
    int state;
    int action;
    double reward;
    int next_state;
    bool terminal;
    double priority; // PER: Priority (TD Error magnitude)
};

#endif // ESD_TYPES_MQH
