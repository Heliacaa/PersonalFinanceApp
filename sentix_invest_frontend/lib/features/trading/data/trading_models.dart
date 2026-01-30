class TradeResponse {
  final bool success;
  final String message;
  final double? newBalance;

  TradeResponse({
    required this.success,
    required this.message,
    this.newBalance,
  });

  factory TradeResponse.fromJson(Map<String, dynamic> json) {
    return TradeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      newBalance: json['newBalance']?.toDouble(),
    );
  }
}
