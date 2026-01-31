class PriceAlert {
  final String id;
  final String symbol;
  final String stockName;
  final double targetPrice;
  final double currentPrice;
  final String alertType; // ABOVE or BELOW
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? triggeredAt;

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
    };
  }

  bool get isAbove => alertType == 'ABOVE';
  bool get isBelow => alertType == 'BELOW';

  /// Calculate how close the current price is to the target
  double get percentToTarget {
    if (currentPrice == 0) return 0;
    return ((targetPrice - currentPrice) / currentPrice) * 100;
  }

  /// Check if alert condition would be triggered now
  bool get wouldTrigger {
    if (alertType == 'ABOVE') {
      return currentPrice >= targetPrice;
    } else {
      return currentPrice <= targetPrice;
    }
  }
}

class CreateAlertRequest {
  final String symbol;
  final String stockName;
  final double targetPrice;
  final String alertType;

  CreateAlertRequest({
    required this.symbol,
    required this.stockName,
    required this.targetPrice,
    required this.alertType,
  });

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'stockName': stockName,
      'targetPrice': targetPrice,
      'alertType': alertType,
    };
  }
}
