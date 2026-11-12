import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/booking_bloc.dart';
import '../../home/bloc/home_bloc.dart';
import '../../../core/theme/app_theme.dart';

/// Well-known Addis Ababa pick-ups. Addresses are typed by hand elsewhere in this
/// screen, so a rider can book without a geocoder round-trip.
const _places = <_Spot>[
  _Spot('Bole Medhanialem', 8.9950, 38.7800),
  _Spot('Bole Airport', 8.9810, 38.7960),
  _Spot('Mexico Square', 9.0100, 38.7530),
  _Spot('Piassa', 9.0340, 38.7500),
  _Spot('Kazanchis', 9.0110, 38.7580),
  _Spot('CMC', 9.0300, 38.7400),
  _Spot('Megenagna', 9.0330, 38.7640),
  _Spot('Sar Bet', 8.9740, 38.8300),
  _Spot('Ayat', 9.0570, 38.8020),
  _Spot('Gerji', 9.0230, 38.8100),
  _Spot('Meskel Square', 9.0120, 38.7560),
];

class _Spot {
  final String label;
  final double lat;
  final double lng;
  const _Spot(this.label, this.lat, this.lng);
}

class BookingScreen extends StatefulWidget {
  /// A destination handed over by a recent-place chip on the home screen.
  final RecentPlace? initialDestination;

  const BookingScreen({super.key, this.initialDestination});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _selectedPaymentMethod = 'CASH';
  String? _selectedVehicleType;
  _Spot? _pickup;
  _Spot? _destination;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDestination;
    if (initial != null) {
      _destination = _Spot(initial.address, initial.lat, initial.lng);
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
    }
  }

  void _loadOptions() {
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) return;
    context.read<BookingBloc>().add(RideOptionsRequested(
          pickup.lat, pickup.lng, destination.lat, destination.lng,
        ));
  }

  void _requestRide() {
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) {
      _toast('Choose a pickup and a destination first');
      return;
    }
    final state = context.read<BookingBloc>().state;
    final vehicleType = _activeVehicleType(
        state is RideOptionsLoaded ? state.options : const <Map<String, dynamic>>[]);
    if (vehicleType == null) {
      _toast('Pick a ride type');
      return;
    }

    context.read<BookingBloc>().add(RideRequested({
      'pickupAddress': pickup.label,
      'pickupLatitude': pickup.lat,
      'pickupLongitude': pickup.lng,
      'destinationAddress': destination.label,
      'destinationLatitude': destination.lat,
      'destinationLongitude': destination.lng,
      'vehicleType': vehicleType,
      'paymentMethod': _selectedPaymentMethod,
    }));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor));
  }

  Future<void> _useCurrentLocation() async {
    if (await Geolocator.isLocationServiceEnabled() == false) {
      _toast('Turn on location services to use your current position');
      return;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
      if (!mounted) return;
      _toast('RideEt needs location access to set your pickup');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      // Snap to the nearest landmark so the address box stays readable.
      final nearest = _nearestTo(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _pickup = nearest);
      _loadOptions();
    } catch (_) {
      if (mounted) _toast('Could not read your location');
    }
  }

  static _Spot _nearestTo(double lat, double lng) {
    _Spot best = _places.first;
    double bestKm = double.infinity;
    for (final place in _places) {
      final km = Geolocator.distanceBetween(lat, lng, place.lat, place.lng) / 1000;
      if (km < bestKm) {
        bestKm = km;
        best = place;
      }
    }
    return best;
  }

  Future<void> _pickSpot({required bool isPickup}) async {
    final chosen = await showModalBottomSheet<_Spot>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(isPickup ? 'Where from?' : 'Where to?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ..._places.map((spot) => ListTile(
                  leading: Icon(isPickup ? Icons.trip_origin : Icons.place,
                      color: AppTheme.primaryColor),
                  title: Text(spot.label),
                  subtitle: Text('${spot.lat.toStringAsFixed(4)}, ${spot.lng.toStringAsFixed(4)}'),
                  onTap: () => Navigator.pop(context, spot),
                )),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickup = chosen;
      } else {
        _destination = chosen;
      }
    });
    _loadOptions();
  }

  /// The rider's explicit choice while it is still priced for this trip, otherwise the
  /// first tier with a car nearby. Derived instead of stored so a stale selection from a
  /// previous trip cannot be booked.
  String? _activeVehicleType(List<Map<String, dynamic>> options) {
    if (options.isEmpty) return null;
    final types = options.map((option) => option['vehicleType'] as String?).toList();
    if (_selectedVehicleType != null && types.contains(_selectedVehicleType)) {
      return _selectedVehicleType;
    }
    final reachable = options.firstWhere(
      (option) => option['pickupEtaMinutes'] != null,
      orElse: () => options.first,
    );
    return reachable['vehicleType'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Ride')),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is RideActive) {
            context.go('/tracking/${state.ride['id']}');
          }
          if (state is RideSearching && state.rideId != null) {
            context.go('/tracking/${state.rideId}');
          }
          if (state is BookingError) {
            _toast(state.message);
          }
        },
        builder: (context, state) {
          final options = state is RideOptionsLoaded ? state.options : const <Map<String, dynamic>>[];
          final activeType = _activeVehicleType(options);
          final busy = state is BookingLoading;

          final selected = options.firstWhere(
            (option) => option['vehicleType'] == activeType,
            orElse: () => const {},
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LocationCard(
                  pickup: _pickup,
                  destination: _destination,
                  onPickupTap: () => _pickSpot(isPickup: true),
                  onDestinationTap: () => _pickSpot(isPickup: false),
                  onUseCurrentLocation: _useCurrentLocation,
                ),
                const SizedBox(height: 20),
                const Text('Choose Ride',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (busy && options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (options.isEmpty)
                  Text(
                    _pickup == null || _destination == null
                        ? 'Select a pickup and a destination to see prices.'
                        : 'No fares available for this trip.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  )
                else
                  ...options.map((option) => _RideOptionCard(
                        option: option,
                        selected: option['vehicleType'] == activeType,
                        onTap: () =>
                            setState(() => _selectedVehicleType = option['vehicleType'] as String?),
                      )),
                const SizedBox(height: 20),
                const Text('Payment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PaymentChip(
                      label: 'Cash', icon: Icons.money,
                      selected: _selectedPaymentMethod == 'CASH',
                      onTap: () => setState(() => _selectedPaymentMethod = 'CASH'),
                    ),
                    const SizedBox(width: 12),
                    _PaymentChip(
                      label: 'Card', icon: Icons.credit_card,
                      selected: _selectedPaymentMethod == 'CARD',
                      onTap: () => setState(() => _selectedPaymentMethod = 'CARD'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: busy || activeType == null ? null : _requestRide,
                  child: busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(selected['displayName'] == null
                          ? 'Request Ride'
                          : 'Confirm ${selected['displayName']}'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final _Spot? pickup;
  final _Spot? destination;
  final VoidCallback onPickupTap;
  final VoidCallback onDestinationTap;
  final Future<void> Function() onUseCurrentLocation;

  const _LocationCard({
    required this.pickup, required this.destination,
    required this.onPickupTap, required this.onDestinationTap,
    required this.onUseCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 12, color: AppTheme.successColor),
                  Container(width: 2, height: 32, color: Colors.grey.shade300),
                  const Icon(Icons.location_on, size: 20, color: AppTheme.errorColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _SpotRow(
                      hint: 'Pickup location',
                      value: pickup?.label,
                      onTap: onPickupTap,
                    ),
                    Divider(color: Colors.grey.shade200),
                    _SpotRow(
                      hint: 'Destination',
                      value: destination?.label,
                      onTap: onDestinationTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onUseCurrentLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use my location'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  final String hint;
  final String? value;
  final VoidCallback onTap;

  const _SpotRow({required this.hint, required this.onTap, this.value});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          value ?? hint,
          style: TextStyle(
            fontSize: 15,
            color: value == null ? Colors.grey.shade500 : Colors.black87,
            fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RideOptionCard extends StatelessWidget {
  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback onTap;

  const _RideOptionCard({
    required this.option, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = option['displayName']?.toString() ?? 'RideEt';
    final fare = (option['estimatedFare'] as num?)?.toDouble();
    final eta = (option['pickupEtaMinutes'] as num?)?.toInt();
    final km = (option['distanceKm'] as num?)?.toDouble();
    final minutes = (option['durationMinutes'] as num?)?.toInt();
    final surge = (option['surgeMultiplier'] as num?)?.toDouble() ?? 1;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car,
                color: selected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? AppTheme.primaryColor : Colors.black)),
                  const SizedBox(height: 2),
                  Text(
                    eta == null
                        ? 'No cars available in this tier'
                        : 'Arrives in $eta min'
                            '${km == null ? '' : ' • ${km.toStringAsFixed(1)} km'}'
                            '${minutes == null ? '' : ' • $minutes min ride'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (surge > 1)
                    Text('High demand • ${surge.toStringAsFixed(1)}x',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fare == null ? '-' : 'ETB ${fare.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (selected)
                  const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16,
                color: selected ? Colors.white : AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }
}
