import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// The reference screen's "cash out" button is deliberately absent: RideEt has no payout
/// rail behind the balance, so this shows what the driver has actually earned.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _earnings;
  List<Map<String, dynamic>> _rides = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final earnings = await ApiClient().dio
          .get('/driver/earnings', queryParameters: {'days': 7});
      final history = await ApiClient().dio
          .get('/driver/rides/history', queryParameters: {'size': 10});
      if (!mounted) return;
      setState(() {
        _earnings = Map<String, dynamic>.from(earnings.data['data'] as Map);
        _rides = List<Map<String, dynamic>>.from(
            (history.data['data']['content'] ?? []) as List);
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.data is Map && e.response!.data['message'] is String
            ? e.response!.data['message'] as String
            : 'Could not load your earnings';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Payout')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Try again')),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WeekCard(earnings: _earnings!),
                        const SizedBox(height: 16),
                        _DayBars(days: _days()),
                        const SizedBox(height: 16),
                        _WalletCard(earnings: _earnings!),
                        const SizedBox(height: 24),
                        const Text('Recent trips',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (_rides.isEmpty)
                          const Text('No trips yet', style: TextStyle(color: Colors.grey))
                        else
                          ..._rides.map((ride) => _TripRow(ride: ride)),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<Map<String, dynamic>> _days() {
    final rows = _earnings?['days'];
    if (rows is! List) return const [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }
}

class _WeekCard extends StatelessWidget {
  final Map<String, dynamic> earnings;
  const _WeekCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final window = (earnings['windowEarnings'] as num?)?.toDouble() ?? 0;
    final rides = (earnings['windowRides'] as num?)?.toInt() ?? 0;
    final lifetime = (earnings['lifetimeEarnings'] as num?)?.toDouble() ?? 0;
    final rating = (earnings['rating'] as num?)?.toDouble() ?? 0;
    final ratings = (earnings['totalRatings'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${earnings['windowDays'] ?? 7} days',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 6),
          Text('ETB ${window.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$rides completed rides',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                  child: _MiniStat(
                      label: 'Lifetime', value: 'ETB ${lifetime.toStringAsFixed(0)}')),
              Expanded(
                  child: _MiniStat(
                      label: 'Rating',
                      value: ratings == 0 ? 'No ratings yet' : rating.toStringAsFixed(1)),
            )
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _DayBars extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _DayBars({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final max = days
        .map((day) => (day['amount'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily earnings',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final amount = (day['amount'] as num?)?.toDouble() ?? 0;
                final height = max == 0 ? 4.0 : (100 * amount / max).clamp(4.0, 100.0);
                final date = DateTime.tryParse('${day['date']}');
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: amount == 0 ? Colors.grey.shade200 : AppTheme.primaryColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(date == null ? '' : DateFormat('E').format(date),
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final Map<String, dynamic> earnings;
  const _WalletCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final balance = (earnings['walletBalance'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('ETB ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _TripRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    final raw = ride['completedAt']?.toString();
    final when = raw == null ? null : DateTime.tryParse(raw);
    final fare = (ride['actualFare'] as num?) ?? (ride['estimatedFare'] as num?);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride['destinationAddress'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  when == null
                      ? '${ride['status'] ?? ''}'
                      : '${DateFormat('MMM d, h:mm a').format(when)} · ${ride['status']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(fare == null ? '-' : 'ETB ${fare.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.onlineColor)),
        ],
      ),
    );
  }
}
