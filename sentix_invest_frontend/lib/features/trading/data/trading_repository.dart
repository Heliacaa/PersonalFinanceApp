import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import 'trading_models.dart';

class TradingRepository {
  final DioClient _dioClient;

  TradingRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  Future<TradeResponse> buyStock(String symbol, int quantity) async {
    try {
      final response = await _dioClient.dio.post(
        '/trading/buy',
        data: {'symbol': symbol, 'quantity': quantity},
      );
      return TradeResponse.fromJson(response.data);
    } on DioException catch (e) {
      // Try to extract error message from response
      String message = 'Buy failed';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      } else {
        message = e.message ?? 'Unknown error';
      }
      return TradeResponse(success: false, message: message);
    } catch (e) {
      return TradeResponse(success: false, message: 'Buy failed: $e');
    }
  }

  Future<TradeResponse> sellStock(String symbol, int quantity) async {
    try {
      final response = await _dioClient.dio.post(
        '/trading/sell',
        data: {'symbol': symbol, 'quantity': quantity},
      );
      return TradeResponse.fromJson(response.data);
    } on DioException catch (e) {
      String message = 'Sell failed';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          message = data['message'];
        }
      } else {
        message = e.message ?? 'Unknown error';
      }
      return TradeResponse(success: false, message: message);
    } catch (e) {
      return TradeResponse(success: false, message: 'Sell failed: $e');
    }
  }
}
