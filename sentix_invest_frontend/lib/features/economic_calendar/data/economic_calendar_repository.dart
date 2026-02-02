import '../../../core/network/dio_client.dart';
import 'economic_calendar_models.dart';

class EconomicCalendarRepository {
  final DioClient _dioClient = DioClient();

  Future<EconomicCalendarResponse> getEconomicCalendar({int days = 7}) async {
    try {
      final response = await _dioClient.dio.get(
        '/calendar/economic',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200) {
        return EconomicCalendarResponse.fromJson(response.data);
      }
      throw Exception('Failed to load economic calendar');
    } catch (e) {
      rethrow;
    }
  }
}
