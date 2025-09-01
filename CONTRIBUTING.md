# 🤝 Contributing to SmartOrderBlocks

Thank you for your interest in contributing to **SmartOrderBlocks**! We welcome contributions from traders, developers, and anyone passionate about price action trading. This document provides guidelines to help you contribute effectively.

## 🌟 Ways to Contribute

### 🐛 Bug Reports
- Report bugs through [GitHub Issues](../../issues)
- Provide detailed reproduction steps
- Include MT5 version, broker information, and EA settings
- Attach relevant log files or screenshots

### 💡 Feature Requests
- Suggest new features via [GitHub Issues](../../issues)
- Explain the trading rationale behind the feature
- Provide examples of how it would improve performance
- Consider backward compatibility

### 📝 Documentation
- Improve README.md clarity
- Add trading examples and case studies
- Create video tutorials or guides
- Translate documentation to other languages

### 🔧 Code Contributions
- Fix bugs and improve existing functionality
- Add new price action concepts
- Optimize performance and memory usage
- Enhance risk management features

### 📊 Testing & Validation
- Share backtesting results on different symbols/timeframes
- Test on various brokers and market conditions
- Validate new features before release
- Report performance metrics and edge cases

## 🛠️ Development Guidelines

### Code Standards

#### **Clean Code Principles**
```mql5
// ✅ Good: Clear, descriptive function names
bool IsValidOrderBlock(const OBZone &zone, int currentBar)
{
   // Clear logic with comments
   if(!zone.valid || zone.touched) return false;
   
   // Check if price is in zone using current mode
   return PriceInZoneByMode(zone, currentBar);
}

// ❌ Bad: Unclear naming and no comments
bool chk(const OBZone &z, int b)
{
   if(!z.valid || z.touched) return false;
   return PriceInZoneByMode(z, b);
}
```

#### **Modular Design**
- Keep functions focused on single responsibilities
- Use meaningful parameter names
- Limit function length to ~50 lines when possible
- Group related functionality into logical sections

#### **Proper Comments**
```mql5
//==================== RISK MANAGEMENT ====================

/**
 * Calculate position size based on risk percentage and stop loss distance
 * @param slDistancePoints Stop loss distance in points
 * @return Normalized lot size for the trade
 */
double CalculateLotSize(double slDistancePoints)
{
   if(slDistancePoints <= 0) return 0;
   
   // Calculate risk amount based on account equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * RiskPercent / 100.0;
   
   // ... rest of implementation
}
```

#### **Error Handling**
```mql5
// ✅ Good: Proper error handling
int TrendDir()
{
   if(g_ema_handle == INVALID_HANDLE) 
   {
      Dbg("EMA handle invalid - cannot determine trend");
      return 0;
   }
   
   double ema_buffer[3];
   if(CopyBuffer(g_ema_handle, 0, 1, 3, ema_buffer) <= 0) 
   {
      Dbg("Failed to copy EMA buffer data");
      return 0;
   }
   
   // ... trend logic
}
```

### Performance Guidelines

#### **Efficient Data Access**
- Create indicator handles once in `OnInit()`
- Use `CopyBuffer()` instead of individual `iMA()` calls
- Cache frequently used calculations
- Minimize array resizing operations

#### **Memory Management**
```mql5
// ✅ Good: Proper array management
void PushZone(OBZone &z)
{
   int size = ArraySize(g_bullZones);
   ArrayResize(g_bullZones, size + 1);
   
   // Shift existing elements
   for(int i = size; i > 0; i--) 
      g_bullZones[i] = g_bullZones[i-1];
   
   g_bullZones[0] = z;
   
   // Clean up old zones to prevent memory bloat
   if(size > KeepZonesPerSide * 2)
      ArrayResize(g_bullZones, KeepZonesPerSide);
}
```

### Trading Logic Standards

#### **Price Action Purity**
- Maintain focus on pure price action concepts
- Avoid adding traditional indicators (RSI, MACD, etc.)
- Base all decisions on price structure and patterns
- Document the trading rationale for each feature

#### **Risk Management Priority**
- Always validate stop loss distances against broker requirements
- Implement proper position sizing calculations
- Include safeguards against excessive risk
- Test edge cases (low equity, high volatility, etc.)

## 📋 Pull Request Process

### Before Submitting

1. **Fork the Repository**
   ```bash
   git clone https://github.com/logiccrafterdz/SmartOrderBlocks.git
   cd SmartOrderBlocks
   git checkout -b feature/your-feature-name
   ```

2. **Test Your Changes**
   - Compile without errors in MetaEditor
   - Test on demo account with various settings
   - Verify no regression in existing functionality
   - Document any new parameters or features

3. **Follow Commit Guidelines**
   ```bash
   # ✅ Good commit messages
   git commit -m "feat: add liquidity zone detection"
   git commit -m "fix: resolve SL calculation error for small accounts"
   git commit -m "docs: update installation instructions"
   
   # ❌ Bad commit messages
   git commit -m "update"
   git commit -m "fix bug"
   git commit -m "changes"
   ```

### Pull Request Template

When submitting a PR, please include:

```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Compiled successfully in MetaEditor
- [ ] Tested on demo account
- [ ] No regression in existing features
- [ ] Added/updated relevant documentation

## Trading Rationale
Explain the price action logic behind the change.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
```

### Review Process

1. **Automated Checks**
   - Code compiles without errors
   - Follows naming conventions
   - No obvious security issues

2. **Manual Review**
   - Trading logic validation
   - Performance impact assessment
   - Code quality and maintainability
   - Documentation completeness

3. **Testing Phase**
   - Community testing on demo accounts
   - Performance benchmarking
   - Edge case validation

## 🐛 Bug Report Template

When reporting bugs, please use this template:

```markdown
**Bug Description**
A clear description of what the bug is.

**Reproduction Steps**
1. Go to '...'
2. Set parameters '...'
3. Observe '...'

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- MT5 Version: [e.g. 5.00.3200]
- Broker: [e.g. IC Markets]
- Symbol: [e.g. EURUSD]
- Timeframe: [e.g. H1]
- EA Settings: [paste relevant settings]

**Additional Context**
- Log files (if available)
- Screenshots
- Account type (demo/live)
```

## 💡 Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature.

**Trading Rationale**
Explain how this feature aligns with price action principles.

**Use Case**
Describe specific scenarios where this feature would be beneficial.

**Implementation Ideas**
Suggest how this might be implemented (optional).

**Additional Context**
- Similar features in other platforms
- Academic or trading literature references
- Community feedback or requests
```

## 🗣️ Communication Guidelines

### Community Standards

- **Be Respectful**: Treat all community members with respect
- **Be Constructive**: Provide helpful feedback and suggestions
- **Be Patient**: Remember that contributors are volunteers
- **Be Specific**: Provide detailed information in reports and requests
- **Be Open-Minded**: Consider different trading approaches and perspectives

### Code Review Etiquette

- Focus on the code, not the person
- Explain the "why" behind suggestions
- Acknowledge good practices when you see them
- Ask questions instead of making demands
- Be willing to compromise and find solutions

### Getting Help

- **GitHub Discussions**: For general questions and community chat
- **Issues**: For specific bugs or feature requests
- **Discord**: For real-time community interaction
- **Email**: For private or sensitive matters

## 🏆 Recognition

We value all contributions and recognize contributors through:

- **Contributors List**: Added to README.md
- **Release Notes**: Acknowledgment in version releases
- **Community Highlights**: Featured contributions in newsletters
- **Beta Access**: Early access to new features

## 📚 Resources

### Learning Materials
- [MQL5 Documentation](https://www.mql5.com/en/docs)
- [Price Action Trading Concepts](https://www.babypips.com/learn/forex/price-action)
- [Smart Money Concepts](https://www.tradingview.com/ideas/smartmoneyconcept/)

### Development Tools
- [MetaEditor](https://www.metatrader5.com/en/automated-trading/metaeditor) - Official MQL5 IDE
- [Git](https://git-scm.com/) - Version control
- [Visual Studio Code](https://code.visualstudio.com/) - Alternative editor with MQL5 extensions

---

**Thank you for contributing to SmartOrderBlocks! Together, we're building the future of algorithmic price action trading.**

*Questions? Reach out to us at [logiccrafterdz@gmail.com]*