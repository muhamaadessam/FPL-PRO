import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/models/team_models.dart';
import '../../domain/repositories/team_repository.dart';
import '../cubit/team_cubit.dart';
import '../widgets/pitch_view.dart';

class TeamView extends StatelessWidget {
  const TeamView({super.key, this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final authCubit = entryId == null ? context.read<AuthCubit>() : null;
    return BlocProvider(
      create: (context) => TeamCubit(
        fixturesRepository: context.read<FixturesRepository>(),
        teamRepository: context.read<TeamRepository>(),
        authCubit: authCubit,
        entryId: entryId,
      )..load(),
      child: _TeamBody(entryId: entryId),
    );
  }
}

class _TeamBody extends StatelessWidget {
  const _TeamBody({required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final auth = entryId == null
        ? context.watch<AuthCubit>().state
        : const AuthUnauthenticated();
    if (entryId == null && !auth.isLoading && auth.session == null) {
      return _TeamMessage(
        icon: Icons.lock_outline,
        message: AppLocalizations.of(context).authContractRequired,
      );
    }
    if (entryId == null && !auth.isLoading && auth.session?.entryId == null) {
      return _TeamMessage(
        icon: Icons.error_outline,
        message: AppLocalizations.of(context).entryIdMissing,
      );
    }

    return BlocBuilder<TeamCubit, TeamState>(
      builder: (context, state) {
        if (state.status == TeamStatus.initial ||
            state.status == TeamStatus.loading) {
          return const _TeamSkeleton();
        }
        if (state.status == TeamStatus.failure) {
          return _TeamMessage(
            icon: Icons.error_outline,
            message: _errorMessage(context, state.error!),
            onRetry: context.read<TeamCubit>().refresh,
          );
        }

        return _TeamContent(
          team: state.team!,
          bootstrap: state.bootstrap!,
          gameweekPoints: state.gameweekPoints,
          selectedGameweekId: state.selectedGameweekId!,
          historyPoints: state.historyPoints,
          onGameweekChanged: (gameweekId) {
            if (gameweekId != null) {
              context.read<TeamCubit>().selectGameweek(gameweekId);
            }
          },
          onRefresh: context.read<TeamCubit>().refresh,
        );
      },
    );
  }
}

String _errorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is FplApiException) {
    if (error.kind == FplApiErrorKind.network) return l10n.networkError;
    if (error.kind == FplApiErrorKind.rateLimited) return l10n.rateLimited;
    if (error.kind == FplApiErrorKind.authentication) return l10n.authExpired;
  } else if (error is TeamAccessException) {
    if (error.error == TeamAccessError.entryIdMissing) {
      return l10n.entryIdMissing;
    }
  }
  return l10n.genericError;
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
                flex: 4,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: const Key('team-gameweek-prev'),
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.chevron_left),
                          onPressed:
                              bootstrap.gameweeks.indexWhere(
                                    (g) => g.id == selectedGameweekId,
                                  ) >
                                  0
                              ? () {
                                  final idx = bootstrap.gameweeks.indexWhere(
                                    (g) => g.id == selectedGameweekId,
                                  );
                                  onGameweekChanged(
                                    bootstrap.gameweeks[idx - 1].id,
                                  );
                                }
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            'GW $selectedGameweekId',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                          ),
                        ),
                        IconButton(
                          key: const Key('team-gameweek-next'),
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              bootstrap.gameweeks.indexWhere(
                                        (g) => g.id == selectedGameweekId,
                                      ) >=
                                      0 &&
                                  bootstrap.gameweeks.indexWhere(
                                        (g) => g.id == selectedGameweekId,
                                      ) <
                                      bootstrap.gameweeks.length - 1
                              ? () {
                                  final idx = bootstrap.gameweeks.indexWhere(
                                    (g) => g.id == selectedGameweekId,
                                  );
                                  onGameweekChanged(
                                    bootstrap.gameweeks[idx + 1].id,
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
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
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
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
                label: l10n.highestScore,
                value: gameweek.highestScore?.toString() ?? '—',
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
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

class _TeamSkeleton extends StatefulWidget {
  const _TeamSkeleton();
  @override
  State<_TeamSkeleton> createState() => _TeamSkeletonState();
}

class _TeamSkeletonState extends State<_TeamSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.modulate,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xff8a8a8a),
                Color(0xfff5f5f5),
                Color(0xff8a8a8a),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-2.0 + (_controller.value * 4), 0),
              end: Alignment(-1.0 + (_controller.value * 4), 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 7,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PitchSkeleton(),
        ],
      ),
    );
  }
}
