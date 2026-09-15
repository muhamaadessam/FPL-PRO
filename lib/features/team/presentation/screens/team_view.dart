import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/models/team_models.dart';
import '../../domain/repositories/team_repository.dart';
import '../cubit/team_cubit.dart';
import '../../../dashboard/presentation/cubit/home_preload_cubit.dart';
import '../widgets/pitch_view.dart';

class TeamView extends StatelessWidget {
  const TeamView({super.key, this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final authCubit = entryId == null ? context.read<AuthCubit>() : null;
    return BlocProvider(
      create: (context) {
        HomePreloadState? preload;
        try {
          preload = context.read<HomePreloadCubit>().state;
        } on ProviderNotFoundException catch (_) {}
        final hasPreload =
            preload?.status == PreloadStatus.success && entryId == null;
        final cubit = TeamCubit(
          fixturesRepository: context.read<FixturesRepository>(),
          teamRepository: context.read<TeamRepository>(),
          authCubit: authCubit,
          entryId: entryId,
          initialState: hasPreload
              ? TeamState(
                  status: TeamStatus.success,
                  bootstrap: preload?.bootstrap,
                  team: preload?.teamCurrent,
                  entry: preload?.entry,
                  gameweekPoints: preload?.gameweekPoints ?? const {},
                  historyPoints: preload?.historyPoints ?? const {},
                  selectedGameweekId: preload?.bootstrap?.currentGameweekId,
                )
              : null,
        );
        if (!hasPreload) cubit.load();
        return cubit;
      },
      child: _TeamBody(entryId: entryId),
    );
  }
}

class _TeamBody extends StatelessWidget {
  const _TeamBody({required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final auth = entryId == null
        ? context.watch<AuthCubit>().state
        : const AuthUnauthenticated();
    if (entryId == null && !auth.isLoading && auth.session == null) {
      return _TeamMessage(
        icon: Icons.lock_outline,
        message: AppLocalizations.of(context).authContractRequired,
      );
    }
    if (entryId == null && !auth.isLoading && auth.session?.entryId == null) {
      return _TeamMessage(
        icon: Icons.error_outline,
        message: AppLocalizations.of(context).entryIdMissing,
      );
    }

    return BlocBuilder<TeamCubit, TeamState>(
      builder: (context, state) {
        if (state.status == TeamStatus.initial ||
            state.status == TeamStatus.loading) {
          return const _TeamSkeleton();
        }
        if (state.status == TeamStatus.failure) {
          return _TeamMessage(
            icon: Icons.error_outline,
            message: _errorMessage(context, state.error!),
            onRetry: context.read<TeamCubit>().refresh,
          );
        }

        return _TeamContent(
          team: state.team!,
          bootstrap: state.bootstrap!,
          gameweekPoints: state.gameweekPoints,
          selectedGameweekId: state.selectedGameweekId!,
          historyPoints: state.historyPoints,
          entryId: entryId,
          entry: state.entry,
          onGameweekChanged: (gameweekId) {
            if (gameweekId != null) {
              context.read<TeamCubit>().selectGameweek(gameweekId);
            }
          },
          onRefresh: context.read<TeamCubit>().refresh,
        );
      },
    );
  }
}

String _errorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is FplApiException) {
    if (error.kind == FplApiErrorKind.network) return l10n.networkError;
    if (error.kind == FplApiErrorKind.rateLimited) return l10n.rateLimited;
    if (error.kind == FplApiErrorKind.authentication) return l10n.authExpired;
  } else if (error is TeamAccessException) {
    if (error.error == TeamAccessError.entryIdMissing) {
      return l10n.entryIdMissing;
    }
  }
  return l10n.genericError;
}

class _TeamContent extends StatefulWidget {
  const _TeamContent({
    required this.team,
    required this.bootstrap,
    required this.gameweekPoints,
    required this.selectedGameweekId,
    required this.historyPoints,
    required this.onGameweekChanged,
    required this.onRefresh,
    this.entryId,
    this.entry,
  });

  final MyTeam team;
  final FplBootstrap bootstrap;
  final Map<int, int> gameweekPoints;
  final int selectedGameweekId;
  final Map<int, int> historyPoints;
  final ValueChanged<int?> onGameweekChanged;
  final Future<void> Function() onRefresh;
  final int? entryId;
  final FplEntry? entry;

  @override
  State<_TeamContent> createState() => _TeamContentState();
}

class _TeamContentState extends State<_TeamContent> {
  bool _isPitchView = true;
  PlayerCardMetric _selectedMetric = PlayerCardMetric.points;

  @override
  Widget build(BuildContext context) {
    final starting = widget.team.picks.where((p) => p.position <= 11).toList();
    final bench = widget.team.picks.where((p) => p.position > 11).toList();
    final gameweek = widget.bootstrap.gameweeks.firstWhere(
      (gw) => gw.id == widget.selectedGameweekId,
      orElse: () => widget.bootstrap.gameweeks.first,
    );
    final liveTeamPoints = gameweek.isCurrent
        ? _liveTeamPoints(widget.team.picks, widget.gameweekPoints)
        : null;
    final displayedPoints =
        liveTeamPoints ??
        widget.historyPoints[widget.selectedGameweekId] ??
        (widget.team.summary.gameweekId == widget.selectedGameweekId
            ? widget.team.summary.points
            : null);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          // 1. Top Header: Dynamic Team name & Manager name, Avatar
          Builder(
            builder: (context) {
              final teamName = widget.entry?.name.isNotEmpty == true
                  ? widget.entry!.name
                  : (widget.entryId != null
                      ? 'Entry #${widget.entryId}'
                      : 'My Team');
              final managerName = widget.entry?.playerFullName ?? '';
              final hasDistinctManager = managerName.isNotEmpty &&
                  managerName.trim().toLowerCase() !=
                      teamName.trim().toLowerCase();
              final subtitle = hasDistinctManager ? managerName : null;

              return _TeamHeader(
                title: teamName,
                subtitle: subtitle,
                showBackButton: widget.entryId != null,
              );
            },
          ),
          const SizedBox(height: 10),

          // 2. Gameweek Switcher: < Gameweek 4 > (capped at current gameweek)
          _GameweekSelector(
            selectedGameweekId: widget.selectedGameweekId,
            bootstrap: widget.bootstrap,
            onGameweekChanged: widget.onGameweekChanged,
          ),
          const SizedBox(height: 16),

          // 3. Stats Row: Average | Total Pts (Highlighted Card) | Highest (tappable)
          _StatsSummaryCards(
            averageScore: gameweek.averageEntryScore?.toString() ?? '—',
            totalPoints: displayedPoints?.toString() ?? '—',
            highestScore: gameweek.highestScore?.toString() ?? '—',
            gameweek: gameweek,
          ),
          const SizedBox(height: 18),

          // 4. Sub-Navigation Bar: Segmented [Pitch | List] & Metric Selector Dropdown
          _SubNavigationRow(
            isPitchView: _isPitchView,
            selectedMetric: _selectedMetric,
            onTogglePitch: (isPitch) => setState(() => _isPitchView = isPitch),
            onMetricChanged: (metric) => setState(() => _selectedMetric = metric),
          ),
          const SizedBox(height: 14),

          // 5. Main Content: Perspective Pitch or List View
          if (_isPitchView)
            PitchView(
              starting: starting,
              bench: bench,
              bootstrap: widget.bootstrap,
              gameweekPoints: widget.gameweekPoints,
              metric: _selectedMetric,
            )
          else
            _TeamListView(
              starting: starting,
              bench: bench,
              bootstrap: widget.bootstrap,
              gameweekPoints: widget.gameweekPoints,
            ),
        ],
      ),
    );
  }

  int? _liveTeamPoints(List<TeamPick> picks, Map<int, int> gameweekPoints) {
    if (gameweekPoints.isEmpty) return null;
    final starting = picks.where((pick) => pick.position <= 11);
    if (starting.isEmpty) return null;
    return starting.fold<int>(
      0,
      (total, pick) =>
          total +
          (gameweekPoints[pick.elementId] ?? 0) *
              (pick.multiplier > 0 ? pick.multiplier : 1),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.title,
    this.subtitle,
    this.showBackButton = false,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xff1f1f2e);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back button or symmetric spacing placeholder
          if (showBackButton)
            GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).maybePop();
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff1f152d)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: isDark
                      ? Border.all(color: const Color(0xff2d1f40))
                      : null,
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: titleColor,
                ),
              ),
            )
          else
            const SizedBox(width: 38),
          // Dynamic Team Name & Manager Subtitle
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!.trim(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xffa199b8)
                            : const Color(0xff716b84),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Official FPL Multi-gradient Avatar
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xff00ff87),
                  Color(0xff02efff),
                  Color(0xff963cff),
                  Color(0xffff005a),
                  Color(0xff00ff87),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xff12091c) : Colors.white,
                ),
                child: Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: isDark ? const Color(0xff55d49c) : const Color(0xff37003c),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameweekSelector extends StatelessWidget {
  const _GameweekSelector({
    required this.selectedGameweekId,
    required this.bootstrap,
    required this.onGameweekChanged,
  });

  final int selectedGameweekId;
  final FplBootstrap bootstrap;
  final ValueChanged<int?> onGameweekChanged;

  @override
  Widget build(BuildContext context) {
    final currentIndex = bootstrap.gameweeks.indexWhere(
      (g) => g.id == selectedGameweekId,
    );
    final canGoPrev = currentIndex > 0;

    // Limit next gameweek navigation to the active current gameweek in production
    // (Future gameweeks like GW5 should not open before the deadline)
    final currentGw = bootstrap.gameweeks.firstWhere(
      (g) => g.isCurrent,
      orElse: () => bootstrap.gameweeks.first,
    );
    final isFullSeason = bootstrap.gameweeks.length > 2;
    final maxAllowedId = isFullSeason ? currentGw.id : bootstrap.gameweeks.last.id;
    final canGoNext = selectedGameweekId < maxAllowedId &&
        currentIndex >= 0 &&
        currentIndex < bootstrap.gameweeks.length - 1;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final disabledColor = isDark ? Colors.white24 : Colors.black26;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('team-gameweek-prev'),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: canGoPrev ? textColor : disabledColor,
            onPressed: canGoPrev
                ? () =>
                    onGameweekChanged(bootstrap.gameweeks[currentIndex - 1].id)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Gameweek $selectedGameweekId',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('team-gameweek-next'),
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: canGoNext ? textColor : disabledColor,
            onPressed: canGoNext
                ? () =>
                    onGameweekChanged(bootstrap.gameweeks[currentIndex + 1].id)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryCards extends StatelessWidget {
  const _StatsSummaryCards({
    required this.averageScore,
    required this.totalPoints,
    required this.highestScore,
    required this.gameweek,
  });

  final String averageScore;
  final String totalPoints;
  final String highestScore;
  final Gameweek gameweek;

  void _openHighestTeam(BuildContext context) {
    if (gameweek.highestScoringEntry != null && gameweek.highestScoringEntry! > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamLookupPage(entryId: gameweek.highestScoringEntry),
        ),
      );
    } else {
      _showHighestPlanDetails(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final averageLabel = isArabic ? l10n.averageScore : 'Average';
    final highestLabel = isArabic ? l10n.highestScore : 'Highest';
    final pointsLabel = isArabic ? l10n.points : 'Total Pts';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final secondaryTextColor = isDark ? const Color(0xffa19bb0) : const Color(0xff6b7280);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Average
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    averageScore,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      averageLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Total Pts (Highlighted Card)
            Container(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff00d4ff), Color(0xff0088ff)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff00d4ff).withValues(alpha: isDark ? 0.45 : 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalPoints,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff002554),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      pointsLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff002554),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Highest (Tappable to view plan/details)
            Expanded(
              child: InkWell(
                onTap: () => _openHighestTeam(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        highestScore,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              highestLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth < 320 ? 320 : constraints.maxWidth,
            child: content,
          ),
        );
      },
    );
  }

  void _showHighestPlanDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xff1f152d) : Colors.white;
    final handleColor = isDark ? const Color(0xff36264d) : Colors.grey[300]!;
    final titleColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final subColor = isDark ? const Color(0xffa19bb0) : Colors.grey[600]!;
    final scoreColor = isDark ? const Color(0xff55d49c) : const Color(0xff37003c);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(
              Icons.emoji_events_rounded,
              size: 40,
              color: Color(0xffffb800),
            ),
            const SizedBox(height: 10),
            Text(
              'Gameweek ${gameweek.id} Highest Score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${gameweek.highestScore ?? '—'} Points',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: scoreColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Average gameweek score: ${gameweek.averageEntryScore ?? '—'} pts',
              style: TextStyle(
                fontSize: 13,
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (gameweek.highestScoringEntry != null &&
                gameweek.highestScoringEntry! > 0) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamLookupPage(
                          entryId: gameweek.highestScoringEntry,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text(
                    'View Highest Team Lineup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xff55d49c) : const Color(0xff37003c),
                    foregroundColor: isDark ? const Color(0xff12091c) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xff2d1f40) : const Color(0xfff0edf6),
                  foregroundColor: isDark ? Colors.white : const Color(0xff1f1f2e),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubNavigationRow extends StatelessWidget {
  const _SubNavigationRow({
    required this.isPitchView,
    required this.selectedMetric,
    required this.onTogglePitch,
    required this.onMetricChanged,
  });

  final bool isPitchView;
  final PlayerCardMetric selectedMetric;
  final ValueChanged<bool> onTogglePitch;
  final ValueChanged<PlayerCardMetric> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segmentedBg = isDark ? const Color(0xff1f152d) : const Color(0xfff0edf6);
    final dropdownBg = isDark ? const Color(0xff1f152d) : Colors.white;
    final dropdownBorder = isDark ? const Color(0xff2d1f40) : const Color(0xffe2e0ea);
    final dropdownAccent = isDark ? const Color(0xff55d49c) : const Color(0xff37003c);
    final popupItemText = isDark ? Colors.white : const Color(0xff1f1f2e);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Pitch | List Segmented Control
            Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: segmentedBg,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SegmentTab(
                    title: 'Pitch',
                    isSelected: isPitchView,
                    onTap: () => onTogglePitch(true),
                  ),
                  _SegmentTab(
                    title: 'List',
                    isSelected: !isPitchView,
                    onTap: () => onTogglePitch(false),
                  ),
                ],
              ),
            ),

            // Filter / Metric Selector Dropdown: Points, Price, Form, Selected %, Total Pts
            PopupMenuButton<PlayerCardMetric>(
              onSelected: onMetricChanged,
              color: dropdownBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: dropdownBorder),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: PlayerCardMetric.points,
                  child: Row(
                    children: [
                      Icon(Icons.sports_soccer, size: 16, color: dropdownAccent),
                      const SizedBox(width: 8),
                      Text('Points', style: TextStyle(fontWeight: FontWeight.w700, color: popupItemText)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: PlayerCardMetric.price,
                  child: Row(
                    children: [
                      Icon(Icons.attach_money_rounded, size: 16, color: dropdownAccent),
                      const SizedBox(width: 8),
                      Text('Current Price', style: TextStyle(fontWeight: FontWeight.w700, color: popupItemText)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: PlayerCardMetric.form,
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded, size: 16, color: dropdownAccent),
                      const SizedBox(width: 8),
                      Text('Form', style: TextStyle(fontWeight: FontWeight.w700, color: popupItemText)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: PlayerCardMetric.selectedPercent,
                  child: Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 16, color: dropdownAccent),
                      const SizedBox(width: 8),
                      Text('Selected %', style: TextStyle(fontWeight: FontWeight.w700, color: popupItemText)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: PlayerCardMetric.totalPoints,
                  child: Row(
                    children: [
                      Icon(Icons.military_tech_rounded, size: 16, color: dropdownAccent),
                      const SizedBox(width: 8),
                      Text('Total Points', style: TextStyle(fontWeight: FontWeight.w700, color: popupItemText)),
                    ],
                  ),
                ),
              ],
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: dropdownBg,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: dropdownBorder, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _metricIcon(selectedMetric),
                      size: 15,
                      color: dropdownAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _metricTitle(selectedMetric),
                      style: TextStyle(
                        color: dropdownAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: dropdownAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: constraints.maxWidth < 360 ? 360 : constraints.maxWidth,
            child: content,
          ),
        );
      },
    );
  }

  IconData _metricIcon(PlayerCardMetric metric) {
    switch (metric) {
      case PlayerCardMetric.points:
        return Icons.sports_soccer;
      case PlayerCardMetric.price:
        return Icons.attach_money_rounded;
      case PlayerCardMetric.form:
        return Icons.trending_up_rounded;
      case PlayerCardMetric.selectedPercent:
        return Icons.people_outline_rounded;
      case PlayerCardMetric.totalPoints:
        return Icons.military_tech_rounded;
    }
  }

  String _metricTitle(PlayerCardMetric metric) {
    switch (metric) {
      case PlayerCardMetric.points:
        return 'Points';
      case PlayerCardMetric.price:
        return 'Price';
      case PlayerCardMetric.form:
        return 'Form';
      case PlayerCardMetric.selectedPercent:
        return 'Selected %';
      case PlayerCardMetric.totalPoints:
        return 'Total Pts';
    }
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xff2d1f40) : Colors.white;
    final activeText = isDark ? const Color(0xff55d49c) : const Color(0xff1f1f2e);
    final inactiveText = isDark ? const Color(0xffa19bb0) : const Color(0xff6b7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? activeText : inactiveText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TeamListView extends StatelessWidget {
  const _TeamListView({
    required this.starting,
    required this.bench,
    required this.bootstrap,
    required this.gameweekPoints,
  });

  final List<TeamPick> starting;
  final List<TeamPick> bench;
  final FplBootstrap bootstrap;
  final Map<int, int> gameweekPoints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Starting XI'),
        ...starting.map((pick) => _buildPlayerTile(context, pick, false)),
        const SizedBox(height: 16),
        _buildSectionHeader(context, 'Substitutes'),
        ...bench.map((pick) => _buildPlayerTile(context, pick, true)),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xff1f1f2e),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildPlayerTile(BuildContext context, TeamPick pick, bool isBench) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xff1f152d) : Colors.white;
    final tileBorder = isDark ? const Color(0xff2d1f40) : const Color(0xfff0edf6);
    final titleColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final subColor = isDark ? const Color(0xffa19bb0) : const Color(0xff6b7280);

    final player = bootstrap.players[pick.elementId];
    final team = player == null ? null : bootstrap.teams[player.teamId];
    final points = gameweekPoints[pick.elementId];
    final pointsText = points != null ? '$points pts' : '—';

    final isUnavailable = player?.isUnavailable ?? false;
    final isDoubtful = player?.isDoubtful ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          // Club / Shirt indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isBench
                  ? (isDark ? const Color(0xff2d1f40) : const Color(0xffc5ece1))
                  : const Color(0xff00d4ff).withValues(alpha: isDark ? 0.25 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                team?.shortName ?? 'PL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xff55d49c) : const Color(0xff37003c),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Player name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      player?.webName ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    if (pick.isCaptain) ...[
                      const SizedBox(width: 6),
                      _miniRoleBadge('C'),
                    ] else if (pick.isViceCaptain) ...[
                      const SizedBox(width: 6),
                      _miniRoleBadge('V'),
                    ],
                  ],
                ),
                if (isUnavailable)
                  const Text(
                    'Unavailable',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xffdc2626),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (isDoubtful)
                  Text(
                    player?.news.isNotEmpty == true
                        ? player!.news
                        : 'Doubtful',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xfff59e0b),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    team?.name ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Points chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xff37003c),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pointsText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniRoleBadge(String label) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xff1f1f2e),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeamMessage extends StatelessWidget {
  const _TeamMessage({required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class TeamLookupPage extends StatelessWidget {
  const TeamLookupPage({super.key, required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (entryId == null || entryId! <= 0) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TeamHeader(
                title: '',
                showBackButton: true,
              ),
              Expanded(
                child: Center(child: Text(l10n.entryIdInvalid)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: TeamView(entryId: entryId),
      ),
    );
  }
}

class _TeamSkeleton extends StatefulWidget {
  const _TeamSkeleton();
  @override
  State<_TeamSkeleton> createState() => _TeamSkeletonState();
}

class _TeamSkeletonState extends State<_TeamSkeleton>
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
          blendMode: BlendMode.modulate,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xff8a8a8a),
                Color(0xfff5f5f5),
                Color(0xff8a8a8a),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-2.0 + (_controller.value * 4), 0),
              end: Alignment(-1.0 + (_controller.value * 4), 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white54,
                ),
              ),
              Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 160,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 110,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PitchSkeleton(),
        ],
      ),
    );
  }
}
