class PortfolioHolding {
  final String id;
  final String symbol;
  final String stockName;
  final int quantity;
  final double averagePurchasePrice;
  final double currentPrice;
  final double currentValue;
  final double totalCostBasis;
  final double profitLoss;
  final double profitLossPercent;
  final String currency;
  final double? valueInPreferredCurrency;

  PortfolioHolding({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.quantity,
    required this.averagePurchasePrice,
    required this.currentPrice,
    required this.currentValue,
    required this.totalCostBasis,
    required this.profitLoss,
    required this.profitLossPercent,
    required this.currency,
    this.valueInPreferredCurrency,
  });

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) {
    return PortfolioHolding(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      quantity: json['quantity'] ?? 0,
      averagePurchasePrice: (json['averagePurchasePrice'] ?? 0).toDouble(),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      currentValue: (json['currentValue'] ?? 0).toDouble(),
      totalCostBasis: (json['totalCostBasis'] ?? 0).toDouble(),
      profitLoss: (json['profitLoss'] ?? 0).toDouble(),
      profitLossPercent: (json['profitLossPercent'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'TRY',
      valueInPreferredCurrency:
          json['valueInPreferredCurrency']?.toDouble(),
    );
  }

  bool get isProfit => profitLoss >= 0;
}

class AllocationItem {
  final String symbol;
  final String stockName;
  final double value;
  final double percentage;

  AllocationItem({
    required this.symbol,
    required this.stockName,
    required this.value,
    required this.percentage,
  });

  factory AllocationItem.fromJson(Map<String, dynamic> json) {
    return AllocationItem(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class PortfolioSummary {
  final double totalValue;
  final double totalCostBasis;
  final double totalProfitLoss;
  final double totalProfitLossPercent;
  final double cashBalance;
  final int holdingsCount;
  final List<AllocationItem> allocations;
  final String? displayCurrency;

  PortfolioSummary({
    required this.totalValue,
    required this.totalCostBasis,
    required this.totalProfitLoss,
    required this.totalProfitLossPercent,
    required this.cashBalance,
    required this.holdingsCount,
    required this.allocations,
    this.displayCurrency,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      totalCostBasis: (json['totalCostBasis'] ?? 0).toDouble(),
      totalProfitLoss: (json['totalProfitLoss'] ?? 0).toDouble(),
      totalProfitLossPercent: (json['totalProfitLossPercent'] ?? 0).toDouble(),
      cashBalance: (json['cashBalance'] ?? 0).toDouble(),
      holdingsCount: json['holdingsCount'] ?? 0,
      allocations:
          (json['allocations'] as List<dynamic>?)
              ?.map((e) => AllocationItem.fromJson(e))
              .toList() ??
          [],
      displayCurrency: json['displayCurrency'],
    );
  }

  bool get isProfit => totalProfitLoss >= 0;
}

class Transaction {
  final String id;
  final String symbol;
  final String stockName;
  final String type;
  final int quantity;
  final double pricePerShare;
  final double totalAmount;
  final String currency;
  final DateTime executedAt;

  Transaction({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.type,
    required this.quantity,
    required this.pricePerShare,
    required this.totalAmount,
    required this.currency,
    required this.executedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      type: json['type'] ?? '',
      quantity: json['quantity'] ?? 0,
      pricePerShare: (json['pricePerShare'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'TRY',
      executedAt: json['executedAt'] != null
          ? DateTime.parse(json['executedAt'])
          : DateTime.now(),
    );
  }

  bool get isBuy => type == 'BUY';
}
