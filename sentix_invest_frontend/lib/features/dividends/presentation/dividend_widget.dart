import 'package:flutter/material.dart';
import '../data/dividend_models.dart';
import '../data/dividend_repository.dart';

class DividendWidget extends StatefulWidget {
  final String symbol;

  const DividendWidget({super.key, required this.symbol});

  @override
  State<DividendWidget> createState() => _DividendWidgetState();
}

class _DividendWidgetState extends State<DividendWidget> {
  final DividendRepository _repository = DividendRepository();
  StockDividend? _dividend;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDividends();
  }

  Future<void> _loadDividends() async {
    try {
      final dividend = await _repository.getDividends(widget.symbol);
      setState(() {
        _dividend = dividend;
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dividends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );
    }

    if (_error != null || _dividend == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Could not load dividend data',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    if (!_dividend!.hasDividends) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.money_off, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Text(
              'This stock does not pay dividends',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 12),
        if (_dividend!.nextDividend != null) _buildNextDividendCard(),
        if (_dividend!.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildHistoryCard(),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    final d = _dividend!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9A5).withValues(alpha: 0.2),
            const Color(0xFF00D9A5).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D9A5).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildMetric('Annual Yield', '${d.annualYield}%')),
          Container(width: 1, height: 40, color: Colors.grey[700]),
          Expanded(
            child: _buildMetric('Annual Dividend', '\$${d.annualDividend}'),
          ),
          Container(width: 1, height: 40, color: Colors.grey[700]),
          Expanded(
            child: _buildMetric(
              'Frequency',
              _formatFrequency(d.payoutFrequency),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatFrequency(String freq) {
    switch (freq) {
      case 'MONTHLY':
        return 'Monthly';
      case 'QUARTERLY':
        return 'Quarterly';
      case 'SEMI_ANNUALLY':
        return 'Semi-Annual';
      case 'ANNUALLY':
        return 'Annually';
      default:
        return freq;
    }
  }

  Widget _buildNextDividendCard() {
    final next = _dividend!.nextDividend!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Color(0xFF6C5CE7),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Dividend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ex-Date: ${_formatDate(next.exDate)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${next.amount.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: Color(0xFF00D9A5),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'per share',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final history = _dividend!.history.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent History',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...history.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(payment.exDate),
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  Text(
                    '\$${payment.amount.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
