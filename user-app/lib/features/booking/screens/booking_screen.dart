import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/booking_bloc.dart';
import '../../../core/theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  String _selectedVehicleType = 'ECONOMY';
  String _selectedPaymentMethod = 'CARD';
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;

  final _vehicleTypes = [
    {'type': 'ECONOMY', 'icon': Icons.directions_car, 'label': 'Economy', 'desc': '4 seats • Affordable'},
    {'type': 'STANDARD', 'icon': Icons.car_rental, 'label': 'Standard', 'desc': '4 seats • Comfortable'},
    {'type': 'PREMIUM', 'icon': Icons.star, 'label': 'Premium', 'desc': '4 seats • Luxury'},
    {'type': 'XL', 'icon': Icons.airport_shuttle, 'label': 'XL', 'desc': '6 seats • Spacious'},
  ];

  void _estimateFare() {
    if (_pickupLatLng != null && _destLatLng != null) {
      context.read<BookingBloc>().add(EstimateFareRequested(
            _pickupLatLng!.latitude, _pickupLatLng!.longitude,
            _destLatLng!.latitude, _destLatLng!.longitude,
          ));
    }
  }

  void _requestRide(Map<String, dynamic>? estimate) {
    if (_pickupLatLng == null || _destLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and destination')));
      return;
    }

    context.read<BookingBloc>().add(RideRequested({
      'pickupAddress': _pickupCtrl.text,
      'pickupLatitude': _pickupLatLng!.latitude,
      'pickupLongitude': _pickupLatLng!.longitude,
      'destinationAddress': _destCtrl.text,
      'destinationLatitude': _destLatLng!.latitude,
      'destinationLongitude': _destLatLng!.longitude,
      'vehicleType': _selectedVehicleType,
      'paymentMethod': _selectedPaymentMethod,
    }));
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
          if (state is BookingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
          }
        },
        builder: (context, state) {
          final estimate = state is FareEstimated ? state.estimate : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location inputs
                _LocationCard(
                  pickupCtrl: _pickupCtrl,
                  destCtrl: _destCtrl,
                  onPickupSet: (latlng) {
                    setState(() => _pickupLatLng = latlng);
                    _estimateFare();
                  },
                  onDestSet: (latlng) {
                    setState(() => _destLatLng = latlng);
                    _estimateFare();
                  },
                ),
                const SizedBox(height: 20),

                // Vehicle type
                const Text('Choose Ride',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._vehicleTypes.map((v) => _VehicleTypeCard(
                      type: v['type'] as String,
                      icon: v['icon'] as IconData,
                      label: v['label'] as String,
                      desc: v['desc'] as String,
                      selected: _selectedVehicleType == v['type'],
                      estimatedFare: estimate?['estimatedFare'],
                      onTap: () => setState(() => _selectedVehicleType = v['type'] as String),
                    )),

                const SizedBox(height: 20),

                // Payment method
                const Text('Payment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PaymentChip(
                      label: 'Card', icon: Icons.credit_card,
                      selected: _selectedPaymentMethod == 'CARD',
                      onTap: () => setState(() => _selectedPaymentMethod = 'CARD'),
                    ),
                    const SizedBox(width: 12),
                    _PaymentChip(
                      label: 'Wallet', icon: Icons.account_balance_wallet_outlined,
                      selected: _selectedPaymentMethod == 'WALLET',
                      onTap: () => setState(() => _selectedPaymentMethod = 'WALLET'),
                    ),
                    const SizedBox(width: 12),
                    _PaymentChip(
                      label: 'Cash', icon: Icons.money,
                      selected: _selectedPaymentMethod == 'CASH',
                      onTap: () => setState(() => _selectedPaymentMethod = 'CASH'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: state is BookingLoading ? null : () => _requestRide(estimate),
                  child: state is BookingLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(estimate != null
                          ? 'Request Ride • \$${estimate['estimatedFare']}'
                          : 'Request Ride'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final Function(LatLng) onPickupSet;
  final Function(LatLng) onDestSet;

  const _LocationCard({
    required this.pickupCtrl, required this.destCtrl,
    required this.onPickupSet, required this.onDestSet,
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
                    TextField(
                      controller: pickupCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Pickup location',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onTap: () async {
                        // TODO: open place picker
                        final pos = await Geolocator.getCurrentPosition();
                        pickupCtrl.text = 'Current Location';
                        onPickupSet(LatLng(pos.latitude, pos.longitude));
                      },
                    ),
                    Divider(color: Colors.grey.shade200),
                    TextField(
                      controller: destCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Destination',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) {
                        // Demo: use a fixed offset for destination
                        onDestSet(const LatLng(37.7849, -122.4094));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  final String type, label, desc;
  final IconData icon;
  final bool selected;
  final double? estimatedFare;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.type, required this.icon, required this.label,
    required this.desc, required this.selected,
    required this.onTap, this.estimatedFare,
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
            if (estimatedFare != null)
              Text('\$${estimatedFare!.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? AppTheme.primaryColor : Colors.black)),
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
