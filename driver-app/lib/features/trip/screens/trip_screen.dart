import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../bloc/trip_bloc.dart';
import '../../../core/theme/app_theme.dart';

class TripScreen extends StatefulWidget {
  final String rideId;
  const TripScreen({super.key, required this.rideId});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  GoogleMapController? _mapController;
  String _otpInput = '';

  @override
  void initState() {
    super.initState();
    context.read<TripBloc>().add(TripRefreshed(widget.rideId));
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'DRIVER_ASSIGNED': return 'Head to Pickup';
      case 'DRIVER_ARRIVED':  return 'Waiting for Passenger';
      case 'IN_PROGRESS':     return 'Ride in Progress';
      default: return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripBloc, TripState>(
      listener: (ctx, state) {
        if (state is TripDone) ctx.go('/home');
        if (state is TripError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
        }
      },
      builder: (ctx, state) {
        final ride = state is TripActive ? state.ride : null;
        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (ride?['pickupLatitude'] as num?)?.toDouble() ?? 0,
                    (ride?['pickupLongitude'] as num?)?.toDouble() ?? 0,
                  ),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: {
                  if (ride != null) Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(
                      (ride['pickupLatitude'] as num).toDouble(),
                      (ride['pickupLongitude'] as num).toDouble(),
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                  if (ride != null) Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(
                      (ride['destinationLatitude'] as num).toDouble(),
                      (ride['destinationLongitude'] as num).toDouble(),
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Destination'),
                  ),
                },
              ),

              // Status bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                  color: AppTheme.primaryColor,
                  child: Text(
                    _statusLabel(ride?['status']),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Bottom action panel
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
                      if (ride != null) ...[
                        // Passenger info
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ride['passengerName'] ?? 'Passenger',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(ride['pickupAddress'] ?? '',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Text('\$${(ride['estimatedFare'] as num?)?.toStringAsFixed(2) ?? '-'}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // OTP input for starting ride
                      if (ride?['status'] == 'DRIVER_ARRIVED') ...[
                        const Text('Enter passenger OTP to start ride',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        PinCodeTextField(
                          appContext: context,
                          length: 6,
                          onChanged: (v) => _otpInput = v,
                          pinTheme: PinTheme(
                            shape: PinCodeFieldShape.box,
                            borderRadius: BorderRadius.circular(8),
                            fieldHeight: 48,
                            fieldWidth: 42,
                            activeFillColor: Colors.white,
                            selectedFillColor: Colors.white,
                            inactiveFillColor: Colors.white,
                            activeColor: AppTheme.primaryColor,
                            selectedColor: AppTheme.primaryColor,
                            inactiveColor: Colors.grey.shade300,
                          ),
                          enableActiveFill: true,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ctx.read<TripBloc>().add(
                              TripStarted(widget.rideId, _otpInput)),
                          child: const Text('Start Ride'),
                        ),
                      ] else if (ride?['status'] == 'DRIVER_ASSIGNED') ...[
                        ElevatedButton(
                          onPressed: () => ctx.read<TripBloc>().add(TripArrived(widget.rideId)),
                          child: const Text('I Have Arrived'),
                        ),
                      ] else if (ride?['status'] == 'IN_PROGRESS') ...[
                        ElevatedButton(
                          onPressed: () => ctx.read<TripBloc>().add(TripCompleted(widget.rideId)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.onlineColor),
                          child: const Text('Complete Ride'),
                        ),
                      ],

                      const SizedBox(height: 8),
                      if (ride?['status'] != 'IN_PROGRESS')
                        TextButton(
                          onPressed: () {
                            ctx.read<TripBloc>().add(TripCancelled(widget.rideId));
                          },
                          child: const Text('Cancel Ride', style: TextStyle(color: AppTheme.errorColor)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
