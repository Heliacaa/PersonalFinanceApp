import 'package:flutter/material.dart';
import '../data/risk_models.dart';
import '../data/risk_repository.dart';

class RiskAnalysisWidget extends StatefulWidget {
  final List<String> symbols;

  const RiskAnalysisWidget({super.key, required this.symbols});

  @override
  State<RiskAnalysisWidget> createState() => _RiskAnalysisWidgetState();
}

class _RiskAnalysisWidgetState extends State<RiskAnalysisWidget> {
  final RiskRepository _repository = RiskRepository();
  PortfolioRisk? _risk;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRiskData();
  }

  Future<void> _loadRiskData() async {
    if (widget.symbols.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No stocks in portfolio';
      });
      return;
    }

    try {
      final risk = await _repository.getPortfolioRisk(widget.symbols);
      setState(() {
        _risk = risk;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load risk data',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadRiskData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallRiskCard(),
          const SizedBox(height: 20),
          _buildRiskMetricsGrid(),
          const SizedBox(height: 20),
          _buildStockRisksList(),
        ],
      ),
    );
  }

  Widget _buildOverallRiskCard() {
    final risk = _risk!;
    Color riskColor;
    IconData riskIcon;

    if (risk.isHighRisk) {
      riskColor = const Color(0xFFFF6B6B);
      riskIcon = Icons.warning_rounded;
    } else if (risk.isLowRisk) {
      riskColor = const Color(0xFF00D9A5);
      riskIcon = Icons.check_circle_rounded;
    } else {
      riskColor = const Color(0xFFFFB347);
      riskIcon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            riskColor.withValues(alpha: 0.3),
            riskColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(riskIcon, color: riskColor, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portfolio Risk Level',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    risk.overallRisk,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Diversification',
                  '${risk.diversificationScore.toInt()}%',
                ),
              ),
              Expanded(
                child: _buildMiniMetric(
                  'Correlation Risk',
                  risk.correlationRisk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskMetricsGrid() {
    final risk = _risk!;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Beta',
            risk.portfolioBeta.toStringAsFixed(2),
            _getBetaDescription(risk.portfolioBeta),
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Volatility',
            '${risk.portfolioVolatility.toStringAsFixed(1)}%',
            _getVolatilityDescription(risk.portfolioVolatility),
            Icons.show_chart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Sharpe',
            risk.portfolioSharpeRatio.toStringAsFixed(2),
            _getSharpeDescription(risk.portfolioSharpeRatio),
            Icons.insights,
          ),
        ),
      ],
    );
  }

  String _getBetaDescription(double beta) {
    if (beta > 1.2) return 'High';
    if (beta < 0.8) return 'Low';
    return 'Neutral';
  }

  String _getVolatilityDescription(double vol) {
    if (vol > 35) return 'High';
    if (vol < 20) return 'Low';
    return 'Moderate';
  }

  String _getSharpeDescription(double sharpe) {
    if (sharpe > 1) return 'Good';
    if (sharpe < 0) return 'Poor';
    return 'OK';
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String description,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C5CE7), size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRisksList() {
    final stocks = _risk!.stockRisks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Individual Stock Risk',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...stocks.map((stock) => _buildStockRiskCard(stock)),
      ],
    );
  }

  Widget _buildStockRiskCard(StockRiskMetrics stock) {
    Color riskColor;
    if (stock.isHighRisk) {
      riskColor = const Color(0xFFFF6B6B);
    } else if (stock.isLowRisk) {
      riskColor = const Color(0xFF00D9A5);
    } else {
      riskColor = const Color(0xFFFFB347);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      stock.stockName,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stock.riskLevel,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStockMetric('Beta', stock.beta.toStringAsFixed(2)),
              _buildStockMetric(
                'Vol',
                '${stock.volatility.toStringAsFixed(1)}%',
              ),
              _buildStockMetric('Sharpe', stock.sharpeRatio.toStringAsFixed(2)),
              _buildStockMetric(
                'VaR',
                '${stock.valueAtRisk.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
