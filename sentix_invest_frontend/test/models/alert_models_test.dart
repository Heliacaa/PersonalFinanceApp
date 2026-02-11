import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/features/alert/data/alert_models.dart';

void main() {
  group('PriceAlert', () {
    test('fromJson parses all fields including new alert types', () {
      final json = {
        'id': 'alert-1',
        'symbol': 'AAPL',
        'stockName': 'Apple Inc.',
        'targetPrice': 200.0,
        'currentPrice': 175.0,
        'alertType': 'ABOVE',
        'isActive': true,
        'createdAt': '2024-01-15T10:00:00',
        'triggeredAt': null,
        'referencePrice': 150.0,
        'daysNotice': 7,
      };

      final alert = PriceAlert.fromJson(json);

      expect(alert.id, 'alert-1');
      expect(alert.symbol, 'AAPL');
      expect(alert.stockName, 'Apple Inc.');
      expect(alert.targetPrice, 200.0);
      expect(alert.currentPrice, 175.0);
      expect(alert.alertType, 'ABOVE');
      expect(alert.isActive, true);
      expect(alert.createdAt, isNotNull);
      expect(alert.triggeredAt, isNull);
      expect(alert.referencePrice, 150.0);
      expect(alert.daysNotice, 7);
    });

    test('isAbove / isBelow / isPercent type checks', () {
      PriceAlert makeAlert(String type) => PriceAlert(
            id: '1',
            symbol: 'AAPL',
            stockName: 'Apple',
            targetPrice: 200,
            currentPrice: 175,
            alertType: type,
            isActive: true,
          );

      expect(makeAlert('ABOVE').isAbove, true);
      expect(makeAlert('ABOVE').isBelow, false);
      expect(makeAlert('BELOW').isBelow, true);
      expect(makeAlert('PERCENT_CHANGE').isPercent, true);
      expect(makeAlert('EARNINGS_REMINDER').isEarnings, true);
      expect(makeAlert('DIVIDEND_PAYMENT').isDividend, true);
    });

    test('percentToTarget calculates correctly for ABOVE', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 100.0,
        alertType: 'ABOVE',
        isActive: true,
      );
      // (200-100)/100 * 100 = 100%
      expect(alert.percentToTarget, 100.0);
    });

    test('percentToTarget returns 0 for earnings/dividend types', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 175.0,
        alertType: 'EARNINGS_REMINDER',
        isActive: true,
      );
      expect(alert.percentToTarget, 0);
    });

    test('wouldTrigger returns true when ABOVE target met', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 150.0,
        currentPrice: 175.0,
        alertType: 'ABOVE',
        isActive: true,
      );
      expect(alert.wouldTrigger, true);
    });

    test('wouldTrigger returns false when ABOVE target not met', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 175.0,
        alertType: 'ABOVE',
        isActive: true,
      );
      expect(alert.wouldTrigger, false);
    });

    test('wouldTrigger returns true when BELOW target met', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 175.0,
        alertType: 'BELOW',
        isActive: true,
      );
      expect(alert.wouldTrigger, true);
    });

    test('wouldTrigger for PERCENT_CHANGE type', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 10.0, // 10% threshold
        currentPrice: 165.0,
        alertType: 'PERCENT_CHANGE',
        isActive: true,
        referencePrice: 150.0,
      );
      // |165-150|/150 * 100 = 10%, which >= 10% target → true
      expect(alert.wouldTrigger, true);
    });

    test('wouldTrigger returns false for EARNINGS_REMINDER', () {
      final alert = PriceAlert(
        id: '1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 250.0,
        alertType: 'EARNINGS_REMINDER',
        isActive: true,
      );
      expect(alert.wouldTrigger, false);
    });

    test('toJson produces correct map', () {
      final alert = PriceAlert(
        id: 'alert-1',
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        currentPrice: 175.0,
        alertType: 'ABOVE',
        isActive: true,
        referencePrice: 150.0,
        daysNotice: 5,
      );

      final json = alert.toJson();
      expect(json['id'], 'alert-1');
      expect(json['symbol'], 'AAPL');
      expect(json['alertType'], 'ABOVE');
      expect(json['referencePrice'], 150.0);
      expect(json['daysNotice'], 5);
    });
  });

  group('CreateAlertRequest', () {
    test('toJson includes all fields', () {
      final request = CreateAlertRequest(
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        alertType: 'ABOVE',
        referencePrice: 175.0,
        daysNotice: 7,
      );

      final json = request.toJson();
      expect(json['symbol'], 'AAPL');
      expect(json['stockName'], 'Apple');
      expect(json['targetPrice'], 200.0);
      expect(json['alertType'], 'ABOVE');
      expect(json['referencePrice'], 175.0);
      expect(json['daysNotice'], 7);
    });

    test('toJson omits null optional fields', () {
      final request = CreateAlertRequest(
        symbol: 'AAPL',
        stockName: 'Apple',
        targetPrice: 200.0,
        alertType: 'BELOW',
      );

      final json = request.toJson();
      expect(json['referencePrice'], isNull);
      expect(json['daysNotice'], isNull);
    });
  });
}
