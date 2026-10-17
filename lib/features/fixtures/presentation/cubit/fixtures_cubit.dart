import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fpl_engine/fpl_engine.dart';
import '../../domain/repositories/fixtures_repository.dart';

enum FixturesStatus { initial, loading, success, failure }

class FixturesState {
  const FixturesState({
    this.status = FixturesStatus.initial,
    this.bootstrap,
    this.fixtures = const [],
    this.predictions,
    this.error,
  });

  final FixturesStatus status;
  final FplBootstrap? bootstrap;
  final List<FplFixture> fixtures;

  /// Match predictions by fixture id; null until resolved.
  final Map<int, FixturePrediction>? predictions;
  final Object? error;

  FixturesState copyWith({
    FixturesStatus? status,
    FplBootstrap? bootstrap,
    List<FplFixture>? fixtures,
    Map<int, FixturePrediction>? predictions,
    Object? error,
  }) {
    return FixturesState(
      status: status ?? this.status,
      bootstrap: bootstrap ?? this.bootstrap,
      fixtures: fixtures ?? this.fixtures,
      predictions: predictions ?? this.predictions,
      error: error,
    );
  }
}

class FixturesCubit extends Cubit<FixturesState> {
  FixturesCubit(this._repository, {FixturesState? initialState})
    : super(initialState ?? const FixturesState());

  final FixturesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: FixturesStatus.loading, error: null));
    try {
      final bootstrap = await _repository.getBootstrap();
      final fixtures = await _repository.getFixtures();
      emit(
        state.copyWith(
          status: FixturesStatus.success,
          bootstrap: bootstrap,
          fixtures: fixtures,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(status: FixturesStatus.failure, error: error));
      return;
    }
    await loadPredictions();
  }

  /// Uses the server's published predictions when they match the loaded
  /// data, otherwise computes them on device. The fixture list shows first.
  Future<void> loadPredictions() async {
    final bootstrap = state.bootstrap;
    final fixtures = state.fixtures;
    if (bootstrap == null) return;
    final published = await _repository.getPublishedFixturePredictions(
      bootstrap.players,
    );
    // A refresh replaced the data meanwhile; it resolves its own.
    if (isClosed || !identical(state.fixtures, fixtures)) return;
    final predictions =
        published?.usableFor(bootstrap: bootstrap, fixtures: fixtures) ??
        const FixturePredictionEngine().predictNextGameweeks(
          fixtures: fixtures,
          teams: bootstrap.teams,
          players: bootstrap.players,
          fromGameweekId: bootstrap.currentGameweekId,
        );
    emit(state.copyWith(predictions: predictions));
  }

  Future<void> refresh() => load();
}
