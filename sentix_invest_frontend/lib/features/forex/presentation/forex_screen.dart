import 'package:flutter/material.dart';
import '../data/forex_models.dart';
import '../data/forex_repository.dart';

class ForexScreen extends StatefulWidget {
  const ForexScreen({super.key});

  @override
  State<ForexScreen> createState() => _ForexScreenState();
}

class _ForexScreenState extends State<ForexScreen>
    with SingleTickerProviderStateMixin {
  final _repository = ForexRepository();
  late TabController _tabController;

  // Rates tab
  List<ForexRate> _rates = [];
  bool _isLoadingRates = true;
  String? _ratesError;
  String _baseCurrency = 'USD';

  // Converter tab
  final _amountController = TextEditingController(text: '1000');
  String _fromCurrency = 'USD';
  String _toCurrency = 'TRY';
  ForexConvertResponse? _conversionResult;
  bool _isConverting = false;

  final List<String> _currencies = [
    'USD', 'EUR', 'GBP', 'TRY', 'JPY', 'CHF', 'CAD', 'AUD', 'CNY', 'INR'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() {
      _isLoadingRates = true;
      _ratesError = null;
    });

    try {
      final response = await _repository.getForexRates(base: _baseCurrency);
      setState(() {
        _rates = response.rates;
        _isLoadingRates = false;
      });
    } catch (e) {
      setState(() {
        _ratesError = e.toString();
        _isLoadingRates = false;
      });
    }
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isConverting = true);

    try {
      final result = await _repository.convertCurrency(
        from: _fromCurrency,
        to: _toCurrency,
        amount: amount,
      );
      setState(() {
        _conversionResult = result;
        _isConverting = false;
      });
    } catch (e) {
      setState(() => _isConverting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _conversionResult = null;
    });
  }

  String _getCurrencyFlag(String currency) {
    final flags = {
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'TRY': '🇹🇷',
      'JPY': '🇯🇵',
      'CHF': '🇨🇭',
      'CAD': '🇨🇦',
      'AUD': '🇦🇺',
      'CNY': '🇨🇳',
      'INR': '🇮🇳',
      'BRL': '🇧🇷',
      'RUB': '🇷🇺',
      'KRW': '🇰🇷',
      'MXN': '🇲🇽',
      'SGD': '🇸🇬',
    };
    return flags[currency] ?? '💱';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Forex Exchange'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C5CE7),
          tabs: const [
            Tab(text: 'Rates', icon: Icon(Icons.show_chart)),
            Tab(text: 'Converter', icon: Icon(Icons.swap_horiz)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRatesTab(),
          _buildConverterTab(),
        ],
      ),
    );
  }

  Widget _buildRatesTab() {
    return Column(
      children: [
        _buildBaseCurrencySelector(),
        Expanded(child: _buildRatesList()),
      ],
    );
  }

  Widget _buildBaseCurrencySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _currencies.map((currency) {
            final isSelected = _baseCurrency == currency;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${_getCurrencyFlag(currency)} $currency'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _baseCurrency = currency);
                    _loadRates();
                  }
                },
                selectedColor: const Color(0xFF6C5CE7),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                ),
                backgroundColor: const Color(0xFF16213E),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRatesList() {
    if (_isLoadingRates) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    if (_ratesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Error loading rates',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            TextButton(onPressed: _loadRates, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRates,
      color: const Color(0xFF6C5CE7),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rates.length,
        itemBuilder: (context, index) {
          final rate = _rates[index];
          return _buildRateCard(rate);
        },
      ),
    );
  }

  Widget _buildRateCard(ForexRate rate) {
    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              _getCurrencyFlag(rate.currency),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rate.currency,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    rate.name,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rate.rate.toStringAsFixed(rate.rate > 100 ? 2 : 4),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '1 $_baseCurrency',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConverterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // From Currency
          _buildCurrencyInput(
            label: 'From',
            currency: _fromCurrency,
            onCurrencyChanged: (value) {
              setState(() {
                _fromCurrency = value!;
                _conversionResult = null;
              });
            },
            controller: _amountController,
            showInput: true,
          ),
          const SizedBox(height: 16),
          // Swap Button
          IconButton(
            onPressed: _swapCurrencies,
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_vert,
                color: Color(0xFF6C5CE7),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // To Currency
          _buildCurrencyInput(
            label: 'To',
            currency: _toCurrency,
            onCurrencyChanged: (value) {
              setState(() {
                _toCurrency = value!;
                _conversionResult = null;
              });
            },
            result: _conversionResult?.result,
            showInput: false,
          ),
          const SizedBox(height: 32),
          // Convert Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isConverting ? null : _convert,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConverting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Convert',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (_conversionResult != null) ...[
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFF16213E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Exchange Rate',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1 ${_conversionResult!.fromCurrency} = ${_conversionResult!.rate.toStringAsFixed(4)} ${_conversionResult!.toCurrency}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyInput({
    required String label,
    required String currency,
    required void Function(String?) onCurrencyChanged,
    TextEditingController? controller,
    double? result,
    required bool showInput,
  }) {
    return Card(
      color: const Color(0xFF16213E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Currency Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: currency,
                    onChanged: onCurrencyChanged,
                    dropdownColor: const Color(0xFF16213E),
                    underline: const SizedBox(),
                    items: _currencies.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Text(_getCurrencyFlag(c)),
                            const SizedBox(width: 8),
                            Text(
                              c,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                // Amount Input or Result
                Expanded(
                  child: showInput
                      ? TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter amount',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          textAlign: TextAlign.right,
                        )
                      : Text(
                          result?.toStringAsFixed(2) ?? '0.00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
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
