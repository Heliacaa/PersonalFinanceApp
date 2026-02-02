import 'package:flutter/material.dart';

class AIAnalysisResponse {
  final String symbol;
  final String stockName;
  final String analysis;
  final String recommendation; // BUY, HOLD, SELL
  final double confidence;
  final List<String> keyPoints;
  final String generatedAt;

  AIAnalysisResponse({
    required this.symbol,
    required this.stockName,
    required this.analysis,
    required this.recommendation,
    required this.confidence,
    required this.keyPoints,
    required this.generatedAt,
  });

  factory AIAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResponse(
      symbol: json['symbol'] ?? '',
      stockName: json['stockName'] ?? '',
      analysis: json['analysis'] ?? '',
      recommendation: json['recommendation'] ?? 'HOLD',
      confidence: (json['confidence'] ?? 0).toDouble(),
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      generatedAt: json['generatedAt'] ?? '',
    );
  }

  Color get recommendationColor {
    switch (recommendation.toUpperCase()) {
      case 'BUY':
        return const Color(0xFF00B894);
      case 'SELL':
        return const Color(0xFFE74C3C);
      case 'HOLD':
      default:
        return const Color(0xFFF39C12);
    }
  }

  IconData get recommendationIcon {
    switch (recommendation.toUpperCase()) {
      case 'BUY':
        return Icons.trending_up;
      case 'SELL':
        return Icons.trending_down;
      case 'HOLD':
      default:
        return Icons.trending_flat;
    }
  }
}
