import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/trip_bloc.dart';

class TripScreen extends StatefulWidget {
  final String rideId;
  const TripScreen({super.key, required this.rideId});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  GoogleMapController? _mapController;
  String _otpInput = '';
  StreamSubscription? _pushes;

  @override
  void initState() {
    super.initState();
    context.read<TripBloc>().add(TripLoaded(widget.rideId));
    // A passenger can walk away mid-approach; the driver at the kerb must hear about it.
    _pushes = WebSocketService().pushes.listen((push) {
      if (!mounted) return;
      if (push.rideId.toString() != widget.rideId) return;
      if (push.eventType == 'RIDE_CANCELLED') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The passenger cancelled this ride.')));
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _pushes?.cancel();
    super.dispose();
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
        return 'Head to the pickup';
      case 'DRIVER_ARRIVED':
        return 'Waiting for the passenger';
      case 'IN_PROGRESS':
        return 'Ride in progress';
      case 'SEARCHING':
        return 'Looking for a driver';
      default:
        return 'Loading trip...';
    }
  }

  void _centerOn(LatLng point) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripBloc, TripState>(
      listener: (ctx, state) {
        if (state is TripIdle) ctx.go('/home');
        if (state is TripFailure) {
          ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
        }
      },
      builder: (ctx, state) {
        if (state is TripLoading) return _TripScaffold(child: const Center(child: CircularProgressIndicator()));
        if (state is TripDone) return _CompletedPanel(ride: state.ride);

        final ride = state is TripActive ? state.ride : null;
        final pickup = ride == null
            ? null
            : LatLng((ride['pickupLatitude'] as num?)?.toDouble() ?? 0,
                (ride['pickupLongitude'] as num?)?.toDouble() ?? 0);

        return _TripScaffold(
          statusLabel: _statusLabel(ride?['status']),
          detailLabel: switch (ride?['status']) {
            'IN_PROGRESS' => ride?['destinationAddress']?.toString(),
            _ => ride?['pickupAddress']?.toString(),
          },
          map: GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              if (pickup != null) _centerOn(pickup);
            },
            initialCameraPosition:
                CameraPosition(target: pickup ?? const LatLng(8.9950, 38.7800), zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              if (ride != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: pickup!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(title: 'Pickup', snippet: '${ride['pickupAddress']}'),
                ),
              if (ride != null)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: LatLng((ride['destinationLatitude'] as num).toDouble(),
                      (ride['destinationLongitude'] as num).toDouble()),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow:
                      InfoWindow(title: 'Destination', snippet: '${ride['destinationAddress']}'),
                ),
            },
          ),
          panel: _TripPanel(
            ride: ride,
            otp: _otpInput,
            busy: state is TripLoading,
            onOtpChanged: (v) => _otpInput = v,
            onArrived: () => ctx.read<TripBloc>().add(TripArrived(widget.rideId)),
            onStart: () => ctx.read<TripBloc>().add(TripStarted(widget.rideId, _otpInput)),
            onComplete: () => ctx.read<TripBloc>().add(TripCompleted(widget.rideId)),
            onCancel: () => _confirmCancel(ctx),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext ctx) async {
    final yes = await showDialog<bool>(
      context: ctx,
      builder: (b) => AlertDialog(
        title: const Text('Cancel this ride?'),
        content: const Text('The passenger is told you cancelled and the ride goes back to the pool.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(b, false), child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(b, true), child: const Text('Cancel ride')),
        ],
      ),
    );
    if (yes != true || !ctx.mounted) return;
    ctx.read<TripBloc>().add(TripCancelled(widget.rideId, reason: 'driver cancelled'));
  }
}

class _TripScaffold extends StatelessWidget {
  final Widget? map;
  final Widget? panel;
  final String? statusLabel;
  final String? detailLabel;
  final Widget child;

  _TripScaffold({this.map, this.panel, this.statusLabel, this.detailLabel, Widget? child})
      : child = child ?? const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    if (map == null) return Scaffold(body: child);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: map!),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppTheme.primaryColor,
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(statusLabel ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        if (detailLabel != null)
                          Text(detailLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: panel ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _TripPanel extends StatelessWidget {
  final Map<String, dynamic>? ride;
  final String otp;
  final bool busy;
  final ValueChanged<String> onOtpChanged;
  final VoidCallback onArrived;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _TripPanel({
    required this.ride,
    required this.otp,
    required this.busy,
    required this.onOtpChanged,
    required this.onArrived,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = ride?['status'];
    final fare = (ride?['estimatedFare'] as num?)?.toDouble();
    final km = (ride?['distanceKm'] as num?)?.toDouble();
    final minutes = (ride?['durationMinutes'] as num?)?.toInt();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ride != null)
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${ride!['passengerName'] ?? 'Passenger'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${ride!['destinationAddress'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fare == null ? 'Fare pending' : 'ETB ${fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    if (km != null || minutes != null)
                      Text(
                          '${km == null ? '' : '${km.toStringAsFixed(1)} km'}'
                          '${km != null && minutes != null ? ' · ' : ''}'
                          '${minutes == null ? '' : '$minutes min'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          if (ride != null) const SizedBox(height: 16),
          if (status == 'DRIVER_ASSIGNED')
            _PrimaryButton(label: 'I have arrived', onPressed: onArrived)
          else if (status == 'DRIVER_ARRIVED') ...[
            const Text('Ask the passenger for their 6-digit start code',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            PinCodeTextField(
              appContext: context,
              length: 6,
              onChanged: onOtpChanged,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 46,
                fieldWidth: 40,
                activeFillColor: Colors.white,
                selectedFillColor: Colors.white,
                inactiveFillColor: Colors.white,
                activeColor: AppTheme.primaryColor,
                selectedColor: AppTheme.primaryColor,
                inactiveColor: Colors.grey.shade300,
              ),
              enableActiveFill: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            _SlideToAction(
              label: 'SLIDE TO START TRIP',
              disabledLabel: 'Enter the code to start',
              enabled: otp.length == 6 && !busy,
              onConfirm: onStart,
            ),
          ] else if (status == 'IN_PROGRESS')
            _SlideToAction(
              label: 'SLIDE TO COMPLETE RIDE',
              disabledLabel: 'Completing…',
              color: AppTheme.onlineColor,
              enabled: !busy,
              onConfirm: onComplete,
            ),
          if (status == 'DRIVER_ASSIGNED' || status == 'DRIVER_ARRIVED') ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onCancel, child: const Text('Cancel this ride')),
          ],
        ],
      ),
    );
  }
}

/// Deliberately has no tap handler — the whole point is that the action needs a drag.
class _SlideToAction extends StatefulWidget {
  final String label;

  /// Shown while the slider is locked, which differs per step.
  final String disabledLabel;
  final Color color;
  final bool enabled;
  final VoidCallback onConfirm;

  const _SlideToAction({
    required this.label,
    required this.disabledLabel,
    required this.enabled,
    required this.onConfirm,
    this.color = AppTheme.primaryColor,
  });

  @override
  State<_SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<_SlideToAction> {
  static const double _thumb = 48;
  double _dragged = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final travel = (constraints.maxWidth - _thumb - 8).clamp(0.0, double.infinity);
      return GestureDetector(
        onHorizontalDragUpdate: widget.enabled
            ? (delta) => setState(() =>
                _dragged = (_dragged + delta.delta.dx).clamp(0.0, travel))
            : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                final fired = travel > 0 && _dragged / travel > 0.85;
                setState(() => _dragged = 0);
                if (fired) widget.onConfirm();
              }
            : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.enabled ? widget.color.withOpacity(0.12) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: _thumb + 16),
                child: Text(
                  widget.enabled ? widget.label : widget.disabledLabel,
                  style: TextStyle(
                      color: widget.enabled ? widget.color : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Transform.translate(
                    offset: Offset(_dragged, 0),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: widget.enabled ? widget.color : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _CompletedPanel extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _CompletedPanel({required this.ride});

  @override
  Widget build(BuildContext context) {
    final actual = (ride['actualFare'] as num?)?.toDouble();
    final estimated = (ride['estimatedFare'] as num?)?.toDouble();
    final km = (ride['distanceKm'] as num?)?.toDouble();
    final minutes = (ride['durationMinutes'] as num?)?.toInt();
    final cash = ride['paymentMethod'] == 'CASH';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.check_circle_outline, size: 56, color: AppTheme.onlineColor),
              const SizedBox(height: 12),
              const Text('Trip complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(cash ? 'Collect the fare in cash.' : 'The card charge was billed automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              _Row(label: 'Passenger', value: '${ride['passengerName'] ?? '-'}'),
              _Row(
                  label: 'Fare',
                  value: 'ETB ${(actual ?? estimated ?? 0).toStringAsFixed(2)}',
                  strong: true),
              if (actual != null && estimated != null && actual != estimated)
                _Row(label: 'Estimate', value: 'ETB ${estimated.toStringAsFixed(2)}'),
              if (km != null) _Row(label: 'Distance', value: '${km.toStringAsFixed(1)} km'),
              if (minutes != null) _Row(label: 'Duration', value: '$minutes min'),
              const Spacer(),
              _PrimaryButton(label: 'Back online', onPressed: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool strong;

  const _Row({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.bold : FontWeight.w500, fontSize: strong ? 18 : 14)),
        ],
      ),
    );
  }
}
