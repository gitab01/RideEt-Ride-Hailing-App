import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../bloc/booking_bloc.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng _driverLocation = const LatLng(0, 0);
  Timer? _refreshTimer;
  Map<String, dynamic>? _rideData;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    context.read<BookingBloc>().add(RideStatusRefreshed(widget.rideId));
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        context.read<BookingBloc>().add(RideStatusRefreshed(widget.rideId));
      }
    });

    // WebSocket for real-time driver location
    WebSocketService().subscribeToDriverLocation(
      widget.rideId,
      (msg) {
        // Parse driver location from message
        if (mounted) {
          setState(() {
            _driverLocation = LatLng(
              (msg['latitude'] as num?)?.toDouble() ?? 0,
              (msg['longitude'] as num?)?.toDouble() ?? 0,
            );
            _updateDriverMarker();
          });
        }
      },
    );
  }

  void _updateDriverMarker() {
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _driverLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Your Driver'),
    ));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WebSocketService().unsubscribeFromDriverLocation();
    super.dispose();
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'SEARCHING': return 'Finding your driver...';
      case 'DRIVER_ASSIGNED': return 'Driver is on the way';
      case 'DRIVER_ARRIVED': return 'Driver has arrived!';
      case 'IN_PROGRESS': return 'On your way';
      case 'COMPLETED': return 'Arrived!';
      case 'CANCELLED': return 'Ride cancelled';
      default: return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is RideActive) {
          setState(() => _rideData = state.ride);
          if (state.ride['status'] == 'DRIVER_ASSIGNED' ||
              state.ride['status'] == 'IN_PROGRESS') {
            // Subscribe to driver location
          }
        }
        if (state is RideCompleted) {
          _refreshTimer?.cancel();
          context.go('/ride-complete/${widget.rideId}');
        }
      },
      builder: (context, state) {
        final ride = state is RideActive ? state.ride : _rideData;

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(37.7749, -122.4194),
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),

              // Status card at top
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_car,
                            color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusText(ride?['status']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (ride?['driverName'] != null)
                              Text(ride!['driverName'],
                                  style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (ride?['status'] == 'DRIVER_ASSIGNED' ||
                          ride?['status'] == 'SEARCHING')
                        TextButton(
                          onPressed: () {
                            context.read<BookingBloc>().add(
                                RideCancelled(widget.rideId, reason: 'Changed my mind'));
                            context.go('/home');
                          },
                          child: const Text('Cancel',
                              style: TextStyle(color: AppTheme.errorColor)),
                        ),
                    ],
                  ),
                ),
              ),

              // Driver info card at bottom
              if (ride?['driverName'] != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _DriverInfoCard(ride: ride!),
                ),

              // Loading indicator
              if (ride?['status'] == 'SEARCHING')
                const Center(child: _SearchingAnimation()),
            ],
          ),
        );
      },
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _DriverInfoCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  (ride['driverName'] as String?)?.substring(0, 1) ?? 'D',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride['driverName'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text('${ride['driverRating'] ?? '5.0'}',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              // Call button
              CircleAvatar(
                backgroundColor: AppTheme.successColor,
                child: IconButton(
                  icon: const Icon(Icons.phone, color: Colors.white, size: 20),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${ride['vehicleColor'] ?? ''} ${ride['vehicleMake'] ?? ''}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ride['licensePlate'] ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Ride start OTP (shown to passenger)
          if (ride['status'] == 'DRIVER_ARRIVED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Show driver your OTP:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text('••••••',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          letterSpacing: 4, color: AppTheme.primaryColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchingAnimation extends StatefulWidget {
  const _SearchingAnimation();

  @override
  State<_SearchingAnimation> createState() => _SearchingAnimationState();
}

class _SearchingAnimationState extends State<_SearchingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      margin: const EdgeInsets.only(top: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: const Icon(Icons.directions_car, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          const Text('Finding your driver...', style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
