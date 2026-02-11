import '../../../core/network/dio_client.dart';
import '../../../core/models/page_response.dart';
import 'watchlist_models.dart';

class WatchlistRepository {
  final DioClient _dioClient;

  WatchlistRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get watchlist with pagination.
  Future<PageResponse<WatchlistItem>> getWatchlistPaginated({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/watchlist',
        queryParameters: {'page': page, 'size': size},
      );
      if (response.statusCode == 200) {
        return PageResponse.fromJson(
          response.data,
          (json) => WatchlistItem.fromJson(json),
        );
      }
      throw Exception('Failed to load watchlist');
    } catch (e) {
      throw Exception('Error fetching watchlist: $e');
    }
  }

  /// Get watchlist (backward compatible, returns first page as list).
  Future<List<WatchlistItem>> getWatchlist() async {
    final pageResponse = await getWatchlistPaginated();
    return pageResponse.content;
  }

  Future<WatchlistItem?> addToWatchlist(String symbol, String stockName) async {
    try {
      final response = await _dioClient.dio.post(
        '/watchlist',
        data: {'symbol': symbol, 'stockName': stockName},
      );
      if (response.statusCode == 200) {
        return WatchlistItem.fromJson(response.data);
      }
      return null;
    } catch (e) {
      throw Exception('Error adding to watchlist: $e');
    }
  }

  Future<bool> removeFromWatchlist(String symbol) async {
    try {
      final response = await _dioClient.dio.delete('/watchlist/$symbol');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isInWatchlist(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/watchlist/$symbol/exists');
      if (response.statusCode == 200) {
        return response.data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
