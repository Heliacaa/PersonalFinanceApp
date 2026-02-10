/// Models for dividend tracking feature
library;

class StockDividend {
  final String symbol;
  final String stockName;
  final bool hasDividends;
  final double annualYield;
  final double annualDividend;
  final String payoutFrequency;
  final DividendPayment? lastDividend;
  final DividendPayment? nextDividend;
  final List<DividendPayment> history;

  StockDividend({
    required this.symbol,
    required this.stockName,
    required this.hasDividends,
    required this.annualYield,
    required this.annualDividend,
    required this.payoutFrequency,
    this.lastDividend,
    this.nextDividend,
    required this.history,
  });

  factory StockDividend.fromJson(Map<String, dynamic> json) {
    return StockDividend(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      hasDividends: json['hasDividends'] ?? false,
      annualYield: (json['annualYield'] ?? 0).toDouble(),
      annualDividend: (json['annualDividend'] ?? 0).toDouble(),
      payoutFrequency: json['payoutFrequency'] ?? 'NONE',
      lastDividend: json['lastDividend'] != null
          ? DividendPayment.fromJson(json['lastDividend'])
          : null,
      nextDividend: json['nextDividend'] != null
          ? DividendPayment.fromJson(json['nextDividend'])
          : null,
      history: (json['history'] as List? ?? [])
          .map((e) => DividendPayment.fromJson(e))
          .toList(),
    );
  }
}

class DividendPayment {
  final String exDate;
  final String paymentDate;
  final double amount;
  final String currency;

  DividendPayment({
    required this.exDate,
    required this.paymentDate,
    required this.amount,
    required this.currency,
  });

  factory DividendPayment.fromJson(Map<String, dynamic> json) {
    return DividendPayment(
      exDate: json['exDate'] ?? '',
      paymentDate: json['paymentDate'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
    );
  }

  DateTime get exDateTime => DateTime.parse(exDate);
  DateTime get paymentDateTime => DateTime.parse(paymentDate);
}
