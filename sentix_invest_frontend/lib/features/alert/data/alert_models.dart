class PriceAlert {
  final String id;
  final String symbol;
  final String stockName;
  final double targetPrice;
  final double currentPrice;
  final String
  alertType; // ABOVE, BELOW, PERCENT_CHANGE, EARNINGS_REMINDER, DIVIDEND_PAYMENT
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? triggeredAt;
  final double? referencePrice;
  final int? daysNotice;

  PriceAlert({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.targetPrice,
    required this.currentPrice,
    required this.alertType,
    required this.isActive,
    this.createdAt,
    this.triggeredAt,
    this.referencePrice,
    this.daysNotice,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      targetPrice: (json['targetPrice'] ?? 0).toDouble(),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      alertType: json['alertType'] ?? 'ABOVE',
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      triggeredAt: json['triggeredAt'] != null
          ? DateTime.parse(json['triggeredAt'])
          : null,
      referencePrice: json['referencePrice']?.toDouble(),
      daysNotice: json['daysNotice'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'stockName': stockName,
      'targetPrice': targetPrice,
      'currentPrice': currentPrice,
      'alertType': alertType,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'triggeredAt': triggeredAt?.toIso8601String(),
      'referencePrice': referencePrice,
      'daysNotice': daysNotice,
    };
  }

  bool get isAbove => alertType == 'ABOVE';
  bool get isBelow => alertType == 'BELOW';
  bool get isPercent => alertType == 'PERCENT_CHANGE';
  bool get isEarnings => alertType == 'EARNINGS_REMINDER';
  bool get isDividend => alertType == 'DIVIDEND_PAYMENT';

  /// Calculate how close the current price is to the target
  double get percentToTarget {
    if (currentPrice == 0 || isEarnings || isDividend) return 0;
    return ((targetPrice - currentPrice) / currentPrice) * 100;
  }

  /// Check if alert condition would be triggered now
  bool get wouldTrigger {
    if (isEarnings || isDividend) return false; // Can't check locally easily

    if (alertType == 'ABOVE') {
      return currentPrice >= targetPrice;
    } else if (alertType == 'BELOW') {
      return currentPrice <= targetPrice;
    } else if (alertType == 'PERCENT_CHANGE' && referencePrice != null) {
      final diff = (currentPrice - referencePrice!).abs();
      final percent = (diff / referencePrice!) * 100;
      return percent >= targetPrice;
    }
    return false;
  }
}

class CreateAlertRequest {
  final String symbol;
  final String stockName;
  final double targetPrice;
  final String alertType;
  final double? referencePrice;
  final int? daysNotice;

  CreateAlertRequest({
    required this.symbol,
    required this.stockName,
    required this.targetPrice,
    required this.alertType,
    this.referencePrice,
    this.daysNotice,
  });

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'stockName': stockName,
      'targetPrice': targetPrice,
      'alertType': alertType,
      'referencePrice': referencePrice,
      'daysNotice': daysNotice,
    };
  }
}
