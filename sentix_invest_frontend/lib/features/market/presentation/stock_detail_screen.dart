import 'package:flutter/material.dart';
import '../data/market_models.dart';
import '../../trading/presentation/buy_stock_screen.dart';
import '../../trading/presentation/sell_stock_screen.dart';
import '../../portfolio/data/portfolio_repository.dart';
import '../../portfolio/data/portfolio_models.dart';
import '../../watchlist/data/watchlist_repository.dart';
import '../../../core/network/dio_client.dart';

class StockDetailScreen extends StatefulWidget {
  final StockQuote stock;

  const StockDetailScreen({super.key, required this.stock});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final PortfolioRepository _portfolioRepository = PortfolioRepository();
  final WatchlistRepository _watchlistRepository = WatchlistRepository();
  final DioClient _dioClient = DioClient();

  String _selectedPeriod = '1mo';
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = true;
  bool _isInWatchlist = false;
  PortfolioHolding? _holding;
  double _userBalance = 0;

  final List<Map<String, String>> _periods = [
    {'label': '1D', 'value': '1d'},
    {'label': '1W', 'value': '5d'},
    {'label': '1M', 'value': '1mo'},
    {'label': '3M', 'value': '3mo'},
    {'label': '1Y', 'value': '1y'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadHistory(),
      _checkWatchlist(),
      _loadHolding(),
      _loadUserBalance(),
    ]);
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await _dioClient.dio.get(
        '/stocks/${widget.stock.symbol}/history',
        queryParameters: {'period': _selectedPeriod},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(
            response.data['data'] ?? [],
          );
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _checkWatchlist() async {
    final inWatchlist = await _watchlistRepository.isInWatchlist(
      widget.stock.symbol,
    );
    if (mounted) {
      setState(() => _isInWatchlist = inWatchlist);
    }
  }

  Future<void> _loadHolding() async {
    final holding = await _portfolioRepository.getHoldingBySymbol(
      widget.stock.symbol,
    );
    if (mounted) {
      setState(() => _holding = holding);
    }
  }

  Future<void> _loadUserBalance() async {
    try {
      final response = await _dioClient.dio.get('/users/me');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _userBalance = (response.data['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_isInWatchlist) {
      final success = await _watchlistRepository.removeFromWatchlist(
        widget.stock.symbol,
      );
      if (success && mounted) {
        setState(() => _isInWatchlist = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from watchlist')));
      }
    } else {
      final result = await _watchlistRepository.addToWatchlist(
        widget.stock.symbol,
        widget.stock.name,
      );
      if (result != null && mounted) {
        setState(() => _isInWatchlist = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to watchlist')));
      }
    }
  }

  void _navigateToBuy() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BuyStockScreen(stock: widget.stock, availableBalance: _userBalance),
      ),
    );
    if (result == true) {
      _loadData(); // Refresh data after purchase
    }
  }

  void _navigateToSell() async {
    if (_holding == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SellStockScreen(holding: _holding!),
      ),
    );
    if (result == true) {
      _loadData(); // Refresh data after sale
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stock.symbol),
        actions: [
          IconButton(
            icon: Icon(_isInWatchlist ? Icons.star : Icons.star_outline),
            color: _isInWatchlist ? Colors.amber : null,
            onPressed: _toggleWatchlist,
            tooltip: _isInWatchlist
                ? 'Remove from Watchlist'
                : 'Add to Watchlist',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockHeader(),
            const SizedBox(height: 24),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildChart(),
            const SizedBox(height: 24),
            if (_holding != null) ...[
              _buildHoldingInfo(),
              const SizedBox(height: 24),
            ],
            _buildStatistics(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader() {
    final stock = widget.stock;
    final isPositive = stock.isPositive;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stock.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stock.currency} ${stock.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${stock.change.toStringAsFixed(2)} (${stock.changePercent.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Market: ${stock.marketState}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPeriod = period['value']!);
                  _loadHistory();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    if (_isLoadingHistory) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_historyData.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No chart data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Simple line chart representation
    final prices = _historyData
        .map((d) => (d['close'] as num).toDouble())
        .toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final isPositive = prices.isNotEmpty && prices.last >= prices.first;
    final lineColor = isPositive ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ChartPainter(
                  prices: prices,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                  priceRange: priceRange,
                  lineColor: lineColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'High: ${maxPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  'Low: ${minPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingInfo() {
    final holding = _holding!;
    final isProfit = holding.isProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Position',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPositionItem('Shares', '${holding.quantity}'),
                _buildPositionItem(
                  'Avg Cost',
                  holding.averagePurchasePrice.toStringAsFixed(2),
                ),
                _buildPositionItem(
                  'Value',
                  holding.currentValue.toStringAsFixed(2),
                ),
                _buildPositionItem(
                  'P&L',
                  '${isProfit ? '+' : ''}${holding.profitLoss.toStringAsFixed(2)}',
                  valueColor: profitColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_historyData.isNotEmpty) ...[
              _buildStatRow(
                'Open',
                _historyData.last['open']?.toStringAsFixed(2) ?? '-',
              ),
              _buildStatRow(
                'High',
                _historyData.last['high']?.toStringAsFixed(2) ?? '-',
              ),
              _buildStatRow(
                'Low',
                _historyData.last['low']?.toStringAsFixed(2) ?? '-',
              ),
              _buildStatRow(
                'Close',
                _historyData.last['close']?.toStringAsFixed(2) ?? '-',
              ),
              _buildStatRow(
                'Volume',
                _formatVolume(_historyData.last['volume']),
              ),
            ] else ...[
              Text(
                'Loading statistics...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatVolume(dynamic volume) {
    if (volume == null) return '-';
    final v = (volume as num).toDouble();
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(2)}B';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}K';
    return v.toStringAsFixed(0);
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _navigateToBuy,
              icon: const Icon(Icons.add),
              label: const Text(
                'Buy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _holding != null ? _navigateToSell : null,
              icon: const Icon(Icons.remove),
              label: const Text(
                'Sell',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Simple chart painter
class _ChartPainter extends CustomPainter {
  final List<double> prices;
  final double minPrice;
  final double maxPrice;
  final double priceRange;
  final Color lineColor;

  _ChartPainter({
    required this.prices,
    required this.minPrice,
    required this.maxPrice,
    required this.priceRange,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty || priceRange == 0) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * size.width;
      final y =
          size.height - ((prices[i] - minPrice) / priceRange) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
