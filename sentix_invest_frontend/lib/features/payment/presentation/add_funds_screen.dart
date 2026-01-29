import 'package:flutter/material.dart';
import '../data/payment_repository.dart';
import 'checkout_screen.dart';

class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  final _paymentRepository = PaymentRepository();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final List<double> _presetAmounts = [50, 100, 250, 500, 1000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectPreset(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
    setState(() => _error = null);
  }

  Future<void> _initiatePayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 1) {
      setState(() => _error = 'Minimum amount is ₺1');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _paymentRepository.initializeCheckout(amount);

      if (!mounted) return;

      if (result.success && result.htmlContent != null) {
        // Navigate to checkout screen with the HTML content
        final paymentSuccess = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              htmlContent: result.htmlContent!,
              token: result.token!,
              amount: amount,
            ),
          ),
        );

        if (paymentSuccess == true && mounted) {
          // Payment successful, go back to dashboard
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = result.errorMessage ?? 'Failed to initialize payment';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Funds')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'How much would you like to add?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₺ ',
                prefixStyle: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 24),

            // Preset amounts
            const Text(
              'Quick select:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetAmounts.map((amount) {
                return ActionChip(
                  label: Text('₺${amount.toStringAsFixed(0)}'),
                  onPressed: () => _selectPreset(amount),
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Payment info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Payment Information',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Secure payment via iyzico\n'
                      '• Funds will be added instantly\n'
                      '• No additional fees',
                      style: TextStyle(color: Colors.grey[600], height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Continue to Payment',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            // Test card info (for sandbox)
            const SizedBox(height: 24),
            Card(
              color: Colors.amber.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Test Card (Sandbox)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Card: 5528790000000008\n'
                      'Expiry: Any future date\n'
                      'CVV: Any 3 digits',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
