import 'package:flutter/material.dart';
import '../data/crypto_models.dart';
import '../data/crypto_repository.dart';

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  final _repository = CryptoRepository();
  List<CryptoQuote> _cryptos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCryptos();
  }

  Future<void> _loadCryptos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repository.getCryptoMarkets(limit: 50);
      setState(() {
        _cryptos = response.cryptocurrencies;
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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Cryptocurrencies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCryptos,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Error loading cryptocurrencies',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadCryptos,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_cryptos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.currency_bitcoin, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No cryptocurrencies available',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCryptos,
      color: const Color(0xFF6C5CE7),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cryptos.length,
        itemBuilder: (context, index) {
          final crypto = _cryptos[index];
          return _buildCryptoCard(crypto);
        },
      ),
    );
  }

  Widget _buildCryptoCard(CryptoQuote crypto) {
    final isPositive = crypto.isPositive;
    final changeColor = isPositive ? Colors.green : Colors.red;

    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showCryptoDetails(crypto),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${crypto.rank}',
                    style: const TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Image
              if (crypto.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    crypto.image!,
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.currency_bitcoin,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.currency_bitcoin,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 12),
              // Name and Symbol
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crypto.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      crypto.symbol,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Price and Change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${crypto.price.toStringAsFixed(crypto.price < 1 ? 6 : 2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: changeColor,
                        size: 14,
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${crypto.changePercent24h.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCryptoDetails(CryptoQuote crypto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (crypto.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      crypto.image!,
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                        Icons.currency_bitcoin,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crypto.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      crypto.symbol,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '#${crypto.rank}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              'Price',
              '\$${crypto.price.toStringAsFixed(crypto.price < 1 ? 6 : 2)}',
            ),
            _buildDetailRow('24h Change', '${crypto.changePercent24h.toStringAsFixed(2)}%',
                color: crypto.isPositive ? Colors.green : Colors.red),
            _buildDetailRow('Market Cap', crypto.formattedMarketCap),
            _buildDetailRow(
              '24h Volume',
              '\$${(crypto.volume24h / 1e9).toStringAsFixed(2)}B',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
