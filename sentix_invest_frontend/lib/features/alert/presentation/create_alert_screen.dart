import 'package:flutter/material.dart';
import '../data/alert_models.dart';
import '../data/alert_repository.dart';

class CreateAlertScreen extends StatefulWidget {
  final String symbol;
  final String stockName;
  final double currentPrice;

  const CreateAlertScreen({
    super.key,
    required this.symbol,
    required this.stockName,
    required this.currentPrice,
  });

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _alertRepository = AlertRepository();
  final _daysNoticeController = TextEditingController(text: '1');
  String _alertType =
      'ABOVE'; // ABOVE, BELOW, PERCENT_CHANGE, EARNINGS_REMINDER, DIVIDEND_PAYMENT
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with a suggested target (5% above/below current)
    _priceController.text = (widget.currentPrice * 1.05).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _daysNoticeController.dispose();
    super.dispose();
  }

  Future<void> _createAlert() async {
    // Only validate form if it's a price alert (where the input is visible)
    bool isPriceAlert = [
      'ABOVE',
      'BELOW',
      'PERCENT_CHANGE',
    ].contains(_alertType);
    if (isPriceAlert && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // For non-price alerts, targetPrice is ignored by backend logic but required by @Positive validation.
      // We send 1.0 as a dummy positive value.
      final double targetPrice = isPriceAlert
          ? (double.tryParse(_priceController.text) ?? 0)
          : 1.0;

      final request = CreateAlertRequest(
        symbol: widget.symbol,
        stockName: widget.stockName,
        targetPrice: targetPrice,
        alertType: _alertType,
        referencePrice: widget.currentPrice,
        daysNotice: int.tryParse(_daysNoticeController.text),
      );

      await _alertRepository.createAlert(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert created for ${widget.symbol}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPriceAlert = [
      'ABOVE',
      'BELOW',
      'PERCENT_CHANGE',
    ].contains(_alertType);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Text(
          'Set Alert',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stock Info Card
              _buildStockInfoCard(),
              const SizedBox(height: 32),

              // Alert Type Selector
              const Text(
                'Alert Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAlertTypeChip(
                    'Price Above',
                    'ABOVE',
                    Icons.arrow_upward_rounded,
                  ),
                  _buildAlertTypeChip(
                    'Price Below',
                    'BELOW',
                    Icons.arrow_downward_rounded,
                  ),
                  _buildAlertTypeChip(
                    '% Change',
                    'PERCENT_CHANGE',
                    Icons.percent_rounded,
                  ),
                  _buildAlertTypeChip(
                    'Earnings',
                    'EARNINGS_REMINDER',
                    Icons.event_note_rounded,
                  ),
                  _buildAlertTypeChip(
                    'Dividends',
                    'DIVIDEND_PAYMENT',
                    Icons.attach_money_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              if (isPriceAlert) ...[
                // Target Price Input
                const Text(
                  'Target Price',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPriceInput(),
                const SizedBox(height: 16),
                // Quick Percentage Buttons
                Wrap(
                  spacing: 8,
                  children: [
                    _buildPercentButton(-10),
                    _buildPercentButton(-5),
                    _buildPercentButton(5),
                    _buildPercentButton(10),
                    _buildPercentButton(20),
                  ],
                ),
              ] else ...[
                const Text(
                  'Notify Me Before',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDaysNoticeSelector(),
              ],

              const SizedBox(height: 40),

              // Create Alert Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Alert',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2D2D44), const Color(0xFF1F1F35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.symbol.substring(
                  0,
                  widget.symbol.length > 2 ? 2 : widget.symbol.length,
                ),
                style: const TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  widget.stockName,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Current Price',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                '\$${widget.currentPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInput() {
    final double targetPrice = double.tryParse(_priceController.text) ?? 0;
    final double percentDiff = widget.currentPrice > 0
        ? ((targetPrice - widget.currentPrice) / widget.currentPrice) * 100
        : 0;

    return TextFormField(
      controller: _priceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        prefixText: '\$ ',
        prefixStyle: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: const Color(0xFF2D2D44),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
        ),
        suffixIcon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${percentDiff >= 0 ? '+' : ''}${percentDiff.toStringAsFixed(1)}%',
              style: TextStyle(
                color: percentDiff >= 0
                    ? const Color(0xFF00D9A5)
                    : const Color(0xFFFF6B6B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onChanged: (value) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a target price';
        }
        final price = double.tryParse(value);
        if (price == null || price <= 0) {
          return 'Please enter a valid price';
        }
        return null;
      },
    );
  }

  Widget _buildDaysNoticeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _daysNoticeController.text,
          dropdownColor: const Color(0xFF2D2D44),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6C5CE7)),
          items: [
            const DropdownMenuItem(value: '1', child: Text('1 Day Before')),
            const DropdownMenuItem(value: '3', child: Text('3 Days Before')),
            const DropdownMenuItem(value: '7', child: Text('1 Week Before')),
            const DropdownMenuItem(value: '14', child: Text('2 Weeks Before')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _daysNoticeController.text = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildAlertTypeChip(String label, String type, IconData icon) {
    final isSelected = _alertType == type;
    final color = isSelected
        ? const Color(0xFF6C5CE7)
        : const Color(0xFF2D2D44);
    final textColor = isSelected ? Colors.white : Colors.grey[400];

    return GestureDetector(
      onTap: () => setState(() => _alertType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentButton(int percent) {
    return ActionChip(
      backgroundColor: const Color(0xFF2D2D44),
      label: Text(
        '${percent > 0 ? '+' : ''}$percent%',
        style: const TextStyle(color: Colors.white),
      ),
      onPressed: () {
        final newPrice = widget.currentPrice * (1 + percent / 100);
        _priceController.text = newPrice.toStringAsFixed(2);
        setState(() {
          _alertType = percent > 0 ? 'ABOVE' : 'BELOW';
        });
      },
    );
  }
}
