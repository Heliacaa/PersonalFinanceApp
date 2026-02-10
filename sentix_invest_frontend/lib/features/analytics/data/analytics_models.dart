/// Models for portfolio analytics feature
library;

class PortfolioPerformance {
  final double currentValue;
  final double totalInvested;
  final double totalReturn;
  final double totalReturnPercent;
  final double dayChange;
  final double dayChangePercent;
  final List<PerformanceDataPoint> performanceHistory;
  final List<AllocationByStock> allocationByStock;
  final List<AllocationBySector> allocationBySector;

  PortfolioPerformance({
    required this.currentValue,
    required this.totalInvested,
    required this.totalReturn,
    required this.totalReturnPercent,
    required this.dayChange,
    required this.dayChangePercent,
    required this.performanceHistory,
    required this.allocationByStock,
    required this.allocationBySector,
  });

  factory PortfolioPerformance.fromJson(Map<String, dynamic> json) {
    return PortfolioPerformance(
      currentValue: (json['currentValue'] ?? 0).toDouble(),
      totalInvested: (json['totalInvested'] ?? 0).toDouble(),
      totalReturn: (json['totalReturn'] ?? 0).toDouble(),
      totalReturnPercent: (json['totalReturnPercent'] ?? 0).toDouble(),
      dayChange: (json['dayChange'] ?? 0).toDouble(),
      dayChangePercent: (json['dayChangePercent'] ?? 0).toDouble(),
      performanceHistory: (json['performanceHistory'] as List? ?? [])
          .map((e) => PerformanceDataPoint.fromJson(e))
          .toList(),
      allocationByStock: (json['allocationByStock'] as List? ?? [])
          .map((e) => AllocationByStock.fromJson(e))
          .toList(),
      allocationBySector: (json['allocationBySector'] as List? ?? [])
          .map((e) => AllocationBySector.fromJson(e))
          .toList(),
    );
  }

  bool get isPositive => totalReturn >= 0;
  bool get isDayPositive => dayChange >= 0;
}

class PerformanceDataPoint {
  final DateTime date;
  final double portfolioValue;
  final double dailyReturn;
  final double cumulativeReturn;

  PerformanceDataPoint({
    required this.date,
    required this.portfolioValue,
    required this.dailyReturn,
    required this.cumulativeReturn,
  });

  factory PerformanceDataPoint.fromJson(Map<String, dynamic> json) {
    return PerformanceDataPoint(
      date: DateTime.parse(json['date']),
      portfolioValue: (json['portfolioValue'] ?? 0).toDouble(),
      dailyReturn: (json['dailyReturn'] ?? 0).toDouble(),
      cumulativeReturn: (json['cumulativeReturn'] ?? 0).toDouble(),
    );
  }
}

class AllocationByStock {
  final String symbol;
  final String stockName;
  final double value;
  final double percentage;
  final double profitLoss;
  final double profitLossPercent;

  AllocationByStock({
    required this.symbol,
    required this.stockName,
    required this.value,
    required this.percentage,
    required this.profitLoss,
    required this.profitLossPercent,
  });

  factory AllocationByStock.fromJson(Map<String, dynamic> json) {
    return AllocationByStock(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      profitLoss: (json['profitLoss'] ?? 0).toDouble(),
      profitLossPercent: (json['profitLossPercent'] ?? 0).toDouble(),
    );
  }

  bool get isPositive => profitLoss >= 0;
}

class AllocationBySector {
  final String sector;
  final double value;
  final double percentage;
  final int stockCount;

  AllocationBySector({
    required this.sector,
    required this.value,
    required this.percentage,
    required this.stockCount,
  });

  factory AllocationBySector.fromJson(Map<String, dynamic> json) {
    return AllocationBySector(
      sector: json['sector'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      stockCount: json['stockCount'] ?? 0,
    );
  }
}
