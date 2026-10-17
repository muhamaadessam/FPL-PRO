import 'package:flutter/material.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../fixtures/presentation/screens/fixtures_view.dart';
import '../../../leagues/presentation/screens/leagues_view.dart';
import '../../../recommendations/presentation/screens/recommendations_view.dart';
import '../../../settings/presentation/screens/settings_view.dart';
import '../../../team/presentation/screens/team_view.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  static const _settingsIndex = 4;

  int _selectedIndex = 0;

  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      const TeamView(),
      const RecommendationsView(),
      const FixturesView(),
      const LeaguesView(),
      const SettingsView(),
    ];
    final destinations = [
      _Destination(Icons.groups_outlined, Icons.groups_rounded, l10n.myTeam),
      _Destination(
        Icons.auto_awesome_outlined,
        Icons.auto_awesome_rounded,
        l10n.tips,
      ),
      _Destination(
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
        l10n.matches,
      ),
      _Destination(
        Icons.emoji_events_outlined,
        Icons.emoji_events_rounded,
        l10n.leagues,
      ),
      _Destination(
        Icons.settings_outlined,
        Icons.settings_rounded,
        l10n.settings,
      ),
    ];

    if (Breakpoints.hasTopNav(context)) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopNavBar(
                destinations: destinations,
                selectedIndex: _selectedIndex,
                settingsIndex: _settingsIndex,
                onSelected: _select,
              ),
              Expanded(child: pages[_selectedIndex]),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkNavBg : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkNavBorder : const Color(0x12000000),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Website-style header: brand on the start side, page links in the middle
/// and settings at the end.
class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.settingsIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final int settingsIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = destinations[settingsIndex];
    final settingsSelected = selectedIndex == settingsIndex;
    final accent = isDark
        ? AppColors.plMint
        : Theme.of(context).colorScheme.primary;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkNavBg : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkNavBorder : const Color(0x12000000),
            width: 0.8,
          ),
        ),
      ),
      padding: contentInsets(
        context,
        const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Row(
        children: [
          const _Brand(),
          const SizedBox(width: 28),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    if (index != settingsIndex)
                      _NavLink(
                        destination: destinations[index],
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: settings.label,
            onPressed: () => onSelected(settingsIndex),
            style: IconButton.styleFrom(
              backgroundColor: settingsSelected
                  ? accent.withValues(alpha: 0.14)
                  : null,
            ),
            icon: Icon(
              settingsSelected ? settings.selectedIcon : settings.icon,
              color: settingsSelected
                  ? accent
                  : AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff120824),
            border: Border.all(
              color: AppColors.plMint.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.28,
              child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'FPL',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.plMint,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'PRO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.plPurple,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? AppColors.plMint
        : Theme.of(context).colorScheme.primary;
    final color = selected ? accent : AppColors.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.textPrimary(isDark) : color,
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
