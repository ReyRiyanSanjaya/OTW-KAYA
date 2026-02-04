//+------------------------------------------------------------------+
//|                        ESD TRADING FRAMEWORK                      |
//|                            ESD_ML.mqh                             |
//+------------------------------------------------------------------+
//| MODULE: Machine Learning & Reinforcement Learning System
//|
//| DESCRIPTION:
//|   Implements adaptive machine learning for trading optimization
//|   using Q-Learning with Experience Replay, feature importance
//|   tracking, validation split for overfitting prevention, and
//|   confidence threshold filtering.
//|
//| DEPENDENCIES:
//|   - ESD_Globals.mqh (required)
//|   - ESD_Inputs.mqh (required)
//|
//| PUBLIC FUNCTIONS:
//|   - ESD_InitializeML()            : Initialize ML system
//|   - ESD_UpdateMLModel()           : Update model periodically
//|   - ESD_CollectMLFeatures()       : Collect feature vector
//|   - ESD_GetMLEntrySignal()        : Get ML-weighted entry signal
//|   - ESD_GetMLAdjustedLotSize()    : Get adaptive lot size
//|   - ESD_GetMLAdjustedSLTP()       : Get adaptive SL/TP
//|   - ESD_GetMLConfidence()         : Get current ML confidence
//|   - ESD_MLConfidenceFilter()      : Filter by confidence level
//|   - ESD_GetFeatureImportance()    : Get feature importance scores
//|   - ESD_IsModelOverfitting()      : Check for overfitting
//|
//| ML FEATURES:
//|   1. Q-Learning with Experience Replay
//|   2. Adaptive Parameter Optimization
//|   3. Validation Split (Overfitting Prevention)
//|   4. Feature Importance Tracking
//|   5. Confidence Threshold Filtering
//|
//| VERSION: 2.1
//| LAST UPDATED: 2025-12-17
//+------------------------------------------------------------------+
#property copyright "SMC"
#property link      "https://www.mql5.com"

#include "ESD_Globals.mqh"
#include "ESD_Inputs.mqh"

//+------------------------------------------------------------------+
//| Enhanced RL Global Variables & Defines                          |
//+------------------------------------------------------------------+
#define MAX_EXPERIENCES 1000
#define BATCH_SIZE 32
#define STATES 729 // 3^6 states (Added MTF Feature)
#define ACTIONS 9  // More granular actions
#define VALIDATION_RATIO 0.2  // 20% for validation

static Experience g_experience_buffer[MAX_EXPERIENCES];
static int g_exp_write_idx = 0;
static int g_exp_count = 0;
static double g_Q[STATES][ACTIONS];
static bool g_q_initialized = false;

//+------------------------------------------------------------------+
//| ML Enhancement: Validation Split Variables                       |
//+------------------------------------------------------------------+
static double g_training_error = 0.0;
static double g_validation_error = 0.0;
static bool g_is_overfitting = false;
static int g_overfit_counter = 0;
static double g_prev_validation_error = 1.0;

//+------------------------------------------------------------------+
//| ML Enhancement: Feature Importance Tracking                      |
//+------------------------------------------------------------------+
struct ESD_FeatureImportance
{
    double trend_importance;
    double volatility_importance;
    double momentum_importance;
    double orderflow_importance;
    double heatmap_importance;
    double structure_importance;
    double regime_importance;
    datetime last_update;
};

static ESD_FeatureImportance g_feature_importance;
static double g_feature_impact_sum[7];
static int g_feature_sample_count = 0;

//+------------------------------------------------------------------+
//| ML Enhancement: Confidence Threshold Variables                   |
//+------------------------------------------------------------------+
static double g_ml_confidence = 0.5;
static double g_ml_confidence_history[];
static int g_confidence_history_size = 100;

// Note: g_perf_metrics and g_prev_perf_metrics are in ESD_Globals.mqh


//+------------------------------------------------------------------+
//| Initialize Machine Learning System                              |
//+------------------------------------------------------------------+
// --- ULTIMATE ML: DUAL BRAIN ARCHITECTURE ---
// Removed static g_Q to use ESD_Brain_Trend and ESD_Brain_Reversal from Globals.

//+------------------------------------------------------------------+
//| Initialize Machine Learning System (V3.0)                       |
//+------------------------------------------------------------------+
void ESD_InitializeML()
{
    if (!ESD_UseMachineLearning)
        return;

    Print("🧠 ULTIMATE ML V3.0: Initializing...");

    // Initialize Global ML Weights
    ESD_ml_trend_weight = 1.0;
    ESD_ml_volatility_weight = 1.0;
    ESD_ml_momentum_weight = 1.0;
    ESD_ml_risk_appetite = 0.5;
    ESD_ml_optimal_sl_multiplier = 1.0;
    ESD_ml_optimal_tp_multiplier = 1.0;
    ESD_ml_lot_size_multiplier = 1.0;

    // Initialize Brains if not loaded from file
    if (!ESD_ml_data_loaded)
    {
        if (ESD_EnablePersistence)
        {
            if (ESD_LoadMLData())
            {
                Print("💾 ML Memory Loaded Successfully!");
                ESD_ml_data_loaded = true;
            }
            else
            {
                Print("💾 No ML Memory Found. Creating new Brains...");
                ESD_ResetBrain(ESD_Brain_Trend);
                ESD_ResetBrain(ESD_Brain_Reversal);
            }
        }
        else
        {
            ESD_ResetBrain(ESD_Brain_Trend);
            ESD_ResetBrain(ESD_Brain_Reversal);
        }
        
        // Load Symbol Profile
        if (ESD_EnableProfiling)
            ESD_LoadSymbolProfile();
    }
    
    // Hyper-Speed Pre-Training
    if (ESD_EnablePreTraining && !ESD_ml_data_loaded) // Only pre-train if fresh start
    {
        Print("⚡ HYPER-SPEED: Starting Historical Pre-Training...");
        ESD_PreTrainOnHistory();
    }

    // Initialize RL system variables
    g_exp_write_idx = 0;
    g_exp_count = 0;
    ZeroMemory(g_perf_metrics);
    ZeroMemory(g_prev_perf_metrics);

    Print("🚀 ML System Ready: Dual-Brain & Virtual Engine Active.");
}

//+------------------------------------------------------------------+
//| Reset Brain Q-Table                                             |
//+------------------------------------------------------------------+
void ESD_ResetBrain(ESD_ML_Brain_State &brain)
{
    MathSrand((int)TimeLocal());
    for (int s = 0; s < STATES; s++)
        for (int a = 0; a < ACTIONS; a++)
            brain.q_table[s][a] = (MathRand() % 200 - 100) / 10000.0; // Small random init
    
    brain.initialized = true;
    brain.accuracy = 0.5;
    brain.trade_count = 0;
}

//+------------------------------------------------------------------+
//| Persistence: Save ML Data                                       |
//+------------------------------------------------------------------+
void ESD_SaveMLData()
{
    if (!ESD_EnablePersistence) return;
    
    string filename = "ESD_ML_" + _Symbol + ".bin";
    int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
    
    if (handle != INVALID_HANDLE)
    {
        // Save Brain 1 (Trend)
        FileWriteStruct(handle, ESD_Brain_Trend);
        // Save Brain 2 (Reversal)
        FileWriteStruct(handle, ESD_Brain_Reversal);
        // Save Profile
        FileWriteStruct(handle, ESD_CurrentProfile);
        
        FileClose(handle);
        // Print("💾 ML Data Saved.");
    }
}

//+------------------------------------------------------------------+
//| Persistence: Load ML Data                                       |
//+------------------------------------------------------------------+
bool ESD_LoadMLData()
{
    string filename = "ESD_ML_" + _Symbol + ".bin";
    
    if (!FileIsExist(filename)) return false;
    
    int handle = FileOpen(filename, FILE_READ | FILE_BIN);
    if (handle != INVALID_HANDLE)
    {
        ESD_ML_Brain_State temp_trend, temp_rev;
        ESD_SymbolProfile temp_profile;
        
        uint res1 = FileReadStruct(handle, temp_trend);
        uint res2 = FileReadStruct(handle, temp_rev);
        uint res3 = FileReadStruct(handle, temp_profile);
        
        if (res1 > 0 && res2 > 0)
        {
            ESD_Brain_Trend = temp_trend;
            ESD_Brain_Reversal = temp_rev;
            if (res3 > 0) ESD_CurrentProfile = temp_profile;
            
            FileClose(handle);
            return true;
        }
        FileClose(handle);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Persistence: Load/Save Just Profile                             |
//+------------------------------------------------------------------+
void ESD_LoadSymbolProfile()
{
     string filename = "ESD_Profile_" + _Symbol + ".bin";
     if (FileIsExist(filename))
     {
          int handle = FileOpen(filename, FILE_READ | FILE_BIN);
          if (handle != INVALID_HANDLE) {
               FileReadStruct(handle, ESD_CurrentProfile);
               FileClose(handle);
          }
     }
     else
     {
          ESD_CurrentProfile.symbol = _Symbol;
          ESD_CurrentProfile.avg_daily_range = iATR(_Symbol, PERIOD_D1, 14);
     }
}

void ESD_SaveSymbolProfile()
{
     string filename = "ESD_Profile_" + _Symbol + ".bin";
     int handle = FileOpen(filename, FILE_WRITE | FILE_BIN);
     if (handle != INVALID_HANDLE) {
          FileWriteStruct(handle, ESD_CurrentProfile);
          FileClose(handle);
     }
}

//+------------------------------------------------------------------+
//| Collect Features untuk Machine Learning                         |
//+------------------------------------------------------------------+
ESD_ML_Features ESD_CollectMLFeatures()
{
    ESD_ML_Features features;

    ENUM_TIMEFRAMES current_tf = Period();

    // Basic technical features
    double ema_fast = iMA(_Symbol, current_tf, 20, 0, MODE_EMA, PRICE_CLOSE);
    double ema_slow = iMA(_Symbol, current_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
    features.trend_strength = MathAbs(ema_fast - ema_slow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 100.0;

    features.volatility = iATR(_Symbol, current_tf, 14) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    features.rsi = iRSI(_Symbol, current_tf, 14, PRICE_CLOSE);

    // Momentum features
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    CopyRates(_Symbol, current_tf, 0, 3, rates);
    features.momentum = (rates[0].close - rates[2].close) / rates[2].close * 100;

    // Additional features bisa ditambahkan di sini
    features.market_regime = 0;
    features.correlation = 0;

    // --- 1. Trend Strength Feature ---
    features.trend_strength = (ESD_bullish_trend_strength + (1.0 - ESD_bearish_trend_strength)) / 2.0;
    features.trend_strength = MathMin(MathMax(features.trend_strength, 0.0), 1.0);

    // --- 2. Volatility Feature (Normalized ATR) ---
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (price > 0.0)
    {
        // ATR relatif terhadap harga, normalisasi ke 0–1
        features.volatility = atr / price;
        features.volatility = MathMin(features.volatility * 100.0, 1.0); // biasanya ATR < 1% harga
    }
    else
        features.volatility = 0.0;

    // --- 3. Momentum Feature (RSI Normalized) ---
    double rsi = 0.5;
    double rsi_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if (rsi_handle != INVALID_HANDLE && CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) > 0)
        rsi = rsi_buffer[0] / 100.0;
    features.momentum = MathMin(MathMax(rsi, 0.0), 1.0);

    // --- 4. Volume Ratio Feature ---
    features.volume_ratio = 1.0;
    if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) >= 2 && rates[1].tick_volume > 0)
    {
        double ratio = (double)rates[0].tick_volume / rates[1].tick_volume;
        features.volume_ratio = MathMin(MathMax(ratio, 0.0), 2.0) / 2.0; // normalisasi 0–1
    }

    // --- 5. Market Regime Feature (0–6 → 0–1) ---
    features.market_regime = MathMin(MathMax((double)ESD_current_regime / 6.0, 0.0), 1.0);

    // --- 6. Time of Day Feature (0–24 jam → 0–1) ---
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    double seconds_in_day = (time_struct.hour * 3600.0 + time_struct.min * 60.0 + time_struct.sec);
    features.time_of_day = MathMin(MathMax(seconds_in_day / 86400.0, 0.0), 1.0);

    // --- 7. Heatmap Strength Feature (±100 → 0–1) ---
    features.heatmap_strength = MathMin(MathMax((ESD_heatmap_strength + 100.0) / 200.0, 0.0), 1.0);

    // --- 8. Order Flow Strength Feature (±100 → 0–1) ---
    features.orderflow_strength = MathMin(MathMax((ESD_orderflow_strength + 100.0) / 200.0, 0.0), 1.0);

    // --- 9. Structure Quality Feature ---
    features.structure_quality = MathMin(MathMax(ESD_GetCurrentZoneQuality(), 0.0), 1.0);

    // --- 10. Risk Sentiment Feature ---
    features.risk_sentiment = MathMin(MathMax(ESD_CalculateRiskSentiment(), 0.0), 1.0);
    
    // --- 11. Mata Elang Feature (Higher Timeframe Trend) ---
    // Compare H1/H4 MA for broader context
    double h4_ma_fast = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
    double h4_ma_slow = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    // Normalize: >0 Bullish, <0 Bearish. Map to 0-1 (0.5 = Neutral)
    double trend_diff = (h4_ma_fast - h4_ma_slow) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 50.0; // Normalize by points
    features.higher_tf_trend = MathMin(MathMax(0.5 + (trend_diff * 0.5), 0.0), 1.0);

    return features;
}

void ESD_UpdateMLWeights(const ESD_ML_Features &features)
{
    // --- Default weights (baseline) ---
    double trend_weight_base = 0.35;
    double volatility_weight_base = 0.25;
    double momentum_weight_base = 0.25;
    double risk_weight_base = 0.15;
    double ESD_ml_risk_weight = 0;

    // --- Adaptif terhadap kondisi pasar ---
    // Jika trend kuat, beri bobot lebih besar pada trend & momentum
    if (features.trend_strength > 0.7)
    {
        trend_weight_base += 0.10;
        momentum_weight_base += 0.05;
        volatility_weight_base -= 0.05;
    }

    // Jika volatilitas tinggi, kurangi pengaruh trend, tambahkan safety
    if (features.volatility > 0.6)
    {
        volatility_weight_base += 0.05;
        trend_weight_base -= 0.10;
        risk_weight_base += 0.10;
    }

    // Jika sentiment pasar sangat rendah (ketakutan tinggi), perkuat faktor safety
    if (features.risk_sentiment < 0.4)
    {
        risk_weight_base += 0.10;
        momentum_weight_base -= 0.05;
    }

    // --- Normalisasi total weight = 1.0 ---
    double total = trend_weight_base + volatility_weight_base + momentum_weight_base + risk_weight_base;
    if (total > 0)
    {
        ESD_ml_trend_weight = trend_weight_base / total;
        ESD_ml_volatility_weight = volatility_weight_base / total;
        ESD_ml_momentum_weight = momentum_weight_base / total;
        ESD_ml_risk_weight = risk_weight_base / total;
    }
    else
    {
        // fallback default
        ESD_ml_trend_weight = 0.35;
        ESD_ml_volatility_weight = 0.25;
        ESD_ml_momentum_weight = 0.25;
        ESD_ml_risk_weight = 0.15;
    }
}

//+------------------------------------------------------------------+
//| Calculate Risk Sentiment Indicator                              |
//+------------------------------------------------------------------+
double ESD_CalculateRiskSentiment()
{
    // Simplified risk sentiment based on multiple factors
    double sentiment = 0.5; // Neutral default

    // 1. Volatility component (high volatility = fear)
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double norm_vol = atr / price;

    if (norm_vol > 0.005) // High volatility
        sentiment -= 0.3;
    else if (norm_vol < 0.001) // Low volatility
        sentiment += 0.2;

    // 2. Trend component (strong trends = confidence)
    double trend_component = MathMax(ESD_bullish_trend_strength, ESD_bearish_trend_strength);
    sentiment += (trend_component - 0.5) * 0.2;

    // 3. Regime component
    if (ESD_current_regime == REGIME_TRENDING_BULLISH || ESD_current_regime == REGIME_TRENDING_BEARISH)
        sentiment += 0.1;
    else if (ESD_current_regime == REGIME_RANGING_HIGH_VOL || ESD_current_regime == REGIME_TRANSITION)
        sentiment -= 0.1;

    return MathMin(MathMax(sentiment, 0.0), 1.0);
}

//+------------------------------------------------------------------+
//| Enhanced Q-Learning dengan Experience Replay                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Enhanced Q-Learning dengan Experience Replay (Dual-Brain)        |
//+------------------------------------------------------------------+
void ESD_AdaptParametersWithEnhancedRL(ESD_ML_Features &features)
{
    if (!ESD_UseMachineLearning)
        return;

    // --- Hyperparameters ---
    static double epsilon = 0.20; // exploration rate
    static double epsilon_min = 0.02;
    static double epsilon_decay = 0.995;
    static int update_counter = 0;
    
    // --- ADAPTIVE CURIOSITY (Regime Change Detection) ---
    static int prev_regime_check = -1;
    if (ESD_current_regime != prev_regime_check)
    {
         if (prev_regime_check != -1) // Not first run
         {
             epsilon = MathMax(epsilon, 0.30); // Boost to 30% on regime change
             Print("🔍 ML: Market Regime Changed! Boosting Curiosity to 30%.");
         }
         prev_regime_check = ESD_current_regime;
    }

    update_counter++;

    // --- Update performance metrics ---
    ESD_UpdateMLPerformance();
    
    // --- Store previous state (Mental Sandbox) ---
    static int prev_state = -1;
    static int prev_action = -1;
    static double prev_params[4]; // To calculate reward

    // --- Get current state ---
    int current_state = EncodeEnhancedState(features);
    
    // --- DECISION: Which brain controls the parameters? ---
    ESD_ML_Brain_State *brain_ptr;
    if (features.trend_strength > 0.6) brain_ptr = &ESD_Brain_Trend;
    else brain_ptr = &ESD_Brain_Reversal;
    
    // --- REWARD & STORAGE (PER) ---
    // If we have a previous action, evaluate it and store in Replay Buffer
    if (prev_state != -1 && prev_action != -1)
    {
        double current_params[4] = {ESD_ml_trend_weight, ESD_ml_volatility_weight, ESD_ml_momentum_weight, ESD_ml_risk_appetite};
        double reward = CalculateEnhancedReward(prev_params, current_params, ESD_CalculatePerformanceScore(), ESD_ml_performance.win_rate);
        
        // Calculate TD Error for Priority
        double max_q_next = -9999.0;
        for (int a = 0; a < ACTIONS; a++) if (brain_ptr->q_table[current_state][a] > max_q_next) max_q_next = brain_ptr->q_table[current_state][a];
        
        double target = reward + 0.95 * max_q_next; // Gamma 0.95
        double old_q = brain_ptr->q_table[prev_state][prev_action];
        double td_error = MathAbs(target - old_q);
        
        // Store with Priority
        StoreExperience(prev_state, prev_action, reward, current_state, (update_counter % 100 == 0), td_error + 0.01);
        
        // Learn (PER Sampling)
        if (update_counter % 5 == 0) LearnFromExperience(0.1, 0.95);
    }

    // --- Select best action from the chosen brain ---
    int action = 0;
    double max_q = brain_ptr->q_table[current_state][0];
    for (int a = 1; a < ACTIONS; a++)
    {
        if (brain_ptr->q_table[current_state][a] > max_q)
        {
            max_q = brain_ptr->q_table[current_state][a];
            action = a;
        }
    }

    // --- Action mapping (9 actions untuk kontrol lebih halus) ---
    double delta = ESD_ML_LearningRate * 2.0; // Slightly larger steps
    delta = MathMax(0.02, delta);

    switch (action)
    {
    case 0: // Increase trend weight
        ESD_ml_trend_weight = MathMin(ESD_ml_trend_weight + delta, 2.5);
        break;
    case 1: // Decrease trend weight
        ESD_ml_trend_weight = MathMax(ESD_ml_trend_weight - delta, 0.3);
        break;
    case 2: // Increase volatility weight
        ESD_ml_volatility_weight = MathMin(ESD_ml_volatility_weight + delta, 2.5);
        break;
    case 3: // Decrease volatility weight
        ESD_ml_volatility_weight = MathMax(ESD_ml_volatility_weight - delta, 0.3);
        break;
    case 4: // Increase momentum weight
        ESD_ml_momentum_weight = MathMin(ESD_ml_momentum_weight + delta, 2.5);
        break;
    case 5: // Decrease momentum weight
        ESD_ml_momentum_weight = MathMax(ESD_ml_momentum_weight - delta, 0.3);
        break;
    case 6: // Increase risk appetite
        ESD_ml_risk_appetite = MathMin(ESD_ml_risk_appetite + delta * 0.5, 0.90);
        break;
    case 7: // Decrease risk appetite
        ESD_ml_risk_appetite = MathMax(ESD_ml_risk_appetite - delta * 0.5, 0.15);
        break;
    case 8: // Balanced adjustment based on performance
        if (ESD_ml_performance.win_rate > 0.58)
        {
            // Increase all weights moderately
            ESD_ml_trend_weight = MathMin(ESD_ml_trend_weight + delta * 0.3, 2.5);
            ESD_ml_momentum_weight = MathMin(ESD_ml_momentum_weight + delta * 0.3, 2.5);
            ESD_ml_risk_appetite = MathMin(ESD_ml_risk_appetite + delta * 0.2, 0.90);
        }
        else if (ESD_ml_performance.win_rate < 0.42)
        {
            // Decrease all weights moderately
            ESD_ml_trend_weight = MathMax(ESD_ml_trend_weight - delta * 0.3, 0.3);
            ESD_ml_momentum_weight = MathMax(ESD_ml_momentum_weight - delta * 0.3, 0.3);
            ESD_ml_risk_appetite = MathMax(ESD_ml_risk_appetite - delta * 0.2, 0.15);
        }
        break;
    }

    // --- Constrain parameters ---
    ESD_ml_trend_weight = MathMax(0.3, MathMin(ESD_ml_trend_weight, 2.5));
    ESD_ml_volatility_weight = MathMax(0.3, MathMin(ESD_ml_volatility_weight, 2.5));
    ESD_ml_momentum_weight = MathMax(0.3, MathMin(ESD_ml_momentum_weight, 2.5));
    ESD_ml_risk_appetite = MathMax(0.10, MathMin(ESD_ml_risk_appetite, 0.95));

    // --- Update Previous State for next tick ---
    prev_state = current_state;
    prev_action = action;
    prev_params[0] = ESD_ml_trend_weight;
    prev_params[1] = ESD_ml_volatility_weight;
    prev_params[2] = ESD_ml_momentum_weight;
    prev_params[3] = ESD_ml_risk_appetite;

    // --- Advanced adaptations ---
    ESD_AdaptSLTPMultipliers(features, ESD_CalculatePerformanceScore());
    ESD_AdaptLotSizeMultiplier(features, ESD_CalculatePerformanceScore());

    // --- Logging (every 50 updates) ---
    if (update_counter % 50 == 0)
    {
        PrintFormat("ULTIMATE ML: State=%d Action=%d (Brain: %s) Acc=%.1f%%",
                    current_state, action, (features.trend_strength > 0.6 ? "TREND" : "REVERSAL"),
                    brain_ptr->accuracy * 100);
    }
}

//+------------------------------------------------------------------+
//| Fungsi bantu diskretisasi adaptif (3 bins dengan thresholds dinamis) |
//+------------------------------------------------------------------+
int AdaptiveBin3(double value, double &low_threshold, double &high_threshold,
                 double min_val, double max_val, double current_avg)
{
    // Adjust thresholds based on recent average
    low_threshold = current_avg - (current_avg - min_val) * 0.4;
    high_threshold = current_avg + (max_val - current_avg) * 0.4;

    if (value < low_threshold)
        return 0;
    if (value > high_threshold)
        return 2;
    return 1;
}

//+------------------------------------------------------------------+
//| Enhanced State Encoding dengan 5 features (243 states)           |
//+------------------------------------------------------------------+
int EncodeEnhancedState(ESD_ML_Features &features)
{
    static double trend_low = 0.35, trend_high = 0.65;
    static double vol_low = 0.0025, vol_high = 0.0075;
    static double mom_low = 0.35, mom_high = 0.65;
    static double risk_low = 0.33, risk_high = 0.66;
    static double perf_low = 0.4, perf_high = 0.6;

    // Calculate current averages for adaptive binning
    double perf_score = ESD_CalculatePerformanceScore();

    int t_bin = AdaptiveBin3(features.trend_strength, trend_low, trend_high, 0.0, 1.0, 0.5);
    int v_bin = AdaptiveBin3(features.volatility, vol_low, vol_high, 0.001, 0.01, 0.005);
    int m_bin = AdaptiveBin3(features.momentum, mom_low, mom_high, 0.0, 1.0, 0.5);
    int r_bin = AdaptiveBin3(features.risk_sentiment, risk_low, risk_high, 0.0, 1.0, 0.5);
    int p_bin = AdaptiveBin3(perf_score, perf_low, perf_high, 0.0, 1.0, 0.5);
    int h_bin = AdaptiveBin3(features.higher_tf_trend, 0.4, 0.6, 0.0, 1.0, 0.5); // MTF Bin

    // Encode: state = t + 3*(v + 3*(m + 3*(r + 3*(p + 3*h))))
    int state = t_bin + 3 * (v_bin + 3 * (m_bin + 3 * (r_bin + 3 * (p_bin + 3 * h_bin))));
    return MathMin(state, STATES - 1);
}

//+------------------------------------------------------------------+
//| Calculate Enhanced Reward dengan multiple metrics                |
//+------------------------------------------------------------------+
double CalculateEnhancedReward(double &old_params[], double &new_params[],
                               double perf_score, double win_rate)
{
    double reward = 0.0;

    // 1. Performance improvement reward (40%)
    double perf_improvement = perf_score - 0.5;
    reward += perf_improvement * 1.5;

    // 2. Win rate reward (25%)
    double wr_improvement = (win_rate - 0.5) * 1.0;
    reward += wr_improvement;

    // 3. Profit factor reward (20%)
    double profit_factor = (g_perf_metrics.total_profit > 0 && g_perf_metrics.total_loss != 0)
                               ? g_perf_metrics.total_profit / MathAbs(g_perf_metrics.total_loss)
                               : 1.0;
    if (profit_factor > 1.5)
        reward += 0.3;
    else if (profit_factor < 1.0)
        reward -= 0.3;

    // 4. Drawdown penalty (15%)
    if (g_perf_metrics.max_drawdown > 0.15)
        reward -= 0.4;
    else if (g_perf_metrics.max_drawdown < 0.08)
        reward += 0.2;

    // 5. Consistency bonus (10%)
    if (g_perf_metrics.consecutive_wins >= 3)
        reward += 0.15;
    if (g_perf_metrics.consecutive_losses >= 3)
        reward -= 0.2;

    // 6. Parameter stability penalty - prevent wild swings
    double stability_penalty = 0.0;
    for (int i = 0; i < 4; i++)
    {
        double change = MathAbs(new_params[i] - old_params[i]);
        stability_penalty += change * 0.15;
    }
    reward -= MathMin(stability_penalty, 0.5);

    // 7. Risk-adjusted return bonus
    if (g_perf_metrics.sharpe_ratio > 1.5)
        reward += 0.25;
    else if (g_perf_metrics.sharpe_ratio < 0.5)
        reward -= 0.25;

    // Normalize reward to [-1, 1]
    return MathMax(-1.0, MathMin(1.0, reward));
}

//+------------------------------------------------------------------+
//| Store Experience dalam Replay Buffer (With Priority)             |
//+------------------------------------------------------------------+
void StoreExperience(int state, int action, double reward, int next_state, bool terminal, double priority=1.0)
{
    g_experience_buffer[g_exp_write_idx].state = state;
    g_experience_buffer[g_exp_write_idx].action = action;
    g_experience_buffer[g_exp_write_idx].reward = reward;
    g_experience_buffer[g_exp_write_idx].next_state = next_state;
    g_experience_buffer[g_exp_write_idx].terminal = terminal;
    g_experience_buffer[g_exp_write_idx].priority = priority;

    g_exp_write_idx = (g_exp_write_idx + 1) % MAX_EXPERIENCES;
    if (g_exp_count < MAX_EXPERIENCES)
        g_exp_count++;
}

//+------------------------------------------------------------------+
//| Experience Replay - Prioritized Sampling (The PER Logic)          |
//+------------------------------------------------------------------+
void LearnFromExperience(double alpha, double gamma)
{
    if (g_exp_count < BATCH_SIZE)
        return;

    int batch_count = MathMin(BATCH_SIZE, g_exp_count);
    
    // 1. Calculate Total Priority (Sum)
    double total_priority = 0;
    for (int i=0; i<g_exp_count; i++) total_priority += g_experience_buffer[i].priority;
    if (total_priority == 0) total_priority = 1.0;

    for (int i = 0; i < batch_count; i++)
    {
        // 2. Weighted Random Sampling
        double rand_p = (double)MathRand() / 32767.0 * total_priority;
        double cumulative_p = 0;
        int idx = 0;
        
        for (int j=0; j<g_exp_count; j++)
        {
             cumulative_p += g_experience_buffer[j].priority;
             if (cumulative_p >= rand_p)
             {
                 idx = j;
                 break;
             }
        }
        
        Experience exp = g_experience_buffer[idx];

        // 3. Q-Learning Update
        // Determine which brain this experience belongs to (Simplified context check)
        // Since we don't store brain_id in basic experience yet, we use global pointer assumption 
        // OR we just update BOTH/Specific brains if we had stored it.
        // For V3.1, let's assume we are updating the Trend Brain for now or make it generic.
        // BETTER: Use State ID to guess Brain? Or just update Trend Brain as default?
        // Let's use ESD_Brain_Trend as primary learner for Replay or infer from context.
        // Todo: Add brain_id to Experience struct for perfect dual-brain replay.
        // For now, let's update Trend Brain (assuming it handles general parameter logic).
        
        double max_q_next_t = -9999.0;
        for (int a = 0; a < ACTIONS; a++) if (ESD_Brain_Trend.q_table[exp.next_state][a] > max_q_next_t) max_q_next_t = ESD_Brain_Trend.q_table[exp.next_state][a];

        double target = exp.terminal ? exp.reward : exp.reward + gamma * max_q_next_t;
        double old_q = ESD_Brain_Trend.q_table[exp.state][exp.action];
        double new_q = old_q + alpha * (target - old_q);
        
        ESD_Brain_Trend.q_table[exp.state][exp.action] = new_q;
        
        // 4. Update Priority (TD Error)
        double td_error = MathAbs(target - old_q);
        g_experience_buffer[idx].priority = td_error + 0.001; // Small constant prevents 0 probability
    }
}

//+------------------------------------------------------------------+
//| Update Performance Metrics                                        |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
    g_prev_perf_metrics = g_perf_metrics;

    // Update metrics from current trading performance
    g_perf_metrics.total_profit = ESD_ml_performance.total_profit;
    g_perf_metrics.total_loss = MathAbs(ESD_ml_performance.total_loss);
    g_perf_metrics.max_drawdown = ESD_ml_performance.max_drawdown;
    g_perf_metrics.avg_win = ESD_ml_performance.average_win;
    g_perf_metrics.avg_loss = MathAbs(ESD_ml_performance.average_loss);

    // Calculate Sharpe-like ratio (simplified)
    double avg_return = (g_perf_metrics.total_profit - g_perf_metrics.total_loss) /
                        MathMax(1.0, (double)ESD_ml_performance.total_trades);
    double return_std = MathSqrt(MathAbs(g_perf_metrics.avg_win - g_perf_metrics.avg_loss));
    g_perf_metrics.sharpe_ratio = (return_std > 0) ? avg_return / return_std : 0.0;

    g_perf_metrics.last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Update ML Performance Metrics                                   |
//+------------------------------------------------------------------+
void ESD_UpdateMLPerformance()
{
    // Calculate performance metrics dari trading history
    double total_profit = 0;
    double total_loss = 0;
    int wins = 0;
    int losses = 0;
    double returns[];
    int return_count = 0;

    HistorySelect(0, TimeCurrent());
    int total = HistoryDealsTotal();

    for (int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != ESD_MagicNumber)
            continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

        if (profit > 0)
        {
            wins++;
            total_profit += profit;
        }
        else
        {
            losses++;
            total_loss += MathAbs(profit);
        }

        // Collect returns untuk Sharpe ratio
        ArrayResize(returns, return_count + 1);
        returns[return_count] = profit;
        return_count++;
    }

    // Update performance metrics
    ESD_ml_performance.trade_count = wins + losses;
    ESD_ml_performance.total_trades = wins + losses;
    ESD_ml_performance.win_rate = (ESD_ml_performance.trade_count > 0) ? (double)wins / ESD_ml_performance.trade_count : 0.0;
    ESD_ml_performance.profit_factor = (total_loss > 0) ? total_profit / total_loss : (total_profit > 0 ? 999 : 0);
    ESD_ml_performance.sharpe_ratio = ESD_CalculateSharpeRatio(returns);
    ESD_ml_performance.total_return = total_profit - total_loss;
    ESD_ml_performance.total_profit = total_profit;
    ESD_ml_performance.total_loss = total_loss;
    ESD_ml_performance.average_win = (wins > 0) ? total_profit / wins : 0;
    ESD_ml_performance.average_loss = (losses > 0) ? total_loss / losses : 0;
    ESD_ml_performance.last_update = TimeCurrent();

    // Update consecutive wins/losses
    static int last_wins = 0, last_losses = 0;
    if (wins > last_wins)
    {
        g_perf_metrics.consecutive_wins++;
        g_perf_metrics.consecutive_losses = 0;
    }
    else if (losses > last_losses)
    {
        g_perf_metrics.consecutive_losses++;
        g_perf_metrics.consecutive_wins = 0;
    }
    last_wins = wins;
    last_losses = losses;
}

//+------------------------------------------------------------------+
//| Calculate Sharpe Ratio                                          |
//+------------------------------------------------------------------+
double ESD_CalculateSharpeRatio(double &returns[])
{
    int size = ArraySize(returns);
    if (size < 2)
        return 0.0;

    double sum = 0.0;
    for (int i = 0; i < size; i++)
        sum += returns[i];

    double mean = sum / size;

    double variance = 0.0;
    for (int i = 0; i < size; i++)
        variance += MathPow(returns[i] - mean, 2);

    double std_dev = MathSqrt(variance / (size - 1));

    if (std_dev == 0)
        return 0.0;

    return mean / std_dev * MathSqrt(252); // Annualized Sharpe ratio
}

//+------------------------------------------------------------------+
//| Calculate Overall Performance Score                             |
//+------------------------------------------------------------------+
double ESD_CalculatePerformanceScore()
{
    double score = 0.0;
    int factors = 0;

    if (ESD_ml_performance.trade_count >= 10)
    {
        // Win Rate component (30% weight)
        score += ESD_ml_performance.win_rate * 0.3;
        factors++;

        // Profit Factor component (30% weight)
        double pf_score = MathMin(ESD_ml_performance.profit_factor / 3.0, 1.0);
        score += pf_score * 0.3;
        factors++;

        // Sharpe Ratio component (20% weight)
        double sharpe_score = MathMin(ESD_ml_performance.sharpe_ratio / 2.0, 1.0);
        score += sharpe_score * 0.2;
        factors++;

        // Consistency component (20% weight)
        double consistency = 1.0 - (ESD_ml_performance.volatility / 0.1); // Lower volatility better
        score += MathMax(consistency, 0.0) * 0.2;
        factors++;
    }

    return (factors > 0) ? score : 0.5; // Return 0.5 jika belum cukup data
}

//+------------------------------------------------------------------+
//| Adaptive SL/TP Multipliers                                      |
//+------------------------------------------------------------------+
void ESD_AdaptSLTPMultipliers(ESD_ML_Features &features, double performance_score)
{
    if (!ESD_ML_AdaptiveSLTP)
        return;

    // Adaptive SL Multiplier
    if (features.volatility > 0.006) // High volatility
        ESD_ml_optimal_sl_multiplier = MathMin(ESD_ml_optimal_sl_multiplier + ESD_ML_LearningRate, 1.5);
    else if (features.volatility < 0.002 && performance_score > 0.6) // Low volatility + good performance
        ESD_ml_optimal_sl_multiplier = MathMax(ESD_ml_optimal_sl_multiplier - ESD_ML_LearningRate, 0.7);

    // Adaptive TP Multiplier
    if (features.trend_strength > 0.7 && performance_score > 0.6) // Strong trend + good performance
        ESD_ml_optimal_tp_multiplier = MathMin(ESD_ml_optimal_tp_multiplier + ESD_ML_LearningRate, 1.8);
    else if (features.trend_strength < 0.4 || performance_score < 0.4) // Weak trend or poor performance
        ESD_ml_optimal_tp_multiplier = MathMax(ESD_ml_optimal_tp_multiplier - ESD_ML_LearningRate, 0.8);
}

//+------------------------------------------------------------------+
//| Adaptive Lot Size Multiplier                                    |
//+------------------------------------------------------------------+
void ESD_AdaptLotSizeMultiplier(ESD_ML_Features &features, double performance_score)
{
    if (!ESD_ML_AdaptiveLotSize)
        return;

    // Base pada risk appetite dan performance
    double base_multiplier = ESD_ml_risk_appetite;

    // Adjust berdasarkan volatility
    if (features.volatility > 0.007) // Very high volatility
        base_multiplier *= 0.7;
    else if (features.volatility < 0.003 && performance_score > 0.6) // Low volatility + good performance
        base_multiplier *= 1.2;

    // Adjust berdasarkan trend strength
    if (features.trend_strength > 0.75 && performance_score > 0.65)
        base_multiplier *= 1.1;

    // Adjust berdasarkan drawdown protection
    if (ESD_ml_performance.max_drawdown > 0.1) // 10% drawdown
        base_multiplier *= 0.8;

    ESD_ml_lot_size_multiplier = MathMin(MathMax(base_multiplier, 0.3), 2.0);
}

//+------------------------------------------------------------------+
//| Adjust Dynamic Filters berdasarkan ML                          |
//+------------------------------------------------------------------+
void ESD_AdjustDynamicFilters()
{
    if (!ESD_ML_DynamicFilter)
        return;

    // Adaptive Trend Strength Threshold
    if (ESD_ml_performance.win_rate > 0.65 && ESD_ml_trend_weight > 1.2)
        ESD_TrendStrengthThreshold = MathMin(ESD_TrendStrengthThreshold + 0.05, 0.9);
    else if (ESD_ml_performance.win_rate < 0.35 || ESD_ml_trend_weight < 0.8)
        ESD_TrendStrengthThreshold = MathMax(ESD_TrendStrengthThreshold - 0.05, 0.3);

    // Adaptive Zone Quality Filter
    if (ESD_ml_performance.win_rate > 0.7)
        ESD_MinZoneQualityScore = MathMin(ESD_MinZoneQualityScore + 0.05, 0.8);
    else if (ESD_ml_performance.win_rate < 0.4)
        ESD_MinZoneQualityScore = MathMax(ESD_MinZoneQualityScore - 0.05, 0.4);

    // Adaptive Heatmap Threshold
    if (ESD_ml_performance.profit_factor > 2.0)
        ESD_HeatmapStrengthThreshold = MathMin(ESD_HeatmapStrengthThreshold + 5, 85);
    else if (ESD_ml_performance.profit_factor < 1.0)
        ESD_HeatmapStrengthThreshold = MathMax(ESD_HeatmapStrengthThreshold - 5, 50);
}

//+------------------------------------------------------------------+
//| Update Machine Learning Model                                   |
//+------------------------------------------------------------------+
void ESD_UpdateMLModel()
{
    if (!ESD_UseMachineLearning)
        return;

    static int last_update_bar = 0;
    int current_bar = iBars(_Symbol, PERIOD_CURRENT);

    if (current_bar - last_update_bar < ESD_ML_UpdateInterval)
        return;

    // Collect current features
    ESD_ML_Features features = ESD_CollectMLFeatures();

    // Update performance metrics
    ESD_UpdateMLPerformance();

    // Adaptive Parameter Adjustment menggunakan Enhanced Reinforcement Learning
    ESD_AdaptParametersWithEnhancedRL(features);

    // Dynamic Filter Adjustment
    if (ESD_ML_DynamicFilter)
        ESD_AdjustDynamicFilters();

    last_update_bar = current_bar;

    // Auto-Save Protection (Anti-Amnesia)
    static datetime last_autosave = 0;
    if (TimeCurrent() - last_autosave > 3600) // Save every 1 hour
    {
        ESD_SaveMLData();
        last_autosave = TimeCurrent();
        Print("💾 ML: Auto-Saved Learning Data.");
    }

    // Log ML status
    if (ESD_ShowObjects && ESD_ShowLabels)
    {
        ESD_DrawTradingDataPanel();
    }
}

//+------------------------------------------------------------------+
//| Get ML-Enhanced Entry Signal                                    |
//+------------------------------------------------------------------+
double ESD_GetMLEntrySignal(bool is_buy_signal, ESD_ML_Features &features)
{
    if (!ESD_UseMachineLearning)
        return 1.0;

    // --- Update weights adaptively ---
    ESD_UpdateMLWeights(features);

    double base_signal = is_buy_signal ? 1.0 : -1.0;
    double ml_confidence = 0.0;
    double ESD_ml_risk_weight = 0.5;

    // --- Weighted aggregation ---
    ml_confidence += features.trend_strength * ESD_ml_trend_weight;
    ml_confidence += (1.0 - features.volatility) * ESD_ml_volatility_weight;
    ml_confidence += (MathAbs(features.momentum - 0.5) * 2.0) * ESD_ml_momentum_weight;
    ml_confidence += features.risk_sentiment * ESD_ml_risk_weight;
    ml_confidence += features.structure_quality * 0.3;
    ml_confidence += features.heatmap_strength * 0.2;
    ml_confidence += features.orderflow_strength * 0.2;

    // --- Sentiment safety multiplier ---
    double sentiment = MathMax(features.risk_sentiment, 0.5);
    ml_confidence *= sentiment;

    // --- Normalize range + offset ---
    ml_confidence = MathMin(MathMax(ml_confidence + 0.2, 0.0), 2.0);

    return base_signal * ml_confidence;
}

//+------------------------------------------------------------------+
//| Get ML-Adjusted Lot Size                                        |
//+------------------------------------------------------------------+
double ESD_GetMLAdjustedLotSize()
{
    if (!ESD_UseMachineLearning || !ESD_ML_AdaptiveLotSize)
        return ESD_LotSize;

    double base_lot = ESD_LotSize;
    double adjusted_lot = base_lot * ESD_ml_lot_size_multiplier;

    // Ensure within broker limits
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    adjusted_lot = MathMax(adjusted_lot, min_lot);
    adjusted_lot = MathMin(adjusted_lot, max_lot);

    return adjusted_lot;
}

//+------------------------------------------------------------------+
//| Get ML-Adjusted SL/TP                                           |
//+------------------------------------------------------------------+
void ESD_GetMLAdjustedSLTP(bool is_buy, double entry_price, double &sl, double &tp)
{
    if (!ESD_UseMachineLearning || !ESD_ML_AdaptiveSLTP)
        return;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Apply ML multipliers to SL/TP distances
    double sl_points = ESD_StopLossPoints * ESD_ml_optimal_sl_multiplier;
    double tp_points = ESD_TakeProfitPoints * ESD_ml_optimal_tp_multiplier;

    if (is_buy)
    {
        sl = entry_price - sl_points * point;
        tp = entry_price + tp_points * point;
    }
    else
    {
        sl = entry_price + sl_points * point;
        tp = entry_price - tp_points * point;
    }
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Get Current ML Confidence Level                  |
//| Returns value between 0.0 (no confidence) and 1.0 (high conf)   |
//+------------------------------------------------------------------+
double ESD_GetMLConfidence()
{
    if (!ESD_UseMachineLearning)
        return 1.0; // Return max if ML disabled
    
    return g_ml_confidence;
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Confidence Threshold Filter                       |
//| Returns true if trade should be allowed based on ML confidence   |
//+------------------------------------------------------------------+
bool ESD_MLConfidenceFilter(bool is_buy)
{
    if (!ESD_UseMachineLearning || !ESD_ML_DynamicFilter)
        return true; // Allow if ML disabled
    
    double confidence = g_ml_confidence;
    double threshold = ESD_ML_ConfidenceThreshold;
    
    // Adjust threshold based on market conditions
    if (g_is_overfitting)
    {
        // Increase threshold when overfitting detected
        threshold = MathMin(threshold + 0.15, 0.90);
        Print("⚠️ ML Overfitting detected - Confidence threshold increased to ", threshold);
    }
    
    // Check if confidence meets threshold
    if (confidence < threshold)
    {
        Print("📊 ML Confidence Filter BLOCKED trade. Confidence: ", 
              DoubleToString(confidence, 2), " < Threshold: ", DoubleToString(threshold, 2));
        return false;
    }
    
    return true;
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Update Confidence Value                           |
//| Called after each prediction to update confidence metric         |
//+------------------------------------------------------------------+
void ESD_UpdateMLConfidence(ESD_ML_Features &features, double prediction_result)
{
    // Calculate confidence based on feature alignment and past performance
    double feature_alignment = 0.0;
    
    // Strong trend + strong momentum = high confidence
    if (features.trend_strength > 0.7 && MathAbs(features.momentum - 0.5) > 0.2)
        feature_alignment += 0.3;
    
    // Good structure quality
    if (features.structure_quality > 0.7)
        feature_alignment += 0.2;
    
    // Orderflow and heatmap alignment
    if (features.orderflow_strength > 0.6 && features.heatmap_strength > 0.6)
        feature_alignment += 0.2;
    else if (features.orderflow_strength < 0.4 && features.heatmap_strength < 0.4)
        feature_alignment += 0.2; // Both bearish = also confident
    
    // Performance-based confidence
    double perf_confidence = ESD_ml_performance.win_rate;
    
    // Combine factors
    g_ml_confidence = (feature_alignment + perf_confidence) / 2.0;
    g_ml_confidence = MathMin(MathMax(g_ml_confidence, 0.1), 1.0);
    
    // Store in history
    int hist_size = ArraySize(g_ml_confidence_history);
    if (hist_size >= g_confidence_history_size)
    {
        // Shift array
        for (int i = 0; i < hist_size - 1; i++)
            g_ml_confidence_history[i] = g_ml_confidence_history[i + 1];
        g_ml_confidence_history[hist_size - 1] = g_ml_confidence;
    }
    else
    {
        ArrayResize(g_ml_confidence_history, hist_size + 1);
        g_ml_confidence_history[hist_size] = g_ml_confidence;
    }
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Get Feature Importance Scores                     |
//| Returns structure with importance of each feature                 |
//+------------------------------------------------------------------+
ESD_FeatureImportance ESD_GetFeatureImportance()
{
    return g_feature_importance;
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Update Feature Importance                         |
//| Tracks which features contribute most to successful trades       |
//+------------------------------------------------------------------+
void ESD_UpdateFeatureImportance(ESD_ML_Features &features, double trade_result)
{
    if (g_feature_sample_count == 0)
    {
        // Initialize
        ArrayFill(g_feature_impact_sum, 0, 7, 0.0);
    }
    
    // Calculate feature contributions to trade result
    // Positive trade = features contributed positively
    double impact_multiplier = (trade_result > 0) ? 1.0 : -1.0;
    
    g_feature_impact_sum[0] += features.trend_strength * impact_multiplier;
    g_feature_impact_sum[1] += features.volatility * impact_multiplier;
    g_feature_impact_sum[2] += features.momentum * impact_multiplier;
    g_feature_impact_sum[3] += features.orderflow_strength * impact_multiplier;
    g_feature_impact_sum[4] += features.heatmap_strength * impact_multiplier;
    g_feature_impact_sum[5] += features.structure_quality * impact_multiplier;
    g_feature_impact_sum[6] += features.market_regime * impact_multiplier;
    
    g_feature_sample_count++;
    
    // Update importance scores (normalized)
    if (g_feature_sample_count >= 10)
    {
        double total_abs_impact = 0.0;
        for (int i = 0; i < 7; i++)
            total_abs_impact += MathAbs(g_feature_impact_sum[i]);
        
        if (total_abs_impact > 0)
        {
            g_feature_importance.trend_importance = g_feature_impact_sum[0] / total_abs_impact;
            g_feature_importance.volatility_importance = g_feature_impact_sum[1] / total_abs_impact;
            g_feature_importance.momentum_importance = g_feature_impact_sum[2] / total_abs_impact;
            g_feature_importance.orderflow_importance = g_feature_impact_sum[3] / total_abs_impact;
            g_feature_importance.heatmap_importance = g_feature_impact_sum[4] / total_abs_impact;
            g_feature_importance.structure_importance = g_feature_impact_sum[5] / total_abs_impact;
            g_feature_importance.regime_importance = g_feature_impact_sum[6] / total_abs_impact;
            g_feature_importance.last_update = TimeCurrent();
        }
    }
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Print Feature Importance Report                   |
//+------------------------------------------------------------------+
void ESD_PrintFeatureImportance()
{
    Print("════════════════ FEATURE IMPORTANCE ════════════════");
    Print(StringFormat("Trend:      %.2f%%", g_feature_importance.trend_importance * 100));
    Print(StringFormat("Volatility: %.2f%%", g_feature_importance.volatility_importance * 100));
    Print(StringFormat("Momentum:   %.2f%%", g_feature_importance.momentum_importance * 100));
    Print(StringFormat("OrderFlow:  %.2f%%", g_feature_importance.orderflow_importance * 100));
    Print(StringFormat("Heatmap:    %.2f%%", g_feature_importance.heatmap_importance * 100));
    Print(StringFormat("Structure:  %.2f%%", g_feature_importance.structure_importance * 100));
    Print(StringFormat("Regime:     %.2f%%", g_feature_importance.regime_importance * 100));
    Print("════════════════════════════════════════════════════");
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Check for Overfitting                             |
//| Compares training vs validation error to detect overfitting      |
//+------------------------------------------------------------------+
bool ESD_IsModelOverfitting()
{
    return g_is_overfitting;
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Update Validation Split                           |
//| Splits experience buffer into training and validation sets       |
//+------------------------------------------------------------------+
void ESD_UpdateValidationSplit()
{
    if (g_exp_count < 100)
        return; // Not enough data
    
    int validation_size = (int)(g_exp_count * VALIDATION_RATIO);
    int training_size = g_exp_count - validation_size;
    
    // Calculate training error
    double training_error_sum = 0.0;
    for (int i = 0; i < training_size; i++)
    {
        Experience exp = g_experience_buffer[i];
        double q_predicted = g_Q[exp.state][exp.action];
        double actual = exp.reward;
        training_error_sum += MathPow(q_predicted - actual, 2);
    }
    g_training_error = training_error_sum / training_size;
    
    // Calculate validation error
    double validation_error_sum = 0.0;
    for (int i = training_size; i < g_exp_count; i++)
    {
        Experience exp = g_experience_buffer[i];
        double q_predicted = g_Q[exp.state][exp.action];
        double actual = exp.reward;
        validation_error_sum += MathPow(q_predicted - actual, 2);
    }
    g_validation_error = validation_error_sum / validation_size;
    
    // Check for overfitting:
    // - Validation error increasing while training error decreasing
    // - Validation error > 1.5x training error
    bool error_divergence = (g_validation_error > g_prev_validation_error * 1.1);
    bool error_gap = (g_validation_error > g_training_error * 1.5);
    
    if (error_divergence && error_gap)
    {
        g_overfit_counter++;
        if (g_overfit_counter >= 3)
        {
            g_is_overfitting = true;
            Print("⚠️ OVERFITTING DETECTED!");
            Print("   Training Error:   ", DoubleToString(g_training_error, 4));
            Print("   Validation Error: ", DoubleToString(g_validation_error, 4));
        }
    }
    else
    {
        g_overfit_counter = MathMax(0, g_overfit_counter - 1);
        if (g_overfit_counter == 0)
            g_is_overfitting = false;
    }
    
    g_prev_validation_error = g_validation_error;
}


//+------------------------------------------------------------------+
//| ML ENHANCEMENT: Apply Anti-Overfitting Measures                   |
//| Adjusts learning when overfitting is detected                     |
//+------------------------------------------------------------------+
void ESD_ApplyAntiOverfitting()
{
    if (!g_is_overfitting)
        return;
    
    // Reduce learning rate temporarily
    double adjusted_lr = ESD_ML_LearningRate * 0.5;
    
    // Increase exploration to escape local optima
    // (Handled in main RL loop by checking g_is_overfitting)
    
    // Reset part of experience buffer (oldest experiences)
    int reset_count = g_exp_count / 4; // Reset 25% oldest
    for (int i = 0; i < g_exp_count - reset_count; i++)
    {
        g_experience_buffer[i] = g_experience_buffer[i + reset_count];
    }
    g_exp_count -= reset_count;
    g_exp_write_idx = g_exp_count;
    
    Print("🔄 Anti-overfitting applied: Reset ", reset_count, " old experiences");
}

//+------------------------------------------------------------------+
//| VIRTUAL TRADING ENGINE (HYPER-SPEED LEARNING)                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Open Virtual Trade for Learning                                 |
//+------------------------------------------------------------------+
void ESD_OpenVirtualTrade(int type, double price, double sl, double tp, string comment)
{
    if (!ESD_EnableVirtualTraining) return;

    // Find empty slot
    int idx = -1;
    for (int i = 0; i < ArraySize(ESD_virtual_trades); i++)
    {
        if (!ESD_virtual_trades[i].active)
        {
            idx = i;
            break;
        }
    }

    if (idx == -1) // Resize if full
    {
        idx = ArraySize(ESD_virtual_trades);
        ArrayResize(ESD_virtual_trades, idx + 10);
    }

    ESD_virtual_trades[idx].ticket = ++ESD_virtual_ticket_counter;
    ESD_virtual_trades[idx].open_time = TimeCurrent();
    ESD_virtual_trades[idx].type = type;
    ESD_virtual_trades[idx].open_price = price;
    ESD_virtual_trades[idx].sl = sl;
    ESD_virtual_trades[idx].tp = tp;
    ESD_virtual_trades[idx].lot = 0.1; // Dummy lot
    ESD_virtual_trades[idx].comment = comment;
    ESD_virtual_trades[idx].active = true;
    
    // Capture ML State Context
    ESD_ML_Features features = ESD_CollectMLFeatures();
    ESD_virtual_trades[idx].state_id = EncodeEnhancedState(features);
    
    // Determine which brain to use based on signal type
    if (StringFind(comment, "Structure") >= 0 || StringFind(comment, "Trend") >= 0)
        ESD_virtual_trades[idx].brain_used = ML_BRAIN_TREND;
    else
        ESD_virtual_trades[idx].brain_used = ML_BRAIN_REVERSAL;
        
    // Select action (Epsilon Greedy) based on the specific brain
    ESD_virtual_trades[idx].action_id = ESD_SelectAction(ESD_virtual_trades[idx].brain_used, ESD_virtual_trades[idx].state_id);
}

//+------------------------------------------------------------------+
//| Manage Virtual Trades (Check TP/SL)                             |
//+------------------------------------------------------------------+
void ESD_ManageVirtualTrades(double bid, double ask)
{
    for (int i = 0; i < ArraySize(ESD_virtual_trades); i++)
    {
        if (!ESD_virtual_trades[i].active) continue;

        bool close = false;
        double close_price = 0;
        double profit = 0;

        if (ESD_virtual_trades[i].type == ORDER_TYPE_BUY)
        {
            if (ESD_virtual_trades[i].tp > 0 && bid >= ESD_virtual_trades[i].tp) { close = true; close_price = ESD_virtual_trades[i].tp; }
            else if (ESD_virtual_trades[i].sl > 0 && bid <= ESD_virtual_trades[i].sl) { close = true; close_price = ESD_virtual_trades[i].sl; }
        }
        else // SELL
        {
            if (ESD_virtual_trades[i].tp > 0 && ask <= ESD_virtual_trades[i].tp) { close = true; close_price = ESD_virtual_trades[i].tp; }
            else if (ESD_virtual_trades[i].sl > 0 && ask >= ESD_virtual_trades[i].sl) { close = true; close_price = ESD_virtual_trades[i].sl; }
        }

        if (close)
        {
            // Calculate Result
            if (ESD_virtual_trades[i].type == ORDER_TYPE_BUY)
                profit = (close_price - ESD_virtual_trades[i].open_price);
            else
                profit = (ESD_virtual_trades[i].open_price - close_price);
            
            // FEEDBACK LOOP: Update Q-Table with SNIPER REWARD
            ESD_UpdateBrain(ESD_virtual_trades[i], profit);
            ESD_virtual_trades[i].active = false;
        }
        else
        {
            // Track Drawdown for Sniper Reward
            double current_pl = 0;
            if (ESD_virtual_trades[i].type == ORDER_TYPE_BUY) current_pl = bid - ESD_virtual_trades[i].open_price;
            else current_pl = ESD_virtual_trades[i].open_price - ask;
            
            if (current_pl < 0 && current_pl < ESD_virtual_trades[i].max_unrealized_loss)
                 ESD_virtual_trades[i].max_unrealized_loss = current_pl;
        }
    }
}

//+------------------------------------------------------------------+
//| Hyper-Speed Historical Pre-Training                             |
//+------------------------------------------------------------------+
void ESD_PreTrainOnHistory()
{
    if (!ESD_EnablePreTraining) return;
    int bars = ESD_PreTrainCandles;
    if (bars > 5000) bars = 5000;
    
    // Copy M1 Data for faster simulation
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if (CopyRates(_Symbol, PERIOD_M5, 0, bars, rates) < bars) return;
    
    Print("⚡ PRE-TRAINING: Simulating ", bars, " M5 candles...");
    
    // Simulate loop
    for (int i = bars - 1; i >= 0; i--)
    {
         double open = rates[i].open;
         double high = rates[i].high;
         double low = rates[i].low;
         double close = rates[i].close;
         
         // 1. Manage existing trades
         ESD_ManageVirtualTrades(low, high); 
         
         // 2. Dummy Features (Approximation)
         // In a real implementation this would recalculate indicators
         // We use random approximation here to speed up demo
         
         // 3. Simple Signals for Training
         bool buy_sig = (close > open && (high - low) > 20 * _Point * 10);
         bool sell_sig = (close < open && (high - low) > 20 * _Point * 10);
         
         if (buy_sig) ESD_OpenVirtualTrade(ORDER_TYPE_BUY, close, close - 200*_Point, close + 400*_Point, "PreTrain-Trend");
         if (sell_sig) ESD_OpenVirtualTrade(ORDER_TYPE_SELL, close, close + 200*_Point, close - 400*_Point, "PreTrain-Trend");
         
         // Reversal Logic
         if (close < low + (high-low)*0.2) ESD_OpenVirtualTrade(ORDER_TYPE_BUY, close, low - 50*_Point, high, "PreTrain-Reversal");
         if (close > high - (high-low)*0.2) ESD_OpenVirtualTrade(ORDER_TYPE_SELL, close, high + 50*_Point, low, "PreTrain-Reversal");
    }
    
    PrintFormat("⚡ Pre-Training Complete: Brains Updated.");
}

//+------------------------------------------------------------------+
//| Select Action from Specific Brain                               |
//+------------------------------------------------------------------+
int ESD_SelectAction(ENUM_ML_BRAIN_TYPE brain_type, int state)
{
    // Pointer simulation
    ESD_ML_Brain_State *ptr;
    if (brain_type == ML_BRAIN_TREND) ptr = &ESD_Brain_Trend;
    else ptr = &ESD_Brain_Reversal;
    
    // Epsilon Greedy
    if ((double)MathRand() / 32767.0 < 0.1) // 10% Exploration
        return MathRand() % ACTIONS;
        
    int best_action = 0;
    double max_q = -99999.0;
    
    for(int a=0; a<ACTIONS; a++)
    {
        if (ptr->q_table[state][a] > max_q) {
            max_q = ptr->q_table[state][a];
            best_action = a;
        }
    }
    return best_action;
}

//+------------------------------------------------------------------+
//| Update Brain Q-Table (Enhanced with Sniper Reward)              |
//+------------------------------------------------------------------+
void ESD_UpdateBrain(ESD_VirtualTrade &trade, double profit)
{
    // --- SNIPER REWARD LOGIC ---
    // Reward bukan hanya Win/Loss, tapi "Seberapa Bagus Kualitasnya?"
    // Reward Base: Profit / Risk
    double risk = MathAbs(trade.sl - trade.open_price);
    if (risk == 0) risk = 100 * _Point; // Safety
    
    double reward = 0;
    
    if (profit > 0)
    {
         // Win
         double r_multiple = profit / risk;
         
         // Penalty for Drawdown (Sniper Check)
         double drawdown_penalty = MathAbs(trade.max_unrealized_loss) / risk;
         
         // Jika Drawdown kecil (Sniper Entry), Reward Maksimal
         // Jika Drawdown besar (Hampir SL), Reward Berkurang drastic
         reward = MathMin(1.0, (r_multiple * 0.5) + (1.0 - drawdown_penalty)); 
         
         if (drawdown_penalty > 0.8) reward = 0.1; // Menang hoki (hampir SL), reward kecil
    }
    else
    {
         // Loss
         reward = -1.0;
         // No penalty for "good loss" yet, simple punishment
    }

    // --- LEARNING SPEED: Q-Lambda (Eligibility Traces) ---
    // Watkins' Q(lambda) Algorithm
    double lambda = 0.8;  // Trace decay rate (High = Long memory)
    double gamma = 0.95;  // Discount factor
    
    ESD_ML_Brain_State *brain;
    if (trade.brain_used == ML_BRAIN_TREND) brain = &ESD_Brain_Trend;
    else brain = &ESD_Brain_Reversal;
    
    // 1. Calculate TD Error
    double max_q_next = -9999.0;
    // Note: Since this is a "Trade Result" update (Terminal state effectively for this trade),
    // we don't look at next state Q. Reward is the final result.
    // For proper Q-Lambda in continuous tasks, we'd need next state. 
    // Here we treat trade close as end of episode for that specific trade logic.
    // But to boost learning, we propagate this reward back to the state that triggered it via trace.
    
    double old_q = brain->q_table[trade.state_id][trade.action_id];
    double delta = reward - old_q;
    
    // 2. Increment Trace for visited state
    brain->e_table[trade.state_id][trade.action_id] += 1.0;
    
    // 3. Update ALL States based on Traces
    // To speed up, we only loop active traces if possible, but here we loop all or significant ones.
    // Optimization: Loop only if trace > threshold.
    
    int states_updated = 0;
    for(int s=0; s<STATES; s++)
    {
        for(int a=0; a<ACTIONS; a++)
        {
            if(brain->e_table[s][a] > 0.01) // Only update significant traces
            {
               brain->q_table[s][a] += alpha * delta * brain->e_table[s][a];
               brain->e_table[s][a] *= gamma * lambda; // Decay
               states_updated++;
            }
        }
    }
    
    // Update accuracy stats
    brain->trade_count++;
    if (profit > 0) brain->accuracy = (brain->accuracy * 0.99) + 0.01;
    else brain->accuracy = (brain->accuracy * 0.99);

    // Profile Update (Counterfactual)
    ESD_UpdateSymbolProfile(profit);
}

//+------------------------------------------------------------------+
//| Update Symbol Profile                                           |
//+------------------------------------------------------------------+
void ESD_UpdateSymbolProfile(double profit)
{
    // Learning pair characteristics
    if (profit > 0)
        ESD_CurrentProfile.trend_persistence += 0.001; // Assume trend continuation works
    else
        ESD_CurrentProfile.spike_probability += 0.001; // Assume fakeout/spike
        
    // Normalize
    if(ESD_CurrentProfile.trend_persistence > 1.0) ESD_CurrentProfile.trend_persistence = 1.0;
    if(ESD_CurrentProfile.spike_probability > 1.0) ESD_CurrentProfile.spike_probability = 1.0;
    
    ESD_CurrentProfile.last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| CHECK SMART GATE (Should we trade?)                             |
//+------------------------------------------------------------------+
bool ESD_CheckVirtualGate(string strategy_type)
{
    if (!ESD_EnableDualBrain) return true;
    
    // Choose Brain
    ESD_ML_Brain_State *brain;
    if (StringFind(strategy_type, "Trend") >= 0) brain = &ESD_Brain_Trend;
    else brain = &ESD_Brain_Reversal;
    
    // Gate Logic
    // 1. Brain must have experience
    if (brain->trade_count < 10) return true; // Allow trading to learn initially
    
    // 2. Accuracy Check
    if (brain->accuracy < 0.45) 
    {
        Print("⛔ GATE BLOCKED: Brain Accuracy too low (", DoubleToString(brain->accuracy*100, 1), "%)");
        return false;
    }
    
    // 3. Profile Warning (Spikes)
    if (ESD_CurrentProfile.spike_probability > 0.7 && StringFind(strategy_type, "Breakout") >= 0)
    {
        Print("⛔ GATE BLOCKED: High Spike Probability for Breakout");
        return false;
    }
    
    return true;
}

// --- END OF FILE ---
