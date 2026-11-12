import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// What one ride costs and whether it has been collected. Cash rides are settled in the
/// car, so this screen only reports them; card rides go through Stripe's payment sheet.
class PaymentScreen extends StatefulWidget {
  final String rideId;
  const PaymentScreen({super.key, required this.rideId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await ApiClient().dio.get('/payments/rides/${widget.rideId}/status');
      setState(() {
        _status = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = _message(e, 'Could not read the payment for this ride');
        _loading = false;
      });
    }
  }

  Future<void> _pay() async {
    setState(() { _paying = true; _error = null; });
    try {
      final intent = await ApiClient().dio.post('/payments/rides/${widget.rideId}/create-intent');
      final clientSecret = (intent.data['data'] as Map)['clientSecret'] as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RideEt',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      await _loadStatus();
      if (mounted) setState(() => _paying = false);
    } on StripeException catch (e) {
      setState(() {
        _paying = false;
        _error = e.error.message ?? 'The card payment was not completed';
      });
    } on DioException catch (e) {
      setState(() {
        _paying = false;
        _error = _message(e, 'Payment could not be started');
      });
    } catch (_) {
      setState(() { _paying = false; _error = 'Payment could not be started'; });
    }
  }

  static String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return fallback;
  }

  bool get _isPaid => (_status?['status'] ?? '').toString() == 'COMPLETED';
  bool get _isCash => (_status?['paymentMethod'] ?? '').toString() == 'CASH';
  double get _amount => (_status?['amount'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                    ),
                    child: Column(
                      children: [
                        Text('ETB ${_amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          _isPaid
                              ? 'Paid'
                              : _isCash
                                  ? 'Pay the driver in cash'
                                  : 'Awaiting card payment',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),
                        _StatusChip(
                          label: (_status?['status'] ?? 'PENDING').toString(),
                          color: _isPaid
                              ? AppTheme.successColor
                              : _isCash
                                  ? AppTheme.primaryColor
                                  : Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_isPaid && !_isCash)
                    ElevatedButton(
                      onPressed: _paying ? null : _pay,
                      child: _paying
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Pay by card'),
                    )
                  else if (_isPaid)
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Back to home'),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
