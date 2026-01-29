import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/dio_client.dart';

class AuthRepository {
  final DioClient _dioClient;
  final FlutterSecureStorage _storage;

  AuthRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient(),
      _storage = const FlutterSecureStorage();

  Future<void> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/authenticate',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final token = response
            .data['token']; // Assuming the token is returned in a 'token' field
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
        } else {
          throw Exception('Token not found in response');
        }
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> register(
    String firstname,
    String lastname,
    String email,
    String password,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/register',
        data: {
          'fullName': '$firstname $lastname',
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to register: ${response.statusCode}');
      }
      // Optionally leverage the returned token to auto-login
      final token = response.data['token'];
      if (token != null) {
        await _storage.write(key: 'auth_token', value: token);
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }
}
