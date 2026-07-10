import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

abstract class TripEvent extends Equatable {
  @override List<Object?> get props => [];
}
class TripAccepted  extends TripEvent { final String rideId; TripAccepted(this.rideId); }
class TripArrived   extends TripEvent { final String rideId; TripArrived(this.rideId); }
class TripStarted   extends TripEvent { final String rideId; final String otp; TripStarted(this.rideId, this.otp); }
class TripCompleted extends TripEvent { final String rideId; TripCompleted(this.rideId); }
class TripCancelled extends TripEvent { final String rideId; final String? reason; TripCancelled(this.rideId, {this.reason}); }
class TripRefreshed extends TripEvent { final String rideId; TripRefreshed(this.rideId); }

abstract class TripState extends Equatable {
  @override List<Object?> get props => [];
}
class TripInitial   extends TripState {}
class TripLoading   extends TripState {}
class TripActive    extends TripState { final Map<String, dynamic> ride; TripActive(this.ride); @override List<Object?> get props => [ride]; }
class TripDone      extends TripState { final Map<String, dynamic> ride; TripDone(this.ride); @override List<Object?> get props => [ride]; }
class TripError     extends TripState { final String message; TripError(this.message); @override List<Object?> get props => [message]; }

class TripBloc extends Bloc<TripEvent, TripState> {
  final _api = ApiClient();

  TripBloc() : super(TripInitial()) {
    on<TripAccepted>(_onAccept);
    on<TripArrived>(_onArrive);
    on<TripStarted>(_onStart);
    on<TripCompleted>(_onComplete);
    on<TripCancelled>(_onCancel);
    on<TripRefreshed>(_onRefresh);
  }

  Future<void> _onAccept(TripAccepted e, Emitter<TripState> emit) async {
    emit(TripLoading());
    try {
      final res = await _api.dio.post('/driver/rides/${e.rideId}/accept');
      emit(TripActive(res.data['data']));
    } on DioException catch (ex) {
      emit(TripError(ex.response?.data['message'] ?? 'Failed to accept'));
    }
  }

  Future<void> _onArrive(TripArrived e, Emitter<TripState> emit) async {
    try {
      final res = await _api.dio.post('/driver/rides/${e.rideId}/arrived');
      emit(TripActive(res.data['data']));
    } on DioException catch (ex) {
      emit(TripError(ex.response?.data['message'] ?? 'Failed'));
    }
  }

  Future<void> _onStart(TripStarted e, Emitter<TripState> emit) async {
    try {
      final res = await _api.dio.post('/driver/rides/${e.rideId}/start',
          queryParameters: {'otp': e.otp});
      emit(TripActive(res.data['data']));
    } on DioException catch (ex) {
      emit(TripError(ex.response?.data['message'] ?? 'Invalid OTP'));
    }
  }

  Future<void> _onComplete(TripCompleted e, Emitter<TripState> emit) async {
    try {
      final res = await _api.dio.post('/driver/rides/${e.rideId}/complete');
      emit(TripDone(res.data['data']));
    } on DioException catch (ex) {
      emit(TripError(ex.response?.data['message'] ?? 'Failed'));
    }
  }

  Future<void> _onCancel(TripCancelled e, Emitter<TripState> emit) async {
    try {
      await _api.dio.post('/driver/rides/${e.rideId}/cancel',
          queryParameters: {'reason': e.reason});
      emit(TripInitial());
    } on DioException catch (ex) {
      emit(TripError(ex.response?.data['message'] ?? 'Failed'));
    }
  }

  Future<void> _onRefresh(TripRefreshed e, Emitter<TripState> emit) async {
    try {
      final res = await _api.dio.get('/rides/${e.rideId}');
      emit(TripActive(res.data['data']));
    } catch (_) {}
  }
}
