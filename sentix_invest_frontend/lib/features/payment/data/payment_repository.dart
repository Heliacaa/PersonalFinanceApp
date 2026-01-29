import '../../../core/network/dio_client.dart';

class PaymentRepository {
  final DioClient _dioClient;

  PaymentRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  /// Initialize iyzico checkout form
  /// Returns the HTML content to be displayed
  Future<CheckoutFormResult> initializeCheckout(double amount) async {
    try {
      final response = await _dioClient.dio.post(
        '/payments/checkout',
        data: {'amount': amount},
      );

      if (response.statusCode == 200) {
        return CheckoutFormResult(
          success: true,
          htmlContent: response.data['checkoutFormContent'],
          token: response.data['token'],
          conversationId: response.data['conversationId'],
        );
      } else {
        return CheckoutFormResult(
          success: false,
          errorMessage:
              response.data['errorMessage'] ?? 'Payment initialization failed',
        );
      }
    } catch (e) {
      return CheckoutFormResult(success: false, errorMessage: 'Error: $e');
    }
  }

  /// Check payment status after callback
  Future<PaymentResult> checkPaymentStatus(String token) async {
    try {
      final response = await _dioClient.dio.post(
        '/payments/callback',
        queryParameters: {'token': token},
      );

      return PaymentResult(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        newBalance: (response.data['newBalance'] ?? 0).toDouble(),
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Error checking payment: $e',
      );
    }
  }
}

class CheckoutFormResult {
  final bool success;
  final String? htmlContent;
  final String? token;
  final String? conversationId;
  final String? errorMessage;

  CheckoutFormResult({
    required this.success,
    this.htmlContent,
    this.token,
    this.conversationId,
    this.errorMessage,
  });
}

class PaymentResult {
  final bool success;
  final String message;
  final double? newBalance;

  PaymentResult({
    required this.success,
    required this.message,
    this.newBalance,
  });
}
