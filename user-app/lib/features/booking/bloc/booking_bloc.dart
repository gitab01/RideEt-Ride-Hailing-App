import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

// Events
abstract class BookingEvent extends Equatable {
  @override List<Object?> get props => [];
}

class EstimateFareRequested extends BookingEvent {
  final double pickupLat, pickupLng, destLat, destLng;
  EstimateFareRequested(this.pickupLat, this.pickupLng, this.destLat, this.destLng);
  @override List<Object?> get props => [pickupLat, pickupLng, destLat, destLng];
}

class RideRequested extends BookingEvent {
  final Map<String, dynamic> rideData;
  RideRequested(this.rideData);
  @override List<Object?> get props => [rideData];
}

class RideCancelled extends BookingEvent {
  final String rideId;
  final String? reason;
  RideCancelled(this.rideId, {this.reason});
}

class RideStatusRefreshed extends BookingEvent {
  final String rideId;
  RideStatusRefreshed(this.rideId);
}

// States
abstract class BookingState extends Equatable {
  @override List<Object?> get props => [];
}

class BookingInitial extends BookingState {}
class BookingLoading extends BookingState {}

class FareEstimated extends BookingState {
  final Map<String, dynamic> estimate;
  FareEstimated(this.estimate);
  @override List<Object?> get props => [estimate];
}

class RideActive extends BookingState {
  final Map<String, dynamic> ride;
  RideActive(this.ride);
  @override List<Object?> get props => [ride];
}

class RideCompleted extends BookingState {
  final Map<String, dynamic> ride;
  RideCompleted(this.ride);
  @override List<Object?> get props => [ride];
}

class BookingError extends BookingState {
  final String message;
  BookingError(this.message);
  @override List<Object?> get props => [message];
}

// Bloc
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final _api = ApiClient();

  BookingBloc() : super(BookingInitial()) {
    on<EstimateFareRequested>(_onEstimate);
    on<RideRequested>(_onRequest);
    on<RideStatusRefreshed>(_onRefresh);
    on<RideCancelled>(_onCancel);
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
      emit(BookingError(e.response?.data['message'] ?? 'Failed to estimate fare'));
    }
  }

  Future<void> _onRequest(RideRequested event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final response = await _api.dio.post('/rides/request', data: event.rideData);
      emit(RideActive(response.data['data']));
    } on DioException catch (e) {
      emit(BookingError(e.response?.data['message'] ?? 'Failed to request ride'));
    }
  }

  Future<void> _onRefresh(RideStatusRefreshed event, Emitter<BookingState> emit) async {
    try {
      final response = await _api.dio.get('/rides/${event.rideId}');
      final ride = response.data['data'];
      if (ride['status'] == 'COMPLETED') {
        emit(RideCompleted(ride));
      } else {
        emit(RideActive(ride));
      }
    } on DioException catch (e) {
      emit(BookingError(e.response?.data['message'] ?? 'Failed to refresh'));
    }
  }

  Future<void> _onCancel(RideCancelled event, Emitter<BookingState> emit) async {
    try {
      await _api.dio.post('/rides/${event.rideId}/cancel',
          queryParameters: {'reason': event.reason});
      emit(BookingInitial());
    } on DioException catch (e) {
      emit(BookingError(e.response?.data['message'] ?? 'Failed to cancel'));
    }
  }
}
