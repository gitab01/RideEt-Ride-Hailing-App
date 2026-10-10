import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';

// Events
abstract class BookingEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class EstimateFareRequested extends BookingEvent {
  final double pickupLat, pickupLng, destLat, destLng;
  EstimateFareRequested(this.pickupLat, this.pickupLng, this.destLat, this.destLng);
  @override
  List<Object?> get props => [pickupLat, pickupLng, destLat, destLng];
}

class RideRequested extends BookingEvent {
  final Map<String, dynamic> rideData;
  RideRequested(this.rideData);
  @override
  List<Object?> get props => [rideData];
}

class RideCancelled extends BookingEvent {
  final String rideId;
  final String? reason;
  RideCancelled(this.rideId, {this.reason});
  @override
  List<Object?> get props => [rideId, reason];
}

class RideStatusRefreshed extends BookingEvent {
  final String rideId;
  RideStatusRefreshed(this.rideId);
  @override
  List<Object?> get props => [rideId];
}

class ActiveRideLoaded extends BookingEvent {}

/// A push off the app-wide STOMP session.
class RidePushed extends BookingEvent {
  final RideUpdate update;
  RidePushed(this.update);
  @override
  List<Object?> get props => [update.eventType, update.rideId];
}

// States
abstract class BookingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class FareEstimated extends BookingState {
  final Map<String, dynamic> estimate;
  FareEstimated(this.estimate);
  @override
  List<Object?> get props => [estimate];
}

/// Waiting for a driver. The backend re-broadcasts this each widening round.
class RideSearching extends BookingState {
  final int? rideId;
  final int driversContacted;
  final double radiusKm;
  RideSearching({this.rideId, this.driversContacted = 0, this.radiusKm = 0});
  @override
  List<Object?> get props => [rideId, driversContacted, radiusKm];
}

class RideActive extends BookingState {
  final Map<String, dynamic> ride;
  RideActive(this.ride);
  int? get rideId => (ride['id'] as num?)?.toInt();
  String? get status => ride['status'] as String?;
  @override
  List<Object?> get props => [ride];
}

class RideCompleted extends BookingState {
  final Map<String, dynamic> ride;
  RideCompleted(this.ride);
  @override
  List<Object?> get props => [ride];
}

class BookingError extends BookingState {
  final String message;
  BookingError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final _api = ApiClient();
  StreamSubscription<RideUpdate>? _pushes;

  BookingBloc() : super(BookingInitial()) {
    on<EstimateFareRequested>(_onEstimate);
    on<RideRequested>(_onRequest);
    on<RideStatusRefreshed>(_onRefresh);
    on<RideCancelled>(_onCancel);
    on<ActiveRideLoaded>(_onActiveRide);
    on<RidePushed>(_onPushed);

    // Live status changes arrive on the user queue; the REST refresh is only a fallback
    // for pushes missed while the socket was down.
    _pushes = WebSocketService().updates.listen((update) {
      if (update.eventType != 'LOCATION') add(RidePushed(update));
    });
  }

  /// Ride the client currently believes is live, used to drop pushes for old rides.
  int? get _trackedRideId {
    final state = this.state;
    if (state is RideActive) return state.rideId;
    if (state is RideSearching) return state.rideId;
    return null;
  }

  @override
  Future<void> close() async {
    await _pushes?.cancel();
    return super.close();
  }

  Future<void> _onEstimate(EstimateFareRequested event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final response = await _api.dio.get('/rides/estimate', queryParameters: {
        'pickupLat': event.pickupLat,
        'pickupLng': event.pickupLng,
        'destLat': event.destLat,
        'destLng': event.destLng,
      });
      emit(FareEstimated(response.data['data']));
    } on DioException catch (e) {
      emit(BookingError(_message(e, 'Failed to estimate fare')));
    }
  }

  Future<void> _onRequest(RideRequested event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final response = await _api.dio.post('/rides/request', data: event.rideData);
      final ride = response.data['data'];
      emit(ride['status'] == 'SEARCHING'
          ? RideSearching(rideId: (ride['id'] as num?)?.toInt())
          : RideActive(ride));
    } on DioException catch (e) {
      emit(BookingError(_message(e, 'Failed to request ride')));
    }
  }

  Future<void> _onActiveRide(ActiveRideLoaded event, Emitter<BookingState> emit) async {
    try {
      final response = await _api.dio.get('/rides/active');
      final rides = response.data['data'];
      if (rides is! List || rides.isEmpty) {
        emit(BookingInitial());
        return;
      }
      _applyRide(Map<String, dynamic>.from(rides.first as Map), emit);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) emit(BookingError(_message(e, 'No active ride')));
    }
  }

  Future<void> _onRefresh(RideStatusRefreshed event, Emitter<BookingState> emit) async {
    try {
      final response = await _api.dio.get('/rides/${event.rideId}');
      _applyRide(response.data['data'], emit);
    } on DioException catch (e) {
      emit(BookingError(_message(e, 'Failed to refresh')));
    }
  }

  Future<void> _onCancel(RideCancelled event, Emitter<BookingState> emit) async {
    try {
      await _api.dio.post('/rides/${event.rideId}/cancel',
          queryParameters: {if (event.reason != null) 'reason': event.reason});
      emit(BookingInitial());
    } on DioException catch (e) {
      emit(BookingError(_message(e, 'Failed to cancel')));
    }
  }

  Future<void> _onPushed(RidePushed event, Emitter<BookingState> emit) async {
    final update = event.update;
    final tracked = _trackedRideId;
    if (tracked != null && update.rideId != null && update.rideId != tracked) return;

    switch (update.eventType) {
      case 'SEARCHING_DRIVERS':
        emit(RideSearching(
          rideId: update.rideId ?? tracked,
          driversContacted: (update.data['driversContacted'] as num?)?.toInt() ?? 0,
          radiusKm: (update.data['radiusKm'] as num?)?.toDouble() ?? 0,
        ));
        break;
      case 'NO_DRIVER_FOUND':
        emit(BookingError(update.data['reason']?.toString() ??
            'No drivers accepted nearby. Please try again.'));
        break;
      case 'DRIVER_CANCELLED':
      case 'RIDE_CANCELLED':
        emit(BookingError(update.data['reason']?.toString() ?? 'The ride was cancelled'));
        break;
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ARRIVED':
      case 'RIDE_STARTED':
      case 'RIDE_COMPLETED':
        _applyRide(update.data, emit);
        break;
    }
  }

  void _applyRide(Map<String, dynamic> ride, Emitter<BookingState> emit) {
    switch (ride['status']) {
      case 'SEARCHING':
      case 'REQUESTED':
        emit(RideSearching(rideId: (ride['id'] as num?)?.toInt()));
        break;
      case 'COMPLETED':
        emit(RideCompleted(ride));
        break;
      case 'CANCELLED':
      case 'NO_DRIVER_FOUND':
        emit(BookingInitial());
        break;
      default:
        emit(RideActive(ride));
    }
  }

  static String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String && data.isNotEmpty) return data.substring(0, data.length.clamp(0, 120));
    return e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError
        ? 'Cannot reach the RideEt server'
        : fallback;
  }
}
