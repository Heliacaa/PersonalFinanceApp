import '../../../core/network/dio_client.dart';
import '../../../core/models/page_response.dart';
import 'portfolio_models.dart';

class PortfolioRepository {
  final DioClient _dioClient;

  PortfolioRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  Future<List<PortfolioHolding>> getPortfolio() async {
    try {
      final response = await _dioClient.dio.get('/portfolio');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => PortfolioHolding.fromJson(e)).toList();
      }
      throw Exception('Failed to load portfolio');
    } catch (e) {
      throw Exception('Error fetching portfolio: $e');
    }
  }

  Future<PortfolioSummary> getPortfolioSummary() async {
    try {
      final response = await _dioClient.dio.get('/portfolio/summary');
      if (response.statusCode == 200) {
        return PortfolioSummary.fromJson(response.data);
      }
      throw Exception('Failed to load portfolio summary');
    } catch (e) {
      throw Exception('Error fetching portfolio summary: $e');
    }
  }

  Future<PortfolioHolding?> getHoldingBySymbol(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/portfolio/$symbol');
      if (response.statusCode == 200) {
        return PortfolioHolding.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch transactions with pagination support.
  Future<PageResponse<Transaction>> getTransactionsPaginated({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/trading/transactions',
        queryParameters: {'page': page, 'size': size},
      );
      if (response.statusCode == 200) {
        return PageResponse.fromJson(
          response.data,
          (json) => Transaction.fromJson(json),
        );
      }
      throw Exception('Failed to load transactions');
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }

  /// Backward compatible: fetch first page of transactions as a simple list.
  Future<List<Transaction>> getTransactions() async {
    final pageResponse = await getTransactionsPaginated();
    return pageResponse.content;
  }
}
