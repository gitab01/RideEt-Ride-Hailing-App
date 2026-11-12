import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiClient().dio.get('/rides/history');
      setState(() {
        _rides = List<Map<String, dynamic>>.from(res.data['data']['content'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No trips yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _RideCard(ride: _rides[i]),
                ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _RideCard({required this.ride});

  Color _statusColor(String? status) {
    switch (status) {
      case 'COMPLETED': return AppTheme.successColor;
      case 'CANCELLED': return AppTheme.errorColor;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = ride['completedAt'] != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(ride['completedAt']))
        : 'In progress';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(ride['status']).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ride['status'] ?? '',
                  style: TextStyle(
                      color: _statusColor(ride['status']),
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.circle, iconColor: AppTheme.successColor,
            address: ride['pickupAddress'] ?? '',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(width: 1.5, height: 16, color: Colors.grey.shade300),
          ),
          _LocationRow(
            icon: Icons.location_on, iconColor: AppTheme.errorColor,
            address: ride['destinationAddress'] ?? '',
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${(ride['distanceKm'] as num?)?.toStringAsFixed(1) ?? '-'} km',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              Text(
                ride['actualFare'] == null
                    ? '-'
                    : 'ETB ${(ride['actualFare'] as num).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String address;
  const _LocationRow({required this.icon, required this.iconColor, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(address,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
