import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

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
          debugPrint('[DioClient] Request: ${options.method} ${options.path}');
          debugPrint('[DioClient] Token present: ${token != null}');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('[DioClient] Authorization header added');
          } else {
            debugPrint('[DioClient] WARNING: No auth token found!');
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          debugPrint('[DioClient] Error: ${error.response?.statusCode} - ${error.message}');
          debugPrint('[DioClient] Request path: ${error.requestOptions.path}');
          debugPrint('[DioClient] Request headers: ${error.requestOptions.headers}');
          return handler.next(error);
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
