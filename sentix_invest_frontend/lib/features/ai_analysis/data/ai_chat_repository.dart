import '../../../core/network/dio_client.dart';
import 'ai_chat_models.dart';

class AIChatRepository {
  final DioClient _dioClient = DioClient();

  /// Send a chat message and receive an AI response with RAG context.
  Future<ChatMessage> sendMessage({
    required String message,
    required String sessionId,
    String? symbol,
  }) async {
    try {
      final body = <String, dynamic>{
        'message': message,
        'sessionId': sessionId,
      };
      if (symbol != null && symbol.isNotEmpty) {
        body['symbol'] = symbol;
      }

      final response = await _dioClient.dio.post('/ai/chat', data: body);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return ChatMessage(
          role: 'assistant',
          content: data['response'] ?? '',
          sources: (data['sources'] as List<dynamic>?)
                  ?.map((s) => ChatSource.fromJson(s as Map<String, dynamic>))
                  .toList() ??
              [],
        );
      }
      throw Exception('Failed to get AI response');
    } catch (e) {
      rethrow;
    }
  }

  /// Get RAG system status.
  Future<Map<String, dynamic>> getRAGStatus() async {
    try {
      final response = await _dioClient.dio.get('/ai/rag/status');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to get RAG status');
    } catch (e) {
      rethrow;
    }
  }
}
