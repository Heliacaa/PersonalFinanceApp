import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/features/watchlist/data/watchlist_models.dart';

void main() {
  group('WatchlistItem', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'watch-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'addedAt': '2024-06-15T10:30:00',
        'currentPrice': 175.50,
        'change': 2.30,
        'changePercent': 1.33,
        'currency': 'USD',
      };

      final item = WatchlistItem.fromJson(json);

      expect(item.id, 'watch-1');
      expect(item.symbol, 'AAPL');
      expect(item.stockName, 'Apple Inc.');
      expect(item.addedAt.year, 2024);
      expect(item.addedAt.month, 6);
      expect(item.currentPrice, 175.50);
      expect(item.change, 2.30);
      expect(item.changePercent, 1.33);
      expect(item.currency, 'USD');
    });

    test('isPositive returns true for positive change', () {
      final item = WatchlistItem(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        addedAt: DateTime.now(),
        change: 2.5,
      );
      expect(item.isPositive, true);
    });

    test('isPositive returns true for zero change', () {
      final item = WatchlistItem(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        addedAt: DateTime.now(),
        change: 0.0,
      );
      expect(item.isPositive, true);
    });

    test('isPositive returns false for negative change', () {
      final item = WatchlistItem(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        addedAt: DateTime.now(),
        change: -1.5,
      );
      expect(item.isPositive, false);
    });

    test('isPositive returns true when change is null', () {
      final item = WatchlistItem(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        addedAt: DateTime.now(),
      );
      // (null ?? 0) >= 0 → true
      expect(item.isPositive, true);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'watch-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'addedAt': '2024-06-15T10:30:00',
      };

      final item = WatchlistItem.fromJson(json);

      expect(item.currentPrice, isNull);
      expect(item.change, isNull);
      expect(item.changePercent, isNull);
      expect(item.currency, isNull);
    });

    test('fromJson uses current datetime when addedAt is null', () {
      final before = DateTime.now();
      final item = WatchlistItem.fromJson({
        'id': '1',
        'symbol': 'AAPL',
        'stockName': 'Apple',
      });
      final after = DateTime.now();

      expect(item.addedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          true);
      expect(item.addedAt.isBefore(after.add(const Duration(seconds: 1))),
          true);
    });
  });
}
