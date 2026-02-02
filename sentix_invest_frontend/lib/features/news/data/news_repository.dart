import '../../../core/network/dio_client.dart';
import 'news_models.dart';

class NewsRepository {
  final DioClient _dioClient;

  NewsRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get news for a specific stock
  Future<StockNews> getNewsForStock(String symbol, {int count = 5}) async {
    try {
      final response = await _dioClient.dio.get(
        '/stocks/$symbol/news',
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
