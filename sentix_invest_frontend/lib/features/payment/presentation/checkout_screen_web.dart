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
  bool _showIframe = true;
  String _viewId = '';
  bool? _paymentResult;
  String? _errorMessage;
  double? _newBalance;

  @override
  void initState() {
    super.initState();
    _viewId = 'iyzico-checkout-${DateTime.now().millisecondsSinceEpoch}';
    _setupIframe();
    _setupMessageListener();
  }

  void _setupIframe() {
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
  }

  void _setupMessageListener() {
    // Listen for messages from the iframe
    html.window.onMessage.listen((event) {
      if (event.data is Map) {
        final data = Map<String, dynamic>.from(event.data as Map);
        if (data['type'] == 'iyzico_callback') {
          final status = data['status'] as String?;
          if (status == 'success') {
            _checkPaymentStatus();
          } else if (status == 'error' || status == 'failure') {
            setState(() {
              _showIframe = false;
              _paymentResult = false;
              _errorMessage = 'Ödeme işlemi başarısız oldu.';
            });
          }
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
    // iyzico callback function
    window.iyziEventCallback = function(event) {
      window.parent.postMessage({
        type: 'iyzico_callback',
        status: event.type,
        data: event
      }, '*');
    };
  </script>
</body>
</html>
''';
  }

  Future<void> _checkPaymentStatus() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _paymentRepository.checkPaymentStatus(widget.token);

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _showIframe = false;
          _paymentResult = true;
          _newBalance = result.newBalance;
        });
      } else {
        setState(() {
          _showIframe = false;
          _paymentResult = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Ödeme durumu kontrol edilemedi: $e';
        });
      }
    }
  }

  void _confirmCancel() {
    setState(() {
      _showIframe = false;
      _paymentResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay ₺${widget.amount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
        actions: [
          // Manual check button
          if (_showIframe)
            TextButton.icon(
              onPressed: _isProcessing ? null : _checkPaymentStatus,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Ödeme Durumu'),
            ),
        ],
      ),
      body: _showIframe ? _buildIframeView() : _buildResultView(),
    );
  }

  Widget _buildIframeView() {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewId),
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
                    'Ödeme kontrol ediliyor...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultView() {
    if (_paymentResult == true) {
      return _buildSuccessView();
    } else if (_paymentResult == false) {
      return _buildErrorView();
    } else {
      return _buildCancelView();
    }
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Ödeme Başarılı!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '₺${widget.amount.toStringAsFixed(2)} hesabınıza eklendi.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_newBalance != null) ...[
              const SizedBox(height: 8),
              Text(
                'Yeni Bakiye: ₺${_newBalance!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text('Tamam', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Ödeme Başarısız',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showIframe = true;
                      _paymentResult = null;
                      _errorMessage = null;
                      _isProcessing = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Tekrar Dene',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Kapat', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.orange, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Ödemeyi İptal Et?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu ödemeyi iptal etmek istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() => _showIframe = true);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Hayır, Devam Et',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Evet, İptal Et',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
