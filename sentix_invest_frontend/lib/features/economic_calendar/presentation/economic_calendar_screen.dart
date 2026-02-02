import 'package:flutter/material.dart';
import '../data/economic_calendar_models.dart';
import '../data/economic_calendar_repository.dart';

class EconomicCalendarScreen extends StatefulWidget {
  const EconomicCalendarScreen({super.key});

  @override
  State<EconomicCalendarScreen> createState() => _EconomicCalendarScreenState();
}

class _EconomicCalendarScreenState extends State<EconomicCalendarScreen> {
  final _repository = EconomicCalendarRepository();
  EconomicCalendarResponse? _calendarData;
  bool _isLoading = true;
  String? _error;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getEconomicCalendar(days: _selectedDays);
      setState(() {
        _calendarData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getImpactColor(String impact) {
    switch (impact.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getCountryFlag(String country) {
    final flags = {
      'US': '🇺🇸',
      'EU': '🇪🇺',
      'UK': '🇬🇧',
      'CN': '🇨🇳',
      'JP': '🇯🇵',
      'TR': '🇹🇷',
      'DE': '🇩🇪',
      'FR': '🇫🇷',
      'AU': '🇦🇺',
      'CA': '🇨🇦',
    };
    return flags[country.toUpperCase()] ?? '🌍';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Economic Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendar,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPeriodChip('3 Days', 3),
            const SizedBox(width: 8),
            _buildPeriodChip('7 Days', 7),
            const SizedBox(width: 8),
            _buildPeriodChip('14 Days', 14),
            const SizedBox(width: 8),
            _buildPeriodChip('30 Days', 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int days) {
    final isSelected = _selectedDays == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDays = days);
          _loadCalendar();
        }
      },
      selectedColor: const Color(0xFF6C5CE7),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
      ),
      backgroundColor: const Color(0xFF16213E),
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
              'Error loading calendar',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadCalendar,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final events = _calendarData?.events ?? [];
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No upcoming events',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Group events by date
    final groupedEvents = <String, List<EconomicEvent>>{};
    for (final event in events) {
      groupedEvents.putIfAbsent(event.date, () => []).add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final date = groupedEvents.keys.elementAt(index);
        final dateEvents = groupedEvents[date]!;
        return _buildDateSection(date, dateEvents);
      },
    );
  }

  Widget _buildDateSection(String date, List<EconomicEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...events.map((event) => _buildEventCard(event)),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final eventDate = DateTime(date.year, date.month, date.day);

      if (eventDate == today) {
        return 'Today';
      } else if (eventDate == tomorrow) {
        return 'Tomorrow';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildEventCard(EconomicEvent event) {
    return Card(
      color: const Color(0xFF16213E),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getCountryFlag(event.country),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.event,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getImpactColor(event.impact).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.impact,
                    style: TextStyle(
                      color: _getImpactColor(event.impact),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  event.time,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const Spacer(),
                if (event.previous != null) ...[
                  Text(
                    'Prev: ${event.previous}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
                if (event.forecast != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Forecast: ${event.forecast}',
                    style: const TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
