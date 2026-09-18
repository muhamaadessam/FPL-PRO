import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';
import '../../../team/presentation/widgets/pitch_view.dart';
import '../../domain/entities/recommendation_data.dart';
import '../../domain/usecases/recommendation_engine.dart';
import 'player_directory_page.dart';

class NextGameweekAnalysisPage extends StatefulWidget {
  const NextGameweekAnalysisPage({
    super.key,
    required this.data,
    this.onTransfer,
  });

  final RecommendationData data;
  final Future<void> Function(TransferSuggestion transfer)? onTransfer;

  @override
  State<NextGameweekAnalysisPage> createState() =>
      _NextGameweekAnalysisPageState();
}

class _NextGameweekAnalysisPageState extends State<NextGameweekAnalysisPage> {
  late SquadAnalysis analysis;

  @override
  void initState() {
    super.initState();
    analysis = widget.data.result.squadAnalysis;
  }

  void _onSwapPlayers(int draggedElementId, int targetElementId) {
    if (draggedElementId == targetElementId) return;

    final players = List<PlayerAnalysis>.from(analysis.players);
    final draggedIdx = players.indexWhere(
      (p) => p.pick.elementId == draggedElementId,
    );
    final targetIdx = players.indexWhere(
      (p) => p.pick.elementId == targetElementId,
    );

    if (draggedIdx == -1 || targetIdx == -1) return;

    final dragged = players[draggedIdx];
    final target = players[targetIdx];

    final draggedWasBench = !dragged.isStarter;
    final targetWasBench = !target.isStarter;

    final newDragged = dragged.copyWith(
      pick: dragged.pick.copyWith(
        position: target.pick.position,
        isCaptain: target.pick.isCaptain,
        isViceCaptain: target.pick.isViceCaptain,
        multiplier: target.pick.multiplier,
      ),
    );

    final newTarget = target.copyWith(
      pick: target.pick.copyWith(
        position: dragged.pick.position,
        isCaptain: dragged.pick.isCaptain,
        isViceCaptain: dragged.pick.isViceCaptain,
        multiplier: dragged.pick.multiplier,
      ),
    );

    players[draggedIdx] = newDragged;
    players[targetIdx] = newTarget;

    const engine = RecommendationEngine();
    if (!engine.isLegalStartingLineup(players)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).invalidFormation)),
      );
      return;
    }

    final newAnalysis = engine.buildSquadAnalysisForPreview(
      players: players,
      currentSeasonCoverage: analysis.currentSeasonCoverage,
      previousSeasonPlayers: analysis.previousSeasonPlayers,
    );

    setState(() {
      analysis = newAnalysis;
    });

    if (draggedWasBench && newDragged.isStarter) {
      _checkAvailabilityWarning(newDragged);
    }
    if (targetWasBench && newTarget.isStarter) {
      _checkAvailabilityWarning(newTarget);
    }
  }

  void _checkAvailabilityWarning(PlayerAnalysis player) {
    if (!player.isStarter) return;

    final fplPlayer = player.projection.player;
    final status = fplPlayer.status;
    final chance = fplPlayer.chanceOfPlayingNextRound;

    if (status == 'a' && (chance == null || chance == 100)) return;

    final l10n = AppLocalizations.of(context);
    final chanceText =
        '${chance ?? (player.projection.availability * 100).round()}%';
    final news = fplPlayer.news.isNotEmpty ? fplPlayer.news : l10n.noNews;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fplPlayer.webName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.availability}: $chanceText'),
            const SizedBox(height: 8),
            Text('${l10n.news}: $news'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _onComparePlayer(int playerId) async {
    final current = analysis.players
        .where((player) => player.projection.player.id == playerId)
        .firstOrNull;
    if (current == null) return;

    final projections = const RecommendationEngine()
        .buildPlayerProjections(
          bootstrap: widget.data.bootstrap,
          fixtures: widget.data.fixtures,
          gameweekId: widget.data.result.gameweekId,
        )
        .where(
          (projection) =>
              projection.player.positionId ==
                  current.projection.player.positionId &&
              projection.player.id != playerId,
        )
        .toList();
    projections.sort((a, b) => b.horizonPoints.compareTo(a.horizonPoints));

    final candidate = await showModalBottomSheet<PlayerProjection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${l10n.comparePlayers} • ${current.projection.player.webName}',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.samePositionAlternatives,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: projections.isEmpty
                      ? Center(child: Text(l10n.noPlayersFound))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: projections.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final projection = projections[index];
                            final player = projection.player;
                            final team =
                                widget.data.bootstrap.teams[player.teamId];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(projection),
                              leading: CircleAvatar(
                                child: Text(team?.shortName ?? 'PL'),
                              ),
                              title: Text(
                                player.webName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${team?.name ?? l10n.unknown} • ${l10n.playerPrice}: £${((player.nowCost ?? 0) / 10).toStringAsFixed(1)}m',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 88,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      projection.nextPoints.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      l10n.expectedNextGameweekPoints,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (candidate == null || !mounted) return;

    final transfer = const RecommendationEngine().buildTransferSuggestion(
      team: widget.data.team,
      bootstrap: widget.data.bootstrap,
      outgoing: current.projection,
      incoming: candidate,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlayerComparisonPage(
          left: current.projection,
          right: candidate,
          bootstrap: widget.data.bootstrap,
          transfer: transfer,
          onTransfer: transfer == null || widget.onTransfer == null
              ? null
              : widget.onTransfer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    final nextGameweekAlerts = analysis.players
        .where(
          (player) =>
              player.projection.player.isUnavailableNextRound ||
              player.projection.player.isDoubtfulNextRound,
        )
        .map((player) => player.pick)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nextGameweekAnalysis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            data.gameweek.name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (nextGameweekAlerts.isNotEmpty) ...[
            _NextGameweekAlerts(
              key: const ValueKey('next-gameweek-alerts'),
              picks: nextGameweekAlerts,
              bootstrap: data.bootstrap,
            ),
            const SizedBox(height: 16),
          ],
          _OverviewPanel(analysis: analysis),
          const SizedBox(height: 8),
          Text(
            l10n.analysisCoverage(
              analysis.currentSeasonCoverage,
              analysis.previousSeasonPlayers,
              analysis.players.length,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          PitchView(
            starting: analysis.starters
                .map((p) => p.pick)
                .toList(growable: false),
            bench: analysis.bench.map((p) => p.pick).toList(growable: false),
            bootstrap: data.bootstrap,
            gameweekPoints: {
              for (final p in analysis.players)
                p.pick.elementId: p.expectedPoints,
            },
            onSwap: _onSwapPlayers,
            onCompare: _onComparePlayer,
          ),
          const SizedBox(height: 24),
          _PlayerList(
            players: [...analysis.starters, ...analysis.bench],
            data: data,
          ),
          const SizedBox(height: 24),
          const _MethodologyPanel(),
          const SizedBox(height: 12),
          Text(
            l10n.analysisDisclaimer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _NextGameweekAlerts extends StatelessWidget {
  const _NextGameweekAlerts({
    super.key,
    required this.picks,
    required this.bootstrap,
  });

  final List<TeamPick> picks;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final subtitleColor = isDark
        ? const Color(0xffb8afc4)
        : const Color(0xff6b7280);
    final panelColor = isDark
        ? const Color(0xff24182e)
        : const Color(0xfffffbf2);
    final borderColor = isDark
        ? const Color(0xff4a3022)
        : const Color(0xfff3dfb4);

    return Container(
      key: const ValueKey('next-gameweek-alerts-panel'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xffd97706),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nextGameweekAlerts,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.nextGameweekAlertsSubtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${picks.length}',
                style: const TextStyle(
                  color: Color(0xffb45309),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...picks.map(
            (pick) => _AlertPlayerRow(
              player: bootstrap.players[pick.elementId]!,
              team: bootstrap.teams[bootstrap.players[pick.elementId]!.teamId],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPlayerRow extends StatelessWidget {
  const _AlertPlayerRow({required this.player, required this.team});

  final FplPlayer player;
  final FplTeam? team;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isUnavailable = player.isUnavailableNextRound;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isUnavailable
        ? (isDark ? const Color(0xffff8d8d) : const Color(0xffc2413d))
        : (isDark ? const Color(0xffffc56b) : const Color(0xffb45309));
    final status = switch (player.status.toLowerCase()) {
      'i' => l10n.injured,
      's' => l10n.suspended,
      _ => isUnavailable ? l10n.unavailable : l10n.doubtful,
    };
    final chance = player.nextRoundChanceOfPlaying;
    final details = player.news.trim().isNotEmpty
        ? player.news.trim()
        : chance != null
        ? l10n.chanceOfPlaying(chance)
        : status;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            isUnavailable
                ? Icons.event_busy_rounded
                : Icons.help_outline_rounded,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.webName} · ${team?.shortName ?? 'PL'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xff1f1f2e),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.analysis});

  final SquadAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final ratingColor = _ratingColor(colors, analysis.rating);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: ratingColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.squadRating,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      l10n.ratingBand(analysis.rating),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: ratingColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.ratingOutOf100(analysis.rating),
                  style: TextStyle(
                    color: ratingColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: l10n.expectedStartingPoints,
                  value: analysis.expectedStartingPoints.toStringAsFixed(1),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: l10n.expectedBenchPoints,
                  value: analysis.expectedBenchPoints.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: l10n.averagePlayerRating,
                  value: l10n.ratingOutOf100(analysis.averageStarterRating),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: l10n.bestLegalLineup,
                  value: analysis.bestLegalLineupPoints.toStringAsFixed(1),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: l10n.selectionEfficiency,
                  value: '${analysis.selectionEfficiency}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.players, required this.data});

  final List<PlayerAnalysis> players;
  final RecommendationData data;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return Text(AppLocalizations.of(context).noFixtures);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < players.length; index++) ...[
            _PlayerAnalysisTile(player: players[index], data: data),
            if (index < players.length - 1)
              Divider(height: 1, color: colors.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _PlayerAnalysisTile extends StatelessWidget {
  const _PlayerAnalysisTile({required this.player, required this.data});

  final PlayerAnalysis player;
  final RecommendationData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final footballer = player.projection.player;
    final team = data.bootstrap.teams[footballer.teamId]?.shortName ?? '—';
    final ratingColor = _ratingColor(colors, player.rating);
    return ExpansionTile(
      key: ValueKey('analysis-player-${footballer.id}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _positionCode(footballer.positionId),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              footballer.webName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (player.pick.isCaptain) ...[
            const SizedBox(width: 6),
            _RoleBadge(label: 'C'),
          ] else if (player.pick.isViceCaptain) ...[
            const SizedBox(width: 6),
            _RoleBadge(label: 'V'),
          ],
        ],
      ),
      subtitle: Text(
        '$team • ${_fixturesLabel(l10n)} • ${_trendLabel(l10n)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${player.expectedPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            l10n.ratingOutOf100(player.rating),
            style: TextStyle(
              color: ratingColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _DetailMetric(
              label: l10n.currentForm,
              value: player.recentPoints.toStringAsFixed(1),
            ),
            _DetailMetric(
              label: l10n.seasonAverage,
              value: player.seasonPoints.toStringAsFixed(1),
            ),
            _DetailMetric(
              label: l10n.previousSeason,
              value:
                  player.previousSeasonPoints?.toStringAsFixed(1) ??
                  l10n.noPreviousSeason,
            ),
            _DetailMetric(
              label: l10n.fixtureRating,
              value: l10n.ratingOutOf100(player.fixtureScore),
            ),
            _DetailMetric(
              label: l10n.availability,
              value: '${(player.projection.availability * 100).round()}%',
            ),
            _DetailMetric(
              label: l10n.reliability,
              value: '${(player.reliability * 100).round()}%',
            ),
          ],
        ),
      ],
    );
  }

  String _fixturesLabel(AppLocalizations l10n) {
    if (player.nextOpponentTeamIds.isEmpty) return l10n.noFixtures;
    return List.generate(player.nextOpponentTeamIds.length, (index) {
      final opponent =
          data.bootstrap.teams[player.nextOpponentTeamIds[index]]?.shortName ??
          '—';
      final venue = player.nextFixturesAtHome[index]
          ? l10n.homeShort
          : l10n.awayShort;
      return '$opponent ($venue)';
    }).join(' • ');
  }

  String _trendLabel(AppLocalizations l10n) {
    return switch (player.trend) {
      PlayerTrend.rising => l10n.rising,
      PlayerTrend.steady => l10n.steady,
      PlayerTrend.falling => l10n.falling,
    };
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MethodologyPanel extends StatelessWidget {
  const _MethodologyPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.calculate_outlined),
        title: Text(
          l10n.ratingMethod,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Text(l10n.ratingMethodDescription)],
      ),
    );
  }
}

String _positionCode(int positionId) {
  return switch (positionId) {
    1 => 'GKP',
    2 => 'DEF',
    3 => 'MID',
    _ => 'FWD',
  };
}

Color _ratingColor(ColorScheme colors, int rating) {
  if (rating >= 75) return colors.primary;
  if (rating >= 60) return colors.tertiary;
  if (rating >= 50) return colors.secondary;
  return colors.error;
}
