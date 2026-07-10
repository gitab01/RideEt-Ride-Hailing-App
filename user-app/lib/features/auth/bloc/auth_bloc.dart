import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';

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
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckAuth(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
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
      emit(AuthAuthenticated(data));
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Login failed';
      emit(AuthError(message));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _api.dio.post('/auth/register', data: event.data);
      final data = response.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      emit(AuthAuthenticated(data));
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Registration failed';
      emit(AuthError(message));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _api.clearTokens();
    emit(AuthUnauthenticated());
  }
}
