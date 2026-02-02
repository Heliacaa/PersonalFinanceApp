import 'package:flutter/material.dart';
import '../data/alert_models.dart';
import '../data/alert_repository.dart';

class AlertsListScreen extends StatefulWidget {
  const AlertsListScreen({super.key});

  @override
  State<AlertsListScreen> createState() => _AlertsListScreenState();
}

class _AlertsListScreenState extends State<AlertsListScreen>
    with SingleTickerProviderStateMixin {
  final _alertRepository = AlertRepository();
  late TabController _tabController;

  List<PriceAlert> _activeAlerts = [];
  List<PriceAlert> _triggeredAlerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _alertRepository.getAlerts();
      setState(() {
        _activeAlerts = alerts.where((a) => a.isActive).toList();
        _triggeredAlerts = alerts
            .where((a) => !a.isActive && a.triggeredAt != null)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load alerts: $e'),
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

  Future<void> _deleteAlert(PriceAlert alert) async {
    try {
      await _alertRepository.deleteAlert(alert.id);
      await _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert deleted for ${alert.symbol}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAlert(PriceAlert alert) async {
    try {
      await _alertRepository.toggleAlert(alert.id);
      await _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text(
          'Price Alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C5CE7),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Active'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_activeAlerts.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Triggered'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D9A5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_triggeredAlerts.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsList(_activeAlerts, isActive: true),
                _buildAlertsList(_triggeredAlerts, isActive: false),
              ],
            ),
    );
  }

  Widget _buildAlertsList(List<PriceAlert> alerts, {required bool isActive}) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.notifications_none : Icons.notifications_active,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active alerts' : 'No triggered alerts',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Set alerts from any stock detail screen',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      color: const Color(0xFF6C5CE7),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          return _buildAlertCard(alerts[index], isActive: isActive);
        },
      ),
    );
  }

  Widget _buildAlertCard(PriceAlert alert, {required bool isActive}) {
    final isEventAlert = alert.isEarnings || alert.isDividend;
    final isAbove = alert.alertType == 'ABOVE';
    
    // Choose colors and icons based on alert type
    Color alertColor;
    IconData alertIcon;
    String alertLabel;
    
    if (alert.isDividend) {
      alertColor = const Color(0xFF6C5CE7); // Purple for dividends
      alertIcon = Icons.attach_money_rounded;
      alertLabel = 'DIVIDEND';
    } else if (alert.isEarnings) {
      alertColor = const Color(0xFFFFA502); // Orange for earnings
      alertIcon = Icons.event_note_rounded;
      alertLabel = 'EARNINGS';
    } else if (alert.isPercent) {
      alertColor = const Color(0xFF00B894); // Teal for percent change
      alertIcon = Icons.percent_rounded;
      alertLabel = 'PERCENT';
    } else {
      alertColor = isAbove ? const Color(0xFF00D9A5) : const Color(0xFFFF6B6B);
      alertIcon = isAbove ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
      alertLabel = alert.alertType;
    }
    
    final priceDiff = alert.targetPrice - alert.currentPrice;
    final percentDiff = (priceDiff / alert.currentPrice) * 100;

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) => _deleteAlert(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF2D2D44), const Color(0xFF1F1F35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: !isEventAlert && alert.wouldTrigger && isActive
              ? Border.all(color: alertColor, width: 2)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: alertColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              alertIcon,
              color: alertColor,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Text(
                alert.symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alertLabel,
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                alert.stockName,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (isEventAlert) ...[
                // For earnings/dividend alerts, show notification timing
                Row(
                  children: [
                    Icon(Icons.notifications_active, size: 14, color: alertColor),
                    const SizedBox(width: 4),
                    Text(
                      'Notify ${alert.daysNotice ?? 1} day${(alert.daysNotice ?? 1) > 1 ? 's' : ''} before',
                      style: TextStyle(
                        color: alertColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.isDividend 
                      ? 'Waiting for dividend announcement'
                      : 'Waiting for earnings date',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ] else ...[
                // For price alerts, show target and current price
                Row(
                  children: [
                    Text(
                      'Target: \$${alert.targetPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: alertColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Current: \$${alert.currentPrice.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${percentDiff.abs().toStringAsFixed(1)}% ${priceDiff > 0 ? 'below' : 'above'} target',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
              if (!isActive && alert.triggeredAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Triggered: ${_formatDate(alert.triggeredAt!)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ],
          ),
          trailing: isActive
              ? Switch(
                  value: alert.isActive,
                  onChanged: (value) => _toggleAlert(alert),
                  activeColor: const Color(0xFF6C5CE7),
                )
              : Icon(Icons.check_circle, color: const Color(0xFF00D9A5)),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
