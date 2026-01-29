import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../data/payment_repository.dart';

class CheckoutScreen extends StatefulWidget {
  final String htmlContent;
  final String token;
  final double amount;

  const CheckoutScreen({
    super.key,
    required this.htmlContent,
    required this.token,
    required this.amount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _paymentRepository = PaymentRepository();
  bool _isProcessing = false;
  String _viewId = '';

  @override
  void initState() {
    super.initState();
    _viewId = 'iyzico-checkout-${DateTime.now().millisecondsSinceEpoch}';
    _setupIframe();
  }

  void _setupIframe() {
    // Create an iframe that will contain the iyzico checkout form
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc = _buildCheckoutHtml();

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => iframe,
    );

    // Listen for payment completion message from iframe
    html.window.onMessage.listen((event) {
      if (event.data is Map) {
        final data = event.data as Map;
        if (data['type'] == 'payment_complete') {
          _handlePaymentComplete(data['token'] as String?);
        }
      }
    });
  }

  String _buildCheckoutHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 16px;
      background: #1a1a2e;
      font-family: Arial, sans-serif;
    }
    #iyzico-checkout-form {
      display: flex;
      justify-content: center;
    }
  </style>
</head>
<body>
  <div id="iyzico-checkout-form">
    ${widget.htmlContent}
  </div>
  <script>
    // Override the callback to notify parent
    window.iyziEventCallback = function(event) {
      if (event.type === 'success' || event.type === 'failure') {
        window.parent.postMessage({
          type: 'payment_complete',
          token: '${widget.token}',
          status: event.type
        }, '*');
      }
    };
  </script>
</body>
</html>
''';
  }

  Future<void> _handlePaymentComplete(String? token) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _paymentRepository.checkPaymentStatus(
        token ?? widget.token,
      );

      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog(result.newBalance ?? 0);
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error processing payment: $e');
      }
    }
  }

  void _showSuccessDialog(double newBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₺${widget.amount.toStringAsFixed(2)} has been added to your account.',
            ),
            const SizedBox(height: 8),
            Text(
              'New Balance: ₺${newBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to add funds with success
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Payment Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, false); // Return to add funds
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay ₺${widget.amount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Payment?'),
                content: const Text(
                  'Are you sure you want to cancel this payment?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No, Continue'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, false);
                    },
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // iyzico checkout form in iframe
          HtmlElementView(viewType: _viewId),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing payment...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
