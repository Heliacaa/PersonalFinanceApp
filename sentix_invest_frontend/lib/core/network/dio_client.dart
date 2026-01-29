import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class DioClient {
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DioClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _getBaseUrl(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Dio get dio => _dio;

  static String _getBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080/api/v1';
      }
    } catch (e) {
      // Platform.isAndroid throws on web, but we handle kIsWeb above.
      // Just in case of other issues fallback to localhost
    }
    return 'http://localhost:8080/api/v1';
  }
}
