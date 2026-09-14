import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/fpl_models.dart';
import '../../../core/network/fpl_api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../team/data/team_repository.dart';
import '../domain/recommendation_engine.dart';

class RecommendationData {
  const RecommendationData({
    required this.result,
    required this.gameweek,
    required this.bootstrap,
  });

  final RecommendationResult result;
  final Gameweek gameweek;
  final FplBootstrap bootstrap;
}

final recommendationsProvider = FutureProvider.autoDispose<RecommendationData>((
  ref,
) async {
  final bootstrap = await ref.watch(bootstrapProvider.future);

  final gameweek = bootstrap.gameweeks.cast<Gameweek?>().firstWhere(
    (gw) => gw?.isNext == true,
    orElse: () => bootstrap.gameweeks.cast<Gameweek?>().firstWhere(
      (gw) => gw != null && gw.id > bootstrap.currentGameweekId,
      orElse: () => bootstrap.gameweeks.last,
    ),
  )!;

  final gameweekId = gameweek.id;
  final fixtures = await ref.watch(allFixturesProvider.future);
  final team = await ref.watch(recommendationTeamProvider(gameweekId).future);

  final engine = const RecommendationEngine();
  final result = engine.build(
    bootstrap: bootstrap,
    fixtures: fixtures,
    team: team,
    gameweekId: gameweekId,
  );

  return RecommendationData(
    result: result,
    gameweek: gameweek,
    bootstrap: bootstrap,
  );
});

class RecommendationsView extends ConsumerWidget {
  const RecommendationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(recommendationsProvider);

    return recommendationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final l10n = AppLocalizations.of(context);
        final message = switch (error) {
          FplApiException(:final kind) when kind == FplApiErrorKind.network =>
            l10n.networkError,
          FplApiException(:final kind)
              when kind == FplApiErrorKind.rateLimited =>
            l10n.rateLimited,
          TeamAccessException() => l10n.entryIdInvalid,
          _ => l10n.genericError,
        };
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(recommendationsProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        );
      },
      data: (data) => _RecommendationContent(
        data: data,
        onRefresh: () async {
          final data = ref.read(recommendationsProvider).value;
          ref.invalidate(bootstrapProvider);
          ref.invalidate(allFixturesProvider);
          if (data != null) {
            ref.invalidate(recommendationTeamProvider(data.gameweek.id));
          }
          ref.invalidate(recommendationsProvider);
          await ref.read(recommendationsProvider.future);
        },
      ),
    );
  }
}

class _RecommendationContent extends StatelessWidget {
  const _RecommendationContent({required this.data, required this.onRefresh});

  final RecommendationData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = data.result;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.recommendations,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      data.gameweek.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.recommendationSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (data.gameweek.deadlineTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.kickoffLabel(data.gameweek.deadlineTime!),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 16),
              if (isNarrow) ...[
                _CaptainCard(result: result, bootstrap: data.bootstrap),
                const SizedBox(height: 8),
                _ChipCard(result: result),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CaptainCard(
                        result: result,
                        bootstrap: data.bootstrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _ChipCard(result: result)),
                  ],
                ),
              const SizedBox(height: 24),
              if (isNarrow) ...[
                Text(
                  l10n.transferIdeas,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${l10n.freeTransfers}: ${result.freeTransfers ?? '—'} • ${l10n.bank}: £${_price(result.bank)}m',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.transferIdeas,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${l10n.freeTransfers}: ${result.freeTransfers ?? '—'} • ${l10n.bank}: £${_price(result.bank)}m',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (result.transfers.isEmpty)
                Text(l10n.noTransferIdeas)
              else
                ...result.transfers.map(
                  (transfer) => _TransferCard(
                    transfer: transfer,
                    bootstrap: data.bootstrap,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                l10n.topPicks,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (var position = 1; position <= 4; position++) ...[
                _PositionPicks(
                  position: position,
                  players: result.topByPosition[position] ?? const [],
                  bootstrap: data.bootstrap,
                ),
                if (position < 4) const SizedBox(height: 12),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.recommendationDisclaimer,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaptainCard extends StatelessWidget {
  const _CaptainCard({required this.result, required this.bootstrap});

  final RecommendationResult result;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final captain = result.captain;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l10n.captainPick,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (captain != null) ...[
            Text(
              captain.player.webName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Text(
              '${captain.nextPoints.toStringAsFixed(1)} pts',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipCard extends StatelessWidget {
  const _ChipCard({required this.result});

  final RecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l10n.chipAdvice,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chipName(result.chip.name),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          Text(
            l10n.chipReason(result.chipReason.name),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, required this.bootstrap});

  final TransferSuggestion transfer;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outTeam =
        bootstrap.teams[transfer.outPlayer.teamId]?.shortName ?? '—';
    final inTeam = bootstrap.teams[transfer.inPlayer.teamId]?.shortName ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_downward,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        transfer.outPlayer.webName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    '$outTeam • £${_price(transfer.outPlayer.nowCost)}m',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        transfer.inPlayer.webName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    '$inTeam • £${_price(transfer.inPlayer.nowCost)}m',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${transfer.netProjectedGain.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                transfer.hitCost > 0 ? l10n.afterHit : l10n.projectedGain,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionPicks extends StatelessWidget {
  const _PositionPicks({
    required this.position,
    required this.players,
    required this.bootstrap,
  });

  final int position;
  final List<PlayerProjection> players;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (players.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.positionName(position).toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < players.length; i++) ...[
                _PlayerRow(projection: players[i], bootstrap: bootstrap),
                if (i < players.length - 1)
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.projection, required this.bootstrap});

  final PlayerProjection projection;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final team = bootstrap.teams[projection.player.teamId]?.shortName ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  projection.player.webName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(team, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '£${_price(projection.player.nowCost)}m',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              projection.nextPoints.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _price(int? value) => ((value ?? 0) / 10).toStringAsFixed(1);
