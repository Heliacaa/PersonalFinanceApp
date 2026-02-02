class CryptoQuote {
  final String id;
  final String symbol;
  final String name;
  final double price;
  final double change24h;
  final double changePercent24h;
  final double marketCap;
  final double volume24h;
  final int rank;
  final String? image;

  CryptoQuote({
    required this.id,
    required this.symbol,
    required this.name,
    required this.price,
    required this.change24h,
    required this.changePercent24h,
    required this.marketCap,
    required this.volume24h,
    required this.rank,
    this.image,
  });

  factory CryptoQuote.fromJson(Map<String, dynamic> json) {
    return CryptoQuote(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      change24h: (json['change24h'] ?? 0).toDouble(),
      changePercent24h: (json['changePercent24h'] ?? 0).toDouble(),
      marketCap: (json['marketCap'] ?? 0).toDouble(),
      volume24h: (json['volume24h'] ?? 0).toDouble(),
      rank: json['rank'] ?? 0,
      image: json['image'],
    );
  }

  bool get isPositive => changePercent24h >= 0;

  String get formattedMarketCap {
    if (marketCap >= 1e12) {
      return '\$${(marketCap / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap >= 1e9) {
      return '\$${(marketCap / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap >= 1e6) {
      return '\$${(marketCap / 1e6).toStringAsFixed(2)}M';
    }
    return '\$${marketCap.toStringAsFixed(0)}';
  }
}

class CryptoMarketsResponse {
  final List<CryptoQuote> cryptocurrencies;
  final String timestamp;

  CryptoMarketsResponse({
    required this.cryptocurrencies,
    required this.timestamp,
  });

  factory CryptoMarketsResponse.fromJson(Map<String, dynamic> json) {
    return CryptoMarketsResponse(
      cryptocurrencies: (json['cryptocurrencies'] as List<dynamic>?)
              ?.map((e) => CryptoQuote.fromJson(e))
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? '',
    );
  }
}
