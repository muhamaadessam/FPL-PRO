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
import 'player_directory_page.dart';

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

class _RecommendationsBody extends StatefulWidget {
  const _RecommendationsBody();

  @override
  State<_RecommendationsBody> createState() => _RecommendationsBodyState();
}

class _RecommendationsBodyState extends State<_RecommendationsBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<RecommendationsCubit>().refresh();
    }
  }

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
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(context, state.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: context.read<RecommendationsCubit>().refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
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
    FplApiException(:final kind) when kind == FplApiErrorKind.authentication =>
      l10n.authExpired,
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

class _RecommendationContentState extends State<_RecommendationContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  RecommendationData get data => widget.data;

  TransferSuggestion? _selectedTransfer;
  SuggestedChip? _selectedChip;
  TransferSuggestion? _submittingTransfer;
  SuggestedChip? _submittingChip;

  int _selectedPositionFilter = 0; // 0: All, 1: GKP, 2: DEF, 3: MID, 4: FWD

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showTransferComparison(TransferSuggestion transfer) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, size: 20),
                      ),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  l10n.chipSelection(l10n.chipName(chip.name)),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.chipReason(data.result.chipReason.name),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.bolt_rounded),
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
    final colors = Theme.of(context).colorScheme;
    final result = data.result;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          return Column(
            children: [
              // Top Header Section: Gameweek & Hero Squad Rating
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          l10n.recommendations,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data.gameweek.name,
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data.gameweek.deadlineTime != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.kickoffLabel(data.gameweek.deadlineTime!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Segmented TabBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: colors.onPrimaryContainer,
                    unselectedLabelColor: colors.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.tune_rounded, size: 15),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.tabPlan,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.tabTransfers,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (result.transfers.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${result.transfers.length}',
                                  style: TextStyle(
                                    color: colors.onPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_outline_rounded, size: 15),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.tabTopPicks,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // TabBar Content Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Plan & Decisions
                    _PlanTab(
                      data: data,
                      isNarrow: isNarrow,
                      selectedChip: _selectedChip,
                      submittingChip: _submittingChip,
                      onChipTap: (chip) => _showChipSelection(chip),
                      onTransfer: widget.onTransfer,
                    ),

                    // Tab 2: Suggested Transfers
                    _TransfersTab(
                      data: data,
                      isNarrow: isNarrow,
                      selectedTransfer: _selectedTransfer,
                      submittingTransfer: _submittingTransfer,
                      onTransferTap: _showTransferComparison,
                    ),

                    // Tab 3: Top Picks
                    _TopPicksTab(
                      data: data,
                      selectedPosition: _selectedPositionFilter,
                      onSelectPosition: (pos) {
                        setState(() => _selectedPositionFilter = pos);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: Plan & Decisions
// -----------------------------------------------------------------------------
class _PlanTab extends StatelessWidget {
  const _PlanTab({
    required this.data,
    required this.isNarrow,
    required this.selectedChip,
    required this.submittingChip,
    required this.onChipTap,
    this.onTransfer,
  });

  final RecommendationData data;
  final bool isNarrow;
  final SuggestedChip? selectedChip;
  final SuggestedChip? submittingChip;
  final ValueChanged<SuggestedChip> onChipTap;
  final Future<void> Function(TransferSuggestion transfer)? onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = data.result;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Unified Gameweek Plan & Squad Rating Hero Card
        _WeeklyPlanCard(
          data: data,
          onTransfer: onTransfer,
        ),
        const SizedBox(height: 14),

        // Quick Decisions Grid: Captain + Chip Advice
        if (isNarrow) ...[
          _CaptainCard(result: result, bootstrap: data.bootstrap),
          const SizedBox(height: 10),
          _ChipCard(
            result: result,
            isSelected: selectedChip == result.chip,
            isSubmitting: submittingChip == result.chip,
            onTap: result.chip == SuggestedChip.none
                ? null
                : () => onChipTap(result.chip),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CaptainCard(result: result, bootstrap: data.bootstrap),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChipCard(
                  result: result,
                  isSelected: selectedChip == result.chip,
                  isSubmitting: submittingChip == result.chip,
                  onTap: result.chip == SuggestedChip.none
                      ? null
                      : () => onChipTap(result.chip),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),

        // Disclaimer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            l10n.recommendationDisclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: Transfers
// -----------------------------------------------------------------------------
class _TransfersTab extends StatelessWidget {
  const _TransfersTab({
    required this.data,
    required this.isNarrow,
    required this.selectedTransfer,
    required this.submittingTransfer,
    required this.onTransferTap,
  });

  final RecommendationData data;
  final bool isNarrow;
  final TransferSuggestion? selectedTransfer;
  final TransferSuggestion? submittingTransfer;
  final ValueChanged<TransferSuggestion> onTransferTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final result = data.result;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Budget & Free Transfers Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.freeTransfers,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          result.freeTransfers != null
                              ? '${result.freeTransfers}'
                              : '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.bank,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '£${_price(result.bank)}m',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Hint Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.transferAlternativesHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Suggestions List or Empty State
        if (result.transfers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: colors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.freeTransfers == null ||
                            data.team.transfers.bank == null ||
                            data.team.picks.any((p) => p.sellingPrice == null)
                        ? l10n.transferDataMissing
                        : l10n.noTransferIdeas,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...result.transfers.map(
            (transfer) => _TransferCard(
              transfer: transfer,
              bootstrap: data.bootstrap,
              isSelected:
                  selectedTransfer?.outPlayer.id == transfer.outPlayer.id &&
                  selectedTransfer?.inPlayer.id == transfer.inPlayer.id,
              isSubmitting:
                  submittingTransfer?.outPlayer.id == transfer.outPlayer.id &&
                  submittingTransfer?.inPlayer.id == transfer.inPlayer.id,
              onTap: () => onTransferTap(transfer),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: Top Picks (Scout)
// -----------------------------------------------------------------------------
class _TopPicksTab extends StatelessWidget {
  const _TopPicksTab({
    required this.data,
    required this.selectedPosition,
    required this.onSelectPosition,
  });

  final RecommendationData data;
  final int selectedPosition;
  final ValueChanged<int> onSelectPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final result = data.result;

    final filterOptions = [
      (0, l10n.allPositionsTab),
      (1, l10n.goalkeeper),
      (2, l10n.defender),
      (3, l10n.midfielder),
      (4, l10n.forward),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Player Directory Action Card
        Material(
          key: const ValueKey('player-directory'),
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerDirectoryPage(
                  bootstrap: data.bootstrap,
                  fixtures: data.fixtures,
                  gameweekId: data.result.gameweekId,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.manage_search_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.playerDirectory,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          l10n.playerDirectorySubtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Position Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterOptions.map((opt) {
              final isSelected = selectedPosition == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(opt.$2),
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                  ),
                  selectedColor: colors.primary,
                  backgroundColor: colors.surfaceContainerHigh,
                  checkmarkColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? colors.primary
                          : colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  onSelected: (_) => onSelectPosition(opt.$1),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Position Lists
        if (selectedPosition == 0)
          for (var pos = 1; pos <= 4; pos++) ...[
            _PositionPicks(
              position: pos,
              players: result.topByPosition[pos] ?? const [],
              bootstrap: data.bootstrap,
            ),
            if (pos < 4) const SizedBox(height: 14),
          ]
        else
          _PositionPicks(
            position: selectedPosition,
            players: result.topByPosition[selectedPosition] ?? const [],
            bootstrap: data.bootstrap,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Weekly Plan Card
// -----------------------------------------------------------------------------
class _WeeklyPlanCard extends StatelessWidget {
  const _WeeklyPlanCard({
    required this.data,
    this.onTransfer,
  });

  final RecommendationData data;
  final Future<void> Function(TransferSuggestion transfer)? onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final analysis = data.result.squadAnalysis;
    final lineup = data.result.suggestedLineup;
    final gain =
        lineup.expectedStartingPoints -
        analysis.expectedStartingPoints;
    final hasFullSquad =
        lineup.players.length == 15 && lineup.suggestedStartingIds.length == 11;
    final formation = [
      for (var position = 2; position <= 4; position++)
        lineup.starters
            .where((p) => p.projection.player.positionId == position)
            .length,
    ].join('–');
    final promoted = lineup.starters
        .where(
          (p) => data.team.picks.any(
            (pick) => pick.elementId == p.pick.elementId && pick.position > 11,
          ),
        )
        .toList();
    final benched = lineup.bench
        .where(
          (p) => data.team.picks.any(
            (pick) => pick.elementId == p.pick.elementId && pick.position <= 11,
          ),
        )
        .toList();
    String names(List<PlayerAnalysis> players) =>
        players.map((p) => p.projection.player.webName).join('، ');

    return Card(
      key: const ValueKey('weekly-plan'),
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clickable Header with Rating, Plan title & Points badge
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('next-gameweek-analysis'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NextGameweekAnalysisPage(
                      data: data,
                      onTransfer: onTransfer,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      // Rating Badge (e.g. 94 / 100)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withValues(alpha: 0.22),
                              colors.primary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${analysis.rating}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: colors.primary,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              '/100',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Title, Band, and hint to open analysis
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    hasFullSquad && formation.isNotEmpty
                                        ? '${l10n.weeklyPlan} • $formation'
                                        : l10n.weeklyPlan,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    l10n.ratingBand(analysis.rating),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  l10n.nextGameweekAnalysis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Points badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gain > 0.05
                              ? colors.primary.withValues(alpha: 0.15)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: gain > 0.05
                                ? colors.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${(hasFullSquad ? lineup.expectedStartingPoints : analysis.expectedStartingPoints).toStringAsFixed(1)} ${l10n.ptsCue}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: gain > 0.05 ? colors.primary : colors.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (hasFullSquad) ...[
              if (gain > 0.05) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Directionality.of(context) == TextDirection.rtl
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${l10n.expectedStartingPoints}: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                analysis.expectedStartingPoints.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: colors.primary,
                                ),
                              ),
                              Text(
                                '${lineup.expectedStartingPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${gain.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.lineupGain(gain),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  l10n.lineupAlreadyBest,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
              ],
              if (promoted.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${l10n.startThesePlayers}: ${names(promoted)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 15,
                            color: colors.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${l10n.benchThesePlayers}: ${names(benched)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (lineup.bench.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.benchOrder}: ${names(lineup.bench)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('suggested-lineup-preview'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NextGameweekAnalysisPage(
                        data: data,
                        onTransfer: onTransfer,
                        useSuggestedLineup: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: Text(l10n.suggestedLineup),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('suggested-lineup-preview'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NextGameweekAnalysisPage(
                        data: data,
                        onTransfer: onTransfer,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.insights_rounded, size: 18),
                  label: Text(l10n.nextGameweekAnalysis),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Captain Card
// -----------------------------------------------------------------------------
class _CaptainCard extends StatelessWidget {
  const _CaptainCard({required this.result, required this.bootstrap});

  final RecommendationResult result;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final captain = result.captain;

    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'C',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
          const SizedBox(height: 10),
          if (captain != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        captain.player.webName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        bootstrap.teams[captain.player.teamId]?.shortName ?? '—',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${result.suggestedLineup.players.firstWhere((p) => p.pick.elementId == captain.player.id).expectedPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (result.viceCaptain != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'VC: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        result.viceCaptain!.player.webName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chip Card
// -----------------------------------------------------------------------------
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
    final isNone = result.chip == SuggestedChip.none;

    return Material(
      color: isSelected
          ? colors.primaryContainer
          : colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
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
                  Icon(
                    isNone ? Icons.shield_outlined : Icons.bolt_rounded,
                    size: 16,
                    color: isNone ? colors.onSurfaceVariant : colors.primary,
                  ),
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
                  if (!isNone)
                    Icon(
                      Icons.touch_app_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNone ? l10n.holdChips : l10n.chipName(result.chip.name),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isNone ? colors.onSurface : colors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.chipReason(result.chipReason.name),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                          maxLines: 2,
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

// -----------------------------------------------------------------------------
// Transfer Card
// -----------------------------------------------------------------------------
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: ValueKey(
          'transfer-${transfer.outPlayer.id}-${transfer.inPlayer.id}',
        ),
        color: isSelected
            ? colors.primaryContainer
            : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: isSubmitting ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Out & In Players Info
                Expanded(
                  child: Column(
                    children: [
                      // Out Player
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: colors.error,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transfer.outPlayer.webName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$outTeam • £${_price(transfer.outPlayer.nowCost)}m',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // In Player
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: colors.primary,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transfer.inPlayer.webName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$inTeam • £${_price(transfer.inPlayer.nowCost)}m',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Projected Gain & CTA
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${transfer.netProjectedGain.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        transfer.hitCost > 0 ? l10n.afterHit : l10n.ptsCue,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Comparison Sheet Widgets
// -----------------------------------------------------------------------------
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            projection.player.webName,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${projection.nextPoints.toStringAsFixed(1)} pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
          Expanded(
            child: Text(
              format(outValue),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              format(inValue),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Position Picks
// -----------------------------------------------------------------------------
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
    final colors = Theme.of(context).colorScheme;
    if (players.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.positionName(position).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < players.length; i++) ...[
                _PlayerRow(
                  projection: players[i],
                  bootstrap: bootstrap,
                  rank: i + 1,
                ),
                if (i < players.length - 1)
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.3),
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
  const _PlayerRow({
    required this.projection,
    required this.bootstrap,
    required this.rank,
  });

  final PlayerProjection projection;
  final FplBootstrap bootstrap;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final team = bootstrap.teams[projection.player.teamId]?.shortName ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  projection.player.webName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
          const SizedBox(width: 14),
          SizedBox(
            width: 36,
            child: Text(
              projection.nextPoints.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _price(int? value) =>
    value == null ? '—' : (value / 10).toStringAsFixed(1);
