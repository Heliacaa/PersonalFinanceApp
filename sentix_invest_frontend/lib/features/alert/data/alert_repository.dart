import '../../../core/network/dio_client.dart';
import 'alert_models.dart';

class AlertRepository {
  final DioClient _dioClient;

  AlertRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Create a new price alert
  Future<PriceAlert> createAlert(CreateAlertRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        '/alerts',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return PriceAlert.fromJson(response.data);
      }
      throw Exception('Failed to create alert');
    } catch (e) {
      throw Exception('Error creating alert: $e');
    }
  }

  /// Get all alerts for the current user
  Future<List<PriceAlert>> getAlerts() async {
    try {
      final response = await _dioClient.dio.get('/alerts');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => PriceAlert.fromJson(e)).toList();
      }
      throw Exception('Failed to load alerts');
    } catch (e) {
      throw Exception('Error fetching alerts: $e');
    }
  }

  /// Get only active alerts
  Future<List<PriceAlert>> getActiveAlerts() async {
    try {
      final response = await _dioClient.dio.get('/alerts/active');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => PriceAlert.fromJson(e)).toList();
      }
      throw Exception('Failed to load active alerts');
    } catch (e) {
      throw Exception('Error fetching active alerts: $e');
    }
  }

  /// Get alerts for a specific stock
  Future<List<PriceAlert>> getAlertsBySymbol(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/alerts/symbol/$symbol');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => PriceAlert.fromJson(e)).toList();
      }
      throw Exception('Failed to load alerts for $symbol');
    } catch (e) {
      throw Exception('Error fetching alerts for $symbol: $e');
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    try {
      final response = await _dioClient.dio.delete('/alerts/$alertId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete alert');
      }
    } catch (e) {
      throw Exception('Error deleting alert: $e');
    }
  }

  /// Toggle alert active status
  Future<PriceAlert> toggleAlert(String alertId) async {
    try {
      final response = await _dioClient.dio.patch('/alerts/$alertId/toggle');
      if (response.statusCode == 200) {
        return PriceAlert.fromJson(response.data);
      }
      throw Exception('Failed to toggle alert');
    } catch (e) {
      throw Exception('Error toggling alert: $e');
    }
  }
}
