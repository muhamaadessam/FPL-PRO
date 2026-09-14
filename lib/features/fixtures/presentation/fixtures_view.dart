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
  });

  final int gameweekId;
  final List<FplFixture> fixtures;
  final Map<int, FplTeam> teams;

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
          return _FixtureCard(fixture: fixtures[index - 1], teams: teams);
        },
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({required this.fixture, required this.teams});

  final FplFixture fixture;
  final Map<int, FplTeam> teams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = teams[fixture.homeTeamId];
    final away = teams[fixture.awayTeamId];

    return Container(
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
                      : (home?.name ?? 'Home'),
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
                      : (away?.name ?? 'Away'),
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
    final showScore = fixture.started || fixture.finished;
    final homeScore = fixture.homeScore;
    final awayScore = fixture.awayScore;

    if (showScore) {
      final scoreText = (homeScore != null && awayScore != null)
          ? '$homeScore - $awayScore'
          : '—';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          scoreText,
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
        l10n.kickoffLabel(fixture.kickoffTime),
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

    if (fixture.finished) {
      label = l10n.fixtureFinished;
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      bgColor = Colors.transparent;
    } else if (fixture.started) {
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
