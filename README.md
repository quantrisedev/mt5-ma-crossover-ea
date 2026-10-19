# MT5 Risk-Based Moving Average Crossover EA (MQL5)

A clean, commented MT5 Expert Advisor built as a demo project for MQL5 freelancing.

## Features
- Fast/Slow MA crossover signals (default EMA 200/50)
- Risk-based lot sizing (risk % of account balance per trade)
- Stop Loss and Take Profit in pips
- Respects broker stop level and symbol digits (3-digit / 5-digit brokers)
- Closes existing EA-managed positions before opening a new one
- Uses `CTrade` for reliable order execution
- Magic number + trade comment for tracking

## Inputs
| Input | Default | Description |
|-------|---------|-------------|
| FastMAPeriod | 200 | Fast MA period |
| SlowMAPeriod | 50 | Slow MA period |
| MAMethod | MODE_EMA | Moving average method |
| Timeframe | PERIOD_CURRENT | Working timeframe |
| RiskPercent | 1.0 | % of balance risked per trade |
| StopLossPips | 50 | Stop loss in pips |
| TakeProfitPips | 100 | Take profit in pips |
| MagicNumber | 20250101 | EA magic number |
| SlippagePoints | 10 | Allowed slippage in points |
| TradeComment | "Quant_MA EA" | Comment on orders |

## Installation
1. Copy `RiskBasedMA_EA.mq5` to: `MT5_data_folder/MQL5/Experts/`
2. Open MetaEditor, compile the file (F7).
3. Attach the EA to a chart in MT5 and enable Algo Trading.
4. Adjust inputs. Test in Strategy Tester before live use.

## Disclaimer
This is a demonstration/reference EA for code-quality purposes. It is not financial advice and does not guarantee profits. Always backtest and forward-test on a demo account.

## Author
Quantrise_dev — [https://github.com/quantrisedev)] — available for MQL5 freelance projects.
