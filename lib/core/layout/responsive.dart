import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Width thresholds shared by every screen, so the app reads like a website
/// on wide browsers while keeping the phone layout untouched.
abstract final class Breakpoints {
  /// From here the shell swaps the bottom bar for a top navigation header.
  static const double topNav = 760;

  /// From here screens may place content side by side.
  static const double wide = 1080;

  /// Default reading width for page content.
  static const double content = 1200;

  /// Narrow width for forms and settings-like pages.
  static const double narrow = 760;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool hasTopNav(BuildContext context) => widthOf(context) >= topNav;

  static bool isWide(BuildContext context) => widthOf(context) >= wide;
}

/// Padding for a full-width scroll view that keeps its children inside a
/// centred column of [maxWidth], so the scrollbar stays at the window edge.
EdgeInsets contentInsets(
  BuildContext context,
  EdgeInsets base, {
  double maxWidth = Breakpoints.content,
}) {
  final width = Breakpoints.widthOf(context);
  final gutter = math.max(0.0, (width - maxWidth) / 2);
  return base.copyWith(left: base.left + gutter, right: base.right + gutter);
}

/// Centres [child] and caps its width; for content outside scroll views.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
