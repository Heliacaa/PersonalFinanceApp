import '../../../core/network/dio_client.dart';
import 'forex_models.dart';

class ForexRepository {
  final DioClient _dioClient = DioClient();

  Future<ForexRatesResponse> getForexRates({String base = 'USD'}) async {
    try {
      final response = await _dioClient.dio.get(
        '/forex/rates',
        queryParameters: {'base': base},
      );

      if (response.statusCode == 200) {
        return ForexRatesResponse.fromJson(response.data);
      }
      throw Exception('Failed to load forex rates');
    } catch (e) {
      rethrow;
    }
  }

  Future<ForexConvertResponse> convertCurrency({
    required String from,
    required String to,
    required double amount,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/forex/convert',
        queryParameters: {
          'from_currency': from,
          'to_currency': to,
          'amount': amount,
        },
      );

      if (response.statusCode == 200) {
        return ForexConvertResponse.fromJson(response.data);
      }
      throw Exception('Failed to convert currency');
    } catch (e) {
      rethrow;
    }
  }
}
