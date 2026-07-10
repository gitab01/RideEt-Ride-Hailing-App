import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';

abstract class DriverAuthEvent extends Equatable {
  @override List<Object?> get props => [];
}
class DriverLoginRequested extends DriverAuthEvent {
  final String email, password;
  DriverLoginRequested(this.email, this.password);
}
class DriverRegisterRequested extends DriverAuthEvent {
  final Map<String, dynamic> data;
  DriverRegisterRequested(this.data);
}
class DriverLogoutRequested extends DriverAuthEvent {}
class DriverAuthCheckRequested extends DriverAuthEvent {}

abstract class DriverAuthState extends Equatable {
  @override List<Object?> get props => [];
}
class DriverAuthInitial   extends DriverAuthState {}
class DriverAuthLoading   extends DriverAuthState {}
class DriverAuthenticated extends DriverAuthState {
  final Map<String, dynamic> user;
  DriverAuthenticated(this.user);
  @override List<Object?> get props => [user];
}
class DriverUnauthenticated extends DriverAuthState {}
class DriverAuthError extends DriverAuthState {
  final String message;
  DriverAuthError(this.message);
  @override List<Object?> get props => [message];
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

  Future<void> _onCheck(DriverAuthCheckRequested e, Emitter<DriverAuthState> emit) async {
    final token = await _storage.read(key: 'access_token');
    token != null ? emit(DriverAuthenticated({'token': token})) : emit(DriverUnauthenticated());
  }

  Future<void> _onLogin(DriverLoginRequested e, Emitter<DriverAuthState> emit) async {
    emit(DriverAuthLoading());
    try {
      final res = await _api.dio.post('/auth/login', data: {'email': e.email, 'password': e.password});
      final data = res.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      emit(DriverAuthenticated(data));
    } on DioException catch (ex) {
      emit(DriverAuthError(ex.response?.data['message'] ?? 'Login failed'));
    }
  }

  Future<void> _onRegister(DriverRegisterRequested e, Emitter<DriverAuthState> emit) async {
    emit(DriverAuthLoading());
    try {
      final res = await _api.dio.post('/auth/register', data: {...e.data, 'role': 'DRIVER'});
      final data = res.data['data'];
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      emit(DriverAuthenticated(data));
    } on DioException catch (ex) {
      emit(DriverAuthError(ex.response?.data['message'] ?? 'Registration failed'));
    }
  }

  Future<void> _onLogout(DriverLogoutRequested e, Emitter<DriverAuthState> emit) async {
    await _api.clearTokens();
    emit(DriverUnauthenticated());
  }
}
