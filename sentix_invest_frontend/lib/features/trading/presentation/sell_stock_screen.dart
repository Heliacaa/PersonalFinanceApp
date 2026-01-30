import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../portfolio/data/portfolio_models.dart';
import '../data/trading_repository.dart';

class SellStockScreen extends StatefulWidget {
  final PortfolioHolding holding;

  const SellStockScreen({super.key, required this.holding});

  @override
  State<SellStockScreen> createState() => _SellStockScreenState();
}

class _SellStockScreenState extends State<SellStockScreen> {
  final TradingRepository _tradingRepository = TradingRepository();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  bool _isLoading = false;
  int _quantity = 1;

  double get _totalProceeds => widget.holding.currentPrice * _quantity;
  bool get _canSell => _quantity > 0 && _quantity <= widget.holding.quantity;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() {
    final value = int.tryParse(_quantityController.text) ?? 0;
    setState(() => _quantity = value.clamp(0, widget.holding.quantity));
  }

  void _incrementQuantity() {
    if (_quantity < widget.holding.quantity) {
      final newValue = _quantity + 1;
      _quantityController.text = newValue.toString();
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      final newValue = _quantity - 1;
      _quantityController.text = newValue.toString();
    }
  }

  void _sellAll() {
    _quantityController.text = widget.holding.quantity.toString();
  }

  Future<void> _executeSell() async {
    if (!_canSell) return;

    setState(() => _isLoading = true);

    final response = await _tradingRepository.sellStock(
      widget.holding.symbol,
      _quantity,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate successful sale
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sell ${widget.holding.symbol}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Holding info header
            _buildHoldingHeader(),
            const SizedBox(height: 24),

            // Quantity input
            _buildQuantityInput(),
            const SizedBox(height: 24),

            // Order summary
            _buildOrderSummary(),
            const SizedBox(height: 24),

            // Sell button
            _buildSellButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingHeader() {
    final holding = widget.holding;
    final isProfit = holding.isProfit;
    final profitColor = isProfit ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.symbol,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      holding.stockName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${holding.currency} ${holding.currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                          color: profitColor,
                          size: 16,
                        ),
                        Text(
                          '${isProfit ? '+' : ''}${holding.profitLossPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: profitColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('You Own', '${holding.quantity} shares'),
                _buildInfoColumn(
                  'Avg Cost',
                  '${holding.averagePurchasePrice.toStringAsFixed(2)}',
                ),
                _buildInfoColumn(
                  'Total Value',
                  '${holding.currentValue.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildQuantityInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantity to Sell',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? _decrementQuantity : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                ),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _quantity < widget.holding.quantity
                      ? _incrementQuantity
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${widget.holding.quantity} shares',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                TextButton(onPressed: _sellAll, child: const Text('Sell All')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final holding = widget.holding;
    final costBasis = holding.averagePurchasePrice * _quantity;
    final proceeds = _totalProceeds;
    final profitLoss = proceeds - costBasis;
    final isProfit = profitLoss >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow(
              'Current Price',
              '${holding.currency} ${holding.currentPrice.toStringAsFixed(2)}',
            ),
            const Divider(),
            _buildSummaryRow('Quantity', '$_quantity shares'),
            const Divider(),
            _buildSummaryRow(
              'Cost Basis',
              '${holding.currency} ${costBasis.toStringAsFixed(2)}',
            ),
            const Divider(),
            _buildSummaryRow(
              'Estimated Proceeds',
              '${holding.currency} ${proceeds.toStringAsFixed(2)}',
              isBold: true,
            ),
            const Divider(),
            _buildSummaryRow(
              'Profit/Loss',
              '${isProfit ? '+' : ''}${holding.currency} ${profitLoss.toStringAsFixed(2)}',
              valueColor: isProfit ? Colors.green : Colors.red,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _canSell && !_isLoading ? _executeSell : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Sell $_quantity ${widget.holding.symbol}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
