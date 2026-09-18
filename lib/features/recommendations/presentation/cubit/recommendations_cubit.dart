import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../../team/data/repositories/team_repository.dart';
import '../../../team/data/models/team_models.dart';
import '../../../team/domain/repositories/team_repository.dart';
import '../../domain/entities/recommendation_data.dart';
import '../../domain/usecases/recommendation_engine.dart';

enum RecommendationsStatus { initial, loading, success, failure }

class RecommendationsState {
  const RecommendationsState({
    this.status = RecommendationsStatus.initial,
    this.data,
    this.error,
  });

  final RecommendationsStatus status;
  final RecommendationData? data;
  final Object? error;

  RecommendationsState copyWith({
    RecommendationsStatus? status,
    RecommendationData? data,
    Object? error,
  }) {
    return RecommendationsState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error,
    );
  }
}

class RecommendationsCubit extends Cubit<RecommendationsState> {
  RecommendationsCubit({
    required this.fixturesRepository,
    required this.teamRepository,
    required this.authCubit,
    RecommendationsState? initialState,
  }) : super(initialState ?? const RecommendationsState());

  final FixturesRepository fixturesRepository;
  final TeamRepository teamRepository;
  final AuthCubit authCubit;

  Future<void> load() async {
    emit(state.copyWith(status: RecommendationsStatus.loading, error: null));
    try {
      final bootstrap = await fixturesRepository.getBootstrap();
      final gameweek = _nextGameweek(bootstrap);
      final session = authCubit.state.session;
      if (session == null || session.entryId == null) {
        throw const TeamAccessException(TeamAccessError.entryIdMissing);
      }
      final fixtures = await fixturesRepository.getFixtures();
      final team = await teamRepository.getMyTeam(
        session: session,
        entryId: session.entryId!,
        gameweekId: gameweek.id,
      );
      final playerSummaries = Map<int, FplPlayerSummary>.fromEntries(
        await Future.wait(
          team.picks.map((pick) async {
            try {
              return MapEntry(
                pick.elementId,
                await fixturesRepository.getPlayerSummary(pick.elementId),
              );
            } on Object {
              return MapEntry(pick.elementId, const FplPlayerSummary());
            }
          }),
        ),
      );
      final result = const RecommendationEngine().build(
        bootstrap: bootstrap,
        fixtures: fixtures,
        team: team,
        gameweekId: gameweek.id,
        playerSummaries: playerSummaries,
      );
      emit(
        RecommendationsState(
          status: RecommendationsStatus.success,
          data: RecommendationData(
            result: result,
            gameweek: gameweek,
            bootstrap: bootstrap,
            team: team,
            fixtures: fixtures,
          ),
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(status: RecommendationsStatus.failure, error: error));
    }
  }

  Gameweek _nextGameweek(FplBootstrap bootstrap) {
    return bootstrap.gameweeks.firstWhere(
      (gameweek) => gameweek.isNext,
      orElse: () => bootstrap.gameweeks.firstWhere(
        (gameweek) => gameweek.id > bootstrap.currentGameweekId,
        orElse: () => bootstrap.gameweeks.last,
      ),
    );
  }

  Future<void> refresh() => load();

  Future<void> makeTransfer(TransferSuggestion transfer) async {
    final session = authCubit.state.session;
    final data = state.data;
    if (session == null || session.entryId == null || data == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    await teamRepository.makeTransfer(
      session: session,
      entryId: session.entryId!,
      gameweekId: data.gameweek.id,
      elementIn: transfer.inPlayer.id,
      elementOut: transfer.outPlayer.id,
      purchasePrice: transfer.inPlayer.nowCost ?? 0,
      sellingPrice: _sellingPrice(data.team, transfer.outPlayer.id),
    );
    await load();
  }

  Future<void> saveChip(SuggestedChip chip) async {
    final session = authCubit.state.session;
    final data = state.data;
    if (session == null || session.entryId == null || data == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    await teamRepository.saveMyTeam(
      session: session,
      entryId: session.entryId!,
      chip: _chipName(chip),
      picks: data.team.picks,
    );
    await load();
  }

  int _sellingPrice(MyTeam team, int elementId) {
    return team.picks
            .firstWhere(
              (pick) => pick.elementId == elementId,
              orElse: () => const TeamPick(
                elementId: 0,
                position: 0,
                multiplier: 0,
                isCaptain: false,
                isViceCaptain: false,
                elementType: 0,
              ),
            )
            .sellingPrice ??
        0;
  }

  String? _chipName(SuggestedChip chip) {
    return switch (chip) {
      SuggestedChip.none => null,
      SuggestedChip.wildcard => 'wildcard',
      SuggestedChip.freeHit => 'freehit',
      SuggestedChip.benchBoost => 'bboost',
      SuggestedChip.tripleCaptain => '3xc',
    };
  }
}
