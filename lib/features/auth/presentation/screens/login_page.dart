import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/cubit/locale_cubit.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/cubit/theme_cubit.dart';
import '../../../../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _glowController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final cardBorder = isDark ? AppColors.darkCardBorder : const Color(0xffeae6f3);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Radial Background Glows
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.plPurple : const Color(0xff6a1b9a))
                        .withValues(alpha: isDark ? 0.45 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.plMint.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.plCyan.withValues(alpha: isDark ? 0.10 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Controls (Theme & Language)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ThemeToggle(
                              isDark: isDark,
                              onToggle: () {
                                context.read<ThemeCubit>().setThemeMode(
                                  isDark ? ThemeMode.light : ThemeMode.dark,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _LanguageToggle(
                              isDark: isDark,
                              isArabic: l10n.isArabic,
                              onTap: () => context.read<LocaleCubit>().toggle(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hero Emblem
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: _HeroEmblem(isDark: isDark),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Brand Name: FPL PRO
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'FPL',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff00ff87),
                                    Color(0xff00cc66),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff00ff87)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff07030e),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Main Title
                      Text(
                        l10n.loginTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          l10n.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Features Highlights Card
                      _FeaturesCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 20),

                      // Primary Call-To-Action: Official Premier League Sign In
                      _OfficialSignInButton(
                        onPressed: () => context.push('/login/web'),
                        label: l10n.officialSignIn,
                        hint: l10n.officialWebViewHint,
                        isDark: isDark,
                        isArabic: l10n.isArabic,
                      ),
                      const SizedBox(height: 14),

                      // Security & Trust Notice
                      _SecurityBadge(
                        isDark: isDark,
                        badgeTitle: l10n.loginSecureBadge,
                        badgeDetails: l10n.loginSecureDetails,
                      ),
                      const SizedBox(height: 18),

                      // Divider with "OR"
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? AppColors.darkCardBorder
                                  : const Color(0xffe5e0f0),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              l10n.isArabic ? 'أو' : 'OR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? AppColors.darkCardBorder
                                  : const Color(0xffe5e0f0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Secondary Option: Guest Public Matches Preview
                      _GuestPreviewButton(
                        onPressed: () => context.push('/preview'),
                        label: l10n.publicPreview,
                        subtitle: l10n.publicPreviewSubtitle,
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isArabic: l10n.isArabic,
                      ),
                      const SizedBox(height: 22),

                      // Subtle Footer
                      Center(
                        child: Text(
                          'FPL PRO • PREMIER LEAGUE COMPANION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

/// Interactive Language switcher pill
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.isDark,
    required this.isArabic,
    required this.onTap,
  });

  final bool isDark;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.85)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardBorder
                  : const Color(0xffe2dced),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 15,
                color: isDark ? AppColors.plMint : AppColors.plMintDark,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'English' : 'العربية',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Theme mode switcher (Light / Dark)
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({
    required this.isDark,
    required this.onToggle,
  });

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.85)
                : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardBorder
                  : const Color(0xffe2dced),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 16,
            color: isDark ? const Color(0xffffb547) : AppColors.plPurple,
          ),
        ),
      ),
    );
  }
}

/// Central glowing hero emblem
class _HeroEmblem extends StatelessWidget {
  const _HeroEmblem({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.plMint.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.plPurple.withValues(alpha: isDark ? 0.65 : 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // Central Circular Emblem
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? const [
                        Color(0xff2d174d),
                        Color(0xff120824),
                      ]
                    : const [
                        Color(0xff37003c),
                        Color(0xff200024),
                      ],
                stops: const [0.3, 1.0],
              ),
              border: Border.all(
                color: AppColors.plMint.withValues(alpha: 0.7),
                width: 2.2,
              ),
            ),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.28,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.sports_soccer_rounded,
                    size: 48,
                    color: AppColors.plMint,
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

/// Highlights card showing key benefits
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({
    required this.isDark,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.l10n,
  });

  final bool isDark;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          _FeatureRow(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xff00ff87),
            iconBg: const Color(0xff00ff87).withValues(alpha: isDark ? 0.15 : 0.12),
            title: l10n.livePointsFeature,
            subtitle: l10n.livePointsFeatureDesc,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? AppColors.darkCardBorder : const Color(0xfff0ebf7),
              height: 1,
            ),
          ),
          _FeatureRow(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xff02efff),
            iconBg: const Color(0xff02efff).withValues(alpha: isDark ? 0.15 : 0.12),
            title: l10n.smartTransfersFeature,
            subtitle: l10n.smartTransfersFeatureDesc,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? AppColors.darkCardBorder : const Color(0xfff0ebf7),
              height: 1,
            ),
          ),
          _FeatureRow(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xffff005a),
            iconBg: const Color(0xffff005a).withValues(alpha: isDark ? 0.15 : 0.12),
            title: l10n.miniLeaguesFeature,
            subtitle: l10n.miniLeaguesFeatureDesc,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Official FPL Login Primary Button
class _OfficialSignInButton extends StatelessWidget {
  const _OfficialSignInButton({
    required this.onPressed,
    required this.label,
    required this.hint,
    required this.isDark,
    required this.isArabic,
  });

  final VoidCallback onPressed;
  final String label;
  final String hint;
  final bool isDark;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                Color(0xff00ff87),
                Color(0xff02efff),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff00ff87).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      color: Color(0xff06030c),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff06030c),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isArabic
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                      color: const Color(0xff06030c),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Official Security and privacy trust badge
class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge({
    required this.isDark,
    required this.badgeTitle,
    required this.badgeDetails,
  });

  final bool isDark;
  final String badgeTitle;
  final String badgeDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.5)
            : const Color(0xfff7f5fb),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkCardBorder.withValues(alpha: 0.7)
              : const Color(0xffece6f6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: isDark ? AppColors.plMint : AppColors.plMintDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.plMint : AppColors.plMintDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  badgeDetails,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guest matches and fixtures preview button
class _GuestPreviewButton extends StatelessWidget {
  const _GuestPreviewButton({
    required this.onPressed,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.isArabic,
  });

  final VoidCallback onPressed;
  final String label;
  final String subtitle;
  final bool isDark;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCardElevated
                      : const Color(0xfff0ebf7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sports_soccer_rounded,
                  color: isDark ? Colors.white : AppColors.plPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isArabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkIconMuted : const Color(0xff8e88a0),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
