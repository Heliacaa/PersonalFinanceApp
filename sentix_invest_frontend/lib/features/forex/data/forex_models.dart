class ForexRate {
  final String currency;
  final double rate;
  final String name;

  ForexRate({
    required this.currency,
    required this.rate,
    required this.name,
  });

  factory ForexRate.fromJson(Map<String, dynamic> json) {
    return ForexRate(
      currency: json['currency'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      name: json['name'] ?? '',
    );
  }
}

class ForexRatesResponse {
  final String baseCurrency;
  final List<ForexRate> rates;
  final String timestamp;

  ForexRatesResponse({
    required this.baseCurrency,
    required this.rates,
    required this.timestamp,
  });

  factory ForexRatesResponse.fromJson(Map<String, dynamic> json) {
    return ForexRatesResponse(
      baseCurrency: json['baseCurrency'] ?? 'USD',
      rates: (json['rates'] as List<dynamic>?)
              ?.map((e) => ForexRate.fromJson(e))
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class ForexConvertResponse {
  final String fromCurrency;
  final String toCurrency;
  final double amount;
  final double result;
  final double rate;
  final String timestamp;

  ForexConvertResponse({
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
    required this.result,
    required this.rate,
    required this.timestamp,
  });

  factory ForexConvertResponse.fromJson(Map<String, dynamic> json) {
    return ForexConvertResponse(
      fromCurrency: json['fromCurrency'] ?? '',
      toCurrency: json['toCurrency'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      result: (json['result'] ?? 0).toDouble(),
      rate: (json['rate'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? '',
    );
  }
}
