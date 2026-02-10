import 'package:flutter/material.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final List<ChatSource> sources;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? json['response'] ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((s) => ChatSource.fromJson(s))
              .toList() ??
          [],
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class ChatSource {
  final String title;
  final String sourceType;
  final String? symbol;
  final double score;

  ChatSource({
    required this.title,
    required this.sourceType,
    this.symbol,
    this.score = 0.0,
  });

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      title: json['title'] ?? '',
      sourceType: json['sourceType'] ?? json['source_type'] ?? '',
      symbol: json['symbol'],
      score: (json['score'] ?? 0).toDouble(),
    );
  }

  Color get sourceColor {
    switch (sourceType.toUpperCase()) {
      case 'NEWS':
        return const Color(0xFF3498DB);
      case 'EDUCATION':
        return const Color(0xFF2ECC71);
      case 'RESEARCH':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  IconData get sourceIcon {
    switch (sourceType.toUpperCase()) {
      case 'NEWS':
        return Icons.newspaper;
      case 'EDUCATION':
        return Icons.school;
      case 'RESEARCH':
        return Icons.analytics;
      default:
        return Icons.source;
    }
  }
}

class ChatSession {
  final String sessionId;
  final List<ChatMessage> messages;
  final String? symbol;

  ChatSession({
    required this.sessionId,
    this.messages = const [],
    this.symbol,
  });
}
