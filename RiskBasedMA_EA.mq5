//+------------------------------------------------------------------+
//|                                             RiskBasedMA_EA.mq5   |
//|                                                      EA demo     |
//+------------------------------------------------------------------+
#property copyright "Quantrise_dev"
#property link      "https://github.com/quantrisedev/mt5-ma-crossover-ea"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- input parameters
input int            FastMAPeriod     = 10;
input int            SlowMAPeriod     = 20;
input ENUM_MA_METHOD MAMethod         = MODE_EMA;
input ENUM_TIMEFRAMES Timeframe       = PERIOD_CURRENT;
input double         RiskPercent      = 1.0;      // Risk % of balance per trade
input double         StopLossPips     = 50;       // Stop loss in pips
input double         TakeProfitPips   = 100;      // Take profit in pips
input long           MagicNumber      = 20250101;
input int            SlippagePoints   = 10;
input string         TradeComment     = "RiskBased MA EA";

//--- global variables
int      fastMAHandle = INVALID_HANDLE;
int      slowMAHandle = INVALID_HANDLE;
int      digits       = 5;
double   point        = 0.00001;
int      pointsPerPip = 10;
datetime lastBarTime  = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   digits       = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   point        = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   pointsPerPip = (digits == 3 || digits == 5) ? 10 : 1;

   fastMAHandle = iMA(_Symbol, Timeframe, FastMAPeriod, 0, MAMethod, PRICE_CLOSE);
   slowMAHandle = iMA(_Symbol, Timeframe, SlowMAPeriod, 0, MAMethod, PRICE_CLOSE);

   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE)
   {
      Print("Failed to create MA handles. Error: ", GetLastError());
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetAsyncMode(false);

   Print("RiskBasedMA_EA initialized on ", _Symbol, " TF: ", EnumToString(Timeframe));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastMAHandle != INVALID_HANDLE) IndicatorRelease(fastMAHandle);
   if(slowMAHandle != INVALID_HANDLE) IndicatorRelease(slowMAHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- only trade on new bar
   datetime currentBarTime = iTime(_Symbol, Timeframe, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   double fast1[1], fast2[1], slow1[1], slow2[1];
   if(CopyBuffer(fastMAHandle, 0, 1, 1, fast1) <= 0) return;
   if(CopyBuffer(fastMAHandle, 0, 2, 1, fast2) <= 0) return;
   if(CopyBuffer(slowMAHandle, 0, 1, 1, slow1) <= 0) return;
   if(CopyBuffer(slowMAHandle, 0, 2, 1, slow2) <= 0) return;

   //--- crossover detection (using closed bar 1 and previous bar 2)
   bool buySignal  = (fast1[0] > slow1[0] && fast2[0] <= slow2[0]);
   bool sellSignal = (fast1[0] < slow1[0] && fast2[0] >= slow2[0]);

   if(buySignal)       OpenBuy();
   else if(sellSignal) OpenSell();
}

//+------------------------------------------------------------------+
//| Close all positions opened by this EA                            |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size from risk %                                   |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPriceDist)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickValue <= 0 || tickSize <= 0 || slPriceDist <= 0) return minLot;

   double lossPerLot = (slPriceDist / tickSize) * tickValue;
   if(lossPerLot <= 0) return minLot;

   double lot = riskMoney / lossPerLot;
   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return lot;
}

//+------------------------------------------------------------------+
//| Adjust SL/TP to respect broker stop level                        |
//+------------------------------------------------------------------+
void AdjustStops(double &sl, double &tp, bool isBuy)
{
   int    stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = stopsLevel * point;
   double price      = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(isBuy)
   {
      if(price - sl < minDist) sl = price - minDist - point;
      if(tp - price < minDist) tp = price + minDist + point;
   }
   else
   {
      if(sl - price < minDist) sl = price + minDist + point;
      if(price - tp < minDist) tp = price - minDist - point;
   }
}

//+------------------------------------------------------------------+
//| Open Buy                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   CloseAllPositions();

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slDist = StopLossPips * pointsPerPip * point;
   double tpDist = TakeProfitPips * pointsPerPip * point;

   double sl = NormalizeDouble(ask - slDist, digits);
   double tp = NormalizeDouble(ask + tpDist, digits);
   AdjustStops(sl, tp, true);

   double lot = CalculateLotSize(slDist);
   bool result = trade.Buy(lot, _Symbol, 0, sl, tp, TradeComment);

   if(!result)
      Print("Buy failed. Retcode: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   else
      Print("Buy opened. Lot: ", lot, " SL: ", sl, " TP: ", tp);
}

//+------------------------------------------------------------------+
//| Open Sell                                                        |
//+------------------------------------------------------------------+
void OpenSell()
{
   CloseAllPositions();

   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = StopLossPips * pointsPerPip * point;
   double tpDist = TakeProfitPips * pointsPerPip * point;

   double sl = NormalizeDouble(bid + slDist, digits);
   double tp = NormalizeDouble(bid - tpDist, digits);
   AdjustStops(sl, tp, false);

   double lot = CalculateLotSize(slDist);
   bool result = trade.Sell(lot, _Symbol, 0, sl, tp, TradeComment);

   if(!result)
      Print("Sell failed. Retcode: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   else
      Print("Sell opened. Lot: ", lot, " SL: ", sl, " TP: ", tp);
}
//+------------------------------------------------------------------+
