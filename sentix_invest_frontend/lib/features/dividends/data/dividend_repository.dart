import '../../../core/network/dio_client.dart';
import 'dividend_models.dart';

class DividendRepository {
  final DioClient _dioClient;

  DividendRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get dividend data for a specific stock
  Future<StockDividend> getDividends(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/stocks/dividends/$symbol');
      if (response.statusCode == 200) {
        return StockDividend.fromJson(response.data);
      }
      throw Exception('Failed to load dividend data');
    } catch (e) {
      throw Exception('Error fetching dividends: $e');
    }
  }

  /// Get dividends for multiple stocks (for portfolio view)
  Future<List<StockDividend>> getPortfolioDividends(
    List<String> symbols,
  ) async {
    final dividends = <StockDividend>[];
    for (final symbol in symbols) {
      try {
        final dividend = await getDividends(symbol);
        if (dividend.hasDividends) {
          dividends.add(dividend);
        }
      } catch (e) {
        // Skip stocks that fail to load
      }
    }
    return dividends;
  }
}
