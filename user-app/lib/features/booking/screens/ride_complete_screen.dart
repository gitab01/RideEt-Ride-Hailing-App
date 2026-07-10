import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RideCompleteScreen extends StatefulWidget {
  final String rideId;
  const RideCompleteScreen({super.key, required this.rideId});

  @override
  State<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends State<RideCompleteScreen> {
  double _rating = 5;
  final _reviewCtrl = TextEditingController();
  bool _submitted = false;
  Map<String, dynamic>? _rideData;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final res = await ApiClient().dio.get('/rides/${widget.rideId}');
      setState(() => _rideData = res.data['data']);
    } catch (_) {}
  }

  Future<void> _submitRating() async {
    try {
      await ApiClient().dio.post('/rides/${widget.rideId}/rate', data: {
        'rating': _rating.toInt(),
        'review': _reviewCtrl.text,
      });
      setState(() => _submitted = true);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data['message'] ?? 'Failed to submit rating')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Success icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('You have arrived!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Hope you had a great ride',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              const SizedBox(height: 32),

              // Fare summary
              if (_rideData != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [const BoxShadow(blurRadius: 8, color: Colors.black12)],
                  ),
                  child: Column(
                    children: [
                      _SummaryRow('Distance', '${_rideData!['distanceKm']?.toStringAsFixed(1) ?? '-'} km'),
                      _SummaryRow('Duration', '${_rideData!['durationMinutes'] ?? '-'} min'),
                      const Divider(),
                      _SummaryRow('Total Fare',
                          '\$${_rideData!['actualFare']?.toStringAsFixed(2) ?? '-'}',
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Rating
              if (!_submitted) ...[
                const Text('Rate your driver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                RatingBar.builder(
                  initialRating: 5,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 40,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: AppTheme.accentColor),
                  onRatingUpdate: (rating) => _rating = rating,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reviewCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Leave a comment (optional)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitRating,
                  child: const Text('Submit Rating'),
                ),
              ] else
                const Column(
                  children: [
                    Icon(Icons.favorite, color: AppTheme.errorColor, size: 36),
                    SizedBox(height: 8),
                    Text('Thanks for rating!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),

              const Spacer(),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}
