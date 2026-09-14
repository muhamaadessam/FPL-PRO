import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/fpl_models.dart';
import '../../domain/repositories/fixtures_repository.dart';

enum FixturesStatus { initial, loading, success, failure }

class FixturesState {
  const FixturesState({
    this.status = FixturesStatus.initial,
    this.bootstrap,
    this.fixtures = const [],
    this.error,
  });

  final FixturesStatus status;
  final FplBootstrap? bootstrap;
  final List<FplFixture> fixtures;
  final Object? error;

  FixturesState copyWith({
    FixturesStatus? status,
    FplBootstrap? bootstrap,
    List<FplFixture>? fixtures,
    Object? error,
  }) {
    return FixturesState(
      status: status ?? this.status,
      bootstrap: bootstrap ?? this.bootstrap,
      fixtures: fixtures ?? this.fixtures,
      error: error,
    );
  }
}

class FixturesCubit extends Cubit<FixturesState> {
  FixturesCubit(this._repository) : super(const FixturesState());

  final FixturesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: FixturesStatus.loading, error: null));
    try {
      final bootstrap = await _repository.getBootstrap();
      final fixtures = await _repository.getFixtures(
        gameweekId: bootstrap.currentGameweekId,
      );
      emit(
        state.copyWith(
          status: FixturesStatus.success,
          bootstrap: bootstrap,
          fixtures: fixtures,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(status: FixturesStatus.failure, error: error));
    }
  }

  Future<void> refresh() => load();
}
