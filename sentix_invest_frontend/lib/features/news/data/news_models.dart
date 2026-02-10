/// Models for stock news feature
library;

class StockNews {
  final String symbol;
  final String stockName;
  final List<NewsItem> news;

  StockNews({
    required this.symbol,
    required this.stockName,
    required this.news,
  });

  factory StockNews.fromJson(Map<String, dynamic> json) {
    return StockNews(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      news: (json['news'] as List? ?? [])
          .map((e) => NewsItem.fromJson(e))
          .toList(),
    );
  }
}

class NewsItem {
  final String title;
  final String summary;
  final String source;
  final String url;
  final DateTime publishedAt;
  final String sentiment; // BULLISH, BEARISH, NEUTRAL
  final double sentimentScore;

  NewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.sentiment,
    required this.sentimentScore,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      source: json['source'] ?? '',
      url: json['url'] ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      sentiment: json['sentiment'] ?? 'NEUTRAL',
      sentimentScore: (json['sentimentScore'] ?? 0).toDouble(),
    );
  }

  bool get isBullish => sentiment == 'BULLISH';
  bool get isBearish => sentiment == 'BEARISH';
  bool get isNeutral => sentiment == 'NEUTRAL';

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }
}
