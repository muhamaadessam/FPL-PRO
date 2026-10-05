import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/official_session.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../data/models/team_models.dart';
import '../../data/repositories/team_repository.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/usecases/squad_editor.dart';

enum ManageTeamStatus { initial, loading, ready, failure }

/// What the last successful write did, so the page can confirm it.
enum ManageTeamAction { lineupSaved, transfersConfirmed }

class ManageTeamState {
  const ManageTeamState({
    this.status = ManageTeamStatus.initial,
    this.bootstrap,
    this.gameweek,
    this.team,
    this.lineup = const [],
    this.lineupChip,
    this.plan,
    this.isSaving = false,
    this.error,
    this.lastAction,
  });

  final ManageTeamStatus status;
  final FplBootstrap? bootstrap;

  /// The gameweek whose deadline the edits apply to.
  final Gameweek? gameweek;

  /// The squad as confirmed on the official site.
  final MyTeam? team;

  /// Draft starting XI, bench order and armbands for [team].
  final List<TeamPick> lineup;

  /// Draft Bench Boost or Triple Captain selection, sent with the lineup.
  final String? lineupChip;
  final TransferPlan? plan;
  final bool isSaving;
  final Object? error;
  final ManageTeamAction? lastAction;

  /// The lineup chip already played on the official site for [gameweek].
  String? get savedLineupChip {
    final chip = team?.activeChip;
    return FplChipName.lineupChips.contains(chip) ? chip : null;
  }

  bool get hasLineupChanges =>
      team != null &&
      (!SquadEditor.sameLineup(lineup, team!.picks) ||
          lineupChip != savedLineupChip);

  bool isChipAvailable(String name) {
    final event = gameweek?.id;
    if (event == null) return false;
    return team?.chips.any((c) => c.name == name && c.isAvailableFor(event)) ??
        false;
  }

  ManageTeamState copyWith({
    ManageTeamStatus? status,
    FplBootstrap? bootstrap,
    Gameweek? gameweek,
    MyTeam? team,
    List<TeamPick>? lineup,
    String? lineupChip,
    bool clearLineupChip = false,
    TransferPlan? plan,
    bool? isSaving,
    Object? error,
    ManageTeamAction? lastAction,
  }) {
    return ManageTeamState(
      status: status ?? this.status,
      bootstrap: bootstrap ?? this.bootstrap,
      gameweek: gameweek ?? this.gameweek,
      team: team ?? this.team,
      lineup: lineup ?? this.lineup,
      lineupChip: clearLineupChip ? null : lineupChip ?? this.lineupChip,
      plan: plan ?? this.plan,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      lastAction: lastAction,
    );
  }
}

/// Drafts lineup, armband, chip and transfer changes for the next deadline
/// and sends them to the official write endpoints.
class ManageTeamCubit extends Cubit<ManageTeamState> {
  ManageTeamCubit({
    required this.fixturesRepository,
    required this.teamRepository,
    required this.authCubit,
  }) : super(const ManageTeamState());

  final FixturesRepository fixturesRepository;
  final TeamRepository teamRepository;
  final AuthCubit authCubit;

  Future<void> load() async {
    emit(state.copyWith(status: ManageTeamStatus.loading));
    try {
      final session = _session();
      final bootstrap = await fixturesRepository.getBootstrap();
      final gameweek = _deadlineGameweek(bootstrap);
      final raw = await teamRepository.getMyTeam(
        session: session,
        entryId: session.entryId!,
        gameweekId: gameweek.id,
      );
      final team = _withElementTypes(raw, bootstrap);
      if (isClosed) return;
      final chip = FplChipName.lineupChips.contains(team.activeChip)
          ? team.activeChip
          : null;
      emit(
        ManageTeamState(
          status: ManageTeamStatus.ready,
          bootstrap: bootstrap,
          gameweek: gameweek,
          team: team,
          lineup: SquadEditor.normalize(team.picks, chip: chip),
          lineupChip: chip,
          plan: TransferPlan.fromTeam(team, bootstrap),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(status: ManageTeamStatus.failure, error: error));
    }
  }

  /// Swaps two players. Returns the rule that blocked it, or null on success.
  SquadEditError? swap(int firstElementId, int secondElementId) {
    return _editLineup(
      (picks) => SquadEditor.swap(
        picks,
        firstElementId,
        secondElementId,
        chip: state.lineupChip,
      ),
    );
  }

  SquadEditError? setCaptain(int elementId) => _editLineup(
    (picks) => SquadEditor.setCaptain(picks, elementId, chip: state.lineupChip),
  );

  SquadEditError? setViceCaptain(int elementId) => _editLineup(
    (picks) =>
        SquadEditor.setViceCaptain(picks, elementId, chip: state.lineupChip),
  );

  /// Selects or clears Bench Boost / Triple Captain for the next save. Only
  /// one chip can be played per gameweek.
  void toggleLineupChip(String chip) {
    final next = state.lineupChip == chip ? null : chip;
    emit(
      state.copyWith(
        lineup: SquadEditor.normalize(state.lineup, chip: next),
        lineupChip: next,
        clearLineupChip: next == null,
      ),
    );
  }

  void resetLineup() {
    final team = state.team;
    if (team == null) return;
    final chip = state.savedLineupChip;
    emit(
      state.copyWith(
        lineup: SquadEditor.normalize(team.picks, chip: chip),
        lineupChip: chip,
        clearLineupChip: chip == null,
      ),
    );
  }

  SquadEditError? queueTransfer(int outElementId, FplPlayer incoming) {
    final plan = state.plan;
    if (plan == null) return SquadEditError.notInSquad;
    try {
      emit(state.copyWith(plan: plan.replace(outElementId, incoming)));
      return null;
    } on SquadEditException catch (error) {
      return error.error;
    }
  }

  void undoTransfer(int originalElementId) {
    final plan = state.plan;
    if (plan == null) return;
    emit(state.copyWith(plan: plan.undo(originalElementId)));
  }

  /// Selects or clears Wildcard / Free Hit for the queued transfers.
  void toggleTransferChip(String chip) {
    final plan = state.plan;
    if (plan == null) return;
    emit(
      state.copyWith(
        plan: plan.chip == chip
            ? plan.copyWith(clearChip: true)
            : plan.copyWith(chip: chip),
      ),
    );
  }

  void resetTransfers() {
    final plan = state.plan;
    if (plan == null) return;
    emit(
      state.copyWith(plan: plan.copyWith(transfers: const [], clearChip: true)),
    );
  }

  /// Saves the draft lineup and chip. Throws on failure so the page can
  /// report it; the draft is kept for another attempt.
  Future<void> saveLineup() async {
    final error = SquadEditor.validate(state.lineup);
    if (error != null) throw SquadEditException(error);
    await _write(ManageTeamAction.lineupSaved, (session) {
      return teamRepository.saveMyTeam(
        session: session,
        entryId: session.entryId!,
        chip: state.lineupChip,
        picks: state.lineup,
      );
    });
  }

  Future<void> confirmTransfers() async {
    final plan = state.plan;
    final gameweek = state.gameweek;
    if (plan == null || gameweek == null || !plan.hasChanges) return;
    await _write(ManageTeamAction.transfersConfirmed, (session) {
      return teamRepository.makeTransfers(
        session: session,
        entryId: session.entryId!,
        gameweekId: gameweek.id,
        transfers: [for (final t in plan.transfers) t.toRequest()],
        chip: plan.chip,
      );
    });
  }

  Future<void> _write(
    ManageTeamAction action,
    Future<void> Function(OfficialSession session) request,
  ) async {
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true));
    try {
      await request(_session());
    } on Object {
      if (!isClosed) emit(state.copyWith(isSaving: false));
      rethrow;
    }
    await load();
    if (!isClosed) emit(state.copyWith(lastAction: action));
  }

  SquadEditError? _editLineup(List<TeamPick> Function(List<TeamPick>) edit) {
    try {
      emit(state.copyWith(lineup: edit(state.lineup)));
      return null;
    } on SquadEditException catch (error) {
      return error.error;
    }
  }

  OfficialSession _session() {
    final session = authCubit.state.session;
    if (session == null || session.entryId == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    return session;
  }

  /// The next deadline: edits made now apply to the upcoming gameweek.
  Gameweek _deadlineGameweek(FplBootstrap bootstrap) {
    return bootstrap.gameweeks.firstWhere(
      (gameweek) => gameweek.isNext,
      orElse: () => bootstrap.gameweeks.firstWhere(
        (gameweek) => gameweek.id > bootstrap.currentGameweekId,
        orElse: () => bootstrap.gameweeks.last,
      ),
    );
  }

  /// The lineup rules need each pick's position type; older responses may
  /// omit `element_type`, so fall back to bootstrap.
  MyTeam _withElementTypes(MyTeam team, FplBootstrap bootstrap) {
    return MyTeam(
      picks: [
        for (final pick in team.picks)
          pick.elementType > 0
              ? pick
              : pick.copyWith(
                  elementType:
                      bootstrap.players[pick.elementId]?.positionId ?? 0,
                ),
      ],
      summary: team.summary,
      transfers: team.transfers,
      chips: team.chips,
      activeChip: team.activeChip,
    );
  }
}
