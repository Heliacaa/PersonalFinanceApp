import 'package:dio/dio.dart';
import 'news_models.dart';

class NewsRepository {
  final Dio _mcpDio;

  NewsRepository({Dio? mcpDio})
    : _mcpDio =
          mcpDio ??
          Dio(
            BaseOptions(
              baseUrl: 'http://localhost:8000', // MCP server
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  /// Get news for a specific stock
  Future<StockNews> getNewsForStock(String symbol, {int count = 5}) async {
    try {
      final response = await _mcpDio.get(
        '/news/$symbol',
        queryParameters: {'count': count},
      );
      if (response.statusCode == 200) {
        return StockNews.fromJson(response.data);
      }
      throw Exception('Failed to load news');
    } catch (e) {
      throw Exception('Error fetching news: $e');
    }
  }
}
