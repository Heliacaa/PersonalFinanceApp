import '../../../core/network/dio_client.dart';
import 'analytics_models.dart';

class AnalyticsRepository {
  final DioClient _dioClient;

  AnalyticsRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Get portfolio performance analytics
  Future<PortfolioPerformance> getPerformanceAnalytics() async {
    try {
      final response = await _dioClient.dio.get('/portfolio/analytics');
      if (response.statusCode == 200) {
        return PortfolioPerformance.fromJson(response.data);
      }
      throw Exception('Failed to load analytics');
    } catch (e) {
      throw Exception('Error fetching analytics: $e');
    }
  }
}
