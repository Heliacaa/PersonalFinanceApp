/// Models for portfolio risk analysis feature
library;

class PortfolioRisk {
  final String overallRisk;
  final double portfolioBeta;
  final double portfolioVolatility;
  final double portfolioSharpeRatio;
  final double diversificationScore;
  final String correlationRisk;
  final List<StockRiskMetrics> stockRisks;

  PortfolioRisk({
    required this.overallRisk,
    required this.portfolioBeta,
    required this.portfolioVolatility,
    required this.portfolioSharpeRatio,
    required this.diversificationScore,
    required this.correlationRisk,
    required this.stockRisks,
  });

  factory PortfolioRisk.fromJson(Map<String, dynamic> json) {
    return PortfolioRisk(
      overallRisk: json['overallRisk'] ?? 'MEDIUM',
      portfolioBeta: (json['portfolioBeta'] ?? 1.0).toDouble(),
      portfolioVolatility: (json['portfolioVolatility'] ?? 0).toDouble(),
      portfolioSharpeRatio: (json['portfolioSharpeRatio'] ?? 0).toDouble(),
      diversificationScore: (json['diversificationScore'] ?? 0).toDouble(),
      correlationRisk: json['correlationRisk'] ?? 'MEDIUM',
      stockRisks: (json['stockRisks'] as List? ?? [])
          .map((e) => StockRiskMetrics.fromJson(e))
          .toList(),
    );
  }

  bool get isHighRisk => overallRisk == 'HIGH';
  bool get isLowRisk => overallRisk == 'LOW';
}

class StockRiskMetrics {
  final String symbol;
  final String stockName;
  final double beta;
  final double volatility;
  final double sharpeRatio;
  final double maxDrawdown;
  final double valueAtRisk;
  final String riskLevel;

  StockRiskMetrics({
    required this.symbol,
    required this.stockName,
    required this.beta,
    required this.volatility,
    required this.sharpeRatio,
    required this.maxDrawdown,
    required this.valueAtRisk,
    required this.riskLevel,
  });

  factory StockRiskMetrics.fromJson(Map<String, dynamic> json) {
    return StockRiskMetrics(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      beta: (json['beta'] ?? 1.0).toDouble(),
      volatility: (json['volatility'] ?? 0).toDouble(),
      sharpeRatio: (json['sharpeRatio'] ?? 0).toDouble(),
      maxDrawdown: (json['maxDrawdown'] ?? 0).toDouble(),
      valueAtRisk: (json['valueAtRisk'] ?? 0).toDouble(),
      riskLevel: json['riskLevel'] ?? 'MEDIUM',
    );
  }

  bool get isHighRisk => riskLevel == 'HIGH';
  bool get isLowRisk => riskLevel == 'LOW';
}
