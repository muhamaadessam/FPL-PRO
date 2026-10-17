import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../themes/app_colors.dart';

class PillTab {
  const PillTab({required this.icon, required this.label, this.badge});

  final IconData icon;
  final String label;

  /// Small count shown after the label, e.g. the number of suggestions.
  final String? badge;
}

/// Tab bar that adapts to the screen. Phones get a segmented control with
/// equal-width tabs; wide screens get website-style tabs: labels at the start
/// with an underline on the selected one, matching the top navigation.
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
    if (compact) return _buildUnderlined(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
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
        tabs: [for (final tab in tabs) _tab(context, tab, compact: false)],
      ),
    );
  }

  Widget _buildUnderlined(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? AppColors.plMint
        : Theme.of(context).colorScheme.primary;
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsetsDirectional.only(end: 28),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: accent, width: 2.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
      dividerColor: AppColors.cardBorder(isDark),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelColor: AppColors.textPrimary(isDark),
      unselectedLabelColor: AppColors.textSecondary(isDark),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: fontSize + 1,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: fontSize + 1,
      ),
      tabs: [for (final tab in tabs) _tab(context, tab, compact: true)],
    );
  }

  Widget _tab(BuildContext context, PillTab tab, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Tab(
      height: compact ? 40 : null,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tab.icon, size: 16),
          const SizedBox(width: 6),
          if (compact)
            Text(tab.label)
          else
            Flexible(child: Text(tab.label, overflow: TextOverflow.ellipsis)),
          if (tab.badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
    );
  }
}
