import 'package:flutter/material.dart';
import '../data/earnings_models.dart';
import '../data/earnings_repository.dart';

class EarningsWidget extends StatefulWidget {
  final String symbol;

  const EarningsWidget({super.key, required this.symbol});

  @override
  State<EarningsWidget> createState() => _EarningsWidgetState();
}

class _EarningsWidgetState extends State<EarningsWidget> {
  final EarningsRepository _repository = EarningsRepository();
  StockEarnings? _earnings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final earnings = await _repository.getEarnings(widget.symbol);
      setState(() {
        _earnings = earnings;
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
                'Earnings',
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

    if (_error != null || _earnings == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Could not load earnings data',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_earnings!.hasUpcoming) _buildUpcomingEarningsCard(),
        if (_earnings!.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildHistoryCard(),
        ],
      ],
    );
  }

  Widget _buildUpcomingEarningsCard() {
    final e = _earnings!;
    final isEarningsSoon = e.isEarningsSoon;
    final accentColor = isEarningsSoon
        ? const Color(0xFFFFB347)
        : const Color(0xFF6C5CE7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Next Earnings',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    if (isEarningsSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SOON',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(e.nextEarningsDate ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (e.fiscalQuarter != null)
                  Text(
                    e.fiscalQuarter!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${e.daysUntilEarnings ?? "?"} days',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (e.nextEpsEstimate != null)
                Text(
                  'EPS Est: \$${e.nextEpsEstimate!.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final history = _earnings!.history.take(4).toList();

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
            'Past Earnings',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    'EPS',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Est',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Surprise',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ...history.map((report) => _buildHistoryRow(report)),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(EarningsReport report) {
    Color? surpriseColor;
    String surpriseText = '-';

    if (report.surprise != null) {
      surpriseColor = report.isBeat == true
          ? const Color(0xFF00D9A5)
          : const Color(0xFFFF6B6B);
      surpriseText =
          '${report.surprise! >= 0 ? '+' : ''}${report.surprise!.toStringAsFixed(1)}%';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatDateShort(report.date),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              report.epsActual != null
                  ? '\$${report.epsActual!.toStringAsFixed(2)}'
                  : '-',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              report.epsEstimate != null
                  ? '\$${report.epsEstimate!.toStringAsFixed(2)}'
                  : '-',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (report.isBeat != null)
                  Icon(
                    report.isBeat! ? Icons.arrow_upward : Icons.arrow_downward,
                    color: surpriseColor,
                    size: 12,
                  ),
                const SizedBox(width: 2),
                Text(
                  surpriseText,
                  style: TextStyle(
                    color: surpriseColor ?? Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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

  String _formatDateShort(String dateStr) {
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
      return "${months[date.month - 1]} '${date.year.toString().substring(2)}";
    } catch (e) {
      return dateStr;
    }
  }
}
