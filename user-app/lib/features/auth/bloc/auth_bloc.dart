import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final Map<String, dynamic> data;
  AuthRegisterRequested(this.data);
  @override
  List<Object?> get props => [data];
}

class AuthOtpSendRequested extends AuthEvent {
  final String phone;
  AuthOtpSendRequested(this.phone);
  @override
  List<Object?> get props => [phone];
}

class AuthOtpVerifyRequested extends AuthEvent {
  final String phone;
  final String code;
  AuthOtpVerifyRequested(this.phone, this.code);
  @override
  List<Object?> get props => [phone, code];
}

class AuthLogoutRequested extends AuthEvent {}
class AuthCheckRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

/// A login code is on its way. [devCode] is only set on the dev profile, where the
/// backend returns the code it generated because there is no SMS gateway to call.
class AuthOtpSent extends AuthState {
  final String phone;
  final int expiresInSeconds;
  final String? devCode;
  AuthOtpSent(this.phone, this.expiresInSeconds, this.devCode);
  @override
  List<Object?> get props => [phone, expiresInSeconds, devCode];
}

class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckAuth);
    on<AuthLoginRequested>(_onLogin);
    on<AuthOtpSendRequested>(_onSendOtp);
    on<AuthOtpVerifyRequested>(_onVerifyOtp);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckAuth(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      await WebSocketService().connect();
      emit(AuthAuthenticated({'token': token}));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _api.dio.post('/auth/login', data: {
        'email': event.email,
        'password': event.password,
      });
      final data = response.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      await WebSocketService().connect();
      emit(AuthAuthenticated(data));
    } on DioException catch (e) {
      emit(AuthError(_message(e, 'Login failed')));
    }
  }

  Future<void> _onSendOtp(AuthOtpSendRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _api.dio.post('/auth/otp/send', data: {'phone': event.phone});
      final data = response.data['data'] as Map<String, dynamic>;
      emit(AuthOtpSent(
        data['phone'] as String? ?? event.phone,
        (data['expiresInSeconds'] as num?)?.toInt() ?? 300,
        data['devCode'] as String?,
      ));
    } on DioException catch (e) {
      emit(AuthError(_message(e, 'Could not send the code')));
    }
  }

  Future<void> _onVerifyOtp(AuthOtpVerifyRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _api.dio.post('/auth/otp/verify',
          data: {'phone': event.phone, 'code': event.code});
      final data = response.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      await WebSocketService().connect();
      emit(AuthAuthenticated(data));
    } on DioException catch (e) {
      emit(AuthError(_message(e, 'That code is not valid')));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _api.dio.post('/auth/register', data: event.data);
      final data = response.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      await WebSocketService().connect();
      emit(AuthAuthenticated(data));
    } on DioException catch (e) {
      emit(AuthError(_message(e, 'Registration failed')));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    WebSocketService().disconnect();
    await _api.clearTokens();
    emit(AuthUnauthenticated());
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
