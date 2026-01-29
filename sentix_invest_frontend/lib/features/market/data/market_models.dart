class MarketIndex {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;

  MarketIndex({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> json) {
    return MarketIndex(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['changePercent'] ?? 0).toDouble(),
    );
  }

  bool get isPositive => change >= 0;
}

class MarketSummary {
  final MarketIndex? bist100;
  final MarketIndex? nasdaq;
  final MarketIndex? sp500;
  final String timestamp;

  MarketSummary({
    this.bist100,
    this.nasdaq,
    this.sp500,
    required this.timestamp,
  });

  factory MarketSummary.fromJson(Map<String, dynamic> json) {
    return MarketSummary(
      bist100: json['bist100'] != null
          ? MarketIndex.fromJson(json['bist100'])
          : null,
      nasdaq: json['nasdaq'] != null
          ? MarketIndex.fromJson(json['nasdaq'])
          : null,
      sp500: json['sp500'] != null ? MarketIndex.fromJson(json['sp500']) : null,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class StockQuote {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final String marketState;
  final String timestamp;

  StockQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.currency,
    required this.marketState,
    required this.timestamp,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    return StockQuote(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['changePercent'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      marketState: json['marketState'] ?? 'UNKNOWN',
      timestamp: json['timestamp'] ?? '',
    );
  }

  bool get isPositive => change >= 0;
}

class StockSearchResult {
  final String symbol;
  final String name;

  StockSearchResult({required this.symbol, required this.name});

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
    );
  }
}
