import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(0, 0);
  StompClient? _stompClient;
  Timer? _locationTimer;
  Map<String, dynamic>? _pendingRide;
  Map<String, dynamic>? _driverProfile;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _startLocationUpdates();
    _connectWebSocket();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient().dio.get('/driver/profile');
      setState(() => _driverProfile = res.data['data']);
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    try {
      if (_isOnline) {
        await ApiClient().dio.post('/driver/offline');
      } else {
        await ApiClient().dio.post('/driver/online');
      }
      setState(() => _isOnline = !_isOnline);
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['message'] ?? 'Failed')));
    }
  }

  void _startLocationUpdates() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return;

    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_isOnline) return;
      try {
        final pos = await Geolocator.getCurrentPosition();
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
        await ApiClient().dio.post('/driver/location', data: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        });
      } catch (_) {}
    });
  }

  void _connectWebSocket() async {
    final token = await _storage.read(key: 'access_token');
    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: AppConfig.wsUrl,
        onConnect: (frame) {
          _stompClient?.subscribe(
            destination: '/user/queue/ride-requests',
            callback: (frame) {
              if (frame.body != null && mounted) {
                // Show ride request dialog
                _showRideRequest({'raw': frame.body});
              }
            },
          );
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _stompClient?.activate();
  }

  void _showRideRequest(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideRequestSheet(
        data: data,
        onAccept: (rideId) {
          Navigator.pop(context);
          context.go('/trip/$rideId');
        },
        onDecline: () => Navigator.pop(context),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _stompClient?.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(target: _currentLocation, zoom: 15),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top status bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              color: Colors.white,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isOnline ? 'You are Online' : 'You are Offline',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: _isOnline ? AppTheme.onlineColor : AppTheme.offlineColor)),
                      Text(
                        _isOnline ? 'Ready to receive rides' : 'Go online to start',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: _isOnline,
                    onChanged: (_) => _toggleOnline(),
                    activeColor: AppTheme.onlineColor,
                  ),
                ],
              ),
            ),
          ),

          // Bottom stats card
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                          label: 'Today\'s Earnings',
                          value: '\$0.00',
                          icon: Icons.attach_money,
                          color: AppTheme.onlineColor),
                      _StatCard(
                          label: 'Trips Today',
                          value: '0',
                          icon: Icons.directions_car,
                          color: AppTheme.primaryColor),
                      _StatCard(
                          label: 'Rating',
                          value: '${_driverProfile?['rating'] ?? '5.0'}',
                          icon: Icons.star,
                          color: Colors.amber),
                    ],
                  ),
                  if (!_isOnline) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _toggleOnline,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.onlineColor),
                      child: const Text('Go Online'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }
}

class _RideRequestSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String) onAccept;
  final VoidCallback onDecline;

  const _RideRequestSheet({required this.data, required this.onAccept, required this.onDecline});

  @override
  State<_RideRequestSheet> createState() => _RideRequestSheetState();
}

class _RideRequestSheetState extends State<_RideRequestSheet> {
  int _countdown = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown <= 0) {
        _timer?.cancel();
        widget.onDecline();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [const BoxShadow(blurRadius: 20, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Ride Request',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              CircleAvatar(
                backgroundColor: AppTheme.errorColor,
                child: Text('$_countdown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _LocRow(icon: Icons.circle, color: AppTheme.onlineColor, text: 'Pickup location'),
          const SizedBox(height: 8),
          const _LocRow(icon: Icons.location_on, color: AppTheme.errorColor, text: 'Destination'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDecline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    foregroundColor: AppTheme.errorColor,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final rideId = widget.data['rideId']?.toString() ?? '0';
                    widget.onAccept(rideId);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LocRow({required this.icon, required this.color, required this.text});

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
