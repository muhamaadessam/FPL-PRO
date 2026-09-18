import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/cubit/locale_cubit.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/cubit/theme_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../dashboard/presentation/cubit/home_preload_cubit.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = context.watch<ThemeCubit>().state;
    final authState = context.watch<AuthCubit>().state;
    final entryId = authState.session?.entryId;
    HomePreloadState? preload;
    try {
      preload = context.watch<HomePreloadCubit>().state;
    } on Object {
      // HomePreloadCubit is supplementary in settings
    }
    final entry = preload?.entry;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = AppColors.card(isDark);
    final cardBorder = isDark ? AppColors.darkCardBorder : const Color(0xfff0edf6);
    final titleColor = AppColors.textPrimary(isDark);
    final subColor = AppColors.textSecondary(isDark);
    final primaryIconColor = isDark ? AppColors.plMint : const Color(0xff37003c);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            l10n.settings,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
        ),

        // Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
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
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.darkBackground : Colors.white,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 28,
                        color: isDark ? AppColors.plMint : const Color(0xff37003c),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry?.name.isNotEmpty == true
                          ? entry!.name
                          : (entry?.playerFullName.isNotEmpty == true
                              ? entry!.playerFullName
                              : (entryId != null ? 'Entry #$entryId' : 'FPL Manager')),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry?.playerFullName.isNotEmpty == true && entry?.name.isNotEmpty == true
                          ? '${entry!.playerFullName} • Entry #${entry.id}'
                          : (entryId != null ? 'Entry #$entryId' : 'FPL Manager'),
                      style: TextStyle(
                        fontSize: 13,
                        color: subColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Theme Section
        Text(
          l10n.themeTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: subColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            children: [
              _ThemeOptionTile(
                icon: Icons.brightness_auto_rounded,
                title: l10n.themeSystem,
                isSelected: themeMode == ThemeMode.system,
                isDark: isDark,
                onTap: () => context
                    .read<ThemeCubit>()
                    .setThemeMode(ThemeMode.system),
              ),
              Divider(height: 1, indent: 48, color: cardBorder),
              _ThemeOptionTile(
                icon: Icons.light_mode_rounded,
                title: l10n.themeLight,
                isSelected: themeMode == ThemeMode.light,
                isDark: isDark,
                onTap: () => context
                    .read<ThemeCubit>()
                    .setThemeMode(ThemeMode.light),
              ),
              Divider(height: 1, indent: 48, color: cardBorder),
              _ThemeOptionTile(
                icon: Icons.dark_mode_rounded,
                title: l10n.themeDark,
                isSelected: themeMode == ThemeMode.dark,
                isDark: isDark,
                onTap: () => context
                    .read<ThemeCubit>()
                    .setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Language Section
        Text(
          l10n.language,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: subColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: ListTile(
            leading: Icon(Icons.translate_rounded, color: primaryIconColor),
            title: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'اللغة العربية'
                  : 'English',
              style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
            ),
            trailing: OutlinedButton(
              onPressed: () => context.read<LocaleCubit>().toggle(),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryIconColor,
                side: BorderSide(
                  color: isDark
                      ? AppColors.plMint.withValues(alpha: 0.6)
                      : const Color(0xff37003c).withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'Switch to EN'
                    : 'التبديل للعربية',
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sign Out Button
        FilledButton.tonalIcon(
          onPressed: () => context.read<AuthCubit>().logout(),
          icon: Icon(
            Icons.logout_rounded,
            color: isDark ? AppColors.darkAlertErrorText : const Color(0xffdc2626),
          ),
          label: Text(
            l10n.logout,
            style: TextStyle(
              color: isDark ? AppColors.darkAlertErrorText : const Color(0xffdc2626),
              fontWeight: FontWeight.w800,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkAlertErrorBg : const Color(0xfffee2e2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: isDark ? const BorderSide(color: AppColors.darkAlertErrorBorder) : BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = AppColors.textPrimary(isDark);
    final activeColor = isDark ? AppColors.plMint : const Color(0xff37003c);
    final inactiveColor = AppColors.textSecondary(isDark);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isSelected ? activeColor : inactiveColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: isDark ? AppColors.plMint : const Color(0xff00b55b),
            )
          : null,
    );
  }
}
