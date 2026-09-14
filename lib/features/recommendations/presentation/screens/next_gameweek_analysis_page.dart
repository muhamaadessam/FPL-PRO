import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../team/presentation/widgets/pitch_view.dart';
import '../../domain/entities/recommendation_data.dart';
import '../../domain/usecases/recommendation_engine.dart';

class NextGameweekAnalysisPage extends StatelessWidget {
  const NextGameweekAnalysisPage({super.key, required this.data});

  final RecommendationData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final analysis = data.result.squadAnalysis;
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
