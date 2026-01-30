import 'package:flutter/material.dart';
import '../data/portfolio_models.dart';
import '../data/portfolio_repository.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final PortfolioRepository _portfolioRepository = PortfolioRepository();

  List<PortfolioHolding> _holdings = [];
  PortfolioSummary? _summary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final holdings = await _portfolioRepository.getPortfolio();
      final summary = await _portfolioRepository.getPortfolioSummary();

      if (mounted) {
        setState(() {
          _holdings = holdings;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transaction History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadPortfolio, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPortfolio,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_holdings.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_summary != null) _buildSummaryCard(),
          const SizedBox(height: 24),
          if (_summary != null && _summary!.allocations.isNotEmpty) ...[
            const Text(
              'Asset Allocation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAllocationChart(),
            const SizedBox(height: 24),
          ],
          const Text(
            'Holdings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._holdings.map(_buildHoldingCard),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No holdings yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start investing by buying stocks from the Markets tab',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summary!;
    final isProfit = summary.isProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Portfolio Value',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '₺ ${summary.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: profitColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isProfit ? '+' : ''}₺${summary.totalProfitLoss.toStringAsFixed(2)} (${summary.totalProfitLossPercent.toStringAsFixed(2)}%)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Cost Basis',
                  '₺${summary.totalCostBasis.toStringAsFixed(2)}',
                ),
                _buildSummaryItem(
                  'Cash',
                  '₺${summary.cashBalance.toStringAsFixed(2)}',
                ),
                _buildSummaryItem('Holdings', '${summary.holdingsCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationChart() {
    final allocations = _summary!.allocations;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Simple horizontal bar representation
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: allocations.asMap().entries.map((entry) {
                    return Expanded(
                      flex: (entry.value.percentage * 10).toInt().clamp(
                        1,
                        1000,
                      ),
                      child: Container(
                        color: colors[entry.key % colors.length],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            ...allocations.asMap().entries.map((entry) {
              final allocation = entry.value;
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        allocation.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${allocation.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingCard(PortfolioHolding holding) {
    final isProfit = holding.isProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.symbol,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    holding.stockName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${holding.currency} ${holding.currentValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: profitColor,
                      size: 14,
                    ),
                    Text(
                      '${isProfit ? '+' : ''}${holding.profitLossPercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: profitColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${holding.quantity} shares @ ${holding.averagePurchasePrice.toStringAsFixed(2)}',
              ),
              Text(
                'P/L: ${isProfit ? '+' : ''}${holding.profitLoss.toStringAsFixed(2)}',
                style: TextStyle(
                  color: profitColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Transaction History Screen (included in same file for simplicity)
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final PortfolioRepository _portfolioRepository = PortfolioRepository();

  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'ALL'; // ALL, BUY, SELL

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactions = await _portfolioRepository.getTransactions();
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Transaction> get _filteredTransactions {
    if (_filter == 'ALL') return _transactions;
    return _transactions.where((t) => t.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Buy', 'BUY'),
                const SizedBox(width: 8),
                _buildFilterChip('Sell', 'SELL'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final transactions = _filteredTransactions;
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) =>
          _buildTransactionCard(transactions[index]),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isBuy = transaction.isBuy;
    final color = isBuy ? Colors.green : Colors.red;
    final icon = isBuy ? Icons.add_circle : Icons.remove_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          '${transaction.type} ${transaction.symbol}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.quantity} shares @ ${transaction.pricePerShare.toStringAsFixed(2)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isBuy ? '-' : '+'}${transaction.currency} ${transaction.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              _formatDate(transaction.executedAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
