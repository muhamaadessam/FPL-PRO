import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
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
    this.useSuggestedLineup = false,
  });

  final RecommendationData data;
  final Future<void> Function(TransferSuggestion transfer)? onTransfer;
  final bool useSuggestedLineup;

  @override
  State<NextGameweekAnalysisPage> createState() =>
      _NextGameweekAnalysisPageState();
}

class _NextGameweekAnalysisPageState extends State<NextGameweekAnalysisPage>
    with SingleTickerProviderStateMixin {
  late SquadAnalysis analysis;
  late final SquadAnalysis initialAnalysis;
  late final TabController _tabController;

  int _selectedPositionFilter = 0; // 0: All, 1: GKP, 2: DEF, 3: MID, 4: FWD
  String _sortOption = 'forecast'; // 'forecast', 'rating', 'form', 'price'
  final Set<int> _expandedPlayerIds = <int>{};

  @override
  void initState() {
    super.initState();
    analysis = widget.useSuggestedLineup
        ? widget.data.result.suggestedLineup
        : widget.data.result.squadAnalysis;
    initialAnalysis = analysis;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _hasLineupChanged => analysis != initialAnalysis;

  void _resetLineup() {
    setState(() {
      analysis = initialAnalysis;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).resetLineup),
        duration: const Duration(seconds: 2),
      ),
    );
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardElevated(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.comparePlayers} • ${current.projection.player.webName}',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.samePositionAlternatives,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary(isDark),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 12),
                  Expanded(
                    child: projections.isEmpty
                        ? Center(child: Text(l10n.noPlayersFound))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            itemCount: projections.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final projection = projections[index];
                              final player = projection.player;
                              final team =
                                  widget.data.bootstrap.teams[player.teamId];
                              return Material(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(projection),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          child: Text(
                                            team?.shortName ?? 'PL',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.webName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${team?.name ?? l10n.unknown} • £${((player.nowCost ?? 0) / 10).toStringAsFixed(1)}m',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              projection.nextPoints
                                                  .toStringAsFixed(1),
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              l10n.ptsCue,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
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

  void _showMethodologySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MethodologyBottomSheet(
        analysis: analysis,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nextGameweekAlerts = analysis.players
        .where(
          (player) =>
              player.projection.player.isUnavailableNextRound ||
              player.projection.player.isDoubtfulNextRound,
        )
        .map((player) => player.pick)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nextGameweekAnalysis),
        actions: [
          if (_hasLineupChanged)
            IconButton(
              icon: const Icon(Icons.replay_rounded),
              tooltip: l10n.resetLineup,
              onPressed: _resetLineup,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: l10n.ratingMethod,
            onPressed: _showMethodologySheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark
                      ? AppColors.darkActiveTab
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: isDark ? Colors.white : colors.onPrimaryContainer,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sports_soccer_rounded, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.tabPitch,
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
                        const Icon(Icons.format_list_bulleted_rounded,
                            size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${l10n.tabPlayerBreakdown} (${analysis.players.length})',
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
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 1: Lineup & Pitch
          _PitchTab(
            analysis: analysis,
            data: data,
            isSuggestedLineup: widget.useSuggestedLineup,
            nextGameweekAlerts: nextGameweekAlerts,
            onSwap: _onSwapPlayers,
            onCompare: _onComparePlayer,
            onInfoTap: _showMethodologySheet,
            onViewAllPlayers: () => _tabController.animateTo(1),
          ),

          // Tab 2: Player Breakdown & Directory
          _PlayerBreakdownTab(
            analysis: analysis,
            data: data,
            isSuggestedLineup: widget.useSuggestedLineup,
            selectedPosition: _selectedPositionFilter,
            sortOption: _sortOption,
            expandedIds: _expandedPlayerIds,
            onPositionChanged: (pos) =>
                setState(() => _selectedPositionFilter = pos),
            onSortChanged: (sort) => setState(() => _sortOption = sort),
            onToggleExpand: (id) {
              setState(() {
                if (_expandedPlayerIds.contains(id)) {
                  _expandedPlayerIds.remove(id);
                } else {
                  _expandedPlayerIds.add(id);
                }
              });
            },
            onCompare: _onComparePlayer,
            onInfoTap: _showMethodologySheet,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Overview Card (Gameweek, Squad Rating, 3 Core Pillars)
// ---------------------------------------------------------------------------
class _HeroOverviewCard extends StatelessWidget {
  const _HeroOverviewCard({
    required this.analysis,
    required this.gameweekName,
    required this.isSuggestedLineup,
    required this.onInfoTap,
  });

  final SquadAnalysis analysis;
  final String gameweekName;
  final bool isSuggestedLineup;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratingColor = _ratingColor(colors, analysis.rating);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Gameweek Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gameweekName,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSuggestedLineup)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.suggestedLineup,
                    style: TextStyle(
                      color: colors.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              // Squad Rating Pill
              InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ratingColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ratingColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 14, color: ratingColor),
                      const SizedBox(width: 5),
                      Text(
                        '${analysis.rating}/100 • ${l10n.ratingBand(analysis.rating)}',
                        style: TextStyle(
                          color: ratingColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 3 Core Metric Pillars
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.6)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStatColumn(
                    label: l10n.expectedStartingPoints,
                    value: analysis.expectedStartingPoints.toStringAsFixed(1),
                    unit: l10n.ptsCue,
                    valueColor: isDark ? AppColors.plMint : colors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: _HeroStatColumn(
                    label: l10n.expectedBenchPoints,
                    value: analysis.expectedBenchPoints.toStringAsFixed(1),
                    unit: l10n.ptsCue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: _HeroStatColumn(
                    label: l10n.selectionEfficiency,
                    value: '${analysis.selectionEfficiency}%',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatColumn extends StatelessWidget {
  const _HeroStatColumn({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Lineup & Pitch
// ---------------------------------------------------------------------------
class _PitchTab extends StatelessWidget {
  const _PitchTab({
    required this.analysis,
    required this.data,
    required this.isSuggestedLineup,
    required this.nextGameweekAlerts,
    required this.onSwap,
    required this.onCompare,
    required this.onInfoTap,
    required this.onViewAllPlayers,
  });

  final SquadAnalysis analysis;
  final RecommendationData data;
  final bool isSuggestedLineup;
  final List<TeamPick> nextGameweekAlerts;
  final void Function(int draggedElementId, int targetElementId) onSwap;
  final void Function(int playerId) onCompare;
  final VoidCallback onInfoTap;
  final VoidCallback onViewAllPlayers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratingColor = _ratingColor(colors, analysis.rating);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Alerts Button / Banner (Compact, taps to open detailed dialog)
        if (nextGameweekAlerts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: _NextGameweekAlerts(
              key: const ValueKey('next-gameweek-alerts'),
              picks: nextGameweekAlerts,
              bootstrap: data.bootstrap,
            ),
          ),
        ],

        // Gameweek & Squad Rating Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.gameweek.name,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSuggestedLineup)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: colors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.suggestedLineup,
                    style: TextStyle(
                      color: colors.tertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: ratingColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ratingColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 12, color: ratingColor),
                      const SizedBox(width: 4),
                      Text(
                        '${analysis.rating}/100 • ${l10n.ratingBand(analysis.rating)}',
                        style: TextStyle(
                          color: ratingColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dedicated Starting Points & Bench / Bench Boost Forecast Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Starting XI Forecast Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_soccer_rounded,
                            size: 13,
                            color: isDark ? AppColors.plMint : colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.expectedStartingPoints,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${analysis.expectedStartingPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.plMint : colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bench Forecast & Bench Boost Potential Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.airline_seat_recline_normal_rounded,
                            size: 13,
                            color: Color(0xfff59e0b),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.expectedBenchPoints,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${analysis.expectedBenchPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xfff59e0b),
                            ),
                          ),
                          // Bench Boost total pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xfff59e0b)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'BB: ${(analysis.expectedStartingPoints + analysis.expectedBenchPoints).toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xfff59e0b),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Pitch View
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
          onSwap: onSwap,
          onCompare: onCompare,
        ),

        const SizedBox(height: 12),

        // Lineup & Captain Insights Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _LineupInsightsCard(
            analysis: analysis,
            bootstrap: data.bootstrap,
            onViewAllPlayers: onViewAllPlayers,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Next Gameweek Alerts (Compact Button that opens detailed Dialog)
// ---------------------------------------------------------------------------
class _NextGameweekAlerts extends StatelessWidget {
  const _NextGameweekAlerts({
    super.key,
    required this.picks,
    required this.bootstrap,
  });

  final List<TeamPick> picks;
  final FplBootstrap bootstrap;

  void _showAlertsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardElevated(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? AppColors.darkAlertWarningBorder
                  : const Color(0xfff3dfb4),
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xffd97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.nextGameweekAlerts,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff573815)
                      : const Color(0xfffde68a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${picks.length}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkAlertWarningText
                        : const Color(0xffb45309),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nextGameweekAlertsSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...picks.map(
                    (pick) {
                      final player = bootstrap.players[pick.elementId];
                      if (player == null) return const SizedBox.shrink();
                      return _AlertPlayerRow(
                        player: player,
                        team: bootstrap.teams[player.teamId],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? AppColors.darkAlertWarningBg
        : const Color(0xfffffbf2);
    final borderColor = isDark
        ? AppColors.darkAlertWarningBorder
        : const Color(0xfff3dfb4);

    final playerNames = picks
        .take(3)
        .map((p) => bootstrap.players[p.elementId]?.webName ?? '')
        .where((n) => n.isNotEmpty)
        .join('، ');

    return Material(
      key: const ValueKey('next-gameweek-alerts-panel'),
      color: panelColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAlertsDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xffd97706),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l10n.nextGameweekAlerts,
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xff573815)
                                : const Color(0xfffde68a),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${picks.length}',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkAlertWarningText
                                  : const Color(0xffb45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playerNames.isNotEmpty
                          ? '$playerNames • ${l10n.tapToViewDetails}'
                          : l10n.tapToViewDetails,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkAlertWarningText
                            : const Color(0xffb45309),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xffd97706),
                size: 22,
              ),
            ],
          ),
        ),
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
        ? (isDark ? AppColors.darkAlertErrorText : const Color(0xffc2413d))
        : (isDark ? AppColors.darkAlertWarningText : const Color(0xffb45309));
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
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            isUnavailable
                ? Icons.event_busy_rounded
                : Icons.help_outline_rounded,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
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

// ---------------------------------------------------------------------------
// Lineup & Captain Insights Card (Clean, modern post-pitch summary)
// ---------------------------------------------------------------------------
class _LineupInsightsCard extends StatelessWidget {
  const _LineupInsightsCard({
    required this.analysis,
    required this.bootstrap,
    required this.onViewAllPlayers,
  });

  final SquadAnalysis analysis;
  final FplBootstrap bootstrap;
  final VoidCallback onViewAllPlayers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final captain = analysis.players.where((p) => p.pick.isCaptain).firstOrNull;
    final viceCaptain =
        analysis.players.where((p) => p.pick.isViceCaptain).firstOrNull;

    final hasLineupGain =
        analysis.bestLegalLineupPoints > analysis.expectedStartingPoints + 0.1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.lineupInsights,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Captain & Vice Captain Row
          Row(
            children: [
              if (captain != null)
                Expanded(
                  child: _LeaderTile(
                    title: l10n.captain,
                    badge: 'C',
                    name: captain.projection.player.webName,
                    team: bootstrap
                            .teams[captain.projection.player.teamId]?.shortName ??
                        'PL',
                    expectedPoints: captain.expectedPoints * 2,
                    isDoubled: true,
                  ),
                ),
              const SizedBox(width: 10),
              if (viceCaptain != null)
                Expanded(
                  child: _LeaderTile(
                    title: l10n.viceCaptain,
                    badge: 'V',
                    name: viceCaptain.projection.player.webName,
                    team: bootstrap
                            .teams[viceCaptain.projection.player.teamId]
                            ?.shortName ??
                        'PL',
                    expectedPoints: viceCaptain.expectedPoints,
                    isDoubled: false,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Smart Lineup Recommendation Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasLineupGain
                  ? (isDark
                      ? const Color(0xff2a2312)
                      : const Color(0xfffef9c3))
                  : (isDark
                      ? const Color(0xff12281e)
                      : const Color(0xffecfdf5)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLineupGain
                    ? const Color(0xfff59e0b).withValues(alpha: 0.3)
                    : const Color(0xff10b981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasLineupGain
                      ? Icons.tips_and_updates_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: hasLineupGain
                      ? const Color(0xffd97706)
                      : const Color(0xff059669),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasLineupGain
                        ? l10n.lineupGain(
                            analysis.bestLegalLineupPoints -
                                analysis.expectedStartingPoints,
                          )
                        : l10n.lineupAlreadyBest,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasLineupGain
                          ? (isDark ? const Color(0xfffcd34d) : const Color(0xffb45309))
                          : (isDark ? const Color(0xff6ee7b7) : const Color(0xff047857)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Jump to All Players Button
          OutlinedButton.icon(
            onPressed: onViewAllPlayers,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
            label: Text(
              '${l10n.tabPlayerBreakdown} (${analysis.players.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({
    required this.title,
    required this.badge,
    required this.name,
    required this.team,
    required this.expectedPoints,
    required this.isDoubled,
  });

  final String title;
  final String badge;
  final String name;
  final String team;
  final double expectedPoints;
  final bool isDoubled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.5)
            : colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoleBadge(label: badge),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              // Scales down rather than overflowing narrow cards.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${expectedPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDoubled ? colors.primary : null,
                    ),
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

// ---------------------------------------------------------------------------
// Tab 2: Player Breakdown & Directory
// ---------------------------------------------------------------------------
class _PlayerBreakdownTab extends StatelessWidget {
  const _PlayerBreakdownTab({
    required this.analysis,
    required this.data,
    required this.isSuggestedLineup,
    required this.selectedPosition,
    required this.sortOption,
    required this.expandedIds,
    required this.onPositionChanged,
    required this.onSortChanged,
    required this.onToggleExpand,
    required this.onCompare,
    required this.onInfoTap,
  });

  final SquadAnalysis analysis;
  final RecommendationData data;
  final bool isSuggestedLineup;
  final int selectedPosition;
  final String sortOption;
  final Set<int> expandedIds;
  final ValueChanged<int> onPositionChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onToggleExpand;
  final void Function(int playerId) onCompare;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    // Filter
    var filtered = analysis.players.where((p) {
      if (selectedPosition == 0) return true;
      return p.projection.player.positionId == selectedPosition;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      return switch (sortOption) {
        'rating' => b.rating.compareTo(a.rating),
        'form' => b.recentPoints.compareTo(a.recentPoints),
        'price' => (b.projection.player.nowCost ?? 0)
            .compareTo(a.projection.player.nowCost ?? 0),
        _ => b.expectedPoints.compareTo(a.expectedPoints),
      };
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Full Hero Squad Overview Card
        _HeroOverviewCard(
          analysis: analysis,
          gameweekName: data.gameweek.name,
          isSuggestedLineup: isSuggestedLineup,
          onInfoTap: onInfoTap,
        ),
        const SizedBox(height: 12),
        // Position Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PositionFilterChip(
                label: l10n.allPositionsTab,
                count: analysis.players.length,
                isSelected: selectedPosition == 0,
                onSelected: () => onPositionChanged(0),
              ),
              const SizedBox(width: 8),
              _PositionFilterChip(
                label: l10n.goalkeeper,
                count: analysis.players
                    .where((p) => p.projection.player.positionId == 1)
                    .length,
                isSelected: selectedPosition == 1,
                onSelected: () => onPositionChanged(1),
              ),
              const SizedBox(width: 8),
              _PositionFilterChip(
                label: l10n.defender,
                count: analysis.players
                    .where((p) => p.projection.player.positionId == 2)
                    .length,
                isSelected: selectedPosition == 2,
                onSelected: () => onPositionChanged(2),
              ),
              const SizedBox(width: 8),
              _PositionFilterChip(
                label: l10n.midfielder,
                count: analysis.players
                    .where((p) => p.projection.player.positionId == 3)
                    .length,
                isSelected: selectedPosition == 3,
                onSelected: () => onPositionChanged(3),
              ),
              const SizedBox(width: 8),
              _PositionFilterChip(
                label: l10n.forward,
                count: analysis.players
                    .where((p) => p.projection.player.positionId == 4)
                    .length,
                isSelected: selectedPosition == 4,
                onSelected: () => onPositionChanged(4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Sort Selector & Count Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${filtered.length} ${l10n.playerDirectory}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            PopupMenuButton<String>(
              initialValue: sortOption,
              onSelected: onSortChanged,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _sortLabel(l10n, sortOption),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'forecast',
                  child: Text(l10n.sortByForecast),
                ),
                PopupMenuItem(
                  value: 'rating',
                  child: Text(l10n.sortByRating),
                ),
                PopupMenuItem(
                  value: 'form',
                  child: Text(l10n.sortByForm),
                ),
                PopupMenuItem(
                  value: 'price',
                  child: Text(l10n.playerPrice),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Player Cards List
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l10n.noPlayersFound),
            ),
          )
        else
          for (final player in filtered) ...[
            _PlayerAnalysisCard(
              player: player,
              data: data,
              isExpanded: expandedIds.contains(player.projection.player.id),
              onToggleExpand: () =>
                  onToggleExpand(player.projection.player.id),
              onCompare: () => onCompare(player.projection.player.id),
            ),
            const SizedBox(height: 8),
          ],

        const SizedBox(height: 24),

        // Methodology Card
        const _MethodologyPanel(),
        const SizedBox(height: 12),
        Text(
          l10n.analysisCoverage(
            analysis.currentSeasonCoverage,
            analysis.previousSeasonPlayers,
            analysis.players.length,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.analysisDisclaimer,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  String _sortLabel(AppLocalizations l10n, String sort) {
    return switch (sort) {
      'rating' => l10n.sortByRating,
      'form' => l10n.sortByForm,
      'price' => l10n.playerPrice,
      _ => l10n.sortByForecast,
    };
  }
}

class _PositionFilterChip extends StatelessWidget {
  const _PositionFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : colors.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.onPrimary.withValues(alpha: 0.25)
                    : colors.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player Analysis Card (Modern, interactive, with direct compare button)
// ---------------------------------------------------------------------------
class _PlayerAnalysisCard extends StatelessWidget {
  const _PlayerAnalysisCard({
    required this.player,
    required this.data,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onCompare,
  });

  final PlayerAnalysis player;
  final RecommendationData data;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final footballer = player.projection.player;
    final team = data.bootstrap.teams[footballer.teamId]?.shortName ?? '—';
    final ratingColor = _ratingColor(colors, player.rating);

    return Container(
      key: ValueKey('analysis-player-${footballer.id}'),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Main Tappable Header
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Position Avatar
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _positionColor(footballer.positionId).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _positionCode(footballer.positionId),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _positionColor(footballer.positionId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name, Team, and Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                footballer.webName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (player.pick.isCaptain) ...[
                              const SizedBox(width: 5),
                              const _RoleBadge(label: 'C'),
                            ] else if (player.pick.isViceCaptain) ...[
                              const SizedBox(width: 5),
                              const _RoleBadge(label: 'V'),
                            ],
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: player.isStarter
                                    ? (isDark ? const Color(0xff12281e) : const Color(0xffecfdf5))
                                    : (isDark ? const Color(0xff1e1a30) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                player.isStarter ? l10n.starterBadge : l10n.benchBadge,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: player.isStarter
                                      ? (isDark ? const Color(0xff6ee7b7) : const Color(0xff059669))
                                      : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$team • £${((footballer.nowCost ?? 0) / 10).toStringAsFixed(1)}m • ${_fixturesLabel(l10n)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expected Points & Rating Pill
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${player.expectedPoints.toStringAsFixed(1)} ${l10n.ptsCue}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ratingColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.ratingOutOf100(player.rating),
                          style: TextStyle(
                            color: ratingColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details & Compare Action
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
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
                        value: player.previousSeasonPoints?.toStringAsFixed(1) ??
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
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onCompare,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                        label: Text(
                          l10n.comparePlayers,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
}

// ---------------------------------------------------------------------------
// Methodology Bottom Sheet & Card
// ---------------------------------------------------------------------------
class _MethodologyBottomSheet extends StatelessWidget {
  const _MethodologyBottomSheet({
    required this.analysis,
    required this.onClose,
  });

  final SquadAnalysis analysis;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardElevated(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.ratingMethod,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.ratingMethodDescription,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analysisCoverage(
                        analysis.currentSeasonCoverage,
                        analysis.previousSeasonPlayers,
                        analysis.players.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.analysisDisclaimer,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
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
}

class _MethodologyPanel extends StatelessWidget {
  const _MethodologyPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.card(isDark),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.calculate_outlined),
        title: Text(
          l10n.ratingMethod,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Text(
            l10n.ratingMethodDescription,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Component Helpers
// ---------------------------------------------------------------------------
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 9,
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
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

Color _positionColor(int positionId) {
  return switch (positionId) {
    1 => const Color(0xffeab308), // Amber for GKP
    2 => const Color(0xff3b82f6), // Blue for DEF
    3 => const Color(0xff10b981), // Green for MID
    _ => const Color(0xffec4899), // Pink/Magenta for FWD
  };
}

Color _ratingColor(ColorScheme colors, int rating) {
  if (rating >= 75) return colors.primary;
  if (rating >= 60) return colors.tertiary;
  if (rating >= 50) return colors.secondary;
  return colors.error;
}
