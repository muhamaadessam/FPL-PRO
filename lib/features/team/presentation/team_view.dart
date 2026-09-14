import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/fpl_models.dart';
import '../../../core/network/fpl_api_client.dart';
import '../../../core/security/session_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../data/team_repository.dart';
import 'pitch_view.dart';

class TeamView extends ConsumerStatefulWidget {
  const TeamView({super.key, this.entryId});

  final int? entryId;

  @override
  ConsumerState<TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends ConsumerState<TeamView> {
  int? _selectedGameweekId;
  @override
  Widget build(BuildContext context) {
    final entryId = widget.entryId;
    final authState = entryId == null
        ? ref.watch(authControllerProvider)
        : null;
    final session = authState?.value;
    if (entryId == null) {
      if (!authState!.isLoading && session == null) {
        return _TeamMessage(
          icon: Icons.lock_outline,
          message: AppLocalizations.of(context).authContractRequired,
        );
      }
      if (!authState.isLoading && session?.entryId == null) {
        return _TeamMessage(
          icon: Icons.error_outline,
          message: AppLocalizations.of(context).entryIdMissing,
        );
      }
    }

    final bootstrapAsync = ref.watch(bootstrapProvider);

    return bootstrapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _TeamMessage(
        icon: Icons.error_outline,
        message: _errorMessage(error),
        onRetry: () => ref.invalidate(bootstrapProvider),
      ),
      data: (bootstrap) {
        final currentGw = bootstrap.currentGameweekId;
        final targetGw = _selectedGameweekId ?? currentGw;

        final AsyncValue<MyTeam> teamAsync;
        if (entryId != null) {
          teamAsync = ref.watch(
            publicTeamProvider((entryId: entryId, gameweekId: targetGw)),
          );
        } else {
          teamAsync = ref.watch(myTeamProvider(targetGw));
        }

        return teamAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _TeamMessage(
            icon: Icons.error_outline,
            message: _errorMessage(error),
            onRetry: () {
              if (entryId != null) {
                ref.invalidate(
                  publicTeamProvider((entryId: entryId, gameweekId: targetGw)),
                );
              } else {
                ref.invalidate(myTeamProvider(targetGw));
              }
            },
          ),
          data: (team) {
            final gwPointsAsync = ref.watch(gameweekPointsProvider(targetGw));
            final historyPointsAsync = entryId == null
                ? ref.watch(entryHistoryPointsProvider(session!.entryId!))
                : const AsyncValue.data(<int, int>{});

            return gwPointsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _TeamMessage(
                icon: Icons.error_outline,
                message: _errorMessage(error),
                onRetry: () => ref.invalidate(gameweekPointsProvider(targetGw)),
              ),
              data: (gwPoints) => historyPointsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _buildTeamContent(
                  team: team,
                  bootstrap: bootstrap,
                  gameweekPoints: gwPoints,
                  targetGw: targetGw,
                  historyPoints: const {},
                  entryId: entryId,
                  session: session,
                ),
                data: (historyPoints) => _buildTeamContent(
                  team: team,
                  bootstrap: bootstrap,
                  gameweekPoints: gwPoints,
                  targetGw: targetGw,
                  historyPoints: historyPoints,
                  entryId: entryId,
                  session: session,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamContent({
    required MyTeam team,
    required FplBootstrap bootstrap,
    required Map<int, int> gameweekPoints,
    required int targetGw,
    required Map<int, int> historyPoints,
    required int? entryId,
    required OfficialSession? session,
  }) {
    return _TeamContent(
      team: team,
      bootstrap: bootstrap,
      gameweekPoints: gameweekPoints,
      selectedGameweekId: targetGw,
      historyPoints: historyPoints,
      onGameweekChanged: (gw) => setState(() => _selectedGameweekId = gw),
      onRefresh: () async {
        final container = ProviderScope.containerOf(context, listen: false);
        if (entryId != null) {
          container.invalidate(
            publicTeamProvider((entryId: entryId, gameweekId: targetGw)),
          );
        } else {
          container.invalidate(myTeamProvider(targetGw));
          container.invalidate(entryHistoryPointsProvider(session!.entryId!));
        }
        container.invalidate(gameweekPointsProvider(targetGw));

        if (entryId != null) {
          await container.read(
            publicTeamProvider((entryId: entryId, gameweekId: targetGw)).future,
          );
        } else {
          await container.read(myTeamProvider(targetGw).future);
          await container.read(
            entryHistoryPointsProvider(session!.entryId!).future,
          );
        }
        await container.read(gameweekPointsProvider(targetGw).future);
      },
    );
  }

  String _errorMessage(Object error) {
    final l10n = AppLocalizations.of(context);
    if (error is FplApiException) {
      if (error.kind == FplApiErrorKind.network) {
        return l10n.networkError;
      }
      if (error.kind == FplApiErrorKind.rateLimited) {
        return l10n.rateLimited;
      }
      if (error.kind == FplApiErrorKind.authentication) {
        return l10n.authExpired;
      }
    } else if (error is TeamAccessException) {
      if (error.error == TeamAccessError.entryIdMissing) {
        return l10n.entryIdMissing;
      }
    }
    return l10n.genericError;
  }
}

class _TeamContent extends StatelessWidget {
  const _TeamContent({
    required this.team,
    required this.bootstrap,
    required this.gameweekPoints,
    required this.selectedGameweekId,
    required this.historyPoints,
    required this.onGameweekChanged,
    required this.onRefresh,
  });

  final MyTeam team;
  final FplBootstrap bootstrap;
  final Map<int, int> gameweekPoints;
  final int selectedGameweekId;
  final Map<int, int> historyPoints;
  final ValueChanged<int?> onGameweekChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final starting = team.picks.where((p) => p.position <= 11).toList();
    final bench = team.picks.where((p) => p.position > 11).toList();
    final gameweek = bootstrap.gameweeks.firstWhere(
      (gw) => gw.id == selectedGameweekId,
      orElse: () => bootstrap.gameweeks.first,
    );
    final liveTeamPoints = gameweek.isCurrent
        ? _liveTeamPoints(team.picks, gameweekPoints)
        : null;
    final displayedPoints =
        liveTeamPoints ??
        historyPoints[selectedGameweekId] ??
        (team.summary.gameweekId == selectedGameweekId
            ? team.summary.points
            : null);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const Key('team-gameweek-filter'),
                      value: selectedGameweekId,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      items: bootstrap.gameweeks
                          .map(
                            (gw) => DropdownMenuItem(
                              value: gw.id,
                              child: Text(
                                'GW ${gw.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: onGameweekChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 7,
                child: _SummaryCard(
                  summary: team.summary,
                  gameweek: gameweek,
                  displayedPoints: displayedPoints,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PitchView(
            starting: starting,
            bench: bench,
            bootstrap: bootstrap,
            gameweekPoints: gameweekPoints,
          ),
        ],
      ),
    );
  }

  int? _liveTeamPoints(List<TeamPick> picks, Map<int, int> gameweekPoints) {
    if (gameweekPoints.isEmpty) return null;
    final starting = picks.where((pick) => pick.position <= 11);
    if (starting.isEmpty) return null;
    return starting.fold<int>(
      0,
      (total, pick) =>
          total +
          (gameweekPoints[pick.elementId] ?? 0) *
              (pick.multiplier > 0 ? pick.multiplier : 1),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.gameweek,
    required this.displayedPoints,
  });
  final TeamSummary summary;
  final Gameweek gameweek;
  final int? displayedPoints;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: _SummaryMetric(
              label: l10n.points,
              value: displayedPoints?.toString() ?? '—',
              color: scheme.onPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: scheme.onPrimary.withValues(alpha: 0.2),
          ),
          Flexible(
            child: _SummaryMetric(
              label: l10n.averageScore,
              value: gameweek.averageEntryScore?.toString() ?? '—',
              color: scheme.onPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: scheme.onPrimary.withValues(alpha: 0.2),
          ),
          Flexible(
            child: _SummaryMetric(
              label: l10n.highestScore,
              value: gameweek.highestScore?.toString() ?? '—',
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TeamMessage extends StatelessWidget {
  const _TeamMessage({required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class TeamLookupPage extends StatelessWidget {
  const TeamLookupPage({super.key, required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (entryId == null || entryId! <= 0) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myTeam)),
        body: Center(child: Text(l10n.entryIdInvalid)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myTeam)),
      body: TeamView(entryId: entryId),
    );
  }
}
