import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';

abstract class TripEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Load whichever ride this driver is currently on, so a relaunched app resumes the trip.
class TripResumed extends TripEvent {}

class TripLoaded extends TripEvent {
  final String rideId;
  TripLoaded(this.rideId);
  @override
  List<Object?> get props => [rideId];
}

class TripArrived extends TripEvent {
  final String rideId;
  TripArrived(this.rideId);
  @override
  List<Object?> get props => [rideId];
}

class TripStarted extends TripEvent {
  final String rideId;
  final String otp;
  TripStarted(this.rideId, this.otp);
  @override
  List<Object?> get props => [rideId, otp];
}

class TripCompleted extends TripEvent {
  final String rideId;
  TripCompleted(this.rideId);
  @override
  List<Object?> get props => [rideId];
}

class TripCancelled extends TripEvent {
  final String rideId;
  final String? reason;
  TripCancelled(this.rideId, {this.reason});
  @override
  List<Object?> get props => [rideId, reason];
}

abstract class TripState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {}

class TripLoading extends TripState {}

/// No ride assigned; the driver belongs on the home screen.
class TripIdle extends TripState {}

class TripActive extends TripState {
  final Map<String, dynamic> ride;
  TripActive(this.ride);
  @override
  List<Object?> get props => [ride];
}

class TripDone extends TripState {
  final Map<String, dynamic> ride;
  TripDone(this.ride);
  @override
  List<Object?> get props => [ride];
}

class TripFailure extends TripState {
  final String message;
  TripFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class TripBloc extends Bloc<TripEvent, TripState> {
  final _api = ApiClient();

  TripBloc() : super(TripInitial()) {
    on<TripResumed>(_onResumed);
    on<TripLoaded>(_onLoaded);
    on<TripArrived>((e, emit) => _post(emit, '/driver/rides/${e.rideId}/arrived'));
    on<TripStarted>((e, emit) =>
        _post(emit, '/driver/rides/${e.rideId}/start', queryParameters: {'otp': e.otp}));
    on<TripCompleted>((e, emit) => _post(emit, '/driver/rides/${e.rideId}/complete', done: true));
    on<TripCancelled>(_onCancelled);
  }

  Future<void> _onResumed(TripResumed e, Emitter<TripState> emit) async {
    emit(TripLoading());
    try {
      final res = await _api.dio.get('/driver/rides/active');
      final rides = (res.data['data'] ?? []) as List;
      if (rides.isEmpty) {
        emit(TripIdle());
        return;
      }
      emit(_classify(rides.first as Map<String, dynamic>));
    } on DioException catch (ex) {
      emit(TripFailure(_errorOf(ex, 'Could not load your trip')));
    }
  }

  Future<void> _onLoaded(TripLoaded e, Emitter<TripState> emit) async {
    if (state is TripInitial) emit(TripLoading());
    try {
      final res = await _api.dio.get('/driver/rides/${e.rideId}');
      final ride = res.data['data'];
      emit(ride == null ? TripIdle() : _classify(ride as Map<String, dynamic>));
    } on DioException catch (ex) {
      emit(TripFailure(_errorOf(ex, 'Could not load your trip')));
    }
  }

  Future<void> _onCancelled(TripCancelled e, Emitter<TripState> emit) async {
    emit(TripLoading());
    try {
      await _api.dio.post('/driver/rides/${e.rideId}/cancel',
          queryParameters: {'reason': e.reason});
      emit(TripIdle());
    } on DioException catch (ex) {
      emit(TripFailure(_errorOf(ex, 'Could not cancel this ride')));
    }
  }

  Future<void> _post(Emitter<TripState> emit, String path,
      {Map<String, dynamic>? queryParameters, bool done = false}) async {
    emit(TripLoading());
    try {
      final res = await _api.dio.post(path, queryParameters: queryParameters);
      final ride = res.data['data'] as Map<String, dynamic>?;
      emit(ride == null ? TripIdle() : (done ? TripDone(ride) : _classify(ride)));
    } on DioException catch (ex) {
      emit(TripFailure(_errorOf(ex, 'That action did not go through')));
    }
  }

  /// The server is the only authority on where a ride is; the same response drives
  /// both the screen and which button is offered next.
  TripState _classify(Map<String, dynamic> ride) {
    switch (ride['status']) {
      case 'COMPLETED':
        return TripDone(ride);
      case 'CANCELLED':
      case 'NO_DRIVER_FOUND':
        return TripIdle();
      default:
        return TripActive(ride);
    }
  }

  static String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError) return 'Cannot reach the RideEt server';
    return fallback;
  }
}
