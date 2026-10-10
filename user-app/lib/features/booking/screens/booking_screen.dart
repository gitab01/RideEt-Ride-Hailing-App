import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/booking_bloc.dart';
import '../../../core/theme/app_theme.dart';

/// Well-known Addis Ababa pick-ups. Addresses are typed by hand elsewhere in this
/// screen, so a rider can book without a geocoder round-trip.
const _places = <_Place>[
  _Place('Bole Medhanialem', 8.9950, 38.7800),
  _Place('Bole Airport', 8.9810, 38.7960),
  _Place('Mexico Square', 9.0100, 38.7530),
  _Place('Piassa', 9.0340, 38.7500),
  _Place('Kazanchis', 9.0110, 38.7580),
  _Place('CMC', 9.0300, 38.7400),
  _Place('Megenagna', 9.0330, 38.7640),
  _Place('Sar Bet', 8.9740, 38.8300),
  _Place('Ayat', 9.0570, 38.8020),
  _Place('Gerji', 9.0230, 38.8100),
];

class _Place {
  final String name;
  final double lat;
  final double lng;
  const _Place(this.name, this.lat, this.lng);
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _selectedVehicleType = 'ECONOMY';
  String _selectedPaymentMethod = 'CASH';
  _Place? _pickup;
  _Place? _destination;
  String? _pickupLabel;

  final _vehicleTypes = const [
    {'type': 'ECONOMY', 'icon': Icons.directions_car, 'label': 'Economy', 'desc': 'Everyday rides'},
    {'type': 'STANDARD', 'icon': Icons.car_rental, 'label': 'Standard', 'desc': 'Newer cars, more legroom'},
    {'type': 'PREMIUM', 'icon': Icons.star, 'label': 'Premium', 'desc': 'Business class'},
    {'type': 'XL', 'icon': Icons.airport_shuttle, 'label': 'XL', 'desc': 'Up to 6 seats'},
  ];

  void _estimateFare() {
    if (_pickup == null || _destination == null) return;
    context.read<BookingBloc>().add(EstimateFareRequested(
          _pickup!.lat, _pickup!.lng, _destination!.lat, _destination!.lng,
        ));
  }

  void _requestRide() {
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) {
      _toast('Choose a pickup and a destination first');
      return;
    }

    context.read<BookingBloc>().add(RideRequested({
      'pickupAddress': _pickupLabel ?? pickup.name,
      'pickupLatitude': pickup.lat,
      'pickupLongitude': pickup.lng,
      'destinationAddress': destination.name,
      'destinationLatitude': destination.lat,
      'destinationLongitude': destination.lng,
      'vehicleType': _selectedVehicleType,
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
      setState(() {
        _pickup = nearest;
        _pickupLabel = 'Near ${nearest.name}';
      });
      _estimateFare();
    } catch (_) {
      if (mounted) _toast('Could not read your location');
    }
  }

  static _Place _nearestTo(double lat, double lng) {
    _Place best = _places.first;
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

  Future<void> _pickPlace({required bool isPickup}) async {
    final chosen = await showModalBottomSheet<_Place>(
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
            ..._places.map((place) => ListTile(
                  leading: Icon(isPickup ? Icons.trip_origin : Icons.place,
                      color: AppTheme.primaryColor),
                  title: Text(place.name),
                  subtitle: Text('${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}'),
                  onTap: () => Navigator.pop(context, place),
                )),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickup = chosen;
        _pickupLabel = null;
      } else {
        _destination = chosen;
      }
    });
    _estimateFare();
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
          final estimate = state is FareEstimated ? state.estimate : null;
          final busy = state is BookingLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LocationCard(
                  pickup: _pickup,
                  destination: _destination,
                  pickupLabel: _pickupLabel,
                  onPickupTap: () => _pickPlace(isPickup: true),
                  onDestinationTap: () => _pickPlace(isPickup: false),
                  onUseCurrentLocation: _useCurrentLocation,
                ),
                if (estimate != null) ...[
                  const SizedBox(height: 16),
                  _EstimateSummary(estimate: estimate),
                ],
                const SizedBox(height: 20),
                const Text('Choose Ride',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._vehicleTypes.map((v) => _VehicleTypeCard(
                      type: v['type'] as String,
                      icon: v['icon'] as IconData,
                      label: v['label'] as String,
                      desc: v['desc'] as String,
                      selected: _selectedVehicleType == v['type'],
                      onTap: () => setState(() => _selectedVehicleType = v['type'] as String),
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
                  onPressed: busy ? null : _requestRide,
                  child: busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Request Ride'),
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
  final _Place? pickup;
  final _Place? destination;
  final String? pickupLabel;
  final VoidCallback onPickupTap;
  final VoidCallback onDestinationTap;
  final Future<void> Function() onUseCurrentLocation;

  const _LocationCard({
    required this.pickup, required this.destination,
    required this.onPickupTap, required this.onDestinationTap,
    required this.onUseCurrentLocation, this.pickupLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(blurRadius: 8, color: Colors.black12)],
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
                    _PlaceRow(
                      hint: 'Pickup location',
                      value: pickup == null ? null : (pickupLabel ?? pickup!.name),
                      onTap: onPickupTap,
                    ),
                    Divider(color: Colors.grey.shade200),
                    _PlaceRow(
                      hint: 'Destination',
                      value: destination?.name,
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
              onPressed: () => onUseCurrentLocation(),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use my location'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final String hint;
  final String? value;
  final VoidCallback onTap;

  const _PlaceRow({required this.hint, required this.onTap, this.value});

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

class _EstimateSummary extends StatelessWidget {
  final Map<String, dynamic> estimate;
  const _EstimateSummary({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final fare = (estimate['estimatedFare'] as num?)?.toDouble() ?? 0;
    final km = (estimate['distanceKm'] as num?)?.toDouble() ?? 0;
    final minutes = (estimate['durationMinutes'] as num?)?.toInt() ?? 0;
    final surge = (estimate['surgeMultiplier'] as num?)?.toDouble() ?? 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$km km • $minutes min',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              if (surge > 1)
                Text('High demand nearby',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
            ],
          ),
          Text('ETB ${fare.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  final String type, label, desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.type, required this.icon, required this.label,
    required this.desc, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? AppTheme.primaryColor : Colors.black)),
                  Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor),
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
