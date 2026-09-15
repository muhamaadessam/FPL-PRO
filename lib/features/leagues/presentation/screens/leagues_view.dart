import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../dashboard/presentation/cubit/home_preload_cubit.dart';
import '../../../team/data/models/team_models.dart';
import '../../../team/domain/repositories/team_repository.dart';

class LeaguesView extends StatelessWidget {
  const LeaguesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<HomePreloadCubit, HomePreloadState>(
      builder: (context, state) {
        final entry = state.entry;
        if (entry == null && state.status == PreloadStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entry == null && state.status == PreloadStatus.failure) {
          return _MessageState(
            icon: Icons.cloud_off_rounded,
            title: l10n.errorLoadingData,
            message: l10n.networkError,
            actionLabel: l10n.retry,
            onAction: context.read<HomePreloadCubit>().load,
          );
        }

        if (entry == null) {
          return _MessageState(
            icon: Icons.emoji_events_outlined,
            title: l10n.noLeagues,
            message: l10n.noLeaguesHint,
            actionLabel: l10n.retry,
            onAction: context.read<HomePreloadCubit>().load,
          );
        }

        final leagues = entry.leagues;
        if (leagues.isEmpty) {
          return _MessageState(
            icon: Icons.emoji_events_outlined,
            title: l10n.noLeagues,
            message: l10n.noLeaguesHint,
            actionLabel: l10n.retry,
            onAction: context.read<HomePreloadCubit>().load,
          );
        }

        final groups = _groupLeagues(leagues, l10n);
        return RefreshIndicator(
          onRefresh: context.read<HomePreloadCubit>().load,
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _PageHeader(entry: entry, leagueCount: leagues.length),
              const SizedBox(height: 20),
              for (final group in groups) _LeagueSection(group: group),
            ],
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.entry, required this.leagueCount});

  final FplEntry entry;
  final int leagueCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.colorScheme.onSurface;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                l10n.leagues,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Text(
              l10n.leagueCount(leagueCount),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.leaguesSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xff1f152d)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.isEmpty ? l10n.fplManager : entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Entry #${entry.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeagueSection extends StatelessWidget {
  const _LeagueSection({required this.group});

  final _LeagueGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xff1f152d)
        : theme.colorScheme.surfaceContainerHighest;
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              Text(
                '${group.leagues.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  child: _RankHeader(l10n: l10n),
                ),
                Divider(height: 1, color: border),
                for (var index = 0; index < group.leagues.length; index++)
                  _LeagueRow(
                    league: group.leagues[index],
                    isLast: index == group.leagues.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankHeader extends StatelessWidget {
  const _RankHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
    return Row(
      children: [
        Expanded(child: Text(l10n.league, style: style)),
        SizedBox(width: 66, child: Text(l10n.currentRank, style: style)),
        SizedBox(width: 62, child: Text(l10n.lastRank, style: style)),
        const SizedBox(width: 30),
      ],
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({required this.league, required this.isLast});

  final FplLeague league;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final rankChange = league.currentRank != null && league.lastRank != null
        ? league.lastRank! - league.currentRank!
        : null;
    final changeColor = rankChange == null || rankChange == 0
        ? secondary
        : rankChange > 0
        ? const Color(0xff18b77a)
        : theme.colorScheme.error;
    final changeIcon = rankChange == null || rankChange == 0
        ? Icons.remove_rounded
        : rankChange > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final changeLabel = rankChange == null || rankChange == 0
        ? l10n.rankUnchanged
        : rankChange > 0
        ? l10n.rankImproved
        : l10n.rankDropped;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LeagueDetailsPage(league: league)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name.isEmpty
                              ? l10n.leagueName(league.id)
                              : league.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (league.rankCount != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            l10n.managerCount(
                              MaterialLocalizations.of(
                                context,
                              ).formatDecimal(league.rankCount!),
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 66,
                    child: Text(
                      _rank(context, league.currentRank),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 62,
                    child: Text(
                      _rank(context, league.lastRank),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Semantics(
                      label: changeLabel,
                      child: Icon(changeIcon, size: 18, color: changeColor),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast) Divider(height: 1, indent: 14, endIndent: 10),
          ],
        ),
      ),
    );
  }

  String _rank(BuildContext context, int? rank) {
    return rank == null
        ? '—'
        : MaterialLocalizations.of(context).formatDecimal(rank);
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class LeagueDetailsPage extends StatefulWidget {
  const LeagueDetailsPage({required this.league, super.key});

  final FplLeague league;

  @override
  State<LeagueDetailsPage> createState() => _LeagueDetailsPageState();
}

class _LeagueDetailsPageState extends State<LeagueDetailsPage> {
  late Future<FplLeagueDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FplLeagueDetails> _load() {
    return context.read<TeamRepository>().getLeagueStandings(
      league: widget.league,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leagueDetails)),
      body: FutureBuilder<FplLeagueDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              title: l10n.errorLoadingData,
              message: l10n.networkError,
              actionLabel: l10n.retry,
              onAction: _reload,
            );
          }

          final details = snapshot.data!;
          if (details.standings.isEmpty) {
            return _MessageState(
              icon: Icons.leaderboard_outlined,
              title: l10n.noStandings,
              message: l10n.noStandingsHint,
              actionLabel: l10n.retry,
              onAction: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            color: Theme.of(context).colorScheme.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _LeagueDetailsHeader(details: details),
                const SizedBox(height: 22),
                _StandingsTable(details: details),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeagueDetailsHeader extends StatelessWidget {
  const _LeagueDetailsHeader({required this.details});

  final FplLeagueDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final league = details.league;
    final isHeadToHead = league.isHeadToHead || league.scoring == 'h';
    final title = league.name.isEmpty
        ? l10n.leagueName(league.id)
        : league.name;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.managerCount(
                    MaterialLocalizations.of(
                      context,
                    ).formatDecimal(details.standings.length),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(
              isHeadToHead ? l10n.headToHeadScoring : l10n.classicScoring,
            ),
            visualDensity: VisualDensity.compact,
            side: BorderSide.none,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.details});

  final FplLeagueDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.standings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: Text('#', style: _headerStyle(context)),
                    ),
                    Expanded(
                      child: Text(l10n.manager, style: _headerStyle(context)),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        l10n.gameweekPointsShort,
                        textAlign: TextAlign.center,
                        style: _headerStyle(context),
                      ),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        l10n.totalPointsShort,
                        textAlign: TextAlign.center,
                        style: _headerStyle(context),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              Divider(height: 1, color: border),
              for (var index = 0; index < details.standings.length; index++)
                _StandingRow(
                  standing: details.standings[index],
                  isLast: index == details.standings.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle? _headerStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing, required this.isLast});

  final FplLeagueStanding standing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentEntryId = context.read<HomePreloadCubit>().state.entryId;
    final isYou = currentEntryId == standing.entryId;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final movement = standing.currentRank != null && standing.lastRank != null
        ? standing.lastRank! - standing.currentRank!
        : null;
    final movementColor = movement == null || movement == 0
        ? secondary
        : movement > 0
        ? const Color(0xff18b77a)
        : theme.colorScheme.error;
    final movementIcon = movement == null || movement == 0
        ? Icons.remove_rounded
        : movement > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final movementLabel = movement == null || movement == 0
        ? l10n.rankUnchanged
        : movement > 0
        ? l10n.rankImproved
        : l10n.rankDropped;
    final managerName = standing.managerName.isEmpty
        ? standing.teamName
        : standing.managerName;

    return Container(
      color: isYou
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    _value(context, standing.currentRank),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isYou ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        managerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (standing.teamName.isNotEmpty &&
                          standing.teamName != managerName)
                        Text(
                          isYou
                              ? '${standing.teamName} • ${l10n.you}'
                              : standing.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondary,
                          ),
                        )
                      else if (isYou)
                        Text(
                          l10n.you,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _value(context, standing.gameweekPoints),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    _value(context, standing.totalPoints),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Semantics(
                    label: movementLabel,
                    child: Icon(movementIcon, size: 17, color: movementColor),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) Divider(height: 1, indent: 12, endIndent: 10),
        ],
      ),
    );
  }

  String _value(BuildContext context, int? value) {
    return value == null
        ? '—'
        : MaterialLocalizations.of(context).formatDecimal(value);
  }
}

class _LeagueGroup {
  const _LeagueGroup({
    required this.title,
    required this.icon,
    required this.leagues,
  });

  final String title;
  final IconData icon;
  final List<FplLeague> leagues;
}

List<_LeagueGroup> _groupLeagues(
  List<FplLeague> leagues,
  AppLocalizations l10n,
) {
  final grouped = <String, List<FplLeague>>{};
  for (final league in leagues) {
    grouped.putIfAbsent(_sectionKey(league), () => []).add(league);
  }

  final groups = [
    _LeagueGroup(
      title: l10n.invitationClassicLeagues,
      icon: Icons.mail_outline_rounded,
      leagues: grouped['invitational'] ?? const [],
    ),
    _LeagueGroup(
      title: l10n.generalLeagues,
      icon: Icons.public_rounded,
      leagues: grouped['general'] ?? const [],
    ),
    _LeagueGroup(
      title: l10n.broadcasterLeagues,
      icon: Icons.campaign_outlined,
      leagues: grouped['broadcaster'] ?? const [],
    ),
    _LeagueGroup(
      title: l10n.publicClassicLeagues,
      icon: Icons.groups_outlined,
      leagues: grouped['public'] ?? const [],
    ),
    _LeagueGroup(
      title: l10n.invitationHeadToHeadLeagues,
      icon: Icons.sports_soccer_outlined,
      leagues: grouped['h2h-invitational'] ?? const [],
    ),
    _LeagueGroup(
      title: l10n.publicHeadToHeadLeagues,
      icon: Icons.sports_soccer_rounded,
      leagues: grouped['h2h-public'] ?? const [],
    ),
  ];
  return groups
      .where((group) => group.leagues.isNotEmpty)
      .toList(growable: false);
}

String _sectionKey(FplLeague league) {
  if (league.isHeadToHead) {
    return league.leagueType == 'x' ? 'h2h-invitational' : 'h2h-public';
  }
  if (league.shortName?.contains('brd-') == true) return 'broadcaster';
  return switch (league.leagueType) {
    'x' => 'invitational',
    'c' => 'public',
    _ => 'general',
  };
}
