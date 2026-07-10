import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  @override List<Object?> get props => [];
}
class HomeLoadRequested extends HomeEvent {}

abstract class HomeState extends Equatable {
  @override List<Object?> get props => [];
}
class HomeInitial extends HomeState {}
class HomeLoaded extends HomeState {}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<HomeLoadRequested>((event, emit) => emit(HomeLoaded()));
  }
}
