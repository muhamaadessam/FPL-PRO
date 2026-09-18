import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/fpl_api_client.dart';
import '../../data/models/fpl_models.dart';
import '../../domain/repositories/fixtures_repository.dart';
import '../../domain/usecases/predict_fixtures.dart';
import '../cubit/fixtures_cubit.dart';
import '../../../dashboard/presentation/cubit/home_preload_cubit.dart';

class FixturesView extends StatelessWidget {
  const FixturesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        HomePreloadState? preload;
        try {
          preload = context.read<HomePreloadCubit>().state;
        } on ProviderNotFoundException catch (_) {}
        final hasPreload = preload?.status == PreloadStatus.success;
        final cubit = FixturesCubit(
          context.read<FixturesRepository>(),
          initialState: hasPreload
              ? FixturesState(
                  status: FixturesStatus.success,
                  bootstrap: preload?.bootstrap,
                  fixtures: preload?.fixtures ?? const [],
                )
              : null,
        );
        if (!hasPreload) cubit.load();
        return cubit;
      },
      child: const _FixturesBody(),
    );
  }
}

class _FixturesBody extends StatelessWidget {
  const _FixturesBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FixturesCubit, FixturesState>(
      builder: (context, state) {
        if (state.status == FixturesStatus.loading ||
            state.status == FixturesStatus.initial) {
          return const _ShimmerSkeleton();
        }
        if (state.status == FixturesStatus.failure) {
          return _ErrorState(
            error: state.error!,
            onRetry: context.read<FixturesCubit>().refresh,
          );
        }
        final bootstrap = state.bootstrap!;
        return _FixtureList(
          gameweekId: bootstrap.currentGameweekId,
          gameweeks: bootstrap.gameweeks,
          fixtures: state.fixtures,
          teams: bootstrap.teams,
          players: bootstrap.players,
        );
      },
    );
  }
}

class _FixtureList extends StatefulWidget {
  const _FixtureList({
    required this.gameweekId,
    required this.gameweeks,
    required this.fixtures,
    required this.teams,
    required this.players,
  });

  final int gameweekId;
  final List<Gameweek> gameweeks;
  final List<FplFixture> fixtures;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;

  @override
  State<_FixtureList> createState() => _FixtureListState();
}

class _FixtureListState extends State<_FixtureList> {
  late int _selectedGameweekId;

  @override
  void initState() {
    super.initState();
    _selectedGameweekId = widget.gameweekId;
  }

  @override
  void didUpdateWidget(covariant _FixtureList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.gameweeks.any(
      (gameweek) => gameweek.id == _selectedGameweekId,
    )) {
      _selectedGameweekId = widget.gameweekId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fixtures = widget.fixtures
        .where((fixture) => fixture.gameweekId == _selectedGameweekId)
        .toList()
      ..sort((a, b) {
        if (a.kickoffTime == null && b.kickoffTime == null) {
          return a.id.compareTo(b.id);
        }
        if (a.kickoffTime == null) return 1;
        if (b.kickoffTime == null) return -1;
        return a.kickoffTime!.compareTo(b.kickoffTime!);
      });

    final dayGroups = <DateTime?, List<FplFixture>>{};
    for (final fixture in fixtures) {
      final localDate = fixture.kickoffTime != null
          ? DateTime(
              fixture.kickoffTime!.toLocal().year,
              fixture.kickoffTime!.toLocal().month,
              fixture.kickoffTime!.toLocal().day,
            )
          : null;
      dayGroups.putIfAbsent(localDate, () => []).add(fixture);
    }

    final selectedGameweekIndex = widget.gameweeks.indexWhere(
      (gameweek) => gameweek.id == _selectedGameweekId,
    );
    final canGoPrevious = selectedGameweekIndex > 0;
    final canGoNext =
        selectedGameweekIndex >= 0 &&
        selectedGameweekIndex < widget.gameweeks.length - 1;
    final predictions = const FixturePredictionEngine().predictNextGameweeks(
      fixtures: widget.fixtures,
      teams: widget.teams,
      players: widget.players,
      fromGameweekId: widget.gameweekId,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<FixturesCubit>().refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('fixtures-gameweek-previous'),
                        tooltip: l10n.previousGameweek,
                        onPressed: canGoPrevious
                            ? () => setState(
                                () => _selectedGameweekId = widget
                                    .gameweeks[selectedGameweekIndex - 1]
                                    .id,
                              )
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l10n.gameweekLabel(_selectedGameweekId),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('fixtures-gameweek-next'),
                        tooltip: l10n.nextGameweek,
                        onPressed: canGoNext
                            ? () => setState(
                                () => _selectedGameweekId = widget
                                    .gameweeks[selectedGameweekIndex + 1]
                                    .id,
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.matchesCount(fixtures.length),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (fixtures.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(child: Text(l10n.noFixtures)),
            )
          else
            for (final entry in dayGroups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4, right: 4),
                child: Text(
                  l10n.matchDayHeader(entry.key),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              for (final fixture in entry.value) ...[
                _FixtureCard(
                  fixture: fixture,
                  teams: widget.teams,
                  players: widget.players,
                  prediction: predictions[fixture.id],
                ),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({
    required this.fixture,
    required this.teams,
    required this.players,
    required this.prediction,
  });

  final FplFixture fixture;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;
  final FixturePrediction? prediction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = teams[fixture.homeTeamId];
    final away = teams[fixture.awayTeamId];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('fixture-card-${fixture.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showFixtureDetails(context),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _TeamBadge(teamCode: home?.code, size: 38),
                    const SizedBox(height: 6),
                    Text(
                      home?.shortName.isNotEmpty == true
                          ? home!.shortName
                          : (home?.name ?? l10n.homeTeam),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    _ScoreArea(fixture: fixture, l10n: l10n, compact: true),
                    const SizedBox(height: 6),
                    _StateBadge(fixture: fixture, l10n: l10n),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TeamBadge(teamCode: away?.code, size: 38),
                    const SizedBox(height: 6),
                    Text(
                      away?.shortName.isNotEmpty == true
                          ? away!.shortName
                          : (away?.name ?? l10n.awayTeam),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFixtureDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.2,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _FixtureDetailsSheet(
          fixture: fixture,
          teams: teams,
          players: players,
          prediction: prediction,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.teamCode, this.size = 38});

  final int? teamCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (teamCode == null) return _FallbackShield(size: size);
    return Image.network(
      'https://resources.premierleague.com/premierleague/badges/70/t$teamCode.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => _FallbackShield(size: size),
    );
  }
}

class _FallbackShield extends StatelessWidget {
  const _FallbackShield({this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: size * 0.5,
      ),
    );
  }
}

class _ScoreArea extends StatelessWidget {
  const _ScoreArea({
    required this.fixture,
    required this.l10n,
    this.compact = false,
  });

  final FplFixture fixture;
  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final homeScore = fixture.homeScore;
    final awayScore = fixture.awayScore;
    final showScore = homeScore != null && awayScore != null;

    if (showScore) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$homeScore - $awayScore',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 18 : 24,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        fixture.isLive || fixture.isFinished
            ? '—'
            : (compact
                ? l10n.kickoffTimeOnly(fixture.kickoffTime)
                : l10n.kickoffLabel(fixture.kickoffTime)),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: compact ? 13 : 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.fixture, required this.l10n});

  final FplFixture fixture;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    Color bgColor;

    if (fixture.isFinished) {
      label = l10n.fixtureFinished;
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      bgColor = Colors.transparent;
    } else if (fixture.isLive) {
      label = l10n.fixtureLive;
      color = const Color(0xFF00FF87);
      bgColor = color.withValues(alpha: 0.1);
    } else {
      label = l10n.fixtureUpcoming;
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      bgColor = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: bgColor == Colors.transparent
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FixtureDetailsSheet extends StatelessWidget {
  const _FixtureDetailsSheet({
    required this.fixture,
    required this.teams,
    required this.players,
    required this.prediction,
    required this.scrollController,
  });

  final FplFixture fixture;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;
  final FixturePrediction? prediction;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = teams[fixture.homeTeamId];
    final away = teams[fixture.awayTeamId];
    final eventSections = [
      _FixtureEventCategory(
        identifier: 'goals_scored',
        title: l10n.goals,
        icon: Icons.sports_soccer,
        pointsFor: (event, player) => _goalPoints(player, event.value),
      ),
      _FixtureEventCategory(
        identifier: 'assists',
        title: l10n.assists,
        icon: Icons.handshake_outlined,
        pointsFor: (event, _) => event.value * 3,
      ),
      _FixtureEventCategory(
        identifier: 'own_goals',
        title: l10n.ownGoals,
        icon: Icons.sports_soccer_outlined,
        pointsFor: (event, _) => event.value * -2,
      ),
      _FixtureEventCategory(
        identifier: 'penalties_saved',
        title: l10n.penaltiesSaved,
        icon: Icons.pan_tool_outlined,
        pointsFor: (event, _) => event.value * 5,
      ),
      _FixtureEventCategory(
        identifier: 'penalties_missed',
        title: l10n.penaltiesMissed,
        icon: Icons.cancel_outlined,
        pointsFor: (event, _) => event.value * -2,
      ),
      _FixtureEventCategory(
        identifier: 'yellow_cards',
        title: l10n.yellowCards,
        icon: Icons.style_outlined,
        pointsFor: (event, _) => event.value * -1,
      ),
      _FixtureEventCategory(
        identifier: 'red_cards',
        title: l10n.redCards,
        icon: Icons.style,
        pointsFor: (event, _) => event.value * -3,
      ),
      _FixtureEventCategory(
        identifier: 'saves',
        title: l10n.saves,
        icon: Icons.sports_handball_outlined,
        pointsFor: (event, _) => event.value ~/ 3,
      ),
      _FixtureEventCategory(
        identifier: 'bonus',
        title: l10n.bonusPoints,
        icon: Icons.military_tech_outlined,
        pointsFor: (event, _) => event.value,
      ),
      _FixtureEventCategory(
        identifier: 'defensive_contribution',
        title: l10n.defensiveContribution,
        icon: Icons.shield_outlined,
        pointsFor: (event, player) =>
            _defensiveContributionPoints(player, event.value),
      ),
    ];

    final entries = [
      for (final section in eventSections)
        (
          section,
          section.entries(fixture, players, home: true),
          section.entries(fixture, players, home: false),
        ),
    ];
    final hasAnyEvents = entries.any(
      (section) => section.$2.isNotEmpty || section.$3.isNotEmpty,
    );

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('fixture-details-scroll'),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.matchDetails,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DetailsTeam(team: home, fallback: l10n.homeTeam),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _ScoreArea(fixture: fixture, l10n: l10n),
                      const SizedBox(height: 8),
                      _StateBadge(fixture: fixture, l10n: l10n),
                    ],
                  ),
                ),
                Expanded(
                  child: _DetailsTeam(team: away, fallback: l10n.awayTeam),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (prediction != null) ...[
              _FixturePredictionPanel(
                prediction: prediction!,
                home: home,
                away: away,
                teams: teams,
              ),
              const SizedBox(height: 24),
            ],
            for (final section in entries)
              _CategoryEventSection(
                title: section.$1.title,
                icon: section.$1.icon,
                homeEvents: section.$2,
                awayEvents: section.$3,
                l10n: l10n,
              ),
            if (!hasAnyEvents && prediction == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  !fixture.started && !fixture.isFinished
                      ? l10n.predictionWindowHint
                      : l10n.noMatchEvents,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FixturePredictionPanel extends StatelessWidget {
  const _FixturePredictionPanel({
    required this.prediction,
    required this.home,
    required this.away,
    required this.teams,
  });

  final FixturePrediction prediction;
  final FplTeam? home;
  final FplTeam? away;
  final Map<int, FplTeam> teams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final homeName = home?.shortName.isNotEmpty == true
        ? home!.shortName
        : l10n.homeTeam;
    final awayName = away?.shortName.isNotEmpty == true
        ? away!.shortName
        : l10n.awayTeam;

    final homeTeamId = home?.id;
    final awayTeamId = away?.id;

    var homeScorers = prediction.homeScorers.isNotEmpty
        ? prediction.homeScorers
        : (homeTeamId != null
            ? prediction.scorers
                .where((s) => s.player.teamId == homeTeamId)
                .toList()
            : <PlayerEventPrediction>[]);
    var awayScorers = prediction.awayScorers.isNotEmpty
        ? prediction.awayScorers
        : (awayTeamId != null
            ? prediction.scorers
                .where((s) => s.player.teamId == awayTeamId)
                .toList()
            : <PlayerEventPrediction>[]);

    if (homeScorers.isEmpty &&
        awayScorers.isEmpty &&
        prediction.scorers.isNotEmpty) {
      homeScorers = prediction.scorers;
    }

    var homeAssists = prediction.homeAssists.isNotEmpty
        ? prediction.homeAssists
        : (homeTeamId != null
            ? prediction.assists
                .where((a) => a.player.teamId == homeTeamId)
                .toList()
            : <PlayerEventPrediction>[]);
    var awayAssists = prediction.awayAssists.isNotEmpty
        ? prediction.awayAssists
        : (awayTeamId != null
            ? prediction.assists
                .where((a) => a.player.teamId == awayTeamId)
                .toList()
            : <PlayerEventPrediction>[]);

    if (homeAssists.isEmpty &&
        awayAssists.isEmpty &&
        prediction.assists.isNotEmpty) {
      homeAssists = prediction.assists;
    }

    return Column(
      key: const ValueKey('fixture-prediction-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PredictedScoreCard(
          prediction: prediction,
          homeName: homeName,
          awayName: awayName,
          l10n: l10n,
        ),
        const SizedBox(height: 20),
        _PredictionCategorySection(
          title: l10n.likelyScorers,
          icon: Icons.sports_soccer,
          homeCandidates: homeScorers,
          awayCandidates: awayScorers,
          l10n: l10n,
        ),
        _PredictionCategorySection(
          title: l10n.likelyAssists,
          icon: Icons.handshake_outlined,
          homeCandidates: homeAssists,
          awayCandidates: awayAssists,
          l10n: l10n,
        ),
        _PredictionCleanSheetSection(
          title: l10n.cleanSheetChance,
          homeName: homeName,
          awayName: awayName,
          homeChance: prediction.homeCleanSheetChance,
          awayChance: prediction.awayCleanSheetChance,
        ),
        _PredictionDisclaimer(text: l10n.predictionDisclaimer),
      ],
    );
  }
}

class _PredictedScoreCard extends StatelessWidget {
  const _PredictedScoreCard({
    required this.prediction,
    required this.homeName,
    required this.awayName,
    required this.l10n,
  });

  final FixturePrediction prediction;
  final String homeName;
  final String awayName;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.matchPrediction,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.predictionConfidence(prediction.confidence),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.predictedScore,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeName,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${prediction.homeGoals} - ${prediction.awayGoals}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: colors.onPrimaryContainer,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  awayName,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionCategorySection extends StatelessWidget {
  const _PredictionCategorySection({
    required this.title,
    required this.icon,
    required this.homeCandidates,
    required this.awayCandidates,
    required this.l10n,
  });

  final String title;
  final IconData icon;
  final List<PlayerEventPrediction> homeCandidates;
  final List<PlayerEventPrediction> awayCandidates;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (homeCandidates.isEmpty && awayCandidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (homeCandidates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '—',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      for (final candidate in homeCandidates)
                        _PredictionPlayerRow(
                          candidate: candidate,
                          isHome: true,
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (awayCandidates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '—',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      for (final candidate in awayCandidates)
                        _PredictionPlayerRow(
                          candidate: candidate,
                          isHome: false,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionPlayerRow extends StatelessWidget {
  const _PredictionPlayerRow({
    required this.candidate,
    required this.isHome,
  });

  final PlayerEventPrediction candidate;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '${candidate.chance}%',
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final playerText = Expanded(
      child: Text(
        candidate.player.webName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: isHome ? TextAlign.start : TextAlign.end,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isHome
            ? [
                playerText,
                const SizedBox(width: 6),
                badge,
              ]
            : [
                badge,
                const SizedBox(width: 6),
                playerText,
              ],
      ),
    );
  }
}

class _PredictionCleanSheetSection extends StatelessWidget {
  const _PredictionCleanSheetSection({
    required this.title,
    required this.homeName,
    required this.awayName,
    required this.homeChance,
    required this.awayChance,
  });

  final String title;
  final String homeName;
  final String awayName;
  final int homeChance;
  final int awayChance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget buildSide({
      required String name,
      required int chance,
      required bool isHome,
    }) {
      final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          '$chance%',
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );

      final label = Expanded(
        child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isHome ? TextAlign.start : TextAlign.end,
        ),
      );

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isHome
              ? [
                  label,
                  const SizedBox(width: 6),
                  badge,
                ]
              : [
                  badge,
                  const SizedBox(width: 6),
                  label,
                ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildSide(
                  name: homeName,
                  chance: homeChance,
                  isHome: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildSide(
                  name: awayName,
                  chance: awayChance,
                  isHome: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionDisclaimer extends StatelessWidget {
  const _PredictionDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.75),
          fontSize: 11,
          height: 1.35,
        ),
      ),
    );
  }
}

class _DetailsTeam extends StatelessWidget {
  const _DetailsTeam({required this.team, required this.fallback});

  final FplTeam? team;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final name = team?.shortName.isNotEmpty == true
        ? team!.shortName
        : (team?.name ?? fallback);
    return Column(
      children: [
        _TeamBadge(teamCode: team?.code),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

int _goalPoints(FplPlayer? player, int goals) {
  final pointsPerGoal = switch (player?.positionId) {
    1 => 10,
    2 => 6,
    3 => 5,
    4 => 4,
    _ => 0,
  };
  return goals * pointsPerGoal;
}

int _defensiveContributionPoints(FplPlayer? player, int contributions) {
  final threshold = switch (player?.positionId) {
    2 => 10,
    3 || 4 => 12,
    _ => 0,
  };
  return threshold > 0 && contributions >= threshold ? 2 : 0;
}

class _FixtureEventCategory {
  const _FixtureEventCategory({
    required this.identifier,
    required this.title,
    required this.icon,
    required this.pointsFor,
  });

  final String identifier;
  final String title;
  final IconData icon;
  final int Function(FplFixtureStatEntry event, FplPlayer? player) pointsFor;

  List<_FixtureDisplayEvent> entries(
    FplFixture fixture,
    Map<int, FplPlayer> players, {
    required bool home,
  }) {
    return fixture
        .entriesFor(identifier, home: home)
        .map((event) {
          final player = players[event.elementId];
          return _FixtureDisplayEvent(
            elementId: event.elementId,
            value: event.value,
            points: pointsFor(event, player),
            player: player,
          );
        })
        .where((event) => event.points != 0)
        .toList(growable: false);
  }
}

class _FixtureDisplayEvent {
  const _FixtureDisplayEvent({
    required this.elementId,
    required this.value,
    required this.points,
    required this.player,
  });

  final int elementId;
  final int value;
  final int points;
  final FplPlayer? player;
}

class _CategoryEventSection extends StatelessWidget {
  const _CategoryEventSection({
    required this.title,
    required this.icon,
    required this.homeEvents,
    required this.awayEvents,
    required this.l10n,
  });

  final String title;
  final IconData icon;
  final List<_FixtureDisplayEvent> homeEvents;
  final List<_FixtureDisplayEvent> awayEvents;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (homeEvents.isEmpty && awayEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final event in homeEvents)
                      _TeamCategoryRow(event: event, l10n: l10n, isHome: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final event in awayEvents)
                      _TeamCategoryRow(event: event, l10n: l10n, isHome: false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamCategoryRow extends StatelessWidget {
  const _TeamCategoryRow({
    required this.event,
    required this.l10n,
    required this.isHome,
  });

  final _FixtureDisplayEvent event;
  final AppLocalizations l10n;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final impactColor = event.points < 0 ? scheme.error : scheme.primary;
    final pointString = event.points > 0
        ? '+${event.points}'
        : '${event.points}';

    final badge = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: impactColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        pointString,
        style: TextStyle(
          color: impactColor,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final countText = Text(
      '${event.value}x',
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final playerText = Expanded(
      child: Text(
        event.player?.webName ?? l10n.playerName(event.elementId),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: isHome ? TextAlign.start : TextAlign.end,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isHome
            ? [
                playerText,
                const SizedBox(width: 6),
                badge,
                const SizedBox(width: 4),
                countText,
              ]
            : [
                countText,
                const SizedBox(width: 4),
                badge,
                const SizedBox(width: 6),
                playerText,
              ],
      ),
    );
  }
}

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
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
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: 6,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: 140,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (error) {
      FplApiException(:final kind) when kind == FplApiErrorKind.network =>
        l10n.networkError,
      FplApiException(:final kind) when kind == FplApiErrorKind.rateLimited =>
        l10n.rateLimited,
      _ => l10n.genericError,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
