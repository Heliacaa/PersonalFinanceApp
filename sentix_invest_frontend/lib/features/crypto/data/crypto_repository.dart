import '../../../core/network/dio_client.dart';
import 'crypto_models.dart';

class CryptoRepository {
  final DioClient _dioClient = DioClient();

  Future<CryptoMarketsResponse> getCryptoMarkets({int limit = 20}) async {
    try {
      final response = await _dioClient.dio.get(
        '/crypto/markets',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        return CryptoMarketsResponse.fromJson(response.data);
      }
      throw Exception('Failed to load crypto markets');
    } catch (e) {
      rethrow;
    }
  }

  Future<CryptoQuote> getCryptoQuote(String id) async {
    try {
      final response = await _dioClient.dio.get('/crypto/quote/$id');

      if (response.statusCode == 200) {
        return CryptoQuote.fromJson(response.data);
      }
      throw Exception('Failed to load crypto quote');
    } catch (e) {
      rethrow;
    }
  }
}
