import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/fpl_api_client.dart';
import '../../data/models/fpl_models.dart';
import '../../domain/repositories/fixtures_repository.dart';
import '../cubit/fixtures_cubit.dart';

class FixturesView extends StatelessWidget {
  const FixturesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FixturesCubit(context.read<FixturesRepository>())..load(),
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
          fixtures: state.fixtures,
          teams: bootstrap.teams,
          players: bootstrap.players,
        );
      },
    );
  }
}

class _FixtureList extends StatelessWidget {
  const _FixtureList({
    required this.gameweekId,
    required this.fixtures,
    required this.teams,
    required this.players,
  });

  final int gameweekId;
  final List<FplFixture> fixtures;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (fixtures.isEmpty) {
      return Center(child: Text(l10n.noFixtures));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<FixturesCubit>().refresh();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: fixtures.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    l10n.gameweekLabel(gameweekId),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.matchesCount(fixtures.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return _FixtureCard(
            fixture: fixtures[index - 1],
            teams: teams,
            players: players,
          );
        },
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({
    required this.fixture,
    required this.teams,
    required this.players,
  });

  final FplFixture fixture;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = teams[fixture.homeTeamId];
    final away = teams[fixture.awayTeamId];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('fixture-card-${fixture.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFixtureDetails(context),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _TeamBadge(teamCode: home?.code),
                    const SizedBox(height: 8),
                    Text(
                      home?.shortName.isNotEmpty == true
                          ? home!.shortName
                          : (home?.name ?? l10n.homeTeam),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
                child: Column(
                  children: [
                    _TeamBadge(teamCode: away?.code),
                    const SizedBox(height: 8),
                    Text(
                      away?.shortName.isNotEmpty == true
                          ? away!.shortName
                          : (away?.name ?? l10n.awayTeam),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.teamCode});

  final int? teamCode;

  @override
  Widget build(BuildContext context) {
    if (teamCode == null) return const _FallbackShield();
    return Image.network(
      'https://resources.premierleague.com/premierleague/badges/70/t$teamCode.png',
      width: 48,
      height: 48,
      errorBuilder: (context, error, stackTrace) => const _FallbackShield(),
    );
  }
}

class _FallbackShield extends StatelessWidget {
  const _FallbackShield();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}

class _ScoreArea extends StatelessWidget {
  const _ScoreArea({required this.fixture, required this.l10n});

  final FplFixture fixture;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final homeScore = fixture.homeScore;
    final awayScore = fixture.awayScore;
    final showScore = homeScore != null && awayScore != null;

    if (showScore) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$homeScore - $awayScore',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        fixture.isLive || fixture.isFinished
            ? '—'
            : l10n.kickoffLabel(fixture.kickoffTime),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
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
    required this.scrollController,
  });

  final FplFixture fixture;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;
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
            for (final section in entries)
              _CategoryEventSection(
                title: section.$1.title,
                icon: section.$1.icon,
                homeEvents: section.$2,
                awayEvents: section.$3,
                l10n: l10n,
              ),
            if (!hasAnyEvents)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.noMatchEvents,
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
