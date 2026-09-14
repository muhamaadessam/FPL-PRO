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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bootstrapProvider),
      ),
      data: (data) {
        final fixtures = ref.watch(fixturesProvider(data.currentGameweekId));
        return fixtures.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
            index == 0 ? const SizedBox.shrink() : const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.gameweekLabel(gameweekId),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
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
    final home = teams[fixture.homeTeamId]?.name ?? 'Home';
    final away = teams[fixture.awayTeamId]?.name ?? 'Away';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  home,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 64,
                alignment: Alignment.center,
                child: _ScoreArea(fixture: fixture, l10n: l10n),
              ),
              Expanded(
                child: Text(
                  away,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (!fixture.finished) ...[
            const SizedBox(height: 8),
            Text(
              l10n.kickoffLabel(fixture.kickoffTime),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
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
    if (fixture.finished &&
        fixture.homeScore != null &&
        fixture.awayScore != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${fixture.homeScore} - ${fixture.awayScore}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    return Text(
      'v',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
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
