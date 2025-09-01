//+------------------------------------------------------------------+
//|                                              SmartOrderBlocks.mq5 |
//|                           Copyright (c) 2025 LogicCrafterDZ     |
//|                          Email: logiccrafterdz@gmail.com        |
//|                          Twitter: @Arana_lib                    |
//|                          Telegram: https://t.me/LogicCrafterDZ  |
//+------------------------------------------------------------------+
//| Purpose: Expert Advisor implementing "Smart Order Blocks with    |
//|          EMA & Sessions" strategy with strict modularity,        |
//|          robust risk management, and session/news filters.       |
//|                                                                  |
//| Notes:                                                           |
//| - All signals are based on CLOSED bars only; no repainting.      |
//| - Deterministic in backtests/live.                               |
//| - One position per symbol/magic by default.                      |
//+------------------------------------------------------------------+
#property copyright ""
#property version   "1.00"
#property strict
#property description "Smart Order Blocks with EMA & Sessions"

#include <Trade/Trade.mqh>

//==================== ENUMERATIONS ====================
enum BodyQualModeEnum
{
   QUAL_ATR = 0,
   QUAL_SMA = 1
};

enum EntryRetraceMode
{
   RETR_TOUCH = 0,
   RETR_CLOSE = 1
};

enum TrailModeEnum
{
   TRAIL_NONE = 0,
   TRAIL_ATR  = 1,
   TRAIL_STEP = 2
};

enum ImpactEnum
{
   IMPACT_High = 0,
   IMPACT_Medium = 1,
   IMPACT_Low = 2
};

//==================== INPUTS ====================
input int                EMA_Period           = 100;      // Reduced for better trend sensitivity
input ENUM_TIMEFRAMES    TrendTimeframe       = PERIOD_CURRENT; // Trend TF
input int                SwingLeft            = 3;
input int                SwingRight           = 3;
input int                KeepZonesPerSide     = 3;
input double             BOS_MinPips          = 8.0;      // Increased for better quality signals
input BodyQualModeEnum   BodyQualMode         = QUAL_ATR; // ATR or SMA body quality
input double             BodyToATR_Min        = 0.6;      // Increased for better quality
input double             BodyToSMA_Min        = 0.8;      // Increased threshold
input double             ImpulseToATR_Min     = 1.2;      // Increased for stronger impulses
input bool               UseWicksInZone       = false;
input bool               UseVolume            = false;
input double             VolumeSpikeFactor    = 1.5;
input EntryRetraceMode   EntryTouchOrClose    = RETR_CLOSE; // Use close instead of touch
input double             PinWickFactor        = 1.8;      // Slightly reduced
input int                PinClosePct          = 25;       // More lenient close requirement
input bool               UseBreakerBlocks     = false;     // Disabled temporarily for testing

// Risk Management - Optimized
input double             RiskPercent          = 0.3;      // Further reduced risk
input double             SL_BufferPips        = 5.0;      // Keep buffer for safety
input double             RR_Target            = 2.0;      // Increased for better risk/reward
input bool               UseBreakEven         = true;
input double             BE_At_RR             = 0.5;      // Earlier break-even
input double             BE_LockPips          = 3.0;      // Lock more profit
input bool               UsePartialTP         = true;
input int                PartialClosePct      = 25;       // Reduced partial close
input TrailModeEnum      TrailMode            = TRAIL_NONE;
input int                ATR_Period           = 14;
input double             ATR_Mult             = 2.0;
input double             TrailStepPips        = 10.0;
input double             TrailStart_RR        = 1.2;

// Sessions
input bool               UseSessions          = true;
input string             Session1_Start       = "07:00";   // Extended morning session
input string             Session1_End         = "11:00";
input string             Session2_Start       = "13:00";   // Extended afternoon session
input string             Session2_End         = "17:00";
input int                BrokerGMTOffset      = 0;         // broker server offset to GMT (hours)
input int                SessionTZOffset      = 0;         // target session TZ offset to GMT (e.g., London)

// News
input bool               UseNewsFilter        = true;
input string             NewsStartTime        = "14:25";   // Manual news start time HH:MM
input string             NewsEndTime          = "15:10";   // Manual news end time HH:MM
input string             NewsAPI_URL          = "";        // add to WebRequest allowed URLs
input ImpactEnum         MinImpact            = IMPACT_High;
input int                NewsLookaheadMinutes = 60;

// Order handling
input bool               AllowMultiplePositions = false;
input long               MagicNumber          = 20250101;
input int                MaxSlippagePoints    = 10;
input int                MaxSpreadPoints      = 50;        // Increased to avoid "Invalid stops"

// Visual/Debug
input bool               ShowZones            = true;
input bool               ShowDebug            = true;

//==================== GLOBALS ====================
CTrade    m_trade;
string    m_symbol;
ENUM_TIMEFRAMES m_chartTF;
datetime  m_lastBarTime = 0;     // last seen bar time for chart TF
int       m_digits;
double    m_point;
double    m_tickSize;
double    m_tickValue;
int       m_spreadPoints;

// Indicator handles (created once in OnInit)
int       g_ema_handle = INVALID_HANDLE;
int       g_atr_handle = INVALID_HANDLE;

// Partial TP tracking
string    g_partialTPDone[];     // Array to track tickets that had partial TP

// OB direction constants
#define DIR_BULL  1
#define DIR_BEAR -1

struct OBZone
{
   long     id;             // unique id
   int      dir;            // 1 bull, -1 bear
   datetime ob_time;        // time of OB candle
   int      ob_index;       // bar index at creation
   double   low;            // zone low
   double   high;           // zone high
   bool     valid;          // invalidated?
   bool     touched;        // has price returned/touched?
   bool     breaker_ready;  // became breaker after invalidation
   datetime invalidated_time;
};

OBZone   g_bullZones[];
OBZone   g_bearZones[];
long     g_nextZoneId = 1;

//==================== UTILS ====================
void Dbg(string msg)
{
   if(!ShowDebug) return;
   Print("[SOB] ",msg);
}

int DigitsPips()
{
   // pips to points multiplier
   if(m_digits==3 || m_digits==5) return 10; else return 1;
}

double PipsToPoints(double pips){ return(pips * DigitsPips()); }

double PointsToPrice(double pts){ return(pts * m_point); }

double PipsToPrice(double pips){ return(PointsToPrice(PipsToPoints(pips))); }

bool IsNewBar()
{
   datetime t = iTime(m_symbol,m_chartTF,0);
   if(t!=m_lastBarTime)
   {
      m_lastBarTime = t;
      return true;
   }
   return false;
}

// Parse HH:MM -> minutes of day
bool ParseHHMM(const string hhmm,int &minutes)
{
   string parts[];
   if(StringSplit(hhmm,':',parts)!=2) return false;
   int h=(int)StringToInteger(parts[0]);
   int m=(int)StringToInteger(parts[1]);
   if(h<0||h>23||m<0||m>59) return false;
   minutes = h*60+m;
   return true;
}

// Convert broker server time to target session TZ minutes-of-day
int SessionMinuteOfDay(datetime t)
{
   // Convert server time -> GMT -> SessionTZ
   datetime gmt = t - (BrokerGMTOffset*3600);
   datetime sess = gmt + (SessionTZOffset*3600);
   MqlDateTime dt; TimeToStruct(sess,dt);
   return dt.hour*60+dt.min;
}

bool InSessionsNow()
{
   if(!UseSessions) return true;
   int s1=0,e1=0,s2=0,e2=0;
   if(!ParseHHMM(Session1_Start,s1)) return false;
   if(!ParseHHMM(Session1_End,e1))   return false;
   if(!ParseHHMM(Session2_Start,s2)) return false;
   if(!ParseHHMM(Session2_End,e2))   return false;
   int nowMin = SessionMinuteOfDay(TimeCurrent());
   bool in1 = (nowMin>=s1 && nowMin<=e1);
   bool in2 = (nowMin>=s2 && nowMin<=e2);
   return (in1||in2);
}

// Average body of last N bars
double AvgBody(int n,int from_shift)
{
   double sum=0; int cnt=0;
   for(int i=from_shift;i<from_shift+n;i++)
   {
      double o=iOpen(m_symbol,m_chartTF,i);
      double c=iClose(m_symbol,m_chartTF,i);
      if(o==0||c==0) break;
      sum += MathAbs(c-o); cnt++;
   }
   if(cnt==0) return 0;
   return sum/cnt;
}

// EMA trend filter with stronger confirmation
int TrendDir()
{
   if(g_ema_handle == INVALID_HANDLE) return 0;
   double ema_buffer[3];
   if(CopyBuffer(g_ema_handle, 0, 1, 3, ema_buffer) <= 0) return 0;
   double close1 = iClose(m_symbol, TrendTimeframe, 1);
   double close2 = iClose(m_symbol, TrendTimeframe, 2);
   double close3 = iClose(m_symbol, TrendTimeframe, 3);
   
   // Require stronger trend confirmation
   bool bullTrend = (close1 > ema_buffer[0]) && (close2 > ema_buffer[1]) && (close3 > ema_buffer[2]);
   bool bearTrend = (close1 < ema_buffer[0]) && (close2 < ema_buffer[1]) && (close3 < ema_buffer[2]);
   
   if(bullTrend) return DIR_BULL;
   if(bearTrend) return DIR_BEAR;
   return 0;
}

// Swing detection: check if bar at index i is swing high/low
bool IsSwingHigh(int i)
{
   double h = iHigh(m_symbol,m_chartTF,i);
   for(int l=1;l<=SwingLeft;l++)   if(iHigh(m_symbol,m_chartTF,i+l)>=h) return false;
   for(int r=1;r<=SwingRight;r++)  if(iHigh(m_symbol,m_chartTF,i-r)>=h) return false;
   return true;
}

bool IsSwingLow(int i)
{
   double l = iLow(m_symbol,m_chartTF,i);
   for(int lft=1;lft<=SwingLeft;lft++) if(iLow(m_symbol,m_chartTF,i+lft)<=l) return false;
   for(int r=1;r<=SwingRight;r++)     if(iLow(m_symbol,m_chartTF,i-r)<=l) return false;
   return true;
}

// Find most recent swing highs/lows before index start
bool GetLastSwings(int start_index,int &lastHighIndex,double &lastHighValue,int &lastLowIndex,double &lastLowValue)
{
   lastHighIndex=-1; lastLowIndex=-1; lastHighValue=0; lastLowValue=0;
   int maxLook = 300; // reasonable search window
   for(int i=start_index+SwingRight; i<start_index+SwingRight+maxLook; i++)
   {
      if(IsSwingHigh(i)) { lastHighIndex=i; lastHighValue=iHigh(m_symbol,m_chartTF,i); break; }
   }
   for(int i=start_index+SwingRight; i<start_index+SwingRight+maxLook; i++)
   {
      if(IsSwingLow(i)) { lastLowIndex=i; lastLowValue=iLow(m_symbol,m_chartTF,i); break; }
   }
   return (lastHighIndex!=-1 && lastLowIndex!=-1);
}

// Detect BOS at bar 'k' (closed)
int DetectBOS(int k,double &brokenLevel)
{
   int hIdx,lIdx; double hVal,lVal;
   if(!GetLastSwings(k+1,hIdx,hVal,lIdx,lVal)) return 0;
   double bosPipsPts = PipsToPoints(BOS_MinPips);
   double closek = iClose(m_symbol,m_chartTF,k);
   // BOS up if new high above last swing high by BOS_MinPips
   if(closek - hVal > PointsToPrice(bosPipsPts)) { brokenLevel=hVal; return DIR_BULL; }
   // BOS down if close below last swing low by threshold
   if(lVal - closek > PointsToPrice(bosPipsPts)) { brokenLevel=lVal; return DIR_BEAR; }
   return 0;
}

// Validate OB quality for bar index 'i' using selected mode
bool OBQualityOK(int i)
{
   double o=iOpen(m_symbol,m_chartTF,i);
   double c=iClose(m_symbol,m_chartTF,i);
   double body=MathAbs(c-o);
   if(BodyQualMode==QUAL_ATR)
   {
      if(g_atr_handle == INVALID_HANDLE) return false;
      double atr_buffer[1];
      // Use proper shift for closed bar
      int shift = (i >= 1) ? i : 1;
      if(CopyBuffer(g_atr_handle, 0, shift, 1, atr_buffer) <= 0) return false;
      return body > BodyToATR_Min*atr_buffer[0];
   }
   else
   {
      double avg=AvgBody(10,i+1);
      if(avg<=0) return false;
      return body > BodyToSMA_Min*avg;
   }
}

bool VolumeSpikeOK(int i)
{
   if(!UseVolume) return true;
   long vol = (long)iVolume(m_symbol,m_chartTF,i);
   double avg=0; int n=20; int cnt=0;
   for(int k=i+1; k<i+1+n; k++) { avg += (double)iVolume(m_symbol,m_chartTF,k); cnt++; }
   if(cnt==0) return false;
   avg/=cnt;
   return (double)vol >= VolumeSpikeFactor*avg;
}

bool ImpulseOK(int afterIndex,int bosIndex)
{
   // displacement: first impulse after OB should have range > ImpulseToATR_Min * ATR(14)
   int checkFrom = afterIndex-1;
   int checkTo   = bosIndex;
   double maxRange=0;
   for(int j=checkFrom; j>=checkTo && j>=0; j--)
   {
      double range = iHigh(m_symbol,m_chartTF,j)-iLow(m_symbol,m_chartTF,j);
      if(range>maxRange) maxRange=range;
   }
   if(g_atr_handle == INVALID_HANDLE) return false;
   double atr_buffer[1];
   // Use proper shift for closed bar
   int shift = (afterIndex >= 1) ? afterIndex : 1;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, atr_buffer) <= 0) return false;
   return maxRange > ImpulseToATR_Min*atr_buffer[0];
}

void PushZone(OBZone &z)
{
   if(z.dir==DIR_BULL)
   {
      int size = ArraySize(g_bullZones);
      ArrayResize(g_bullZones, size+1);
      for(int i=size; i>0; i--) g_bullZones[i] = g_bullZones[i-1];
      g_bullZones[0] = z;
      
      // Clean up and keep only last N zones (valid or invalid)
      if(ArraySize(g_bullZones) > KeepZonesPerSide * 2) // Allow some buffer
      {
         ArrayResize(g_bullZones, KeepZonesPerSide);
      }
   }
   else if(z.dir==DIR_BEAR)
   {
      int size = ArraySize(g_bearZones);
      ArrayResize(g_bearZones, size+1);
      for(int i=size; i>0; i--) g_bearZones[i] = g_bearZones[i-1];
      g_bearZones[0] = z;
      
      // Clean up and keep only last N zones (valid or invalid)
      if(ArraySize(g_bearZones) > KeepZonesPerSide * 2) // Allow some buffer
      {
         ArrayResize(g_bearZones, KeepZonesPerSide);
      }
   }
}

void DrawZone(const OBZone &z)
{
   if(!ShowZones) return;
   string name = StringFormat("SOB_ZONE_%s_%I64d", (z.dir==DIR_BULL?"BULL":"BEAR"), z.id);
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      color col = (z.dir==DIR_BULL? clrGreen: clrTomato);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   }
   datetime t1 = z.ob_time;
   datetime t2 = TimeCurrent()+PeriodSeconds(m_chartTF)*100; // extend to future
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1);
   ObjectSetDouble(0,name,OBJPROP_PRICE,0,z.low);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2);
   ObjectSetDouble(0,name,OBJPROP_PRICE,1,z.high);
}

void InvalidateZonesByClose(int k)
{
   double closek = iClose(m_symbol,m_chartTF,k);
   // bullish invalidated if close below zone low
   for(int i=0;i<ArraySize(g_bullZones);i++)
   {
      if(!g_bullZones[i].valid) continue;
      if(closek < g_bullZones[i].low)
      {
         g_bullZones[i].valid=false;
         g_bullZones[i].invalidated_time = iTime(m_symbol,m_chartTF,k);
         if(UseBreakerBlocks) g_bullZones[i].breaker_ready=true;
         Dbg("Bullish OB " + IntegerToString(g_bullZones[i].id) + " invalidated at " + TimeToString(g_bullZones[i].invalidated_time));
      }
   }
   // bearish invalidated if close above zone high
   for(int i=0;i<ArraySize(g_bearZones);i++)
   {
      if(!g_bearZones[i].valid) continue;
      if(closek > g_bearZones[i].high)
      {
         g_bearZones[i].valid=false;
         g_bearZones[i].invalidated_time = iTime(m_symbol,m_chartTF,k);
         if(UseBreakerBlocks) g_bearZones[i].breaker_ready=true;
         Dbg("Bearish OB " + IntegerToString(g_bearZones[i].id) + " invalidated at " + TimeToString(g_bearZones[i].invalidated_time));
      }
   }
}

// Check if price is in zone (touch or close)
bool PriceInZone(const OBZone &z,double price)
{
   return (price >= z.low && price <= z.high);
}

bool PriceInZoneByMode(const OBZone &z,int k)
{
   if(EntryTouchOrClose==RETR_TOUCH)
   {
      double high_k = iHigh(m_symbol,m_chartTF,k);
      double low_k = iLow(m_symbol,m_chartTF,k);
      return (high_k >= z.low && low_k <= z.high); // bar touched zone
   }
   else
   {
      double close_k = iClose(m_symbol,m_chartTF,k);
      return PriceInZone(z,close_k); // close inside zone
   }
}

// Mark zones as touched when price returns
void UpdateZonesTouched(int k)
{
   for(int i=0;i<ArraySize(g_bullZones);i++)
   {
      if(!g_bullZones[i].valid || g_bullZones[i].touched) continue;
      if(PriceInZoneByMode(g_bullZones[i],k))
      {
         g_bullZones[i].touched=true;
         Dbg("Bullish OB " + IntegerToString(g_bullZones[i].id) + " touched at bar " + IntegerToString(k));
      }
   }
   for(int i=0;i<ArraySize(g_bearZones);i++)
   {
      if(!g_bearZones[i].valid || g_bearZones[i].touched) continue;
      if(PriceInZoneByMode(g_bearZones[i],k))
      {
         g_bearZones[i].touched=true;
         Dbg("Bearish OB " + IntegerToString(g_bearZones[i].id) + " touched at bar " + IntegerToString(k));
      }
   }
}

// Confirmation patterns
bool IsBullishEngulfing(int k)
{
   if(k<1) return false;
   double o1=iOpen(m_symbol,m_chartTF,k+1), c1=iClose(m_symbol,m_chartTF,k+1);
   double o0=iOpen(m_symbol,m_chartTF,k), c0=iClose(m_symbol,m_chartTF,k);
   // current bullish, previous bearish, current body engulfs previous
   return (c0>o0 && c1<o1 && o0<c1 && c0>o1);
}

bool IsBearishEngulfing(int k)
{
   if(k<1) return false;
   double o1=iOpen(m_symbol,m_chartTF,k+1), c1=iClose(m_symbol,m_chartTF,k+1);
   double o0=iOpen(m_symbol,m_chartTF,k), c0=iClose(m_symbol,m_chartTF,k);
   // current bearish, previous bullish, current body engulfs previous
   return (c0<o0 && c1>o1 && o0>c1 && c0<o1);
}

bool IsBullishPinBar(int k)
{
   double o=iOpen(m_symbol,m_chartTF,k), c=iClose(m_symbol,m_chartTF,k);
   double h=iHigh(m_symbol,m_chartTF,k), l=iLow(m_symbol,m_chartTF,k);
   double body=MathAbs(c-o), range=h-l;
   if(range<=0 || body<=0) return false;
   double lowerWick = MathMin(o,c) - l;
   double upperWick = h - MathMax(o,c);
   // lower wick >= PinWickFactor * body, close in top PinClosePct% of range
   bool wickOK = (lowerWick >= PinWickFactor * body);
   bool closeOK = ((c-l)/range * 100.0 >= (100.0-PinClosePct));
   return (wickOK && closeOK);
}

bool IsBearishPinBar(int k)
{
   double o=iOpen(m_symbol,m_chartTF,k), c=iClose(m_symbol,m_chartTF,k);
   double h=iHigh(m_symbol,m_chartTF,k), l=iLow(m_symbol,m_chartTF,k);
   double body=MathAbs(c-o), range=h-l;
   if(range<=0 || body<=0) return false;
   double lowerWick = MathMin(o,c) - l;
   double upperWick = h - MathMax(o,c);
   // upper wick >= PinWickFactor * body, close in bottom PinClosePct% of range
   bool wickOK = (upperWick >= PinWickFactor * body);
   bool closeOK = ((h-c)/range * 100.0 >= (100.0-PinClosePct));
   return (wickOK && closeOK);
}

bool HasBullishConfirmation(int k,const OBZone &z)
{
   if(!PriceInZoneByMode(z,k)) return false;
   return (IsBullishEngulfing(k) || IsBullishPinBar(k));
}

bool HasBearishConfirmation(int k,const OBZone &z)
{
   if(!PriceInZoneByMode(z,k)) return false;
   return (IsBearishEngulfing(k) || IsBearishPinBar(k));
}

//==================== RISK MANAGEMENT ====================
double CalculateLotSize(double slDistancePoints)
{
   if(slDistancePoints<=0) return 0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickValue<=0 || tickSize<=0) return 0;
   double slDistancePrice = slDistancePoints * m_point;
   double slTicks = slDistancePrice / tickSize;
   double lotSize = riskAmount / (slTicks * tickValue);
   // Normalize lot size
   double minLot = SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
   if(stepLot>0) lotSize = MathFloor(lotSize/stepLot) * stepLot;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   return lotSize;
}

//==================== ORDER HANDLING ====================
bool HasOpenPosition()
{
   if(AllowMultiplePositions) return false; // allow multiple
   for(int i=0; i<PositionsTotal(); i++)
   {
      string sym = PositionGetSymbol(i);
      if(sym == "") continue; // invalid position
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(sym == m_symbol && mg == MagicNumber)
         return true;
   }
   return false;
}

bool OpenLong(double entry, double sl, double tp, double lots)
{
   if(HasOpenPosition()) { Dbg("Position already exists, skipping long entry"); return false; }
   m_trade.SetExpertMagicNumber(MagicNumber);
   m_trade.SetDeviationInPoints(MaxSlippagePoints);
   
   // Use market price (0.0) for better execution
   sl = NormalizeDouble(sl, m_digits);
   tp = NormalizeDouble(tp, m_digits);
   lots = NormalizeDouble(lots, 2);
   
   bool result = m_trade.Buy(lots, m_symbol, 0.0, sl, tp, "SOB Long");
   if(result) 
   {
      double actualEntry = m_trade.ResultPrice();
      Dbg("Long opened: " + DoubleToString(lots,2) + " lots at " + DoubleToString(actualEntry,5) + ", SL=" + DoubleToString(sl,5) + ", TP=" + DoubleToString(tp,5));
      // Adjust TP to maintain exact RR based on actual fill price
      if(actualEntry > 0 && sl > 0)
      {
         double newTP = NormalizeDouble(actualEntry + (actualEntry - sl) * RR_Target, m_digits);
         // Try to modify position TP to align with actual RR
         m_trade.PositionModify(m_symbol, sl, newTP);
      }
   }
   else Dbg("Failed to open long: " + m_trade.ResultComment());
   return result;
}

bool OpenShort(double entry, double sl, double tp, double lots)
{
   if(HasOpenPosition()) { Dbg("Position already exists, skipping short entry"); return false; }
   m_trade.SetExpertMagicNumber(MagicNumber);
   m_trade.SetDeviationInPoints(MaxSlippagePoints);
   
   // Use market price (0.0) for better execution
   sl = NormalizeDouble(sl, m_digits);
   tp = NormalizeDouble(tp, m_digits);
   lots = NormalizeDouble(lots, 2);
   
   bool result = m_trade.Sell(lots, m_symbol, 0.0, sl, tp, "SOB Short");
   if(result)
   {
      double actualEntry = m_trade.ResultPrice();
      Dbg("Short opened: " + DoubleToString(lots,2) + " lots at " + DoubleToString(actualEntry,5) + ", SL=" + DoubleToString(sl,5) + ", TP=" + DoubleToString(tp,5));
      // Adjust TP to maintain exact RR based on actual fill price
      if(actualEntry > 0 && sl > 0)
      {
         double newTP = NormalizeDouble(actualEntry - (sl - actualEntry) * RR_Target, m_digits);
         m_trade.PositionModify(m_symbol, sl, newTP);
      }
   }
   else Dbg("Failed to open short: " + m_trade.ResultComment());
   return result;
}

//==================== PARTIAL TP TRACKING ====================
bool IsPartialTPDone(ulong ticket)
{
   string ticketStr = IntegerToString(ticket);
   for(int i=0; i<ArraySize(g_partialTPDone); i++)
   {
      if(g_partialTPDone[i] == ticketStr) return true;
   }
   return false;
}

void MarkPartialTPDone(ulong ticket)
{
   string ticketStr = IntegerToString(ticket);
   int size = ArraySize(g_partialTPDone);
   ArrayResize(g_partialTPDone, size+1);
   g_partialTPDone[size] = ticketStr;
}

//==================== NEWS FILTER ====================
bool NewsBlocksEntry()
{
   if(!UseNewsFilter) return false;
   
   // Manual news filter - check if current time is within news window
   int newsStart=0, newsEnd=0;
   if(!ParseHHMM(NewsStartTime, newsStart)) return false;
   if(!ParseHHMM(NewsEndTime, newsEnd)) return false;
   
   int nowMin = SessionMinuteOfDay(TimeCurrent());
   bool inNewsWindow = (nowMin >= newsStart && nowMin <= newsEnd);
   
   if(inNewsWindow)
   {
      Dbg("News filter active: blocking new entries from " + NewsStartTime + " to " + NewsEndTime);
      return true; // Block new entries
   }
   
   return false; // Allow entries
}

//==================== MAIN LOGIC ====================
void ProcessNewBar(int k)
{
   // k is the index of the newly closed bar (1 = last closed)
   if(k!=1) return; // only process last closed bar
   
   // 1. Invalidate zones by close
   InvalidateZonesByClose(k);
   
   // 2. Update zones touched status
   UpdateZonesTouched(k);
   
   // 3. Look for new BOS and create OB zones
   double brokenLevel;
   int bosDir = DetectBOS(k, brokenLevel);
   if(bosDir != 0)
   {
      Dbg("BOS detected at bar " + IntegerToString(k) + ", direction=" + IntegerToString(bosDir) + ", level=" + DoubleToString(brokenLevel,5));
      
      // Find the OB candle (LAST opposite candle before impulse)
      int obIndex = -1;
      for(int i=k+1; i<k+50; i++) // look back reasonable distance
      {
         double o=iOpen(m_symbol,m_chartTF,i), c=iClose(m_symbol,m_chartTF,i);
         if(bosDir==DIR_BULL && c<o) { obIndex=i; } // Continue to find LAST bearish
         if(bosDir==DIR_BEAR && c>o) { obIndex=i; } // Continue to find LAST bullish
      }
      
      if(obIndex>0)
      {
         // Validate OB quality
         if(OBQualityOK(obIndex) && VolumeSpikeOK(obIndex) && ImpulseOK(obIndex,k))
         {
            // Create OB zone
            OBZone newZone;
            newZone.id = g_nextZoneId++;
            newZone.dir = bosDir;
            newZone.ob_time = iTime(m_symbol,m_chartTF,obIndex);
            newZone.ob_index = obIndex;
            newZone.valid = true;
            newZone.touched = false;
            newZone.breaker_ready = false;
            
            double ob_open = iOpen(m_symbol,m_chartTF,obIndex);
            double ob_close = iClose(m_symbol,m_chartTF,obIndex);
            double ob_high = iHigh(m_symbol,m_chartTF,obIndex);
            double ob_low = iLow(m_symbol,m_chartTF,obIndex);
            
            if(UseWicksInZone)
            {
               newZone.low = ob_low;
               newZone.high = ob_high;
            }
            else
            {
               newZone.low = MathMin(ob_open, ob_close);
               newZone.high = MathMax(ob_open, ob_close);
            }
            
            PushZone(newZone);
            DrawZone(newZone);
            Dbg("Created " + (bosDir==DIR_BULL?"Bullish":"Bearish") + " OB zone " + IntegerToString(newZone.id) + ": " + DoubleToString(newZone.low,5) + "-" + DoubleToString(newZone.high,5));
         }
      }
   }
   
   // 4. Check for entry signals
   if(!InSessionsNow()) { Dbg("Outside trading sessions"); return; }
   if(NewsBlocksEntry()) { Dbg("News blocks entry"); return; }
   
   // Check spread filter
   int currentSpread = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   if(currentSpread > MaxSpreadPoints)
   {
      Dbg("Spread too high: " + IntegerToString(currentSpread) + " > " + IntegerToString(MaxSpreadPoints));
      return;
   }
   
   int trend = TrendDir();
   if(trend==0) { Dbg("No clear trend"); return; }
   
   // Check for long entries
   if(trend==DIR_BULL)
   {
      for(int i=0; i<ArraySize(g_bullZones); i++)
      {
         if(!g_bullZones[i].valid || !g_bullZones[i].touched) continue;
         if(HasBullishConfirmation(k, g_bullZones[i]))
         {
            // Calculate entry, SL, TP
            double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double slLevel = g_bullZones[i].low - PipsToPrice(SL_BufferPips);
            double stops_req = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            if((entry - slLevel) < stops_req)
            {
               Dbg("Skipped long: SL too close to current price (stops level)");
               continue;
            }
            double slDistance = (entry - slLevel) / m_point;
            double tpLevel = entry + (entry - slLevel) * RR_Target;
            double lots = CalculateLotSize(slDistance);
            
            if(lots > 0)
            {
               if(OpenLong(entry, slLevel, tpLevel, lots))
               {
                  // Mark zone as used (optional)
                  Dbg("Long entry triggered on OB " + IntegerToString(g_bullZones[i].id));
                  return; // one trade per bar
               }
            }
         }
      }
   }
   
   // Check for short entries
   if(trend==DIR_BEAR)
   {
      for(int i=0; i<ArraySize(g_bearZones); i++)
      {
         if(!g_bearZones[i].valid || !g_bearZones[i].touched) continue;
         if(HasBearishConfirmation(k, g_bearZones[i]))
         {
            // Calculate entry, SL, TP
            double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double slLevel = g_bearZones[i].high + PipsToPrice(SL_BufferPips);
            double stops_req = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            if((slLevel - entry) < stops_req)
            {
               Dbg("Skipped short: SL too close to current price (stops level)");
               continue;
            }
            double slDistance = (slLevel - entry) / m_point;
            double tpLevel = entry - (slLevel - entry) * RR_Target;
            double lots = CalculateLotSize(slDistance);
            
            if(lots > 0)
            {
               if(OpenShort(entry, slLevel, tpLevel, lots))
               {
                  // Mark zone as used (optional)
                  Dbg("Short entry triggered on OB " + IntegerToString(g_bearZones[i].id));
                  return; // one trade per bar
               }
            }
         }
      }
   }
   
   // Check for Breaker Block entries
   CheckBreakerEntries(k, trend);
}

// Breaker Block helper functions
bool IsRetestFromOpposite(const OBZone &z, int k)
{
   double high_k = iHigh(m_symbol, m_chartTF, k);
   double low_k = iLow(m_symbol, m_chartTF, k);
   double close_k = iClose(m_symbol, m_chartTF, k);
   
   if(z.dir == DIR_BULL) // Bull OB broken upward -> sell on retest from below (now resistance)
      return (high_k >= z.low && low_k <= z.low && close_k < z.low);
   else // Bear OB broken downward -> buy on retest from above (now support)
      return (low_k <= z.high && high_k >= z.high && close_k > z.high);
}

void CheckBreakerEntries(int k, int trend)
{
   if(!UseBreakerBlocks) return;
   
   if(trend == DIR_BEAR) // Sell on broken Bull OB
   {
      for(int i=0; i<ArraySize(g_bullZones); i++)
      {
         if(!g_bullZones[i].breaker_ready) continue;
         if(IsRetestFromOpposite(g_bullZones[i], k) && HasBearishConfirmation(k, g_bullZones[i]))
         {
            // Use current market Bid price for short entries and enforce broker stops level
            double entry = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double slLevel = g_bullZones[i].high + PipsToPrice(SL_BufferPips);
            double stops_req = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            if((slLevel - entry) < stops_req)
            {
               Dbg("Skipped breaker short: SL too close to current price (stops level)");
               continue;
            }
            double slPoints = (slLevel - entry) / m_point;
            double tpLevel = entry - (slLevel - entry) * RR_Target;
            double lots = CalculateLotSize(slPoints);
            if(lots > 0 && OpenShort(entry, slLevel, tpLevel, lots))
            {
               Dbg("Breaker short entry on former Bull OB " + IntegerToString(g_bullZones[i].id));
               return;
            }
         }
      }
   }
   
   if(trend == DIR_BULL) // Buy on broken Bear OB
   {
      for(int i=0; i<ArraySize(g_bearZones); i++)
      {
         if(!g_bearZones[i].breaker_ready) continue;
         if(IsRetestFromOpposite(g_bearZones[i], k) && HasBullishConfirmation(k, g_bearZones[i]))
         {
            // Use current market Ask price for long entries and enforce broker stops level
            double entry = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double slLevel = g_bearZones[i].low - PipsToPrice(SL_BufferPips);
            double stops_req = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            if((entry - slLevel) < stops_req)
            {
               Dbg("Skipped breaker long: SL too close to current price (stops level)");
               continue;
            }
            double slPoints = (entry - slLevel) / m_point;
            double tpLevel = entry + (entry - slLevel) * RR_Target;
            double lots = CalculateLotSize(slPoints);
            if(lots > 0 && OpenLong(entry, slLevel, tpLevel, lots))
            {
               Dbg("Breaker long entry on former Bear OB " + IntegerToString(g_bearZones[i].id));
               return;
            }
         }
      }
   }
}

void ManageOpenPositions()
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      string sym = PositionGetSymbol(i);
      if(sym == "" || sym != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      ulong ticket = PositionGetTicket(i);
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isLong = (ptype == POSITION_TYPE_BUY);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double currentPrice = isLong ? bid : ask;
      
      double profit = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
      double slDistance = isLong ? (openPrice - sl) : (sl - openPrice);
      if(slDistance <= 0) continue;
      double rr = profit / slDistance;
      
      // Break-even logic
      if(UseBreakEven && rr >= BE_At_RR)
      {
         double newSL = openPrice + (isLong ? PipsToPrice(BE_LockPips) : -PipsToPrice(BE_LockPips));
         if((isLong && (sl==0 || newSL > sl)) || (!isLong && (sl==0 || newSL < sl)))
         {
            // Check freeze level before modifying
            double freezeLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            double minDistance = isLong ? (currentPrice - newSL) : (newSL - currentPrice);
            if(minDistance >= freezeLevel)
            {
               m_trade.PositionModify(ticket, NormalizeDouble(newSL, m_digits), tp);
               Dbg("Moved to break-even: SL=" + DoubleToString(newSL,5));
            }
         }
      }
      
      // Partial TP logic (actual implementation - once per position)
      if(UsePartialTP && rr >= 1.0 && !IsPartialTPDone(ticket))
      {
         double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
         double stepLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         double closeVol = MathMax(minLot, vol * PartialClosePct / 100.0);
         if(stepLot > 0) closeVol = MathFloor(closeVol/stepLot)*stepLot;
         closeVol = MathMin(closeVol, vol - minLot); // leave at least minimum open
         if(closeVol > 0)
         {
            if(m_trade.PositionClosePartial(ticket, closeVol))
            {
               MarkPartialTPDone(ticket);
               Dbg("Partial TP executed: closed " + DoubleToString(closeVol,2) + " lots at RR=" + DoubleToString(rr,2));
            }
         }
      }
      
      // Trailing Stop logic
      if(TrailMode != TRAIL_NONE && rr >= TrailStart_RR)
      {
         double newSL = sl;
         if(TrailMode == TRAIL_ATR)
         {
            if(g_atr_handle != INVALID_HANDLE)
            {
               double atr[1];
               if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) > 0)
               {
                  double trail = atr[0] * ATR_Mult;
                  newSL = isLong ? (currentPrice - trail) : (currentPrice + trail);
               }
            }
         }
         else if(TrailMode == TRAIL_STEP)
         {
            double step = PipsToPrice(TrailStepPips);
            newSL = isLong ? (currentPrice - step) : (currentPrice + step);
         }
         
         if((isLong && newSL > sl) || (!isLong && newSL < sl))
         {
            // Check freeze level before modifying
            double freezeLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
            double minDistance = isLong ? (currentPrice - newSL) : (newSL - currentPrice);
            if(minDistance >= freezeLevel)
            {
               m_trade.PositionModify(ticket, NormalizeDouble(newSL, m_digits), tp);
               Dbg("Trailing stop updated: SL=" + DoubleToString(newSL,5));
            }
         }
      }
   }
}

//==================== MT5 EVENT HANDLERS ====================
int OnInit()
{
   m_symbol = Symbol();
   m_chartTF = Period();
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   m_tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   m_spreadPoints = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   
   m_trade.SetExpertMagicNumber(MagicNumber);
   m_trade.SetDeviationInPoints(MaxSlippagePoints);
   
   // Create indicator handles once
   g_ema_handle = iMA(m_symbol, TrendTimeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_handle = iATR(m_symbol, m_chartTF, ATR_Period);
   
   if(g_ema_handle == INVALID_HANDLE)
   {
      Dbg("Failed to create EMA handle");
      return INIT_FAILED;
   }
   if(g_atr_handle == INVALID_HANDLE)
   {
      Dbg("Failed to create ATR handle");
      return INIT_FAILED;
   }
   
   // Initialize arrays
   ArrayResize(g_bullZones, 0);
   ArrayResize(g_bearZones, 0);
   ArrayResize(g_partialTPDone, 0);
   
   // Validate session times
   int s1=0,e1=0,s2=0,e2=0,ns=0,ne=0;
   if(UseSessions)
   {
      if(!ParseHHMM(Session1_Start,s1) || !ParseHHMM(Session1_End,e1) ||
         !ParseHHMM(Session2_Start,s2) || !ParseHHMM(Session2_End,e2))
      {
         Dbg("Invalid session time format. Use HH:MM format.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(UseNewsFilter)
   {
      if(!ParseHHMM(NewsStartTime,ns) || !ParseHHMM(NewsEndTime,ne))
      {
         Dbg("Invalid news time format. Use HH:MM format.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   
   Dbg("SmartOrderBlocks EA initialized on " + m_symbol + " " + EnumToString(m_chartTF));
   Dbg("Trend EMA: " + IntegerToString(EMA_Period) + " on " + EnumToString(TrendTimeframe));
   Dbg("Risk: " + DoubleToString(RiskPercent,1) + "%, RR: " + DoubleToString(RR_Target,1) + ", Sessions: " + (UseSessions?"ON":"OFF"));
   Dbg("News Filter: " + (UseNewsFilter?"ON (" + NewsStartTime + "-" + NewsEndTime + ")":"OFF"));
   Dbg("Max Spread: " + IntegerToString(MaxSpreadPoints) + " points");
   Dbg("Breaker Blocks: " + (UseBreakerBlocks?"ON":"OFF (Testing)"));
   Dbg("Quality Filters - Body/ATR: " + DoubleToString(BodyToATR_Min,1) + ", Impulse/ATR: " + DoubleToString(ImpulseToATR_Min,1));
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Release indicator handles
   if(g_ema_handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ema_handle);
      g_ema_handle = INVALID_HANDLE;
   }
   if(g_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atr_handle);
      g_atr_handle = INVALID_HANDLE;
   }
   
   // Clean up chart objects
   if(ShowZones)
   {
      for(int i=ObjectsTotal(0,-1,-1)-1; i>=0; i--)
      {
         string name = ObjectName(0,i,-1,-1);
         if(StringFind(name,"SOB_ZONE_")>=0) ObjectDelete(0,name);
      }
   }
   
   // Clear arrays
   ArrayResize(g_partialTPDone, 0);
   
   Dbg("SmartOrderBlocks EA deinitialized, reason: " + IntegerToString(reason));
}

void OnTick()
{
   // Check for new bar
   if(IsNewBar())
   {
      ProcessNewBar(1); // process last closed bar
   }
   
   // Manage open positions on every tick
   ManageOpenPositions();
   
   // Update zone drawings
   if(ShowZones)
   {
      for(int i=0; i<ArraySize(g_bullZones); i++) DrawZone(g_bullZones[i]);
      for(int i=0; i<ArraySize(g_bearZones); i++) DrawZone(g_bearZones[i]);
   }
}

/*
=============================================================================
HOW TO BACKTEST:
=============================================================================
1. Symbol/Timeframe: Choose liquid pairs (EURUSD, GBPUSD) on H1 or H4
2. Modeling: Use "Every tick based on real ticks" for most accurate results
3. Period: Test on at least 6-12 months of data
4. Sessions: Ensure BrokerGMTOffset matches your broker's server time
5. News Filter: Set NewsStartTime/NewsEndTime for manual news avoidance (HH:MM format)
6. Spread: Adjust MaxSpreadPoints based on your broker (default 30 points)
7. Optimization: Start with default parameters, then optimize RiskPercent, RR_Target, EMA_Period
8. Risk Management: Test UseBreakEven, UsePartialTP, and TrailMode settings

=============================================================================
LIMITATIONS & TIPS:
=============================================================================
1. News Filter: Now uses manual time windows (NewsStartTime to NewsEndTime)
2. Slippage: Increase MaxSlippagePoints for volatile markets
3. Spread Filter: EA automatically blocks entries when spread > MaxSpreadPoints
4. Freeze Level: EA checks minimum distance before modifying SL/TP
5. Partial TP: Executes only once per position to prevent over-closing
6. Breaker Blocks: Advanced feature - test with UseBreakerBlocks=false first
7. Volume Filter: Not all brokers provide reliable volume data
8. Sessions: Adjust BrokerGMTOffset and SessionTZOffset for your broker
9. Risk: Start with RiskPercent=0.5% for conservative testing
10. Optimization: Don't over-optimize - focus on robust parameter ranges
11. Live Trading: Test on demo first, monitor during different market conditions
12. Performance: Indicator handles are created once for better efficiency
13. Market Orders: Uses market price (0.0) for better execution reliability
14. OB Selection: Finds the LAST opposite candle before impulse for accuracy

News Filter Setup (Manual):
- Set UseNewsFilter=true
- Configure NewsStartTime and NewsEndTime in HH:MM format
- EA will block new entries during this time window
- Existing positions continue to be managed normally

Spread Management:
- Monitor MaxSpreadPoints setting during volatile sessions
- Increase value for news events or low liquidity periods
- EA logs spread rejections for analysis
=============================================================================
*/