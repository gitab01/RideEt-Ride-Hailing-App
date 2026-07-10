import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final profileRes = await ApiClient().dio.get('/driver/profile');
      final ridesRes   = await ApiClient().dio.get('/driver/rides/history');
      setState(() {
        _profile = profileRes.data['data'];
        _rides   = List<Map<String, dynamic>>.from(ridesRes.data['data']['content'] ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings'), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Summary cards
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(
                        label: 'Total Earnings',
                        value: '\$${(_profile?['totalEarnings'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.monetization_on,
                        color: AppTheme.onlineColor,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        label: 'Total Rides',
                        value: '${_profile?['totalRides'] ?? 0}',
                        icon: Icons.directions_car,
                        color: AppTheme.primaryColor,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(
                        label: 'Rating',
                        value: '${_profile?['rating'] ?? '5.0'} ⭐',
                        icon: Icons.star,
                        color: Colors.amber.shade700,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(
                        label: 'Reviews',
                        value: '${_profile?['totalRatings'] ?? 0}',
                        icon: Icons.reviews_outlined,
                        color: Colors.purple,
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recent Trips',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  if (_rides.isEmpty)
                    const Center(child: Text('No trips yet', style: TextStyle(color: Colors.grey)))
                  else
                    ..._rides.map((r) => _TripRow(ride: r)),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
    final date = ride['completedAt'] != null
        ? DateFormat('MMM d, h:mm a').format(DateTime.parse(ride['completedAt']))
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [const BoxShadow(blurRadius: 3, color: Colors.black08)],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride['destinationAddress'] ?? '', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('\$${(ride['actualFare'] as num?)?.toStringAsFixed(2) ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onlineColor)),
        ],
      ),
    );
  }
}
