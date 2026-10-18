import 'package:flutter/material.dart';
import 'package:fpl_engine/fpl_engine.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/player_news.dart';

/// Every player's FPL news grouped by Gameweek deadline, key news first.
class PlayerNewsPage extends StatefulWidget {
  const PlayerNewsPage({
    super.key,
    required this.bootstrap,
    this.squadIds = const {},
  });

  final FplBootstrap bootstrap;
  final Set<int> squadIds;

  @override
  State<PlayerNewsPage> createState() => _PlayerNewsPageState();
}

class _PlayerNewsPageState extends State<PlayerNewsPage> {
  late final List<GameweekNews> _groups = groupPlayerNews(
    widget.bootstrap,
    squadIds: widget.squadIds,
  );
  bool _keyOnly = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SegmentedButton<bool>(
          key: const ValueKey('news-filter'),
          segments: [
            ButtonSegment(value: true, label: Text(l10n.keyNews)),
            ButtonSegment(value: false, label: Text(l10n.allNews)),
          ],
          selected: {_keyOnly},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              setState(() => _keyOnly = value.single),
        ),
      ),
      if (_keyOnly)
        Text(l10n.keyNewsHint, style: Theme.of(context).textTheme.bodySmall),
    ];

    for (final group in _groups) {
      final shown = _keyOnly ? group.keyItems.toList() : group.items;
      final hidden = group.items.length - shown.length;
      if (shown.isEmpty && hidden == 0) continue;
      children.add(_GameweekHeader(group: group, count: shown.length));
      for (final item in shown) {
        children.add(
          _NewsRow(
            item: item,
            team: widget.bootstrap.teams[item.player.teamId],
          ),
        );
      }
      if (hidden > 0) {
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _keyOnly = false),
              child: Text(l10n.moreNewsHidden(hidden)),
            ),
          ),
        );
      }
    }
    if (_groups.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(child: Text(l10n.noNews)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerNewsTitle)),
      body: ListView(
        padding: contentInsets(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: children,
      ),
    );
  }
}

class _GameweekHeader extends StatelessWidget {
  const _GameweekHeader({required this.group, required this.count});

  final GameweekNews group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deadline = group.gameweek.deadlineTime;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.newsBeforeDeadline(group.gameweek.id),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (deadline != null)
                  Text(
                    '${l10n.matchDayHeader(deadline)} · '
                    '${l10n.kickoffTimeOnly(deadline)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, required this.team});

  final PlayerNewsItem item;
  final FplTeam? team;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final player = item.player;

    final (statusColor, icon, status) = player.isUnavailableNextRound
        ? (
            isDark ? AppColors.darkAlertErrorText : const Color(0xffc2413d),
            Icons.event_busy_rounded,
            switch (player.status.toLowerCase()) {
              'i' => l10n.injured,
              's' => l10n.suspended,
              _ => l10n.unavailable,
            },
          )
        : player.isDoubtfulNextRound
        ? (
            isDark ? AppColors.darkAlertWarningText : const Color(0xffb45309),
            Icons.help_outline_rounded,
            l10n.doubtful,
          )
        : (
            isDark ? AppColors.plMint : AppColors.plMintDark,
            Icons.check_circle_outline_rounded,
            l10n.available,
          );
    final added = player.newsAdded;
    final ownership = player.selectedByPercent.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: item.inSquad
            ? Border.all(color: colors.primary.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: statusColor, size: 18),
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
                        '${player.webName} · ${team?.shortName ?? 'PL'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (item.inSquad) ...[
                      const SizedBox(width: 6),
                      _Tag(label: l10n.inYourSquad, color: colors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.playerNews(player.news),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.ownedBy(ownership),
                    if (added != null)
                      l10n.newsAddedAt(
                        '${l10n.matchDayHeader(added)} '
                        '${l10n.kickoffTimeOnly(added)}',
                      ),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
