import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/models/team_models.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/usecases/get_team_for_gameweek.dart';

enum TeamStatus { initial, loading, success, failure }

class TeamState {
  const TeamState({
    this.status = TeamStatus.initial,
    this.bootstrap,
    this.team,
    this.entry,
    this.gameweekPoints = const {},
    this.historyPoints = const {},
    this.selectedGameweekId,
    this.error,
  });

  final TeamStatus status;
  final FplBootstrap? bootstrap;
  final MyTeam? team;
  final FplEntry? entry;
  final Map<int, int> gameweekPoints;
  final Map<int, int> historyPoints;
  final int? selectedGameweekId;
  final Object? error;

  TeamState copyWith({
    TeamStatus? status,
    FplBootstrap? bootstrap,
    MyTeam? team,
    FplEntry? entry,
    Map<int, int>? gameweekPoints,
    Map<int, int>? historyPoints,
    int? selectedGameweekId,
    Object? error,
  }) {
    return TeamState(
      status: status ?? this.status,
      bootstrap: bootstrap ?? this.bootstrap,
      team: team ?? this.team,
      entry: entry ?? this.entry,
      gameweekPoints: gameweekPoints ?? this.gameweekPoints,
      historyPoints: historyPoints ?? this.historyPoints,
      selectedGameweekId: selectedGameweekId ?? this.selectedGameweekId,
      error: error,
    );
  }
}

class TeamCubit extends Cubit<TeamState> {
  TeamCubit({
    required this.fixturesRepository,
    required this.teamRepository,
    this.authCubit,
    this.entryId,
    TeamState? initialState,
  }) : _getTeamForGameweek = GetTeamForGameweek(teamRepository),
       super(initialState ?? const TeamState());

  final FixturesRepository fixturesRepository;
  final GetTeamForGameweek _getTeamForGameweek;
  final TeamRepository teamRepository;
  final AuthCubit? authCubit;
  final int? entryId;

  Future<void> load({int? gameweekId}) async {
    emit(state.copyWith(status: TeamStatus.loading, error: null));
    try {
      final bootstrap = await fixturesRepository.getBootstrap();
      final targetGameweekId =
          gameweekId ?? state.selectedGameweekId ?? bootstrap.currentGameweekId;
      final team = await _loadTeam(bootstrap, targetGameweekId);
      final points = await fixturesRepository.getGameweekPoints(
        targetGameweekId,
      );

      final session = authCubit?.state.session;
      var historyPoints = const <int, int>{};
      if (entryId == null && session?.entryId != null) {
        try {
          historyPoints = await fixturesRepository.getEntryHistoryPoints(
            session!.entryId!,
          );
        } on Object {
          // History is supplementary; the team and live points remain useful.
        }
      }

      FplEntry? entry = state.entry;
      final effectiveEntryId = entryId ?? session?.entryId;
      if (effectiveEntryId != null) {
        try {
          entry = await teamRepository.getEntry(effectiveEntryId);
        } on Object {
          // Entry metadata is supplementary
        }
      }

      emit(
        TeamState(
          status: TeamStatus.success,
          bootstrap: bootstrap,
          team: team,
          entry: entry,
          gameweekPoints: points,
          historyPoints: historyPoints,
          selectedGameweekId: targetGameweekId,
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(status: TeamStatus.failure, error: error));
    }
  }

  Future<MyTeam> _loadTeam(FplBootstrap bootstrap, int gameweekId) {
    if (entryId != null) {
      return teamRepository.getPublicTeam(
        entryId: entryId!,
        gameweekId: gameweekId,
      );
    }

    final session = authCubit?.state.session;
    if (session == null || session.entryId == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    return _getTeamForGameweek(
      session: session,
      entryId: session.entryId!,
      gameweekId: gameweekId,
      currentGameweekId: bootstrap.currentGameweekId,
    );
  }

  void selectGameweek(int gameweekId) {
    if (gameweekId != state.selectedGameweekId) {
      load(gameweekId: gameweekId);
    }
  }

  Future<void> refresh() => load(gameweekId: state.selectedGameweekId);
}
