import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../fixtures/data/models/fpl_models.dart';
import '../../data/models/team_models.dart';
import '../../../../l10n/app_localizations.dart';

enum PlayerCardMetric {
  points,
  price,
  form,
  selectedPercent,
  totalPoints,
}

class PitchView extends StatelessWidget {
  const PitchView({
    super.key,
    required this.starting,
    required this.bench,
    required this.bootstrap,
    required this.gameweekPoints,
    this.onSwap,
    this.metric = PlayerCardMetric.points,
  });

  final List<TeamPick> starting;
  final List<TeamPick> bench;
  final FplBootstrap bootstrap;
  final Map<int, num> gameweekPoints;
  final void Function(int draggedElementId, int targetElementId)? onSwap;
  final PlayerCardMetric metric;

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
        // Realistic Stadium Pitch Card with Perspective Angle
        ClipPath(
          clipper: const _PerspectivePitchClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff0a6e35), Color(0xff12944b)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _FplPerspectivePitchPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
                  child: Column(
                    children: [
                      for (var index = 0; index < rows.length; index++) ...[
                        _PitchRow(
                          picks: rows[index],
                          bootstrap: bootstrap,
                          gameweekPoints: gameweekPoints,
                          onSwap: onSwap,
                          metric: metric,
                        ),
                        if (index != rows.length - 1)
                          const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Bench (Substitutes) Section
        _BenchSection(
          bench: bench,
          bootstrap: bootstrap,
          gameweekPoints: gameweekPoints,
          onSwap: onSwap,
          metric: metric,
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

class _PerspectivePitchClipper extends CustomClipper<Path> {
  const _PerspectivePitchClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const topInset = 16.0;
    const radius = 20.0;

    // Top edge starts narrower for 3D stadium perspective
    path.moveTo(topInset + radius, 0);
    path.lineTo(size.width - topInset - radius, 0);
    path.quadraticBezierTo(size.width - topInset, 0, size.width - topInset + 4, radius * 0.5);
    // Right sideline slants outward to bottom-right
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    // Bottom edge
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    // Left sideline slants inward to top-left
    path.lineTo(topInset - 4, radius * 0.5);
    path.quadraticBezierTo(topInset, 0, topInset + radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FplPerspectivePitchPainter extends CustomPainter {
  const _FplPerspectivePitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const topInset = 16.0;
    const bottomInset = 0.0;
    final bands = 12;

    // 1. Perspective lawn grass stripes with subtle realistic contrast
    for (var i = 0; i < bands; i++) {
      final t0 = i / bands;
      final t1 = (i + 1) / bands;
      final y0 = size.height * t0;
      final y1 = size.height * t1;

      final left0 = lerpDouble(topInset, bottomInset, t0)!;
      final right0 = lerpDouble(size.width - topInset, size.width - bottomInset, t0)!;
      final left1 = lerpDouble(topInset, bottomInset, t1)!;
      final right1 = lerpDouble(size.width - topInset, size.width - bottomInset, t1)!;

      final stripePaint = Paint()
        ..color = (i % 2 == 0) ? const Color(0xff128e48) : const Color(0xff0d7e3e);

      final stripePath = Path()
        ..moveTo(left0, y0)
        ..lineTo(right0, y0)
        ..lineTo(right1, y1)
        ..lineTo(left1, y1)
        ..close();

      canvas.drawPath(stripePath, stripePaint);
    }

    // 2. Crisp white field markings with perspective
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Pitch boundary
    final outlinePath = Path()
      ..moveTo(topInset + 6, 6)
      ..lineTo(size.width - topInset - 6, 6)
      ..lineTo(size.width - 6, size.height - 6)
      ..lineTo(6, size.height - 6)
      ..close();
    canvas.drawPath(outlinePath, linePaint);

    // Goal at top behind keeper (realistic posts and net depth)
    final goalWidth = size.width * 0.32;
    final goalLeft = (size.width - goalWidth) / 2;
    final goalNetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(goalLeft, 6, goalWidth, 12), goalNetPaint);
    canvas.drawLine(Offset(goalLeft, 6), Offset(goalLeft + goalWidth, 6), linePaint);

    // 6-yard box
    final sixYardWidth = size.width * 0.38;
    final sixYardHeight = size.height * 0.085;
    final sixYardLeft = (size.width - sixYardWidth) / 2;
    canvas.drawRect(
      Rect.fromLTWH(sixYardLeft, 6, sixYardWidth, sixYardHeight),
      linePaint,
    );

    // 18-yard penalty box
    final boxWidth = size.width * 0.66;
    final boxHeight = size.height * 0.20;
    final boxLeft = (size.width - boxWidth) / 2;
    canvas.drawRect(
      Rect.fromLTWH(boxLeft, 6, boxWidth, boxHeight),
      linePaint,
    );

    // Penalty spot
    final spotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, 6 + (boxHeight * 0.7)), 2.5, spotPaint);

    // Penalty arc
    final arcRect = Rect.fromCenter(
      center: Offset(size.width / 2, 6 + (boxHeight * 0.7)),
      width: size.width * 0.28,
      height: size.width * 0.28,
    );
    canvas.drawArc(arcRect, 0.15 * 3.14159, 0.7 * 3.14159, false, linePaint);

    // Halfway line across pitch (lower half)
    final halfwayY = size.height * 0.58;
    final halfLeft = lerpDouble(topInset, bottomInset, 0.58)! + 6;
    final halfRight = lerpDouble(size.width - topInset, size.width - bottomInset, 0.58)! - 6;
    canvas.drawLine(Offset(halfLeft, halfwayY), Offset(halfRight, halfwayY), linePaint);

    // Center circle
    final circleRadius = size.width * 0.16;
    canvas.drawCircle(Offset(size.width / 2, halfwayY), circleRadius, linePaint);
    canvas.drawCircle(Offset(size.width / 2, halfwayY), 2.5, spotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BenchSection extends StatelessWidget {
  const _BenchSection({
    required this.bench,
    required this.bootstrap,
    required this.gameweekPoints,
    this.onSwap,
    required this.metric,
  });

  final List<TeamPick> bench;
  final FplBootstrap bootstrap;
  final Map<int, num> gameweekPoints;
  final void Function(int draggedElementId, int targetElementId)? onSwap;
  final PlayerCardMetric metric;

  @override
  Widget build(BuildContext context) {
    if (bench.isEmpty) return const SizedBox.shrink();

    // Sort bench by position order (12: GK, 13: Sub 1, 14: Sub 2, 15: Sub 3)
    final sortedBench = List<TeamPick>.from(bench)
      ..sort((a, b) => a.position.compareTo(b.position));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final benchBg = isDark
        ? const Color(0xff1f152d)
        : const Color(0xffc5ece1);
    final benchBorder = isDark
        ? const Color(0xff36264d)
        : Colors.white.withValues(alpha: 0.6);
    final labelColor = isDark
        ? Colors.white70
        : const Color(0xff1f1f2e);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
      decoration: BoxDecoration(
        color: benchBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: benchBorder, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: sortedBench.map((pick) {
              final player = bootstrap.players[pick.elementId];
              final label = _positionLabel(player?.positionId);
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: sortedBench.map((pick) {
              return _PitchPlayer(
                pick: pick,
                player: bootstrap.players[pick.elementId],
                team: _teamFor(pick),
                points: _displayPoints(pick),
                isBench: true,
                onSwap: onSwap,
                metric: metric,
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  FplTeam? _teamFor(TeamPick pick) {
    final player = bootstrap.players[pick.elementId];
    return player == null ? null : bootstrap.teams[player.teamId];
  }

  num? _displayPoints(TeamPick pick) {
    final points = gameweekPoints[pick.elementId];
    if (points == null) return null;
    return points * (pick.multiplier > 0 ? pick.multiplier : 1);
  }

  String _positionLabel(int? positionId) {
    switch (positionId) {
      case 1:
        return 'GK';
      case 2:
        return 'DEF';
      case 3:
        return 'MID';
      case 4:
        return 'FWD';
      default:
        return 'SUB';
    }
  }
}

class _PitchRow extends StatelessWidget {
  const _PitchRow({
    required this.picks,
    required this.bootstrap,
    required this.gameweekPoints,
    this.onSwap,
    required this.metric,
  });

  final List<TeamPick> picks;
  final FplBootstrap bootstrap;
  final Map<int, num> gameweekPoints;
  final void Function(int draggedElementId, int targetElementId)? onSwap;
  final PlayerCardMetric metric;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    final cardWidth = picks.length >= 5 ? 70.0 : 78.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: picks
          .map(
            (pick) => _PitchPlayer(
              pick: pick,
              player: bootstrap.players[pick.elementId],
              team: _teamFor(pick),
              points: _displayPoints(pick),
              isBench: false,
              onSwap: onSwap,
              metric: metric,
              cardWidth: cardWidth,
            ),
          )
          .toList(growable: false),
    );
  }

  FplTeam? _teamFor(TeamPick pick) {
    final player = bootstrap.players[pick.elementId];
    return player == null ? null : bootstrap.teams[player.teamId];
  }

  num? _displayPoints(TeamPick pick) {
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
    this.onSwap,
    this.metric = PlayerCardMetric.points,
    this.cardWidth = 78.0,
  });

  final TeamPick pick;
  final FplPlayer? player;
  final FplTeam? team;
  final num? points;
  final bool isBench;
  final void Function(int draggedElementId, int targetElementId)? onSwap;
  final PlayerCardMetric metric;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final isGoalkeeper = player?.positionId == 1;
    final localShirt = _localShirtAsset(isGoalkeeper);

    // Compute metric text to show in the points box
    final String metricText;
    switch (metric) {
      case PlayerCardMetric.points:
        metricText = points != null
            ? (points is int ? points.toString() : points!.toStringAsFixed(1))
            : '-';
        break;
      case PlayerCardMetric.price:
        final cost = player?.nowCost;
        metricText = cost != null ? '£${(cost / 10).toStringAsFixed(1)}' : '-';
        break;
      case PlayerCardMetric.form:
        metricText = player?.form != null ? player!.form.toStringAsFixed(1) : '-';
        break;
      case PlayerCardMetric.selectedPercent:
        metricText = player?.selectedByPercent != null
            ? '${player!.selectedByPercent.toStringAsFixed(1)}%'
            : '-';
        break;
      case PlayerCardMetric.totalPoints:
        metricText = '${player?.totalPoints ?? 0}';
        break;
    }

    // Availability status
    final isUnavailable = player?.isUnavailable ?? false;
    final isDoubtful = player?.isDoubtful ?? false;

    final Color nameBgColor;
    final Color nameTextColor;
    if (isUnavailable) {
      nameBgColor = const Color(0xffdc2626);
      nameTextColor = Colors.white;
    } else if (isDoubtful) {
      nameBgColor = const Color(0xfff59e0b);
      nameTextColor = const Color(0xff1f1f2e);
    } else {
      nameBgColor = const Color(0xff1f1f2e);
      nameTextColor = Colors.white;
    }

    Widget shirtWidget = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 54,
          child: _shirt(isGoalkeeper, localShirt),
        ),
        // Captain / Vice-Captain badge on top-left
        if (pick.isCaptain || pick.isViceCaptain)
          Positioned(
            top: -2,
            left: -3,
            child: _RoleBadge(isCaptain: pick.isCaptain),
          ),
        // Alert badge on top-right (warning triangle for doubtful, exclamation for unavailable)
        if (isDoubtful || isUnavailable)
          Positioned(
            top: -2,
            right: -3,
            child: _StatusAlertBadge(isUnavailable: isUnavailable),
          ),
      ],
    );

    // Bench chic soft glass container (removes harsh dark background)
    if (isBench) {
      shirtWidget = Container(
        width: 54,
        height: 58,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: shirtWidget,
      );
    }

    Widget cardContent = GestureDetector(
      onTap: () => _showPlayerDetailsSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          shirtWidget,
          const SizedBox(height: 2),
          // Player Name Box - Clean full-width dedicated for player name
          Container(
            width: cardWidth,
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: nameBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  player?.webName ?? '—',
                  style: TextStyle(
                    color: nameTextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Points Box with Club Logo placed here per user request
          Container(
            width: cardWidth,
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xff37003c),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Team logo commented out for now:
                // _ClubLogo(team: team, color: Colors.white70),
                // const SizedBox(width: 3.5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      metricText,
                      key: ValueKey('pitch-player-points-${pick.elementId}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Opacity(
                  opacity: 0.0,
                  child: SizedBox(
                    width: 0,
                    height: 0,
                    child: Text(
                      AppLocalizations.of(context).ptsCue,
                      style: const TextStyle(fontSize: 0.01),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onSwap != null) {
      return Expanded(
        child: Align(
          alignment: Alignment.topCenter,
          child: DragTarget<int>(
            onAcceptWithDetails: (details) =>
                onSwap!(details.data, pick.elementId),
            builder: (context, candidateData, rejectedData) {
              final isTarget = candidateData.isNotEmpty;
              return Container(
                decoration: isTarget
                    ? BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                padding: isTarget ? const EdgeInsets.all(4) : null,
                child: LongPressDraggable<int>(
                  data: pick.elementId,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(opacity: 0.8, child: cardContent),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: cardContent,
                  ),
                  child: cardContent,
                ),
              );
            },
          ),
        ),
      );
    }

    return Expanded(
      child: Align(alignment: Alignment.topCenter, child: cardContent),
    );
  }

  void _showPlayerDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PlayerDetailBottomSheet(
        player: player,
        team: team,
        pick: pick,
        points: points,
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
        ? const Icon(
            Icons.sports_soccer,
            size: 38,
            color: Colors.white70,
          )
        : Image.asset(
            localAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.sports_soccer,
              size: 38,
              color: Colors.white70,
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
      errorBuilder: (_, _, _) => fallback,
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
      return Icon(Icons.shield_outlined, size: 11, color: color);
    }
    return Image.network(
      'https://resources.premierleague.com/premierleague/badges/70/t$code.png',
      width: 11,
      height: 11,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.shield_outlined, size: 11, color: color),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isCaptain});

  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff1f1f2e),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
          ),
        ],
      ),
      child: Text(
        isCaptain ? 'C' : 'V',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusAlertBadge extends StatelessWidget {
  const _StatusAlertBadge({required this.isUnavailable});

  final bool isUnavailable;

  @override
  Widget build(BuildContext context) {
    if (isUnavailable) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xffdc2626),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Center(
          child: Icon(
            Icons.priority_high_rounded,
            size: 11,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xffffb800),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Center(
        child: Icon(
          Icons.warning_amber_rounded,
          size: 12,
          color: Color(0xff1f1f2e),
        ),
      ),
    );
  }
}

class _PlayerDetailBottomSheet extends StatelessWidget {
  const _PlayerDetailBottomSheet({
    required this.player,
    required this.team,
    required this.pick,
    required this.points,
  });

  final FplPlayer? player;
  final FplTeam? team;
  final TeamPick pick;
  final num? points;

  @override
  Widget build(BuildContext context) {
    final isUnavailable = player?.isUnavailable ?? false;
    final isDoubtful = player?.isDoubtful ?? false;
    final rawChance = player?.effectiveChanceOfPlaying;
    final chance = (rawChance != null && rawChance < 100)
        ? rawChance
        : (isDoubtful ? 50 : 100);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xff1f152d) : Colors.white;
    final handleColor = isDark ? const Color(0xff36264d) : Colors.grey[300]!;
    final titleColor = isDark ? Colors.white : const Color(0xff1f1f2e);
    final subtitleColor = isDark ? const Color(0xffa19bb0) : Colors.grey[600]!;
    final logoColor = isDark ? Colors.white : const Color(0xff37003c);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // Player header
          Row(
            children: [
              _ClubLogo(team: team, color: logoColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player?.webName ?? 'Player',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      '${team?.name ?? ''} • ${_posName(player?.positionId)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (pick.isCaptain || pick.isViceCaptain)
                _RoleBadge(isCaptain: pick.isCaptain),
            ],
          ),

          // Injury / Availability Alert banner
          if (isDoubtful || isUnavailable) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnavailable
                    ? (isDark ? const Color(0xff3b1520) : const Color(0xfffef2f2))
                    : (isDark ? const Color(0xff2d1d07) : const Color(0xfffffbeb)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUnavailable
                      ? (isDark ? const Color(0xff7f1d1d) : const Color(0xfff87171))
                      : (isDark ? const Color(0xff78350f) : const Color(0xfffcd34d)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isUnavailable
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: isUnavailable
                        ? (isDark ? const Color(0xfff87171) : const Color(0xffdc2626))
                        : (isDark ? const Color(0xfffbbf24) : const Color(0xffd97706)),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUnavailable
                              ? 'Unavailable (0% chance of playing)'
                              : 'Doubtful ($chance% chance of playing)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isUnavailable
                                ? (isDark ? const Color(0xfffca5a5) : const Color(0xff991b1b))
                                : (isDark ? const Color(0xfffde68a) : const Color(0xff92400e)),
                          ),
                        ),
                        if (player?.news.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            player!.news,
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnavailable
                                  ? (isDark ? const Color(0xfff87171) : const Color(0xffb91c1c))
                                  : (isDark ? const Color(0xfffbbf24) : const Color(0xffb45309)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem('Points', _formatStatPoints(points), titleColor, subtitleColor),
              _statItem(
                'Price',
                player?.nowCost != null
                    ? '£${(player!.nowCost! / 10).toStringAsFixed(1)}m'
                    : '—',
                titleColor,
                subtitleColor,
              ),
              _statItem('Form', player?.form.toStringAsFixed(1) ?? '—', titleColor, subtitleColor),
              _statItem(
                'Selected',
                player?.selectedByPercent != null
                    ? '${player!.selectedByPercent}%'
                    : '—',
                titleColor,
                subtitleColor,
              ),
              _statItem('Total Pts', player?.totalPoints.toString() ?? '—', titleColor, subtitleColor),
            ],
          ),
          const SizedBox(height: 20),

          // Close Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xff2d1f40) : const Color(0xfff0edf6),
                foregroundColor: isDark ? Colors.white : const Color(0xff1f1f2e),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatPoints(num? pts) {
    if (pts == null) return '—';
    if (pts is int || pts == pts.roundToDouble()) {
      return pts.toInt().toString();
    }
    return pts.toStringAsFixed(1);
  }

  Widget _statItem(String label, String value, Color valueColor, Color labelColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _posName(int? positionId) {
    switch (positionId) {
      case 1:
        return 'Goalkeeper';
      case 2:
        return 'Defender';
      case 3:
        return 'Midfielder';
      case 4:
        return 'Forward';
      default:
        return 'Player';
    }
  }
}

class PitchSkeleton extends StatelessWidget {
  const PitchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipPath(
          clipper: const _PerspectivePitchClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff0a6e35), Color(0xff12944b)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _FplPerspectivePitchPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
                  child: Column(
                    children: const [
                      _PitchSkeletonRow(count: 1),
                      SizedBox(height: 14),
                      _PitchSkeletonRow(count: 4),
                      SizedBox(height: 14),
                      _PitchSkeletonRow(count: 4),
                      SizedBox(height: 14),
                      _PitchSkeletonRow(count: 2),
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
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
          decoration: BoxDecoration(
            color: const Color(0xffc5ece1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const _PitchSkeletonRow(count: 4, isBench: true),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isBench ? 54 : 48,
                  height: isBench ? 58 : 54,
                  decoration: BoxDecoration(
                    color: isBench ? Colors.white24 : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    size: 36,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 78,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xff1f1f2e),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ),
                Container(
                  width: 78,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xff37003c),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
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
