import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../data/models/team_models.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/usecases/squad_editor.dart';
import '../cubit/manage_team_cubit.dart';
import '../widgets/pitch_view.dart';

/// Pick team, armbands, chips and transfers for the next deadline, written
/// through the official FPL endpoints.
class ManageTeamPage extends StatelessWidget {
  const ManageTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ManageTeamCubit(
        fixturesRepository: context.read<FixturesRepository>(),
        teamRepository: context.read<TeamRepository>(),
        authCubit: context.read<AuthCubit>(),
      )..load(),
      child: const _ManageTeamScaffold(),
    );
  }
}

class _ManageTeamScaffold extends StatelessWidget {
  const _ManageTeamScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.manageTeam),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.pickTeam),
              Tab(text: l10n.transfersTab),
            ],
          ),
        ),
        body: BlocConsumer<ManageTeamCubit, ManageTeamState>(
          listenWhen: (previous, current) =>
              current.lastAction != null &&
              previous.lastAction != current.lastAction,
          listener: (context, state) {
            _showMessage(
              context,
              state.lastAction == ManageTeamAction.lineupSaved
                  ? l10n.lineupSaved
                  : l10n.transfersConfirmed,
            );
          },
          builder: (context, state) {
            if (state.status == ManageTeamStatus.failure &&
                state.team == null) {
              return _ErrorView(error: state.error);
            }
            if (state.team == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              children: [
                const TabBarView(children: [_PickTeamTab(), _TransfersTab()]),
                if (state.isSaving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PickTeamTab extends StatefulWidget {
  const _PickTeamTab();

  @override
  State<_PickTeamTab> createState() => _PickTeamTabState();
}

class _PickTeamTabState extends State<_PickTeamTab> {
  /// The player waiting for a substitution partner, if any.
  int? _substituteFrom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ManageTeamCubit>().state;
    final bootstrap = state.bootstrap!;
    final starting = state.lineup.where((p) => p.position <= 11).toList();
    final bench = state.lineup.where((p) => p.position > 11).toList();
    final substituteName = _substituteFrom == null
        ? null
        : bootstrap.players[_substituteFrom]?.webName;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _DeadlineBanner(gameweek: state.gameweek),
              _LineupChips(state: state),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  substituteName == null
                      ? l10n.manageLineupHint
                      : l10n.chooseSubstituteFor(substituteName),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: substituteName == null
                        ? FontWeight.w500
                        : FontWeight.w800,
                  ),
                ),
              ),
              PitchView(
                starting: starting,
                bench: bench,
                bootstrap: bootstrap,
                gameweekPoints: const {},
                metric: PlayerCardMetric.price,
                onSwap: (dragged, target) => _swap(dragged, target),
                onPlayerTap: _onPlayerTap,
              ),
            ],
          ),
        ),
        _ActionBar(
          canReset: state.hasLineupChanges,
          canSubmit: state.hasLineupChanges && !state.isSaving,
          submitLabel: l10n.saveLineup,
          onReset: () {
            setState(() => _substituteFrom = null);
            context.read<ManageTeamCubit>().resetLineup();
          },
          onSubmit: () => _save(context),
        ),
      ],
    );
  }

  void _swap(int first, int second) {
    setState(() => _substituteFrom = null);
    final error = context.read<ManageTeamCubit>().swap(first, second);
    if (error != null) _showEditError(context, error);
  }

  Future<void> _onPlayerTap(int elementId) async {
    final pending = _substituteFrom;
    if (pending != null) {
      if (pending != elementId) _swap(pending, elementId);
      setState(() => _substituteFrom = null);
      return;
    }
    final cubit = context.read<ManageTeamCubit>();
    final pick = cubit.state.lineup.firstWhere((p) => p.elementId == elementId);
    final player = cubit.state.bootstrap!.players[elementId];
    final action = await showModalBottomSheet<_PlayerAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _PlayerActionSheet(pick: pick, player: player),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PlayerAction.captain:
        final error = cubit.setCaptain(elementId);
        if (error != null) _showEditError(context, error);
      case _PlayerAction.viceCaptain:
        final error = cubit.setViceCaptain(elementId);
        if (error != null) _showEditError(context, error);
      case _PlayerAction.substitute:
        setState(() => _substituteFrom = elementId);
      case _PlayerAction.transfer:
        DefaultTabController.of(context).animateTo(1);
        await _pickReplacement(context, elementId);
    }
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _substituteFrom = null);
    try {
      await context.read<ManageTeamCubit>().saveLineup();
    } on Object catch (error) {
      if (context.mounted) _showWriteError(context, error);
    }
  }
}

enum _PlayerAction { captain, viceCaptain, substitute, transfer }

class _PlayerActionSheet extends StatelessWidget {
  const _PlayerActionSheet({required this.pick, required this.player});

  final TeamPick pick;
  final FplPlayer? player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isStarter = pick.position <= 11;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              player?.webName ?? l10n.playerName(pick.elementId),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (isStarter && !pick.isCaptain)
            ListTile(
              leading: const _ArmbandIcon(label: 'C'),
              title: Text(l10n.makeCaptain),
              onTap: () => Navigator.pop(context, _PlayerAction.captain),
            ),
          if (isStarter && !pick.isViceCaptain)
            ListTile(
              leading: const _ArmbandIcon(label: 'V'),
              title: Text(l10n.makeViceCaptain),
              onTap: () => Navigator.pop(context, _PlayerAction.viceCaptain),
            ),
          ListTile(
            leading: const Icon(Icons.swap_vert_rounded),
            title: Text(l10n.substitutePlayer),
            onTap: () => Navigator.pop(context, _PlayerAction.substitute),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: Text(l10n.transferPlayerOut),
            onTap: () => Navigator.pop(context, _PlayerAction.transfer),
          ),
        ],
      ),
    );
  }
}

class _ArmbandIcon extends StatelessWidget {
  const _ArmbandIcon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.plPurple,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LineupChips extends StatelessWidget {
  const _LineupChips({required this.state});

  final ManageTeamState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ManageTeamCubit>();
    return _Section(
      title: l10n.chipsTitle,
      hint: l10n.lineupChipHint,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in [
            FplChipName.benchBoost,
            FplChipName.tripleCaptain,
          ])
            _ChipToggle(
              label: l10n.chipName(chip),
              selected: state.lineupChip == chip,
              played: state.savedLineupChip == chip,
              // Only one chip per gameweek, including a transfer chip.
              enabled:
                  state.savedLineupChip == chip ||
                  (state.isChipAvailable(chip) &&
                      !FplChipName.transferChips.contains(
                        state.team?.activeChip,
                      )),
              onSelected: () => cubit.toggleLineupChip(chip),
            ),
        ],
      ),
    );
  }
}

class _TransfersTab extends StatelessWidget {
  const _TransfersTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ManageTeamCubit>().state;
    final cubit = context.read<ManageTeamCubit>();
    final plan = state.plan!;
    final bootstrap = state.bootstrap!;
    final draft = plan.draftSquad;
    final incomingIds = {for (final t in plan.transfers) t.inPlayer.id};
    final activeTransferChip = FplChipName.transferChips.contains(
      state.team?.activeChip,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _DeadlineBanner(gameweek: state.gameweek),
              _TransferSummary(plan: plan),
              _Section(
                title: l10n.chipsTitle,
                hint: l10n.transferChipHint,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in [
                      FplChipName.wildcard,
                      FplChipName.freeHit,
                    ])
                      _ChipToggle(
                        label: l10n.chipName(chip),
                        selected:
                            plan.chip == chip || state.team?.activeChip == chip,
                        played: state.team?.activeChip == chip,
                        enabled:
                            !activeTransferChip &&
                            state.savedLineupChip == null &&
                            state.isChipAvailable(chip),
                        onSelected: () => cubit.toggleTransferChip(chip),
                      ),
                  ],
                ),
              ),
              _Section(
                title: l10n.pendingTransfers,
                child: plan.transfers.isEmpty
                    ? Text(l10n.noPendingTransfers)
                    : Column(
                        children: [
                          for (final t in plan.transfers)
                            _PendingTransferTile(
                              transfer: t,
                              bootstrap: bootstrap,
                              onUndo: () =>
                                  cubit.undoTransfer(t.outPick.elementId),
                            ),
                        ],
                      ),
              ),
              _Section(
                title: l10n.yourSquad,
                child: Column(
                  children: [
                    for (final position in [1, 2, 3, 4]) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.positionName(position),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                      for (final pick in draft.where(
                        (p) => p.elementType == position,
                      ))
                        _SquadPlayerTile(
                          pick: pick,
                          player: bootstrap.players[pick.elementId],
                          team: bootstrap
                              .teams[bootstrap.players[pick.elementId]?.teamId],
                          isIncoming: incomingIds.contains(pick.elementId),
                          onTap: () =>
                              _pickReplacement(context, pick.elementId),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _ActionBar(
          canReset: plan.hasChanges || plan.chip != null,
          canSubmit: plan.hasChanges && !state.isSaving,
          submitLabel: l10n.confirmTransfers,
          onReset: cubit.resetTransfers,
          onSubmit: () => _confirm(context, plan),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, TransferPlan plan) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmTransfers),
        content: Text(
          l10n.confirmTransfersBody(
            plan.transfers.length,
            plan.pointsCost,
            plan.chip,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ManageTeamCubit>().confirmTransfers();
    } on Object catch (error) {
      if (context.mounted) _showWriteError(context, error);
    }
  }
}

/// Opens the replacement picker for the draft player [outElementId] and
/// queues the chosen transfer.
Future<void> _pickReplacement(BuildContext context, int outElementId) async {
  final cubit = context.read<ManageTeamCubit>();
  final state = cubit.state;
  final bootstrap = state.bootstrap!;
  final outPlayer = bootstrap.players[outElementId];
  if (outPlayer == null) return;
  final incoming = await showModalBottomSheet<FplPlayer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReplacementSheet(
      outPlayer: outPlayer,
      plan: state.plan!,
      bootstrap: bootstrap,
    ),
  );
  if (incoming == null || !context.mounted) return;
  final error = cubit.queueTransfer(outElementId, incoming);
  if (error != null) _showEditError(context, error);
}

class _ReplacementSheet extends StatefulWidget {
  const _ReplacementSheet({
    required this.outPlayer,
    required this.plan,
    required this.bootstrap,
  });

  final FplPlayer outPlayer;
  final TransferPlan plan;
  final FplBootstrap bootstrap;

  @override
  State<_ReplacementSheet> createState() => _ReplacementSheetState();
}

class _ReplacementSheetState extends State<_ReplacementSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final candidates =
        widget.bootstrap.players.values
            .where((p) => p.positionId == widget.outPlayer.positionId)
            .where((p) => p.id != widget.outPlayer.id)
            .where((p) {
              if (query.isEmpty) return true;
              final team = widget.bootstrap.teams[p.teamId];
              return p.webName.toLowerCase().contains(query) ||
                  (team?.name.toLowerCase().contains(query) ?? false) ||
                  (team?.shortName.toLowerCase().contains(query) ?? false);
            })
            .toList()
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Text(
            l10n.replaceFor(widget.outPlayer.webName),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchPlayersHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final player = candidates[index];
                final error = widget.plan.check(widget.outPlayer.id, player);
                final team = widget.bootstrap.teams[player.teamId];
                return ListTile(
                  enabled: error == null,
                  title: Text(player.webName),
                  subtitle: Text(
                    error == null
                        ? '${team?.shortName ?? ''} • ${player.totalPoints} pts'
                        : l10n.squadEditError(error.name),
                  ),
                  trailing: Text(
                    _price(player.nowCost),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(context, player),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferSummary extends StatelessWidget {
  const _TransferSummary({required this.plan});

  final TransferPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final free = plan.chip != null || plan.freeTransfers == null
        ? l10n.unlimited
        : '${plan.freeTransfers}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SummaryStat(label: l10n.freeTransfers, value: free),
          _SummaryStat(
            label: l10n.remainingBank,
            value: _price(plan.remainingBank),
            isWarning: plan.remainingBank < 0,
          ),
          _SummaryStat(
            label: l10n.pointsHit,
            value: l10n.pointsHitValue(plan.pointsCost),
            isWarning: plan.pointsCost > 0,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isWarning
                      ? AppColors.darkAlertErrorText
                      : AppColors.accent(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTransferTile extends StatelessWidget {
  const _PendingTransferTile({
    required this.transfer,
    required this.bootstrap,
    required this.onUndo,
  });

  final PendingTransfer transfer;
  final FplBootstrap bootstrap;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final outName =
        bootstrap.players[transfer.outPick.elementId]?.webName ?? '—';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.swap_horiz_rounded),
      title: Text('$outName → ${transfer.inPlayer.webName}'),
      subtitle: Text(
        '${_price(transfer.sellingPrice)} → ${_price(transfer.purchasePrice)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.undo_rounded),
        tooltip: AppLocalizations.of(context).resetChanges,
        onPressed: onUndo,
      ),
    );
  }
}

class _SquadPlayerTile extends StatelessWidget {
  const _SquadPlayerTile({
    required this.pick,
    required this.player,
    required this.team,
    required this.isIncoming,
    required this.onTap,
  });

  final TeamPick pick;
  final FplPlayer? player;
  final FplTeam? team;
  final bool isIncoming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        player?.webName ?? l10n.playerName(pick.elementId),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isIncoming ? AppColors.accent(isDark) : null,
        ),
      ),
      subtitle: Text(
        '${team?.shortName ?? ''} • ${l10n.sellingPrice} '
        '${_price(pick.sellingPrice ?? player?.nowCost)}',
      ),
      trailing: const Icon(Icons.swap_horiz_rounded),
      onTap: onTap,
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({
    required this.label,
    required this.selected,
    required this.played,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool played;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = played
        ? l10n.chipPlayed
        : enabled
        ? null
        : l10n.chipNotAvailable;
    return FilterChip(
      label: Text(status == null ? label : '$label • $status'),
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DeadlineBanner extends StatelessWidget {
  const _DeadlineBanner({required this.gameweek});

  final Gameweek? gameweek;

  @override
  Widget build(BuildContext context) {
    final gw = gameweek;
    if (gw == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final deadline = gw.deadlineTime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        deadline == null
            ? l10n.deadlineFor(l10n.gameweekLabel(gw.id))
            : '${l10n.deadlineFor(l10n.gameweekLabel(gw.id))} • '
                  '${l10n.kickoffLabel(deadline)}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canReset,
    required this.canSubmit,
    required this.submitLabel,
    required this.onReset,
    required this.onSubmit,
  });

  final bool canReset;
  final bool canSubmit;
  final String submitLabel;
  final VoidCallback onReset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: canReset ? onReset : null,
              child: Text(AppLocalizations.of(context).resetChanges),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canSubmit ? onSubmit : null,
                child: Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(_writeErrorText(context, error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: context.read<ManageTeamCubit>().load,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

String _price(int? tenths) =>
    tenths == null ? '—' : '£${(tenths / 10).toStringAsFixed(1)}m';

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _showEditError(BuildContext context, SquadEditError error) {
  _showMessage(
    context,
    AppLocalizations.of(context).squadEditError(error.name),
  );
}

void _showWriteError(BuildContext context, Object error) {
  _showMessage(context, _writeErrorText(context, error));
}

String _writeErrorText(BuildContext context, Object? error) {
  final l10n = AppLocalizations.of(context);
  return switch (error) {
    SquadEditException(:final error) => l10n.squadEditError(error.name),
    FplApiException(kind: FplApiErrorKind.authentication) =>
      l10n.writeAuthRequired,
    FplApiException(kind: FplApiErrorKind.network) => l10n.networkError,
    FplApiException(kind: FplApiErrorKind.rateLimited) => l10n.rateLimited,
    FplApiException() => l10n.writeFailed,
    _ => l10n.genericError,
  };
}
