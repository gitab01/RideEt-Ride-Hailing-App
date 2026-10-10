import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';

/// Addis Ababa centre, used until the phone reports a fix.
const _fallbackHome = LatLng(8.9950, 38.7800);

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _ws = WebSocketService();

  GoogleMapController? _mapController;
  LatLng _position = _fallbackHome;
  Map<String, dynamic>? _profile;
  double _todayEarnings = 0;
  int _todayTrips = 0;
  Timer? _pingTimer;
  StreamSubscription? _pushes;
  bool _sheetOpen = false;
  bool _didCenter = false;

  String get _status => (_profile?['status'] ?? 'OFFLINE') as String;
  bool get _isOnline => _status == 'ONLINE' || _status == 'ON_TRIP';

  @override
  void initState() {
    super.initState();
    _ws.connect();
    _pushes = _ws.pushes.listen(_onPush);
    _loadProfile();
    _loadToday();
    _startPinging();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _pushes?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient().dio.get('/driver/profile');
      if (!mounted) return;
      setState(() => _profile = res.data['data'] as Map<String, dynamic>);
      final lat = (_profile?['currentLatitude'] as num?)?.toDouble();
      final lng = (_profile?['currentLongitude'] as num?)?.toDouble();
      if (lat != null && lng != null) setState(() => _position = LatLng(lat, lng));
    } on DioException catch (e) {
      _show(_errorOf(e, 'Could not load your profile'));
    }
  }

  /// Today's takings are summed from the trip list rather than trusted from a counter,
  /// because the counter only moves when a ride completes.
  Future<void> _loadToday() async {
    try {
      final res = await ApiClient().dio.get('/driver/rides/history', queryParameters: {'size': 50});
      final rides = (res.data['data']['content'] ?? []) as List;
      final today = DateTime.now();
      double sum = 0;
      int count = 0;
      for (final r in rides) {
        if (r['status'] != 'COMPLETED') continue;
        final at = DateTime.tryParse('${r['completedAt']}');
        if (at == null) continue;
        if (at.year == today.year && at.month == today.month && at.day == today.day) {
          sum += (r['actualFare'] as num?)?.toDouble() ?? 0;
          count++;
        }
      }
      if (!mounted) return;
      setState(() {
        _todayEarnings = sum;
        _todayTrips = count;
      });
    } on DioException catch (_) {/* the stats simply stay at zero */}
  }

  Future<void> _toggleOnline() async {
    try {
      final res = _isOnline
          ? await ApiClient().dio.post('/driver/offline')
          : await ApiClient().dio.post('/driver/online');
      if (!mounted) return;
      setState(() => _profile = res.data['data'] as Map<String, dynamic>);
      // Matching only ever sees drivers the live index is holding, so the first ping
      // after going online has to leave immediately instead of waiting for the timer.
      if (!_isOnline) await _ping();
    } on DioException catch (e) {
      _show(_errorOf(e, 'Could not change your availability'));
    }
  }

  void _startPinging() {
    _ping();
    _pingTimer = Timer.periodic(const Duration(seconds: 8), (_) => _ping());
  }

  Future<void> _ping() async {
    if (!_isOnline) return;
    try {
      if (await Geolocator.isLocationServiceEnabled() == false) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _position = LatLng(pos.latitude, pos.longitude));
      if (!_didCenter) {
        _didCenter = true;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_position, 15));
      }
      _ws.sendLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        heading: pos.heading,
        speedKmh: pos.speed * 3.6,
      );
    } catch (_) {
      // No fix this round; the next tick retries.
    }
  }

  void _onPush(dynamic push) {
    if (!mounted) return;
    switch (push.eventType) {
      case 'RIDE_OFFER':
        _showOffer(push.data as Map<String, dynamic>);
        break;
      case 'OFFER_CANCELLED':
        // Someone else took it; drop the sheet if it is showing this ride.
        if (_sheetOpen) Navigator.of(context).pop();
        break;
      case 'RIDE_CANCELLED':
        _sheetOpen = false;
        _show('The passenger cancelled this ride.');
        context.go('/home');
        break;
    }
  }

  void _showOffer(Map<String, dynamic> offer) {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideRequestSheet(
        offer: offer,
        onAccept: (rideId) {
          setState(() => _sheetOpen = false);
          Navigator.pop(context);
          context.go('/trip/$rideId');
        },
        onDecline: (rideId) async {
          setState(() => _sheetOpen = false);
          Navigator.pop(context);
          // The offer may already have expired; nothing the driver can do about that.
          try {
            await ApiClient().dio.post('/driver/rides/$rideId/decline');
          } on DioException catch (_) {}
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError) return 'Cannot reach the RideEt server';
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final verified = _profile?['documentsVerified'] == true;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(target: _position, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _StatusBar(
              status: _status,
              verified: verified,
              onToggle: verified ? _toggleOnline : null,
              onRefresh: _loadProfile,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _TodayCard(
              earnings: _todayEarnings,
              trips: _todayTrips,
              rating: (_profile?['rating'] as num?)?.toDouble() ?? 5.0,
              rides: (_profile?['totalRides'] as num?)?.toInt() ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String status;
  final bool verified;
  final VoidCallback? onToggle;
  final VoidCallback onRefresh;

  const _StatusBar({
    required this.status,
    required this.verified,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final online = status == 'ONLINE' || status == 'ON_TRIP';
    final color = online ? AppTheme.onlineColor : AppTheme.offlineColor;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (status) {
                    'ON_TRIP' => 'On a trip',
                    'SUSPENDED' => 'Account suspended',
                    _ => online ? 'You are online' : 'You are offline',
                  },
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  verified
                      ? switch (status) {
                          'ON_TRIP' => 'Finish the trip to take another',
                          'SUSPENDED' => 'Contact RideEt support',
                          _ => online ? 'Receiving ride offers' : 'Go online to receive offers',
                        }
                      : 'Verify your documents to go online',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          Switch.adaptive(value: online, onChanged: onToggle == null ? null : (_) => onToggle!()),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final double earnings;
  final int trips;
  final double rating;
  final int rides;

  const _TodayCard({
    required this.earnings,
    required this.trips,
    required this.rating,
    required this.rides,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            label: "Today's ETB",
            value: earnings.toStringAsFixed(0),
            icon: Icons.payments_outlined,
            color: AppTheme.onlineColor,
          ),
          _Stat(
            label: 'Trips today',
            value: '$trips',
            icon: Icons.directions_car_outlined,
            color: AppTheme.primaryColor,
          ),
          _Stat(
            label: 'Rating ($rides)',
            value: rating.toStringAsFixed(1),
            icon: Icons.star_outline,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _Stat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _RideRequestSheet extends StatefulWidget {
  final Map<String, dynamic> offer;
  final void Function(int rideId) onAccept;
  final void Function(int rideId) onDecline;

  const _RideRequestSheet({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_RideRequestSheet> createState() => _RideRequestSheetState();
}

class _RideRequestSheetState extends State<_RideRequestSheet> {
  late final int _window;
  late int _left;
  Timer? _timer;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _window = (widget.offer['offerWindowSeconds'] as num?)?.toInt() ?? 20;
    _left = _window;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        widget.onDecline(_rideId);
      } else {
        setState(() => _left--);
      }
    });
  }

  int get _rideId => (widget.offer['rideId'] as num?)?.toInt() ?? 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    // The accept call can lose a race against another driver; the server answer decides.
    try {
      await ApiClient().dio.post('/driver/rides/$_rideId/accept');
      widget.onAccept(_rideId);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final data = e.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'That ride is no longer available';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final fare = (o['estimatedFare'] as num?)?.toDouble() ?? 0;
    final kmToPickup = (o['distanceToPickupKm'] as num?)?.toDouble();
    final tripMinutes = (o['durationMinutes'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Ride request',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.errorColor,
                child: Text('$_left',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${o['passengerName'] ?? 'Passenger'} · ${(o['vehicleType'] ?? '').toString()}'
            '${kmToPickup == null ? '' : ' · ${kmToPickup.toStringAsFixed(1)} km away'}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          _AddressRow(
            color: AppTheme.onlineColor,
            icon: Icons.radio_button_checked,
            text: '${o['pickupAddress'] ?? 'Pickup'}',
          ),
          const SizedBox(height: 8),
          _AddressRow(
            color: AppTheme.errorColor,
            icon: Icons.place_outlined,
            text: '${o['destinationAddress'] ?? 'Destination'}',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ETB ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (tripMinutes != null)
                Text('~$tripMinutes min', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onDecline(_rideId),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    foregroundColor: AppTheme.errorColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Offer is first to accept · ${AppConfig.baseUrl.split('//').last}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _AddressRow({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
