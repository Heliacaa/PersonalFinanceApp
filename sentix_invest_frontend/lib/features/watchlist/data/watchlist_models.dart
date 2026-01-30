class WatchlistItem {
  final String id;
  final String symbol;
  final String stockName;
  final DateTime addedAt;
  final double? currentPrice;
  final double? change;
  final double? changePercent;
  final String? currency;

  WatchlistItem({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.addedAt,
    this.currentPrice,
    this.change,
    this.changePercent,
    this.currency,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
      currentPrice: json['currentPrice']?.toDouble(),
      change: json['change']?.toDouble(),
      changePercent: json['changePercent']?.toDouble(),
      currency: json['currency'],
    );
  }

  bool get isPositive => (change ?? 0) >= 0;
}
