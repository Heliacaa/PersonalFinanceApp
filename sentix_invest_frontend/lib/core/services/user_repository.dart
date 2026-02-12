import '../network/dio_client.dart';
import '../models/user_profile.dart';

class UserRepository {
  final DioClient _dioClient;

  UserRepository({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  /// Get the current user's profile.
  Future<UserProfile> getProfile() async {
    try {
      final response = await _dioClient.dio.get('/users/me');
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw Exception('Failed to load user profile');
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  /// Toggle paper trading mode on/off.
  Future<UserProfile> togglePaperTrading() async {
    try {
      final response = await _dioClient.dio.patch('/users/paper-trading');
      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data);
      }
      throw Exception('Failed to toggle paper trading');
    } catch (e) {
      throw Exception('Error toggling paper trading: $e');
    }
  }

  /// Update the user's preferred display currency.
  Future<UserProfile> updatePreferredCurrency(String currency) async {
    try {
      final response = await _dioClient.dio.patch(
        '/users/preferred-currency',
        data: {'currency': currency},
      );
      if (response.statusCode == 200) {
        // Backend returns partial map; re-fetch full profile
        return await getProfile();
      }
      throw Exception('Failed to update currency');
    } catch (e) {
      throw Exception('Error updating currency: $e');
    }
  }
}
