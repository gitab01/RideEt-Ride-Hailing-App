import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../booking/bloc/booking_bloc.dart';
import '../../../core/theme/app_theme.dart';

/// Addis Ababa, where RideEt operates and where the emulator has no fix.
const LatLng _addisCenter = LatLng(8.9950, 38.7800);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = _addisCenter;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    context.read<BookingBloc>().add(ActiveRideLoaded());
  }

  Future<void> _loadLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationLoaded = true;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15),
      );
    } catch (_) {
      // No fix (emulator, denied permission): the Addis default stays on screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _locationLoaded ? _currentLocation : const LatLng(0, 0),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top greeting card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning 👋',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('Where are you going?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.go('/notifications'),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                ],
              ),
            ),
          ),

          // Bottom booking panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
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
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Search bar
                  GestureDetector(
                    onTap: () => context.go('/booking'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text('Where to?',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick destinations
                  Row(
                    children: [
                      _QuickDestButton(
                          icon: Icons.home_outlined,
                          label: 'Home',
                          onTap: () => context.go('/booking')),
                      const SizedBox(width: 12),
                      _QuickDestButton(
                          icon: Icons.work_outline,
                          label: 'Work',
                          onTap: () => context.go('/booking')),
                      const SizedBox(width: 12),
                      _QuickDestButton(
                          icon: Icons.add,
                          label: 'Add',
                          onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              onPressed: _loadLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDestButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickDestButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
