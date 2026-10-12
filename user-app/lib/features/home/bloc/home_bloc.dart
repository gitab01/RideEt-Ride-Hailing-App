import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';

/// A destination the rider has already been taken to, offered as a one-tap chip.
class RecentPlace extends Equatable {
  final String address;
  final double lat;
  final double lng;
  const RecentPlace(this.address, this.lat, this.lng);

  @override
  List<Object?> get props => [address, lat, lng];
}

abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeLoadRequested extends HomeEvent {}

abstract class HomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoaded extends HomeState {
  final List<RecentPlace> recentPlaces;
  HomeLoaded(this.recentPlaces);

  @override
  List<Object?> get props => [recentPlaces];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final _api = ApiClient();

  HomeBloc() : super(HomeInitial()) {
    on<HomeLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(HomeLoadRequested event, Emitter<HomeState> emit) async {
    List<RecentPlace> places = const [];
    try {
      places = _destinations(await _api.dio
          .get('/rides/history', queryParameters: {'size': 20}));
    } on DioException catch (_) {
      // A rider who has no history yet, or a cold backend, still gets the map.
    }
    emit(HomeLoaded(places));
  }

  /// Newest first, and only places the app can actually send a rider back to.
  static List<RecentPlace> _destinations(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final rows = (data is Map ? data['content'] : data);
    if (rows is! List) return const [];

    final seen = <String>{};
    final places = <RecentPlace>[];
    for (final row in rows) {
      if (row is! Map) continue;
      if (row['status'] != 'COMPLETED') continue;
      final address = row['destinationAddress']?.toString();
      final lat = (row['destinationLatitude'] as num?)?.toDouble();
      final lng = (row['destinationLongitude'] as num?)?.toDouble();
      if (address == null || address.isEmpty || lat == null || lng == null) continue;
      if (!seen.add(address)) continue;
      places.add(RecentPlace(address, lat, lng));
      if (places.length == 3) break;
    }
    return places;
  }
}
