/// Models for earnings calendar feature

class StockEarnings {
  final String symbol;
  final String stockName;
  final bool hasUpcoming;
  final String? nextEarningsDate;
  final int? daysUntilEarnings;
  final double? nextEpsEstimate;
  final double? nextRevenueEstimate;
  final String? fiscalQuarter;
  final List<EarningsReport> history;

  StockEarnings({
    required this.symbol,
    required this.stockName,
    required this.hasUpcoming,
    this.nextEarningsDate,
    this.daysUntilEarnings,
    this.nextEpsEstimate,
    this.nextRevenueEstimate,
    this.fiscalQuarter,
    required this.history,
  });

  factory StockEarnings.fromJson(Map<String, dynamic> json) {
    return StockEarnings(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      hasUpcoming: json['hasUpcoming'] ?? false,
      nextEarningsDate: json['nextEarningsDate'],
      daysUntilEarnings: json['daysUntilEarnings'],
      nextEpsEstimate: json['nextEpsEstimate']?.toDouble(),
      nextRevenueEstimate: json['nextRevenueEstimate']?.toDouble(),
      fiscalQuarter: json['fiscalQuarter'],
      history: (json['history'] as List? ?? [])
          .map((e) => EarningsReport.fromJson(e))
          .toList(),
    );
  }

  bool get isEarningsSoon =>
      daysUntilEarnings != null && daysUntilEarnings! <= 14;
}

class EarningsReport {
  final String date;
  final double? epsActual;
  final double? epsEstimate;
  final double? revenueActual;
  final double? revenueEstimate;
  final double? surprise;
  final bool? isBeat;

  EarningsReport({
    required this.date,
    this.epsActual,
    this.epsEstimate,
    this.revenueActual,
    this.revenueEstimate,
    this.surprise,
    this.isBeat,
  });

  factory EarningsReport.fromJson(Map<String, dynamic> json) {
    return EarningsReport(
      date: json['date'] ?? '',
      epsActual: json['epsActual']?.toDouble(),
      epsEstimate: json['epsEstimate']?.toDouble(),
      revenueActual: json['revenueActual']?.toDouble(),
      revenueEstimate: json['revenueEstimate']?.toDouble(),
      surprise: json['surprise']?.toDouble(),
      isBeat: json['isBeat'],
    );
  }

  DateTime get dateTime => DateTime.parse(date);
}
