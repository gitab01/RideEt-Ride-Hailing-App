import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../booking/bloc/booking_bloc.dart';
import '../bloc/home_bloc.dart';
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
  LatLng _cameraTarget = _addisCenter;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    context.read<BookingBloc>().add(ActiveRideLoaded());
    context.read<HomeBloc>().add(HomeLoadRequested());
  }

  Future<void> _loadLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _cameraTarget = LatLng(position.latitude, position.longitude));
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_cameraTarget, 15));
    } catch (_) {
      // No fix (emulator, timeout): the Addis default stays on screen.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              controller.animateCamera(CameraUpdate.newLatLngZoom(_cameraTarget, 15));
            },
            initialCameraPosition: CameraPosition(target: _cameraTarget, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Greeting, on a solid card so the map stays readable underneath.
          Positioned(
            top: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
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
                          Text('Good morning',
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
          ),

          // Bottom booking panel
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
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/booking'),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Where to?',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _RecentChips(),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 232,
            child: FloatingActionButton.small(
              onPressed: _locating ? null : _loadLocation,
              backgroundColor: Colors.white,
              child: _locating
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Places this rider has already been taken to; tapping one books the return trip.
class _RecentChips extends StatelessWidget {
  const _RecentChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final places = state is HomeLoaded ? state.recentPlaces : const <RecentPlace>[];
        if (places.isEmpty) {
          return Text(
            'No recent destinations yet',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          );
        }
        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final place = places[index];
              return GestureDetector(
                onTap: () => context.push('/booking', extra: place),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        place.address.length > 24
                            ? '${place.address.substring(0, 24)}…'
                            : place.address,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
