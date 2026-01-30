import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../market/data/market_models.dart';
import '../data/trading_repository.dart';

class BuyStockScreen extends StatefulWidget {
  final StockQuote stock;
  final double availableBalance;

  const BuyStockScreen({
    super.key,
    required this.stock,
    required this.availableBalance,
  });

  @override
  State<BuyStockScreen> createState() => _BuyStockScreenState();
}

class _BuyStockScreenState extends State<BuyStockScreen> {
  final TradingRepository _tradingRepository = TradingRepository();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  bool _isLoading = false;
  int _quantity = 1;

  double get _totalCost => widget.stock.price * _quantity;
  int get _maxAffordable =>
      (widget.availableBalance / widget.stock.price).floor();
  bool get _canAfford => _totalCost <= widget.availableBalance;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() {
    final value = int.tryParse(_quantityController.text) ?? 0;
    setState(() => _quantity = value.clamp(0, 999999));
  }

  void _incrementQuantity() {
    final newValue = _quantity + 1;
    _quantityController.text = newValue.toString();
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      final newValue = _quantity - 1;
      _quantityController.text = newValue.toString();
    }
  }

  void _setMaxQuantity() {
    _quantityController.text = _maxAffordable.toString();
  }

  Future<void> _executeBuy() async {
    if (_quantity < 1 || !_canAfford) return;

    setState(() => _isLoading = true);

    final response = await _tradingRepository.buyStock(
      widget.stock.symbol,
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
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate successful purchase
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
      appBar: AppBar(title: Text('Buy ${widget.stock.symbol}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock info header
            _buildStockHeader(),
            const SizedBox(height: 24),

            // Quantity input
            _buildQuantityInput(),
            const SizedBox(height: 24),

            // Order summary
            _buildOrderSummary(),
            const SizedBox(height: 24),

            // Buy button
            _buildBuyButton(),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.symbol,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(stock.name, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stock.currency} ${stock.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: 16,
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
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
              'Quantity',
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
                  onPressed: _incrementQuantity,
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
                  'Max affordable: $_maxAffordable shares',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                TextButton(
                  onPressed: _maxAffordable > 0 ? _setMaxQuantity : null,
                  child: const Text('Buy Max'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow(
              'Price per share',
              '${widget.stock.currency} ${widget.stock.price.toStringAsFixed(2)}',
            ),
            const Divider(),
            _buildSummaryRow('Quantity', '$_quantity shares'),
            const Divider(),
            _buildSummaryRow(
              'Estimated Total',
              '${widget.stock.currency} ${_totalCost.toStringAsFixed(2)}',
              isBold: true,
            ),
            const Divider(),
            _buildSummaryRow(
              'Available Balance',
              '₺ ${widget.availableBalance.toStringAsFixed(2)}',
              valueColor: _canAfford ? Colors.green : Colors.red,
            ),
            if (!_canAfford) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Insufficient balance',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildBuyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _quantity > 0 && _canAfford && !_isLoading
            ? _executeBuy
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Buy $_quantity ${widget.stock.symbol}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
