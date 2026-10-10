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
  Map<String, dynamic>? _rideData;
  StreamSubscription<RideUpdate>? _pushes;
  Timer? _fallbackRefresh;
  int _driversContacted = 0;

  /// Addis Ababa centre; the camera moves to the ride as soon as it is known.
  static const CameraPosition _initialCamera =
      CameraPosition(target: LatLng(8.9950, 38.7800), zoom: 14);

  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(RideStatusRefreshed(widget.rideId));

    // Pushes drive the UI; this poll only recovers a missed frame.
    _fallbackRefresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) { if (mounted) context.read<BookingBloc>().add(RideStatusRefreshed(widget.rideId)); },
    );

    _pushes = WebSocketService().updates.listen(_onPush);
  }

  void _onPush(RideUpdate update) {
    if (update.eventType == 'LOCATION') {
      _applyDriverPosition(update);
      return;
    }
    if (update.eventType == 'SEARCHING_DRIVERS') {
      setState(() => _driversContacted =
          (update.data['driversContacted'] as num?)?.toInt() ?? _driversContacted);
    }
  }

  void _applyDriverPosition(RideUpdate update) {
    final lat = update.latitude;
    final lng = update.longitude;
    if (lat == null || lng == null) return;
    final position = LatLng(lat, lng);
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'driver');
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: position,
        flat: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your driver'),
      ));
    });
    _mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  void _centerOnPickup(Map<String, dynamic> ride) {
    final lat = (ride['pickupLatitude'] as num?)?.toDouble();
    final lng = (ride['pickupLongitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _markers.removeWhere((m) => m.markerId.value == 'pickup');
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: ride['pickupAddress']?.toString() ?? 'Pickup'),
    ));
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14));
  }

  @override
  void dispose() {
    _pushes?.cancel();
    _fallbackRefresh?.cancel();
    WebSocketService().unsubscribeFromDriverLocation();
    super.dispose();
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'SEARCHING': return 'Finding your driver...';
      case 'DRIVER_ASSIGNED': return 'Driver is on the way';
      case 'DRIVER_ARRIVED': return 'Your driver has arrived';
      case 'IN_PROGRESS': return 'On the way to your destination';
      case 'COMPLETED': return 'Arrived';
      case 'CANCELLED': return 'Ride cancelled';
      case 'NO_DRIVER_FOUND': return 'No driver accepted nearby';
      default: return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is RideActive) {
          final driver = state.ride['driverUserId']?.toString();
          if (driver != null) WebSocketService().subscribeToDriverLocation(driver);
          setState(() {
            _rideData = state.ride;
            _centerOnPickup(state.ride);
          });
        }
        if (state is RideSearching) {
          setState(() => _driversContacted = state.driversContacted);
        }
        if (state is RideCompleted) {
          _fallbackRefresh?.cancel();
          WebSocketService().unsubscribeFromDriverLocation();
          context.go('/ride-complete/${widget.rideId}');
        }
        if (state is BookingError) {
          _fallbackRefresh?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
          context.go('/home');
        }
      },
      builder: (context, state) {
        final ride = state is RideActive
            ? state.ride
            : (state is RideSearching ? null : _rideData);
        final searching = state is RideSearching || ride?['status'] == 'SEARCHING';

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (c) {
                  _mapController = c;
                  if (_rideData != null) _centerOnPickup(_rideData!);
                },
                initialCameraPosition: _initialCamera,
                markers: _markers,
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
                        child: const Icon(Icons.directions_car, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              searching
                                  ? 'Finding your driver...'
                                  : _getStatusText(ride?['status']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (searching && _driversContacted > 0)
                              Text('Contacted $_driversContacted driver(s) so far',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            if (!searching && ride?['driverName'] != null)
                              Text(ride!['driverName'],
                                  style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (searching || ride?['status'] == 'DRIVER_ASSIGNED')
                        TextButton(
                          onPressed: () {
                            context.read<BookingBloc>()
                                .add(RideCancelled(widget.rideId, reason: 'Changed my mind'));
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
              if (ride != null && ride['driverName'] != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _DriverInfoCard(ride: ride),
                ),
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
    final rating = (ride['driverRating'] as num?)?.toDouble() ?? 5.0;
    final awaitingBoarding =
        ride['status'] == 'DRIVER_ASSIGNED' || ride['status'] == 'DRIVER_ARRIVED';

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
                        Text(rating.toStringAsFixed(1),
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
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
                Text([ride['vehicleColor'], ride['vehicleMake'], ride['vehicleModel']]
                    .whereType<String>()
                    .join(' ')),
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

          // The code only reaches the passenger, and only until they board.
          if (awaitingBoarding && ride['rideStartOtp'] != null) ...[
            const SizedBox(height: 12),
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
                  const Text('Show your driver this code:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(ride['rideStartOtp'].toString(),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
