import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/features/portfolio/data/portfolio_models.dart';

void main() {
  group('PortfolioHolding', () {
    test('fromJson parses all fields including valueInPreferredCurrency', () {
      final json = {
        'id': 'hold-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'quantity': 10,
        'averagePurchasePrice': 150.0,
        'currentPrice': 175.0,
        'currentValue': 1750.0,
        'totalCostBasis': 1500.0,
        'profitLoss': 250.0,
        'profitLossPercent': 16.67,
        'currency': 'USD',
        'valueInPreferredCurrency': 53200.0,
      };

      final holding = PortfolioHolding.fromJson(json);

      expect(holding.id, 'hold-1');
      expect(holding.symbol, 'AAPL');
      expect(holding.stockName, 'Apple Inc.');
      expect(holding.quantity, 10);
      expect(holding.averagePurchasePrice, 150.0);
      expect(holding.currentPrice, 175.0);
      expect(holding.currentValue, 1750.0);
      expect(holding.totalCostBasis, 1500.0);
      expect(holding.profitLoss, 250.0);
      expect(holding.profitLossPercent, 16.67);
      expect(holding.currency, 'USD');
      expect(holding.valueInPreferredCurrency, 53200.0);
    });

    test('valueInPreferredCurrency is null when not provided', () {
      final json = {
        'id': 'hold-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'quantity': 10,
        'averagePurchasePrice': 150.0,
        'currentPrice': 175.0,
        'currentValue': 1750.0,
        'totalCostBasis': 1500.0,
        'profitLoss': 250.0,
        'profitLossPercent': 16.67,
        'currency': 'USD',
      };

      final holding = PortfolioHolding.fromJson(json);
      expect(holding.valueInPreferredCurrency, isNull);
    });

    test('isProfit returns true for positive profit', () {
      final holding = PortfolioHolding(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        quantity: 10,
        averagePurchasePrice: 100.0,
        currentPrice: 120.0,
        currentValue: 1200.0,
        totalCostBasis: 1000.0,
        profitLoss: 200.0,
        profitLossPercent: 20.0,
        currency: 'USD',
      );
      expect(holding.isProfit, true);
    });

    test('isProfit returns true for zero profit', () {
      final holding = PortfolioHolding(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        quantity: 10,
        averagePurchasePrice: 100.0,
        currentPrice: 100.0,
        currentValue: 1000.0,
        totalCostBasis: 1000.0,
        profitLoss: 0.0,
        profitLossPercent: 0.0,
        currency: 'USD',
      );
      expect(holding.isProfit, true);
    });

    test('isProfit returns false for negative profit', () {
      final holding = PortfolioHolding(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        quantity: 10,
        averagePurchasePrice: 100.0,
        currentPrice: 80.0,
        currentValue: 800.0,
        totalCostBasis: 1000.0,
        profitLoss: -200.0,
        profitLossPercent: -20.0,
        currency: 'USD',
      );
      expect(holding.isProfit, false);
    });
  });

  group('PortfolioSummary', () {
    test('fromJson parses displayCurrency field', () {
      final json = {
        'totalValue': 10000.0,
        'totalCostBasis': 8000.0,
        'totalProfitLoss': 2000.0,
        'totalProfitLossPercent': 25.0,
        'cashBalance': 5000.0,
        'holdingsCount': 3,
        'allocations': [],
        'displayCurrency': 'EUR',
      };

      final summary = PortfolioSummary.fromJson(json);

      expect(summary.totalValue, 10000.0);
      expect(summary.totalCostBasis, 8000.0);
      expect(summary.totalProfitLoss, 2000.0);
      expect(summary.totalProfitLossPercent, 25.0);
      expect(summary.cashBalance, 5000.0);
      expect(summary.holdingsCount, 3);
      expect(summary.displayCurrency, 'EUR');
    });

    test('displayCurrency is null when not provided', () {
      final json = {
        'totalValue': 10000.0,
        'totalCostBasis': 8000.0,
        'totalProfitLoss': 2000.0,
        'totalProfitLossPercent': 25.0,
        'cashBalance': 5000.0,
        'holdingsCount': 3,
        'allocations': [],
      };

      final summary = PortfolioSummary.fromJson(json);
      expect(summary.displayCurrency, isNull);
    });

    test('isProfit works correctly', () {
      final profit = PortfolioSummary(
        totalValue: 10000,
        totalCostBasis: 8000,
        totalProfitLoss: 2000,
        totalProfitLossPercent: 25,
        cashBalance: 5000,
        holdingsCount: 3,
        allocations: [],
      );
      expect(profit.isProfit, true);

      final loss = PortfolioSummary(
        totalValue: 7000,
        totalCostBasis: 8000,
        totalProfitLoss: -1000,
        totalProfitLossPercent: -12.5,
        cashBalance: 5000,
        holdingsCount: 3,
        allocations: [],
      );
      expect(loss.isProfit, false);
    });

    test('allocations parse correctly', () {
      final json = {
        'totalValue': 10000.0,
        'totalCostBasis': 8000.0,
        'totalProfitLoss': 2000.0,
        'totalProfitLossPercent': 25.0,
        'cashBalance': 5000.0,
        'holdingsCount': 2,
        'allocations': [
          {
            'symbol': 'AAPL',
            'stockName': 'Apple',
            'value': 6000.0,
            'percentage': 60.0,
          },
          {
            'symbol': 'GOOG',
            'stockName': 'Google',
            'value': 4000.0,
            'percentage': 40.0,
          },
        ],
      };

      final summary = PortfolioSummary.fromJson(json);

      expect(summary.allocations.length, 2);
      expect(summary.allocations[0].symbol, 'AAPL');
      expect(summary.allocations[0].percentage, 60.0);
      expect(summary.allocations[1].symbol, 'GOOG');
      expect(summary.allocations[1].value, 4000.0);
    });
  });

  group('Transaction', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'tx-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'type': 'BUY',
        'quantity': 5,
        'pricePerShare': 150.0,
        'totalAmount': 750.0,
        'currency': 'USD',
        'executedAt': '2024-01-15T10:30:00',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.id, 'tx-1');
      expect(tx.symbol, 'AAPL');
      expect(tx.type, 'BUY');
      expect(tx.quantity, 5);
      expect(tx.pricePerShare, 150.0);
      expect(tx.totalAmount, 750.0);
      expect(tx.currency, 'USD');
      expect(tx.isBuy, true);
    });

    test('isBuy returns false for SELL', () {
      final json = {
        'id': 'tx-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'type': 'SELL',
        'quantity': 5,
        'pricePerShare': 150.0,
        'totalAmount': 750.0,
        'currency': 'USD',
        'executedAt': '2024-01-15T10:30:00',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.isBuy, false);
    });
  });

  group('AllocationItem', () {
    test('fromJson parses correctly', () {
      final json = {
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'value': 5000.0,
        'percentage': 45.5,
      };

      final item = AllocationItem.fromJson(json);

      expect(item.symbol, 'AAPL');
      expect(item.stockName, 'Apple Inc.');
      expect(item.value, 5000.0);
      expect(item.percentage, 45.5);
    });

    test('fromJson handles defaults on missing fields', () {
      final item = AllocationItem.fromJson({});

      expect(item.symbol, '');
      expect(item.stockName, '');
      expect(item.value, 0.0);
      expect(item.percentage, 0.0);
    });
  });
}
