import 'package:flutter/material.dart';

import '../../../fixtures/data/models/fpl_models.dart';
import '../../data/models/team_models.dart';
import '../../../../l10n/app_localizations.dart';

class PitchView extends StatelessWidget {
  const PitchView({
    super.key,
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
    final rows = <List<TeamPick>>[
      _byPosition(starting, bootstrap, 1),
      _byPosition(starting, bootstrap, 2),
      _byPosition(starting, bootstrap, 3),
      _byPosition(starting, bootstrap, 4),
    ];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff2d8c47), Color(0xff1a6e30)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PitchMarkingsPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < rows.length; index++) ...[
                        _PitchRow(
                          picks: rows[index],
                          bootstrap: bootstrap,
                          gameweekPoints: gameweekPoints,
                        ),
                        if (index != rows.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
                child: Text(
                  '${AppLocalizations.of(context).bench} (${bench.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _PitchRow(
                picks: bench,
                bootstrap: bootstrap,
                gameweekPoints: gameweekPoints,
                isBench: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<TeamPick> _byPosition(
    List<TeamPick> picks,
    FplBootstrap bootstrap,
    int positionId,
  ) {
    return picks
        .where(
          (pick) => bootstrap.players[pick.elementId]?.positionId == positionId,
        )
        .toList(growable: false);
  }
}

class _PitchMarkingsPainter extends CustomPainter {
  const _PitchMarkingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final half = size.height / 2;
    final boxWidth = size.width * 0.45;
    final boxHeight = size.height * 0.14;
    final boxLeft = (size.width - boxWidth) / 2;

    canvas.drawLine(Offset(0, half), Offset(size.width, half), paint);
    canvas.drawCircle(Offset(size.width / 2, half), size.width * 0.15, paint);
    canvas.drawRect(Rect.fromLTWH(boxLeft, 0, boxWidth, boxHeight), paint);
    canvas.drawRect(
      Rect.fromLTWH(boxLeft, size.height - boxHeight, boxWidth, boxHeight),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PitchRow extends StatelessWidget {
  const _PitchRow({
    required this.picks,
    required this.bootstrap,
    required this.gameweekPoints,
    this.isBench = false,
  });

  final List<TeamPick> picks;
  final FplBootstrap bootstrap;
  final Map<int, int> gameweekPoints;
  final bool isBench;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: picks
          .map(
            (pick) => _PitchPlayer(
              pick: pick,
              player: bootstrap.players[pick.elementId],
              team: _teamFor(pick),
              points: _displayPoints(pick),
              isBench: isBench,
            ),
          )
          .toList(growable: false),
    );
  }

  FplTeam? _teamFor(TeamPick pick) {
    final player = bootstrap.players[pick.elementId];
    return player == null ? null : bootstrap.teams[player.teamId];
  }

  int? _displayPoints(TeamPick pick) {
    final points = gameweekPoints[pick.elementId];
    if (points == null) return null;
    return points * (pick.multiplier > 0 ? pick.multiplier : 1);
  }
}

class _PitchPlayer extends StatelessWidget {
  const _PitchPlayer({
    required this.pick,
    required this.player,
    required this.team,
    required this.points,
    required this.isBench,
  });

  final TeamPick pick;
  final FplPlayer? player;
  final FplTeam? team;
  final int? points;
  final bool isBench;

  @override
  Widget build(BuildContext context) {
    final isGoalkeeper = player?.positionId == 1;
    final textColor = Colors.white;
    final panelColor = const Color(0xff1f1f2e);
    final localShirt = _localShirtAsset(isGoalkeeper);

    return Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 56,
                    child: _shirt(isGoalkeeper, localShirt),
                  ),
                  if (pick.isCaptain || pick.isViceCaptain)
                    Positioned(
                      top: 0,
                      right: -2,
                      child: _RoleBadge(isCaptain: pick.isCaptain),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ClubLogo(team: team, color: textColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        player?.webName ?? '—',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 25),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${points ?? '-'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      AppLocalizations.of(context).ptsCue,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
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

  String? _localShirtAsset(bool isGoalkeeper) {
    if (team?.code == 14 && !isGoalkeeper) {
      return 'assets/shirt/shirt_14-66.webp';
    }
    if (team?.code == 6 && isGoalkeeper) {
      return 'assets/shirt/shirt_6_1-110.webp';
    }
    return null;
  }

  Widget _shirt(bool isGoalkeeper, String? localAsset) {
    final fallback = localAsset == null
        ? Icon(
            Icons.sports_soccer,
            size: 38,
            color: isBench ? Colors.black26 : Colors.white70,
          )
        : Image.asset(
            localAsset,
            fit: BoxFit.contain,
            color: isBench ? Colors.white.withValues(alpha: 0.5) : null,
            colorBlendMode: isBench ? BlendMode.modulate : null,
            errorBuilder: (_, _, _) => Icon(
              Icons.sports_soccer,
              size: 38,
              color: isBench ? Colors.black26 : Colors.white70,
            ),
          );
    final code = team?.code;
    if (code == null) return fallback;

    final fileName = isGoalkeeper
        ? 'shirt_${code}_1-110.webp'
        : 'shirt_$code-66.webp';
    return Image.network(
      'https://fantasy.premierleague.com/dist/img/shirts/standard/$fileName',
      fit: BoxFit.contain,
      color: isBench ? Colors.white.withValues(alpha: 0.5) : null,
      colorBlendMode: isBench ? BlendMode.modulate : null,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isCaptain});

  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCaptain ? scheme.tertiary : scheme.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 2),
      ),
      child: Text(
        isCaptain ? 'C' : 'V',
        style: TextStyle(
          color: isCaptain ? scheme.onTertiary : scheme.onSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ClubLogo extends StatelessWidget {
  const _ClubLogo({required this.team, required this.color});

  final FplTeam? team;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final code = team?.code;
    if (code == null) {
      return Icon(Icons.shield_outlined, size: 10, color: color);
    }
    return Image.network(
      'https://resources.premierleague.com/premierleague/badges/70/t$code.png',
      width: 10,
      height: 10,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.shield_outlined, size: 10, color: color),
    );
  }
}

class PitchSkeleton extends StatelessWidget {
  const PitchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff2d8c47), Color(0xff1a6e30)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PitchMarkingsPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      const _PitchSkeletonRow(count: 1),
                      const SizedBox(height: 12),
                      const _PitchSkeletonRow(count: 4),
                      const SizedBox(height: 12),
                      const _PitchSkeletonRow(count: 4),
                      const SizedBox(height: 12),
                      const _PitchSkeletonRow(count: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
                child: Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const _PitchSkeletonRow(count: 4, isBench: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _PitchSkeletonRow extends StatelessWidget {
  const _PitchSkeletonRow({required this.count, this.isBench = false});
  final int count;
  final bool isBench;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        count,
        (_) => Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 48,
                    height: 56,
                    child: Icon(
                      Icons.sports_soccer,
                      size: 38,
                      color: isBench ? Colors.black26 : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xff1f1f2e),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  Container(
                    height: 25,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
