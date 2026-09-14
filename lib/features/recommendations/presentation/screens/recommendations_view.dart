import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../../team/data/repositories/team_repository.dart';
import '../../../team/domain/repositories/team_repository.dart';
import '../../domain/entities/recommendation_data.dart';
import '../../domain/usecases/recommendation_engine.dart';
import '../cubit/recommendations_cubit.dart';
import 'next_gameweek_analysis_page.dart';

export '../../domain/entities/recommendation_data.dart';

class RecommendationsView extends StatelessWidget {
  const RecommendationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecommendationsCubit(
        fixturesRepository: context.read<FixturesRepository>(),
        teamRepository: context.read<TeamRepository>(),
        authCubit: context.read<AuthCubit>(),
      )..load(),
      child: const _RecommendationsBody(),
    );
  }
}

class _RecommendationsBody extends StatelessWidget {
  const _RecommendationsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecommendationsCubit, RecommendationsState>(
      builder: (context, state) {
        if (state.status == RecommendationsStatus.initial ||
            state.status == RecommendationsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == RecommendationsStatus.failure) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(context, state.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: context.read<RecommendationsCubit>().refresh,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        return _RecommendationContent(
          data: state.data!,
          onRefresh: context.read<RecommendationsCubit>().refresh,
          onTransfer: context.read<RecommendationsCubit>().makeTransfer,
          onChip: context.read<RecommendationsCubit>().saveChip,
        );
      },
    );
  }
}

String _errorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  return switch (error) {
    FplApiException(:final kind) when kind == FplApiErrorKind.network =>
      l10n.networkError,
    FplApiException(:final kind) when kind == FplApiErrorKind.rateLimited =>
      l10n.rateLimited,
    TeamAccessException() => l10n.entryIdInvalid,
    _ => l10n.genericError,
  };
}

class _RecommendationContent extends StatefulWidget {
  const _RecommendationContent({
    required this.data,
    required this.onRefresh,
    required this.onTransfer,
    required this.onChip,
  });

  final RecommendationData data;
  final Future<void> Function() onRefresh;
  final Future<void> Function(TransferSuggestion transfer) onTransfer;
  final Future<void> Function(SuggestedChip chip) onChip;

  @override
  State<_RecommendationContent> createState() => _RecommendationContentState();
}

class _RecommendationContentState extends State<_RecommendationContent> {
  RecommendationData get data => widget.data;
  TransferSuggestion? _selectedTransfer;
  SuggestedChip? _selectedChip;
  TransferSuggestion? _submittingTransfer;
  SuggestedChip? _submittingChip;

  Future<void> _showTransferComparison(TransferSuggestion transfer) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.compareTransfer,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ComparisonPlayer(
                        label: l10n.transferOut,
                        projection: transfer.outProjection,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.swap_horiz),
                    ),
                    Expanded(
                      child: _ComparisonPlayer(
                        label: l10n.transferIn,
                        projection: transfer.inProjection,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ComparisonMetric(
                  label: l10n.projectedPoints,
                  outValue: transfer.outProjection.horizonPoints,
                  inValue: transfer.inProjection.horizonPoints,
                ),
                _ComparisonMetric(
                  label: l10n.nextFixtures,
                  outValue: transfer.outProjection.nextFixtureCount.toDouble(),
                  inValue: transfer.inProjection.nextFixtureCount.toDouble(),
                  decimals: 0,
                ),
                _ComparisonMetric(
                  label: l10n.availability,
                  outValue: transfer.outProjection.availability * 100,
                  inValue: transfer.inProjection.availability * 100,
                  suffix: '%',
                  decimals: 0,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    // Temporarily disabled; keep the transfer callback for later.
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.confirmTransfer),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != true || !mounted) return;
    setState(() => _submittingTransfer = transfer);
    try {
      await widget.onTransfer(transfer);
      if (!mounted) return;
      setState(() {
        _selectedTransfer = transfer;
        _submittingTransfer = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transferSubmitted)));
    } on Object {
      if (!mounted) return;
      setState(() => _submittingTransfer = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  Future<void> _showChipSelection(SuggestedChip chip) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chipSelection(l10n.chipName(chip.name)),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(l10n.chipReason(data.result.chipReason.name)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.bolt),
                    label: Text(l10n.confirmChip),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != true || !mounted) return;
    setState(() => _submittingChip = chip);
    try {
      await widget.onChip(chip);
      if (!mounted) return;
      setState(() {
        _selectedChip = chip;
        _submittingChip = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.chipSubmitted)));
    } on Object {
      if (!mounted) return;
      setState(() => _submittingChip = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = data.result;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
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
              _AnalysisEntryCard(
                analysis: result.squadAnalysis,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NextGameweekAnalysisPage(data: data),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isNarrow) ...[
                _CaptainCard(result: result, bootstrap: data.bootstrap),
                const SizedBox(height: 8),
                _ChipCard(
                  result: result,
                  isSelected: _selectedChip == result.chip,
                  isSubmitting: _submittingChip == result.chip,
                  onTap: result.chip == SuggestedChip.none
                      ? null
                      : () => _showChipSelection(result.chip),
                ),
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
                    Expanded(
                      child: _ChipCard(
                        result: result,
                        isSelected: _selectedChip == result.chip,
                        isSubmitting: _submittingChip == result.chip,
                        onTap: result.chip == SuggestedChip.none
                            ? null
                            : () => _showChipSelection(result.chip),
                      ),
                    ),
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
                    isSelected:
                        _selectedTransfer?.outPlayer.id ==
                            transfer.outPlayer.id &&
                        _selectedTransfer?.inPlayer.id == transfer.inPlayer.id,
                    isSubmitting:
                        _submittingTransfer?.outPlayer.id ==
                            transfer.outPlayer.id &&
                        _submittingTransfer?.inPlayer.id ==
                            transfer.inPlayer.id,
                    onTap: () => _showTransferComparison(transfer),
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

class _AnalysisEntryCard extends StatelessWidget {
  const _AnalysisEntryCard({required this.analysis, required this.onTap});

  final SquadAnalysis analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('next-gameweek-analysis'),
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_outlined, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nextGameweekAnalysis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.nextGameweekAnalysisSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.ratingOutOf100(analysis.rating),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${analysis.expectedStartingPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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
  const _ChipCard({
    required this.result,
    required this.isSelected,
    required this.isSubmitting,
    required this.onTap,
  });

  final RecommendationResult result;
  final bool isSelected;
  final bool isSubmitting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isSubmitting ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.chipName(result.chip.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          l10n.chipReason(result.chipReason.name),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSubmitting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isSelected)
                    Text(
                      l10n.selected,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.bootstrap,
    required this.isSelected,
    required this.isSubmitting,
    required this.onTap,
  });

  final TransferSuggestion transfer;
  final FplBootstrap bootstrap;
  final bool isSelected;
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final outTeam =
        bootstrap.teams[transfer.outPlayer.teamId]?.shortName ?? '—';
    final inTeam = bootstrap.teams[transfer.inPlayer.teamId]?.shortName ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey(
          'transfer-${transfer.outPlayer.id}-${transfer.inPlayer.id}',
        ),
        color: isSelected
            ? colors.primaryContainer
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isSubmitting ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: colors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              transfer.outPlayer.webName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
                            color: colors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              transfer.inPlayer.webName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
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
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${transfer.netProjectedGain.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: colors.primary,
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
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    if (isSubmitting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (isSelected)
                      Text(
                        l10n.selected,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      )
                    else
                      Icon(Icons.trending_up, size: 20, color: colors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonPlayer extends StatelessWidget {
  const _ComparisonPlayer({
    required this.label,
    required this.projection,
    required this.color,
  });

  final String label;
  final PlayerProjection projection;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            projection.player.webName,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${projection.nextPoints.toStringAsFixed(1)} pts',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.outValue,
    required this.inValue,
    this.suffix = '',
    this.decimals = 1,
  });

  final String label;
  final double outValue;
  final double inValue;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    String format(double value) => '${value.toStringAsFixed(decimals)}$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(format(outValue))),
          Expanded(flex: 2, child: Text(label, textAlign: TextAlign.center)),
          Expanded(child: Text(format(inValue), textAlign: TextAlign.end)),
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
