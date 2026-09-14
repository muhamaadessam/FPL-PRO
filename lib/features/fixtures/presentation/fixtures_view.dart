import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/fpl_models.dart';
import '../../../core/network/fpl_api_client.dart';
import '../../../l10n/app_localizations.dart';

class FixturesView extends ConsumerWidget {
  const FixturesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    return bootstrap.when(
      loading: () => const _ShimmerSkeleton(),
      error: (error, _) => _ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bootstrapProvider),
      ),
      data: (data) {
        final fixtures = ref.watch(fixturesProvider(data.currentGameweekId));
        return fixtures.when(
          loading: () => const _ShimmerSkeleton(),
          error: (error, _) => _ErrorState(
            error: error,
            onRetry: () =>
                ref.invalidate(fixturesProvider(data.currentGameweekId)),
          ),
          data: (items) => _FixtureList(
            gameweekId: data.currentGameweekId,
            fixtures: items,
            teams: data.teams,
            players: data.players,
          ),
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
        final container = ProviderScope.containerOf(context, listen: false);
        container.invalidate(fixturesProvider(gameweekId));
        await container.read(fixturesProvider(gameweekId).future);
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
      builder: (_) => _FixtureDetailsSheet(
        fixture: fixture,
        teams: teams,
        players: players,
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
  });

  final FplFixture fixture;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = teams[fixture.homeTeamId];
    final away = teams[fixture.awayTeamId];
    final hasAnyEvents = ['goals_scored', 'assists', 'bonus'].any(
      (stat) =>
          fixture.entriesFor(stat, home: true).isNotEmpty ||
          fixture.entriesFor(stat, home: false).isNotEmpty,
    );

    return SafeArea(
      child: SingleChildScrollView(
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _DetailsTeam(team: home, fallback: l10n.homeTeam),
                            const SizedBox(height: 24),
                            _TeamEventsList(
                              isHome: true,
                              fixture: fixture,
                              players: players,
                              l10n: l10n,
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
                            _DetailsTeam(team: away, fallback: l10n.awayTeam),
                            const SizedBox(height: 24),
                            _TeamEventsList(
                              isHome: false,
                              fixture: fixture,
                              players: players,
                              l10n: l10n,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _ScoreArea(fixture: fixture, l10n: l10n),
                    const SizedBox(height: 8),
                    _StateBadge(fixture: fixture, l10n: l10n),
                    const SizedBox(height: 24),
                    _DetailsTeam(team: home, fallback: l10n.homeTeam),
                    const SizedBox(height: 16),
                    _TeamEventsList(
                      isHome: true,
                      fixture: fixture,
                      players: players,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 24),
                    _DetailsTeam(team: away, fallback: l10n.awayTeam),
                    const SizedBox(height: 16),
                    _TeamEventsList(
                      isHome: false,
                      fixture: fixture,
                      players: players,
                      l10n: l10n,
                    ),
                  ],
                );
              },
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

class _TeamEventsList extends StatelessWidget {
  const _TeamEventsList({
    required this.isHome,
    required this.fixture,
    required this.players,
    required this.l10n,
  });

  final bool isHome;
  final FplFixture fixture;
  final Map<int, FplPlayer> players;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        l10n.goals,
        Icons.sports_soccer,
        fixture.entriesFor('goals_scored', home: isHome),
        false,
      ),
      (
        l10n.assists,
        Icons.handshake_outlined,
        fixture.entriesFor('assists', home: isHome),
        false,
      ),
      (
        l10n.bonusPoints,
        Icons.military_tech_outlined,
        fixture.entriesFor('bonus', home: isHome),
        true,
      ),
    ];

    final activeSections = sections.where((s) => s.$3.isNotEmpty).toList();
    if (activeSections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in activeSections)
          _TeamEventSection(
            title: section.$1,
            icon: section.$2,
            events: section.$3,
            players: players,
            l10n: l10n,
            isBonus: section.$4,
          ),
      ],
    );
  }
}

class _TeamEventSection extends StatelessWidget {
  const _TeamEventSection({
    required this.title,
    required this.icon,
    required this.events,
    required this.players,
    required this.l10n,
    required this.isBonus,
  });

  final String title;
  final IconData icon;
  final List<FplFixtureStatEntry> events;
  final Map<int, FplPlayer> players;
  final AppLocalizations l10n;
  final bool isBonus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          for (var index = 0; index < events.length; index++) ...[
            _TeamEventRow(
              event: events[index],
              player: players[events[index].elementId],
              l10n: l10n,
              isBonus: isBonus,
            ),
            if (index != events.length - 1)
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _TeamEventRow extends StatelessWidget {
  const _TeamEventRow({
    required this.event,
    required this.player,
    required this.l10n,
    required this.isBonus,
  });

  final FplFixtureStatEntry event;
  final FplPlayer? player;
  final AppLocalizations l10n;
  final bool isBonus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player?.webName ?? l10n.playerName(event.elementId),
              style: const TextStyle(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isBonus ? '+${event.value}' : '×${event.value}',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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
