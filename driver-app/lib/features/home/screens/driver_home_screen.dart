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
  Map<String, dynamic>? _week;
  double _todayEarnings = 0;
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
    _loadWeek();
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

  Future<void> _loadWeek() async {
    try {
      final res = await ApiClient().dio.get('/driver/earnings', queryParameters: {'days': 7});
      final data = res.data['data'];
      if (!mounted || data is! Map) return;
      setState(() {
        _week = Map<String, dynamic>.from(data);
        _todayEarnings = (data['todayEarnings'] as num?)?.toDouble() ?? 0;
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
      case 'RIDE_ASSIGNED':
        // Dispatched by the admin console: the ride is already this driver's, so there
        // is no offer to accept — open the trip.
        _sheetOpen = false;
        if (push.rideId != null) context.go('/trip/${push.rideId}');
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
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(CameraUpdate.newLatLngZoom(_position, 15));
            },
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
            child: _IdentityCard(
              name: _profile?['fullName']?.toString() ?? 'Driver',
              status: _status,
              verified: verified,
              onRefresh: _loadProfile,
            ),
          ),
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: _OnlineButton(
              online: _isOnline,
              enabled: verified,
              status: _status,
              onTap: _toggleOnline,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _TodayCard(
              earnings: _todayEarnings,
              acceptanceRate: _week?['acceptanceRatePercent'] as int?,
              wallet: (_week?['walletBalance'] as num?)?.toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String name;
  final String status;
  final bool verified;
  final VoidCallback onRefresh;

  const _IdentityCard({
    required this.name,
    required this.status,
    required this.verified,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 50, 8, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              name.isEmpty ? 'D' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  verified
                      ? switch (status) {
                          'ON_TRIP' => 'On a trip',
                          'SUSPENDED' => 'Account suspended',
                          'ONLINE' => 'Online — receiving requests',
                          _ => 'Offline',
                        }
                      : 'Verify your documents to go online',
                  style: TextStyle(
                      fontSize: 12,
                      color: verified ? Colors.grey.shade600 : AppTheme.errorColor),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}

class _OnlineButton extends StatelessWidget {
  final bool online;
  final bool enabled;
  final String status;
  final VoidCallback onTap;

  const _OnlineButton({
    required this.online,
    required this.enabled,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.onlineColor : AppTheme.offlineColor;
    final caption = !enabled
        ? 'Documents pending review'
        : switch (status) {
            'ON_TRIP' => 'Finish the trip to go back online',
            'SUSPENDED' => 'Contact RideEt support',
            _ => online ? 'Online — tap to go offline' : 'Offline — Tap to start receiving requests',
          };

    return Column(
      children: [
        GestureDetector(
          onTap: enabled && status != 'ON_TRIP' && status != 'SUSPENDED' ? onTap : null,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26)],
              border: Border.all(color: color, width: 6),
            ),
            child: Center(
              child: Text(
                online ? 'GO\nOFFLINE' : 'GO\nONLINE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 15, height: 1.2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: Colors.white,
          child: Text(caption,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  final double earnings;
  final int? acceptanceRate;
  final double? wallet;

  const _TodayCard({
    required this.earnings,
    required this.acceptanceRate,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: "Today's Earnings",
              value: 'ETB ${earnings.toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              color: AppTheme.onlineColor,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Acceptance Rate',
              value: acceptanceRate == null ? '—' : '$acceptanceRate%',
              icon: Icons.thumb_up_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Wallet',
              value: wallet == null ? '—' : 'ETB ${wallet!.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.amber.shade700,
            ),
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
