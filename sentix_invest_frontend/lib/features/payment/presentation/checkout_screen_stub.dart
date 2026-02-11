// Stub implementation for non-web platforms.
// The iyzico checkout iframe only works on web, so on native platforms
// we show a message directing users to use the web version.

import 'package:flutter/material.dart';

class CheckoutScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay ₺${amount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.web, color: Colors.blue, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Web Only',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'The payment checkout is only available on the web platform. '
                'Please use the web version of the app to add funds.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('Go Back', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
