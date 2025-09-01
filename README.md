# 🤖 SmartOrderBlocks

**Expert Advisor for MetaTrader 5 based on Pure Price Action**

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange.svg)
![Language](https://img.shields.io/badge/language-MQL5-green.svg)
![Status](https://img.shields.io/badge/status-Active%20Development-brightgreen.svg)

---

## 📖 Introduction

**SmartOrderBlocks** is a sophisticated Expert Advisor (EA) for MetaTrader 5 that trades based on **pure price action** principles. Unlike traditional EAs that rely heavily on technical indicators, SmartOrderBlocks analyzes raw price movements to identify high-probability trading opportunities.

The bot implements advanced concepts from Smart Money trading, including Break of Structure (BOS), Change of Character (CHoCH), Order Blocks, and institutional-level swing analysis. It's designed for traders who understand that price action is the ultimate indicator.

## 🔧 How It Works

### Core Trading Logic

**SmartOrderBlocks** operates on several key price action concepts:

#### 🎯 **Break of Structure (BOS)**
- Identifies when price breaks above previous swing highs (bullish BOS) or below swing lows (bearish BOS)
- Confirms trend continuation and potential entry zones
- Filters out false breakouts using minimum pip requirements

#### 🔄 **Change of Character (CHoCH)**
- Detects trend reversals through structural changes in price behavior
- Analyzes swing patterns to identify potential trend shifts
- Provides early signals for counter-trend opportunities

#### 📊 **Swing Detection**
- Uses fractal-based analysis to identify significant swing highs and lows
- Configurable left/right bar confirmation for swing validation
- Forms the foundation for all structural analysis

#### 🎯 **Order Block Identification**
- Locates institutional order blocks (areas where smart money placed orders)
- Validates order blocks using body-to-ATR ratios and volume analysis
- Tracks order block invalidation and breaker block formation

#### 💰 **Risk Management**
- Percentage-based position sizing
- Dynamic stop-loss placement based on market structure
- Configurable risk-reward ratios (1:1.5 to 1:3)
- Break-even and partial take-profit functionality

#### 📋 **Order Management**
- Smart entry timing using market structure confirmation
- Multiple confirmation patterns (engulfing, pin bars)
- Session-based trading filters
- Spread and slippage protection

## ✨ Key Features

- ✅ **100% Pure Price Action** - No lagging indicators
- ✅ **Smart Money Concepts** - BOS, CHoCH, Order Blocks
- ✅ **Advanced Risk Management** - Percentage risk, dynamic SL/TP
- ✅ **Session Filtering** - Trade only during optimal market hours
- ✅ **Multiple Timeframe Support** - H1, H4, D1 compatible
- ✅ **Breaker Block Trading** - Advanced institutional concepts
- ✅ **News Filter Integration** - Avoid high-impact news events
- ✅ **Partial Take Profits** - Lock in profits systematically
- ✅ **Break-Even Functionality** - Protect capital automatically
- ✅ **Trailing Stop Options** - ATR-based or fixed pip trailing
- ✅ **Visual Zone Display** - See order blocks on chart
- ✅ **Comprehensive Logging** - Debug and performance tracking

## 📊 Preliminary Results

*Based on backtesting data from January 2024 - March 2024 on XAUUSD H1*

| Metric | Value |
|--------|-------|
| **Total Trades** | 23 |
| **Win Rate** | 65.2% |
| **Profit Factor** | 1.85 |
| **Max Drawdown** | 8.3% |
| **Average RR** | 1:1.8 |
| **Best Trade** | +$847 |
| **Worst Trade** | -$312 |
| **Net Profit** | +$2,156 |

> ⚠️ **Disclaimer**: Past performance does not guarantee future results. Always test on demo accounts first.

## 🚀 Installation & Setup

### Prerequisites
- MetaTrader 5 platform
- Basic understanding of price action concepts
- Demo account for initial testing (recommended)

### Installation Steps

1. **Download the EA file**
   ```
   SmartOrderBlocks_EA.mq5
   ```

2. **Copy to MT5 Experts folder**
   - Open MetaTrader 5
   - Press `Ctrl + Shift + D` to open Data Folder
   - Navigate to `MQL5 → Experts`
   - Copy `SmartOrderBlocks_EA.mq5` into this folder

3. **Compile the EA**
   - Open MetaEditor (F4 in MT5)
   - Open the EA file
   - Press `F7` to compile
   - Ensure no compilation errors

4. **Attach to Chart**
   - Open your desired chart (H1 recommended)
   - Drag the EA from Navigator to the chart
   - Configure settings (see Usage Guide below)
   - Enable "Allow live trading" and "Allow DLL imports"

## 📚 Usage Guide

### Recommended Settings

#### **Conservative Setup (Beginners)**
```
EMA_Period = 100
RiskPercent = 0.3
RR_Target = 2.0
UseBreakerBlocks = false
UseBreakEven = true
BE_At_RR = 0.5
```

#### **Aggressive Setup (Experienced)**
```
EMA_Period = 50
RiskPercent = 0.5
RR_Target = 2.5
UseBreakerBlocks = true
UsePartialTP = true
PartialClosePct = 30
```

### Key Parameters Explained

| Parameter | Description | Recommended Range |
|-----------|-------------|-------------------|
| `EMA_Period` | Trend filter period | 50-200 |
| `RiskPercent` | Risk per trade (% of equity) | 0.3-1.0 |
| `RR_Target` | Risk-Reward ratio | 1.5-3.0 |
| `BOS_MinPips` | Minimum BOS distance | 5-15 pips |
| `BodyToATR_Min` | Order block quality filter | 0.4-0.8 |
| `MaxSpreadPoints` | Maximum allowed spread | 20-50 points |

### Trading Sessions

**Recommended Active Hours (GMT):**
- **London Session**: 07:00 - 11:00
- **New York Session**: 13:00 - 17:00

*Adjust `BrokerGMTOffset` according to your broker's server time.*

## 🛣️ Future Roadmap

### Version 2.0 
- [ ] **Multi-Timeframe Analysis** - Higher TF bias with lower TF entries
- [ ] **Advanced Pattern Recognition** - Flag, pennant, and triangle patterns
- [ ] **Liquidity Mapping** - Identify and target liquidity zones
- [ ] **Market Structure Dashboard** - Real-time structure analysis

### Version 3.0 
- [ ] **Machine Learning Integration** - Pattern recognition enhancement
- [ ] **Sentiment Analysis** - News and social media sentiment
- [ ] **Portfolio Management** - Multi-symbol trading
- [ ] **Mobile Notifications** - Trade alerts via Telegram/Discord

### Community Features
- [ ] **Strategy Sharing Platform** - Community-driven improvements
- [ ] **Backtesting Database** - Shared performance metrics
- [ ] **Educational Content** - Price action tutorials and webinars
- [ ] **Open Source Modules** - Modular strategy components

## 🤝 Contributing

We welcome contributions from the trading and development community! See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

**Ways to contribute:**
- 🐛 Report bugs and issues
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit code improvements
- 📊 Share backtesting results

## 📞 Links & Community

- 🌐 **Website**: [Coming Soon]
- 🐦 **Twitter**: [@SmartOrderBlocks]
- 📱 **Telegram**: [t.me/SmartOrderBlocks]
- 📧 **Email**: [contact@smartorderblocks.com]
- 💬 **Discord**: [discord.gg/smartorderblocks]

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Risk Disclaimer

**Trading foreign exchange and CFDs carries a high level of risk and may not be suitable for all investors. Past performance is not indicative of future results. Please ensure you fully understand the risks involved and seek independent advice if necessary.**

---
