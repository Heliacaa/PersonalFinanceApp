import '../../../core/network/dio_client.dart';
import 'market_models.dart';

class MarketRepository {
  final DioClient _dioClient;

  MarketRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  Future<MarketSummary> getMarketSummary() async {
    try {
      final response = await _dioClient.dio.get('/markets/summary');
      if (response.statusCode == 200) {
        return MarketSummary.fromJson(response.data);
      }
      throw Exception('Failed to load market summary');
    } catch (e) {
      throw Exception('Error fetching market summary: $e');
    }
  }

  Future<StockQuote> getStockQuote(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/stocks/$symbol');
      if (response.statusCode == 200) {
        return StockQuote.fromJson(response.data);
      }
      throw Exception('Stock not found');
    } catch (e) {
      throw Exception('Error fetching stock quote: $e');
    }
  }

  Future<List<StockSearchResult>> searchStocks(String query) async {
    try {
      final response = await _dioClient.dio.get('/stocks/search/$query');
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((r) => StockSearchResult.fromJson(r)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
