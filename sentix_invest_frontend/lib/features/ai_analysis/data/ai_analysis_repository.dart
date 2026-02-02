import '../../../core/network/dio_client.dart';
import 'ai_analysis_models.dart';

class AIAnalysisRepository {
  final DioClient _dioClient = DioClient();

  Future<AIAnalysisResponse> getAIAnalysis(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/ai/analyze/$symbol');

      if (response.statusCode == 200) {
        return AIAnalysisResponse.fromJson(response.data);
      }
      throw Exception('Failed to load AI analysis');
    } catch (e) {
      rethrow;
    }
  }
}
