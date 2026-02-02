import '../../../core/network/dio_client.dart';
import 'risk_models.dart';

class RiskRepository {
  final DioClient _dioClient;

  RiskRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get risk analysis for a portfolio of stocks
  Future<PortfolioRisk> getPortfolioRisk(List<String> symbols) async {
    try {
      final symbolsParam = symbols.join(',');
      final response = await _dioClient.dio.get(
        '/stocks/analytics/risk',
        queryParameters: {'symbols': symbolsParam},
      );
      if (response.statusCode == 200) {
        return PortfolioRisk.fromJson(response.data);
      }
      throw Exception('Failed to load risk analysis');
    } catch (e) {
      throw Exception('Error fetching risk analysis: $e');
    }
  }
}
