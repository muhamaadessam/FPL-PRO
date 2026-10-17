import 'package:flutter/material.dart';

import '../layout/responsive.dart';

class PillTab {
  const PillTab({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;

  /// Small count shown after the label, e.g. the number of suggestions.
  final String? badge;
}

/// Segmented tab bar. Phones get equal-width tabs across the screen; wide
/// screens get a compact group at the start, like tabs on a website, instead
/// of a bar stretched across the whole window.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.indicatorColor,
    required this.labelColor,
    this.height = 42,
    this.fontSize = 12,
  });

  final TabController controller;
  final List<PillTab> tabs;
  final Color indicatorColor;
  final Color labelColor;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = Breakpoints.hasTopNav(context);

    final bar = Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: compact,
        tabAlignment: compact ? TabAlignment.start : null,
        labelPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 20)
            : null,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: indicatorColor,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: labelColor,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
        tabs: [
          for (final tab in tabs)
            Tab(
              child: Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, size: 16),
                  const SizedBox(width: 6),
                  if (compact)
                    Text(tab.label)
                  else
                    Flexible(
                      child: Text(tab.label, overflow: TextOverflow.ellipsis),
                    ),
                  if (tab.badge != null) ...[
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
                        tab.badge!,
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
        ],
      ),
    );

    if (!compact) return bar;
    return Align(alignment: AlignmentDirectional.centerStart, child: bar);
  }
}
