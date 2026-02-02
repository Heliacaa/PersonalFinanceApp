import '../../../core/network/dio_client.dart';
import 'earnings_models.dart';

class EarningsRepository {
  final DioClient _dioClient;

  EarningsRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get earnings data for a specific stock
  Future<StockEarnings> getEarnings(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/stocks/earnings/$symbol');
      if (response.statusCode == 200) {
        return StockEarnings.fromJson(response.data);
      }
      throw Exception('Failed to load earnings data');
    } catch (e) {
      throw Exception('Error fetching earnings: $e');
    }
  }
}
