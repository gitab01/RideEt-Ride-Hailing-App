import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';

abstract class DriverAuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class DriverLoginRequested extends DriverAuthEvent {
  final String phone, password;
  DriverLoginRequested(this.phone, this.password);
  @override
  List<Object?> get props => [phone, password];
}

class DriverRegisterRequested extends DriverAuthEvent {
  final Map<String, dynamic> data;
  DriverRegisterRequested(this.data);
  @override
  List<Object?> get props => [data];
}

class DriverLogoutRequested extends DriverAuthEvent {}

class DriverAuthCheckRequested extends DriverAuthEvent {}

abstract class DriverAuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DriverAuthInitial extends DriverAuthState {}

class DriverAuthLoading extends DriverAuthState {}

class DriverAuthenticated extends DriverAuthState {
  final Map<String, dynamic> user;
  DriverAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class DriverUnauthenticated extends DriverAuthState {}

class DriverAuthError extends DriverAuthState {
  final String message;
  DriverAuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class DriverAuthBloc extends Bloc<DriverAuthEvent, DriverAuthState> {
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  DriverAuthBloc() : super(DriverAuthInitial()) {
    on<DriverAuthCheckRequested>(_onCheck);
    on<DriverLoginRequested>(_onLogin);
    on<DriverRegisterRequested>(_onRegister);
    on<DriverLogoutRequested>(_onLogout);
  }

  /// A stored token is only worth restoring if the server still accepts it.
  Future<void> _onCheck(DriverAuthCheckRequested e, Emitter<DriverAuthState> emit) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      emit(DriverUnauthenticated());
      return;
    }
    emit(DriverAuthLoading());
    try {
      final res = await _api.dio.get('/auth/me');
      await _wsReady();
      emit(DriverAuthenticated(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (ex) {
      if (ex.response?.statusCode == 401 || ex.response?.statusCode == 403) {
        await _api.clearTokens();
        emit(DriverUnauthenticated());
      } else {
        // Offline phone: the stored session is still the best answer we have.
        await _wsReady();
        emit(DriverAuthenticated({'token': token}));
      }
    }
  }

  Future<void> _onLogin(DriverLoginRequested e, Emitter<DriverAuthState> emit) async {
    emit(DriverAuthLoading());
    try {
      final res = await _api.dio.post('/auth/login', data: {'phone': e.phone, 'password': e.password});
      final data = res.data['data'] as Map<String, dynamic>;
      await _api.saveTokens(data['accessToken'] as String, data['refreshToken'] as String?);
      await _wsReady();
      emit(DriverAuthenticated(data));
    } on DioException catch (ex) {
      emit(DriverAuthError(_errorOf(ex, 'Login failed')));
    }
  }

  Future<void> _onRegister(DriverRegisterRequested e, Emitter<DriverAuthState> emit) async {
    emit(DriverAuthLoading());
    try {
      final res = await _api.dio.post('/auth/register', data: {...e.data, 'role': 'DRIVER'});
      final data = res.data['data'] as Map<String, dynamic>;
      await _api.saveTokens(data['accessToken'] as String, data['refreshToken'] as String?);
      await _wsReady();
      emit(DriverAuthenticated(data));
    } on DioException catch (ex) {
      emit(DriverAuthError(_errorOf(ex, 'Registration failed')));
    }
  }

  Future<void> _onLogout(DriverLogoutRequested e, Emitter<DriverAuthState> emit) async {
    WebSocketService().disconnect();
    await _api.clearTokens();
    emit(DriverUnauthenticated());
  }

  /// Offers only reach the driver over STOMP, so the socket opens with the session.
  Future<void> _wsReady() async {
    WebSocketService().disconnect();
    await WebSocketService().connect();
  }

  static String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError) return 'Cannot reach the RideEt server';
    return fallback;
  }
}
