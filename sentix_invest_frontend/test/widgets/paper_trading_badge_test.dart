import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/features/market/data/market_models.dart';
import 'package:sentix_invest_frontend/features/portfolio/data/portfolio_models.dart';
import 'package:sentix_invest_frontend/features/trading/presentation/buy_stock_screen.dart';
import 'package:sentix_invest_frontend/features/trading/presentation/sell_stock_screen.dart';

StockQuote _testStock() => StockQuote(
      symbol: 'AAPL',
      name: 'Apple Inc.',
      price: 175.0,
      change: 2.5,
      changePercent: 1.45,
      currency: 'USD',
      marketState: 'REGULAR',
      timestamp: '2024-01-15T10:30:00',
    );

PortfolioHolding _testHolding() => PortfolioHolding(
      id: 'hold-1',
      symbol: 'AAPL',
      stockName: 'Apple Inc.',
      quantity: 10,
      averagePurchasePrice: 150.0,
      currentPrice: 175.0,
      currentValue: 1750.0,
      totalCostBasis: 1500.0,
      profitLoss: 250.0,
      profitLossPercent: 16.67,
      currency: 'USD',
    );

void main() {
  group('BuyStockScreen paper mode badge', () {
    testWidgets('shows PAPER badge when isPaperTrading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BuyStockScreen(
            stock: _testStock(),
            availableBalance: 10000.0,
            isPaperTrading: true,
          ),
        ),
      );

      expect(find.text('PAPER'), findsOneWidget);
      expect(find.text('Buy AAPL'), findsOneWidget);
    });

    testWidgets('does not show PAPER badge when isPaperTrading is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BuyStockScreen(
            stock: _testStock(),
            availableBalance: 10000.0,
            isPaperTrading: false,
          ),
        ),
      );

      expect(find.text('PAPER'), findsNothing);
      expect(find.text('Buy AAPL'), findsOneWidget);
    });
  });

  group('SellStockScreen paper mode badge', () {
    testWidgets('shows PAPER badge when isPaperTrading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SellStockScreen(
            holding: _testHolding(),
            isPaperTrading: true,
          ),
        ),
      );

      expect(find.text('PAPER'), findsOneWidget);
      expect(find.text('Sell AAPL'), findsOneWidget);
    });

    testWidgets('does not show PAPER badge when isPaperTrading is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SellStockScreen(
            holding: _testHolding(),
            isPaperTrading: false,
          ),
        ),
      );

      expect(find.text('PAPER'), findsNothing);
      expect(find.text('Sell AAPL'), findsOneWidget);
    });
  });
}
